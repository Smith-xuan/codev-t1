"""
Generate function for multi-turn Verilog tool calling in slime.

This module implements a custom generation function that supports multi-turn
conversation with iverilog tool calls, similar to search-r1 but for Verilog code execution.

Adapted from verl framework's VerilogSimulationTool and search-r1's generate_with_search.py

Now uses SandboxFusion instead of custom iverilog_server for better performance and reliability.
"""

import asyncio
import os
import re
import logging
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime
import json
import requests
import time
import tempfile
import shutil
import uuid

from slime.rollout.sglang_rollout import GenerateState
from slime.utils.http_utils import post
from slime.utils.types import Sample

# Initialize logger first (before any imports that might use it)
logger = logging.getLogger(__name__)

# Import SandboxFusion utilities from verl
# Use importlib to avoid triggering verl/__init__.py which imports tensordict
try:
    import sys
    import importlib.util
    verl_path = "/nfs_global/projects/verl"
    
    # Directly import the module file to avoid triggering verl/__init__.py
    # This prevents importing tensordict which may not be available in slime environment
    utils_file_path = f"{verl_path}/verl/utils/reward_score/sandbox_fusion/utils.py"
    if os.path.exists(utils_file_path):
        # Set up module name to match expected package structure
        spec = importlib.util.spec_from_file_location(
            "verl.utils.reward_score.sandbox_fusion.utils", 
            utils_file_path
        )
        if spec is None or spec.loader is None:
            raise ImportError(f"Failed to create module spec from {utils_file_path}")
        
        verl_utils_module = importlib.util.module_from_spec(spec)
        # Add to sys.modules to allow relative imports if needed
        sys.modules["verl.utils.reward_score.sandbox_fusion.utils"] = verl_utils_module
        spec.loader.exec_module(verl_utils_module)
        _process_single_case = verl_utils_module._process_single_case
        SANDBOX_FUSION_AVAILABLE = True
        logger.info("Successfully imported SandboxFusion utilities using direct module import")
    else:
        raise ImportError(f"SandboxFusion utils file not found at {utils_file_path}")
except Exception as e:
    logger.warning(f"Failed to import SandboxFusion utilities: {e}. Falling back to iverilog_server.")
    logger.warning(f"Error details: {type(e).__name__}: {str(e)}")
    import traceback
    logger.debug(f"Traceback: {traceback.format_exc()}")
    SANDBOX_FUSION_AVAILABLE = False
    from local_iverilog_server import iverilog_execute

from verilog_utils import (
    extract_verilog_from_generation,
    clean_verilog_code,
    _parse_tool_call_json,
    _format_ok,
    _check_format_penalties,
    _check_format_reward,
    is_complete_verilog_code,
    run_function_with_timeout,
    verify_one_sample,
)

# Global statistics for tool calls
# These are module-level counters that track statistics across all tool calls in a rollout
_tool_call_stats = {
    "total_calls": 0,
    "compile_errors": 0,
    "empty_outputs": 0,
    "runtime_errors": 0,
    "successes": 0,
}

# Configuration for Iverilog-R1
IVERILOG_CONFIGS = {
    # ============== General Configuration ==============
    "max_turns": 6,  # Maximum number of tool call turns
    "iverilog_concurrency": 32,  # Maximum concurrent iverilog executions (reduced from 128 to prevent cpu starvation)
    # ============== Execution Method Configuration ==============
    # Options: "sandbox_fusion", "local_iverilog", "iverilog_server"
    # - "sandbox_fusion": Use SandboxFusion API (may have concurrency isolation issues)
    # - "local_iverilog": Direct local iverilog execution with UUID isolation (recommended for high concurrency)
    # - "iverilog_server": Use HTTP server (legacy, slower)
    "execution_method": os.getenv("IVERILOG_EXECUTION_METHOD", "sandbox_fusion"),
    # ============== SandboxFusion Configuration ==============
    # Use SandboxFusion URL (can be overridden by environment variable SANDBOX_URL)
    "sandbox_fusion_url": os.getenv("SANDBOX_URL", os.getenv("IVERILOG_URL", "http://127.0.0.1:8181/run_code")),
    "compile_timeout": 30,  # Compilation timeout in seconds (increased from 3s)
    "run_timeout": 10,  # Execution timeout in seconds (increased from 3s)
    # ============== Log Probability Collection ==============
    "return_logprob": True,  # Set to True to collect log probabilities for TIS metrics
    # ============== Reward Model Configuration ==============
    "format_score": 0.2,
}

# Create semaphore for concurrency control
# For SandboxFusion, we still need client-side concurrency control to avoid overloading the server
# The semaphore limit should match or be less than SandboxFusion server's max concurrent requests
if SANDBOX_FUSION_AVAILABLE:
    # SandboxFusion can handle high concurrency, but we limit client-side requests
    # to avoid overwhelming the server and ensure fair resource usage
    # Use a reasonable limit (e.g., 512 or based on server capacity)
    sandbox_concurrency = int(os.getenv("SANDBOX_FUSION_CONCURRENCY", str(IVERILOG_CONFIGS["iverilog_concurrency"])))
    SEMAPHORE = asyncio.Semaphore(sandbox_concurrency)
    logger.info(f"[iverilog-r1] Using SandboxFusion with client-side concurrency limit: {sandbox_concurrency}")
else:
    SEMAPHORE = asyncio.Semaphore(IVERILOG_CONFIGS["iverilog_concurrency"])


def postprocess_predictions(prediction: str):
    """
    Extract action and content from prediction string.
    
    IMPORTANT: For tool_call, this function extracts the COMPLETE code including testbench,
    as the code needs to be executed with iverilog. Testbench removal only happens in reward_func.
    
    Returns:
        Tuple of (action, content) where:
        - action: "tool_call", "answer", or None
        - content: extracted content (verilog code WITH testbench for tool_call, or answer text)
    """
    # DEBUG: Log prediction analysis
    logger.debug(f"[iverilog-r1] postprocess_predictions: prediction length={len(prediction)}, "
                f"has_tool_call_tag={('<tool_call>' in prediction)}, "
                f"has_tool_call_close={('</tool_call>' in prediction)}, "
                f"has_answer_tag={('<answer>' in prediction)}, "
                f"has_answer_close={('</answer>' in prediction)}")
    
    # Check for <tool_call> tags
    tool_call_pattern = r"<tool_call>\s*(\{.*?\})\s*</tool_call>"
    tool_call_match = re.search(tool_call_pattern, prediction, re.DOTALL)
    if tool_call_match:
        logger.debug(f"[iverilog-r1] postprocess_predictions: Found complete <tool_call> tag")
        try:
            import json
            json_str = tool_call_match.group(1).strip()
            logger.debug(f"[iverilog-r1] postprocess_predictions: JSON string length={len(json_str)}, "
                        f"preview={json_str[:200]}...")
            
            # Try to parse JSON - handle both complete and potentially truncated JSON
            try:
                tool_call_data = json.loads(json_str)
                # Normal JSON parsing succeeded
                tool_name = tool_call_data.get("name")
                arguments = tool_call_data.get("arguments", {})
                logger.debug(f"[iverilog-r1] postprocess_predictions: Parsed tool_name={tool_name}, "
                           f"arguments_keys={list(arguments.keys()) if isinstance(arguments, dict) else 'N/A'}")
                
                if tool_name == "verilog_simulator":
                    code = arguments.get("code", "")
                    if code.strip():
                        logger.debug(f"[iverilog-r1] postprocess_predictions: Extracted code length={len(code)}, "
                                   f"code_preview={code[:200]}...")
                        # IMPORTANT: Keep testbench for tool execution
                        return "tool_call", code
                    else:
                        logger.warning(f"[iverilog-r1] postprocess_predictions: tool_name=verilog_simulator but code is empty")
            except json.JSONDecodeError as e:
                logger.debug(f"[iverilog-r1] postprocess_predictions: JSON parsing failed: {e}, "
                           f"trying regex extraction for truncated JSON")
                # If JSON parsing fails, try to extract code using regex (for truncated JSON)
                # Use _parse_tool_call_json with keep_testbench=True
                code = _parse_tool_call_json(json_str, keep_testbench=True)
                if code and "module" in code.lower():
                    logger.debug(f"[iverilog-r1] postprocess_predictions: Extracted code via regex, length={len(code)}")
                    # IMPORTANT: Keep testbench for tool execution
                    return "tool_call", code
                else:
                    logger.warning(f"[iverilog-r1] postprocess_predictions: Regex extraction failed or no module found")
        except (KeyError, AttributeError):
            # Fallback: try regex extraction
            try:
                json_str = tool_call_match.group(1).strip()
                code = _parse_tool_call_json(json_str, keep_testbench=True)
                if code and "module" in code.lower():
                    # IMPORTANT: Keep testbench for tool execution
                    return "tool_call", code
            except Exception:
                pass
    
    # Check for incomplete <tool_call> at the end (truncated)
    incomplete_tool_call_pattern = r"<tool_call>\s*(\{.*?)$"
    incomplete_tool_call_match = re.search(incomplete_tool_call_pattern, prediction, re.DOTALL)
    if incomplete_tool_call_match:
        logger.debug(f"[iverilog-r1] postprocess_predictions: Found incomplete <tool_call> tag (truncated)")
        try:
            json_str = incomplete_tool_call_match.group(1).strip()
            code = _parse_tool_call_json(json_str, keep_testbench=True)
            if code and "module" in code.lower():
                logger.debug(f"[iverilog-r1] postprocess_predictions: Extracted code from incomplete tag, length={len(code)}")
                # IMPORTANT: Keep testbench for tool execution
                return "tool_call", code
            else:
                logger.warning(f"[iverilog-r1] postprocess_predictions: Incomplete tag extraction failed or no module found")
        except Exception as e:
            logger.warning(f"[iverilog-r1] postprocess_predictions: Exception extracting from incomplete tag: {e}")
            pass
    
    # Check for <answer> tags
    answer_pattern = r"<answer>([\s\S]*?)</answer>"
    answer_match = re.search(answer_pattern, prediction, re.DOTALL)
    if answer_match:
        content = answer_match.group(1).strip()
        logger.debug(f"[iverilog-r1] postprocess_predictions: Found complete <answer> tag, content_length={len(content)}")
        return "answer", content
    
    # Check for incomplete <answer> at the end
    incomplete_answer_pattern = r"<answer>([\s\S]*?)$"
    incomplete_answer_match = re.search(incomplete_answer_pattern, prediction, re.DOTALL)
    if incomplete_answer_match:
        content = incomplete_answer_match.group(1).strip()
        logger.debug(f"[iverilog-r1] postprocess_predictions: Found incomplete <answer> tag, content_length={len(content)}")
        return "answer", content
    
    logger.debug(f"[iverilog-r1] postprocess_predictions: No action found, returning None")
    return None, ""


def postprocess_responses(resp: str) -> str:
    """
    Post-process response to ensure tag completeness.
    Only used when IVERILOG_CONFIGS["return_logprob"] is False.
    """
    # Handle <tool_call> tags
    if "<tool_call>" in resp:
        tool_call_pattern = r"<tool_call>\s*\{.*?\}\s*</tool_call>"
        matches = list(re.finditer(tool_call_pattern, resp, re.DOTALL))
        if matches:
            last_match = matches[-1]
            return resp[: last_match.end()]
    
    # Handle <answer> tags
    if "</answer>" in resp:
        return resp.split("</answer>")[0] + "</answer>"
    
    return resp


def _save_empty_output_code(code: str, metadata: Dict[str, Any], output_dir: str = None) -> str:
    """
    Save Verilog code that resulted in empty output for debugging.
    
    Args:
        code: The Verilog code that was executed
        metadata: The metadata returned from SandboxFusion
        output_dir: Directory to save the code file (default: ./empty_output_codes)
    
    Returns:
        Path to the saved file
    """
    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(__file__), "empty_output_codes")
    
    # Create directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Generate filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    filename = f"empty_output_{timestamp}.v"
    filepath = os.path.join(output_dir, filename)
    
    # Prepare content to save
    content = f"""// Verilog code that resulted in empty output
// Saved at: {datetime.now().isoformat()}
// 
// Metadata:
//   status: {metadata.get('status', 'N/A')}
//   api_status: {metadata.get('api_status', 'N/A')}
//   compile_status: {metadata.get('compile_status', 'N/A')}
//   run_status: {metadata.get('run_status', 'N/A')}
//   compile_stderr: {metadata.get('compile_stderr', 'N/A')[:200] if metadata.get('compile_stderr') else 'N/A'}
//   stdout: {metadata.get('stdout', 'N/A')[:200] if metadata.get('stdout') else 'N/A'}
//   stderr: {metadata.get('stderr', 'N/A')[:200] if metadata.get('stderr') else 'N/A'}
//   exit_code: {metadata.get('exit_code', 'N/A')}
//
// Full metadata (JSON):
{json.dumps(metadata, indent=2, default=str)}

// ============================================================================
// Verilog Code:
// ============================================================================

{code}
"""
    
    # Save to file
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    logger.info(f"[iverilog-r1] Saved empty output code to: {filepath}")
    return filepath


async def _call_sandbox_fusion_direct(
    sandbox_fusion_url: str,
    code: str,
    compile_timeout: int,
    run_timeout: int,
    language: str = "verilog",
    semaphore: Optional[asyncio.Semaphore] = None
) -> tuple[Optional[Dict[str, Any]], Optional[str]]:
    """
    Directly call SandboxFusion API without going through verl's _process_single_case.
    This allows us to have more control and better debugging.
    
    Supports high concurrency through asyncio and optional semaphore for rate limiting.
    
    Args:
        sandbox_fusion_url: The URL of the SandboxFusion API
        code: The Verilog code to execute
        compile_timeout: Compile timeout in seconds
        run_timeout: Run timeout in seconds
        language: Language (default: "verilog")
        semaphore: Optional asyncio.Semaphore for concurrency control
    
    Returns:
        Tuple of (api_response, error_message)
    """
    payload = {
        "compile_timeout": compile_timeout,
        "run_timeout": run_timeout,
        "code": code,
        "stdin": "",
        "language": language,
        "files": {},
        "fetch_files": [],
    }
    
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    request_timeout = compile_timeout + run_timeout + 10  # Add 10s buffer
    
    # Use semaphore for concurrency control if provided
    async def _make_request():
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(
            None,
            lambda: requests.post(
                sandbox_fusion_url,
                headers=headers,
                json=payload,
                timeout=request_timeout,
            )
        )
        return response
    
    try:
        # Acquire semaphore if provided (for concurrency control)
        if semaphore:
            async with semaphore:
                response = await _make_request()
        else:
            response = await _make_request()
        
        response.raise_for_status()
        api_response = response.json()
        
        # DEBUG: Log full API response for empty output cases
        if api_response.get("status") == "Success":
            run_result = api_response.get("run_result", {})
            stdout = run_result.get("stdout", "")
            stderr = run_result.get("stderr", "")
            if not stdout and not stderr:
                logger.warning(f"[iverilog-r1] Direct API call: Success but stdout and stderr are empty. "
                             f"Full response keys: {list(api_response.keys())}, "
                             f"run_result keys: {list(run_result.keys()) if run_result else 'None'}, "
                             f"run_result: {json.dumps(run_result, indent=2)[:500]}")
        
        return api_response, None
        
    except requests.exceptions.Timeout as e:
        error_msg = f"API Request Timeout: {e}"
        logger.error(f"[iverilog-r1] Direct API call timeout: {error_msg}")
        return None, error_msg
    except requests.exceptions.RequestException as e:
        error_msg = f"API Request Error: {e}"
        logger.error(f"[iverilog-r1] Direct API call error: {error_msg}")
        return None, error_msg
    except json.JSONDecodeError as e:
        error_msg = f"JSON Decode Error: {e}"
        logger.error(f"[iverilog-r1] Direct API call JSON error: {error_msg}")
        return None, error_msg
    except Exception as e:
        error_msg = f"Unexpected Error: {e}"
        logger.error(f"[iverilog-r1] Direct API call unexpected error: {error_msg}")
        return None, error_msg


async def _execute_iverilog_local(
    code: str,
    compile_timeout: int,
    run_timeout: int,
    semaphore: Optional[asyncio.Semaphore] = None
) -> tuple[Optional[Dict[str, Any]], Optional[str]]:
    """
    Execute Verilog code directly using local iverilog with UUID-based isolation.
    Each request gets a unique temporary directory to avoid file conflicts in high concurrency.
    
    Safety features:
    - UUID-based temporary directory isolation
    - Strict timeout (3 seconds default)
    - Zombie process prevention (proper process cleanup)
    - Output size limit (50KB max, returns error if exceeded)
    - Automatic temporary file cleanup
    
    Args:
        code: The Verilog code to execute
        compile_timeout: Compilation timeout in seconds
        run_timeout: Execution timeout in seconds
        semaphore: Optional asyncio.Semaphore for concurrency control
    
    Returns:
        Tuple of (api_response, error_message) in SandboxFusion format
    """
    MAX_OUTPUT_BYTES = 50 * 1024  # 50KB limit as requested
    MAX_TOTAL_OUTPUT_BYTES = 50 * 1024  # Total output limit
    
    # Use shared filesystem for temporary directories
    iverilog_tmp_base = "/nfs_global/tmp/iverilog_tmp"
    os.makedirs(iverilog_tmp_base, exist_ok=True)
    
    # Create unique temporary directory for this execution
    # Using UUID ensures no conflicts even under high concurrency
    tmp_dir = None
    compile_process = None
    run_process = None
    
    try:
        # Create a unique temporary directory with UUID
        tmp_dir = tempfile.mkdtemp(prefix=f"iverilog_{uuid.uuid4().hex[:8]}_", dir=iverilog_tmp_base)
        verilog_file = os.path.join(tmp_dir, "design.sv")
        
        # Write code to file
        with open(verilog_file, 'w', encoding='utf-8') as f:
            f.write(code)
        
        # Compile command: iverilog -Wall -Winfloop -Wno-timescale -g2012 -s testbench -o test.vvp design.sv
        compile_cmd = [
            "iverilog",
            "-Wall",
            "-Winfloop",
            "-Wno-timescale",
            "-g2012",
            "-s", "testbench",
            "-o", os.path.join(tmp_dir, "test.vvp"),
            verilog_file
        ]
        
        async def _compile():
            nonlocal compile_process
            compile_process = await asyncio.create_subprocess_exec(
                *compile_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=tmp_dir
            )
            
            try:
                compile_stdout, compile_stderr = await asyncio.wait_for(
                    compile_process.communicate(),
                    timeout=compile_timeout
                )
            except asyncio.TimeoutError:
                # Kill the process on timeout to prevent zombie
                try:
                    compile_process.kill()
                    await asyncio.wait_for(compile_process.wait(), timeout=2)
                except Exception:
                    pass
                raise
            
            # Limit output size
            compile_stdout = compile_stdout.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES]
            compile_stderr = compile_stderr.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES]
            
            return {
                "status": "Finished" if compile_process.returncode == 0 else "Error",
                "return_code": compile_process.returncode,
                "stdout": compile_stdout,
                "stderr": compile_stderr,
                "execution_time": 0.0,
            }, compile_process.returncode
        
        # Acquire semaphore if provided
        if semaphore:
            async with semaphore:
                compile_result, compile_rc = await _compile()
        else:
            compile_result, compile_rc = await _compile()
        
        # If compilation failed, return early
        if compile_rc != 0:
            api_response = {
                "status": "Failed",
                "message": "Compilation failed",
                "compile_result": compile_result,
                "run_result": None,
                "files": {},
            }
            return api_response, None
        
        # Run command: vvp -n test.vvp
        run_cmd = ["vvp", "-n", os.path.join(tmp_dir, "test.vvp")]
        
        async def _run():
            nonlocal run_process
            run_process = await asyncio.create_subprocess_exec(
                *run_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=tmp_dir
            )
            
            try:
                run_stdout, run_stderr = await asyncio.wait_for(
                    run_process.communicate(),
                    timeout=run_timeout
                )
            except asyncio.TimeoutError:
                # Kill the process on timeout to prevent zombie
                try:
                    run_process.kill()
                    await asyncio.wait_for(run_process.wait(), timeout=2)
                except Exception:
                    pass
                
                # Try to read any remaining output
                try:
                    remaining_stdout, remaining_stderr = await asyncio.wait_for(
                        run_process.communicate(),
                        timeout=0.5
                    )
                    run_stdout = remaining_stdout if remaining_stdout else b""
                    run_stderr = remaining_stderr if remaining_stderr else b""
                except Exception:
                    run_stdout = b""
                    run_stderr = b""
                
                # Decode and limit output size
                run_stdout_str = run_stdout.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES]
                run_stderr_str = run_stderr.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES]
                
                return {
                    "status": "TimeLimitExceeded",
                    "return_code": 1,
                    "stdout": run_stdout_str,
                    "stderr": f"Execution timeout after {run_timeout} seconds" + (f"\nPartial stderr: {run_stderr_str[:200]}" if run_stderr_str else ""),
                    "execution_time": run_timeout,
                }
            
            # Decode output
            run_stdout_str = run_stdout.decode("utf-8", errors="ignore")
            run_stderr_str = run_stderr.decode("utf-8", errors="ignore")
            
            # Check total output size (stdout + stderr)
            total_output_size = len(run_stdout_str.encode('utf-8')) + len(run_stderr_str.encode('utf-8'))
            if total_output_size > MAX_TOTAL_OUTPUT_BYTES:
                # Truncate output and return error
                run_stdout_str = run_stdout_str[:MAX_OUTPUT_BYTES]
                run_stderr_str = f"Output too large ({total_output_size} bytes > {MAX_TOTAL_OUTPUT_BYTES} bytes). Output truncated.\n" + run_stderr_str[:MAX_OUTPUT_BYTES]
                return {
                    "status": "Error",
                    "return_code": 1,
                    "stdout": run_stdout_str,
                    "stderr": run_stderr_str,
                    "execution_time": 0.0,
                }
            
            # Limit individual output sizes
            run_stdout_str = run_stdout_str[:MAX_OUTPUT_BYTES]
            run_stderr_str = run_stderr_str[:MAX_OUTPUT_BYTES]
            
            return {
                "status": "Finished" if run_process.returncode == 0 else "Error",
                "return_code": run_process.returncode,
                "stdout": run_stdout_str,
                "stderr": run_stderr_str,
                "execution_time": 0.0,
            }
        
        # Acquire semaphore if provided (for run phase)
        if semaphore:
            async with semaphore:
                run_result = await _run()
        else:
            run_result = await _run()
        
        # Format response in SandboxFusion format
        api_response = {
            "status": "Success" if run_result["status"] == "Finished" else "Failed",
            "message": "",
            "compile_result": compile_result,
            "run_result": run_result,
            "files": {},
        }
        
        return api_response, None
        
    except asyncio.TimeoutError:
        error_msg = f"Compilation timeout after {compile_timeout} seconds"
        logger.error(f"[iverilog-r1] Local iverilog timeout: {error_msg}")
        return None, error_msg
    except Exception as e:
        error_msg = f"Unexpected error: {e}"
        logger.error(f"[iverilog-r1] Local iverilog error: {error_msg}")
        import traceback
        logger.debug(f"Traceback: {traceback.format_exc()}")
        return None, error_msg
    finally:
        # Ensure processes are terminated to prevent zombies
        if compile_process and compile_process.returncode is None:
            try:
                compile_process.kill()
                await asyncio.wait_for(compile_process.wait(), timeout=1)
            except Exception:
                pass
        
        if run_process and run_process.returncode is None:
            try:
                run_process.kill()
                await asyncio.wait_for(run_process.wait(), timeout=1)
            except Exception:
                pass
        
        # Clean up temporary directory
        if tmp_dir and os.path.exists(tmp_dir):
            try:
                shutil.rmtree(tmp_dir, ignore_errors=True)
            except Exception as e:
                logger.warning(f"[iverilog-r1] Failed to clean up temp directory {tmp_dir}: {e}")


def _parse_sandbox_fusion_response(api_response: Dict[str, Any]) -> Dict[str, Any]:
    """
    Parse SandboxFusion API response into metadata format similar to _process_single_case.
    
    Args:
        api_response: The raw API response from SandboxFusion
    
    Returns:
        Metadata dictionary in the same format as _process_single_case
    """
    metadata = {
        "case_index": 0,
        "input": "",
        "expected_output": None,
        "api_request_error": None,
        "api_response": api_response,
        "status": "unknown",
        "stdout": None,
        "stderr": None,
        "exit_code": None,
        "duration": None,
        "compile_duration": None,
        "compile_stderr": None,
        "api_status": None,
        "compile_status": None,
        "run_status": None,
    }
    
    if not api_response:
        metadata["status"] = "api_error"
        return metadata
    
    metadata["api_status"] = api_response.get("status")
    compile_result = api_response.get("compile_result")
    run_result = api_response.get("run_result")
    
    # Extract compile information
    if compile_result:
        metadata["compile_status"] = compile_result.get("status")
        metadata["compile_duration"] = compile_result.get("execution_time")
        metadata["compile_stderr"] = compile_result.get("stderr")
    
    # Extract run information
    if run_result:
        metadata["run_status"] = run_result.get("status")
        metadata["stdout"] = run_result.get("stdout")
        metadata["stderr"] = run_result.get("stderr")
        metadata["exit_code"] = run_result.get("return_code")
        metadata["duration"] = run_result.get("execution_time")
    
    # Determine status
    api_status = metadata["api_status"]
    
    if api_status == "SandboxError":
        metadata["status"] = "sandbox_error"
    elif api_status == "Failed":
        is_compile_error = compile_result and (
            metadata["compile_status"] in ["Error", "TimeLimitExceeded"] or
            (metadata["compile_status"] == "Finished" and compile_result.get("return_code") != 0)
        )
        if is_compile_error:
            if metadata["compile_status"] == "TimeLimitExceeded":
                metadata["status"] = "compile_timeout"
            else:
                metadata["status"] = "compile_error"
        elif run_result:
            is_runtime_error = (
                metadata["run_status"] == "TimeLimitExceeded" or
                metadata["run_status"] == "Error" or
                (metadata["run_status"] == "Finished" and run_result.get("return_code") != 0)
            )
            if is_runtime_error:
                if metadata["run_status"] == "TimeLimitExceeded":
                    metadata["status"] = "timeout"
                else:
                    metadata["status"] = "runtime_error"
            else:
                metadata["status"] = "unknown_failure"
        else:
            metadata["status"] = "unknown_failure_state"
    elif api_status == "Success":
        if run_result and metadata["run_status"] == "Finished":
            # Check if output matches expected (we don't have expected_output, so mark as success/wrong_answer)
            actual_output = metadata["stdout"] if metadata["stdout"] is not None else ""
            # Since we don't have expected_output, we'll mark as success if no errors
            if run_result.get("return_code") == 0:
                metadata["status"] = "success"
            else:
                metadata["status"] = "runtime_error"
        else:
            metadata["status"] = "unexpected_success_state"
    else:
        metadata["status"] = f"unknown_api_status_{api_status}"
    
    return metadata


async def execute_predictions(prediction: str) -> tuple[str, bool]:
    """
    Execute predictions and return results.
    
    Uses SandboxFusion (via verl's _process_single_case) if available,
    otherwise falls back to iverilog_server.
    
    Args:
        prediction: The model's prediction string
    
    Returns:
        Tuple of (next_obs, done) where:
        - next_obs: Next observation to append to the conversation
        - done: Whether the conversation is complete
    """
    # DEBUG: Log prediction for debugging
    logger.debug(f"[iverilog-r1] execute_predictions: prediction length={len(prediction)}, "
                f"preview={prediction[:200]}...")
    
    action, content = postprocess_predictions(prediction)
    
    # DEBUG: Log extracted action and content
    logger.debug(f"[iverilog-r1] execute_predictions: action={action}, "
                f"content_length={len(content) if content else 0}, "
                f"content_preview={content[:100] if content else 'None'}...")
    
    if action == "tool_call":
        # Content is the Verilog code (extracted by postprocess_predictions)
        code = content.strip()
        if code:
            # Count tool call
            _tool_call_stats["total_calls"] += 1
            # Log the URL being used for debugging (only once per process, only if not using SandboxFusion)
            if not hasattr(execute_predictions, '_logged_url'):
                if not SANDBOX_FUSION_AVAILABLE:
                    logger.warning(f"[iverilog-r1] SandboxFusion not available, using iverilog server URL: {IVERILOG_CONFIGS.get('iverilog_url', 'N/A')}")
                execute_predictions._logged_url = True
            
            # Check execution method preference
            execution_method = IVERILOG_CONFIGS.get("execution_method", "sandbox_fusion")
            
            if execution_method == "local_iverilog":
                # Use local iverilog with UUID-based isolation (recommended for high concurrency)
                logger.debug(f"[iverilog-r1] Using local iverilog execution with UUID isolation")
                api_response, error_msg = await _execute_iverilog_local(
                    code,
                    IVERILOG_CONFIGS["compile_timeout"],
                    IVERILOG_CONFIGS["run_timeout"],
                    semaphore=SEMAPHORE
                )
                
                if error_msg:
                    metadata = {
                        "status": "api_error",
                        "api_request_error": error_msg,
                        "api_status": "Failed",
                        "compile_status": None,
                        "run_status": None,
                        "stdout": None,
                        "stderr": None,
                    }
                    result_status = -1
                else:
                    # Parse API response into metadata format
                    metadata = _parse_sandbox_fusion_response(api_response)
                    # Derive result_status from metadata for consistency
                    status = metadata.get("status", "unknown")
                    if status == "success":
                        result_status = 0
                    elif status in ["compile_error", "compile_timeout"]:
                        result_status = 1
                    elif status in ["runtime_error", "timeout"]:
                        result_status = 2
                    else:
                        result_status = -1
                
                # Format output for local_iverilog (same logic as sandbox_fusion)
                # Check all possible cases to ensure output is never empty
                output = None
                
                # Priority 1: Check for compile errors
                if metadata.get("compile_status") == "Finished" and metadata.get("compile_stderr"):
                    compile_stderr = metadata.get("compile_stderr", "") or ""
                    if compile_stderr.strip():
                        output = f"Compile Error:\n{compile_stderr.strip()}"
                        _tool_call_stats["compile_errors"] += 1
                    else:
                        if metadata.get("status") == "compile_error":
                            output = "Compile Error: (no error message)"
                            _tool_call_stats["compile_errors"] += 1
                
                # Priority 2: Check for compile timeout
                if not output and metadata.get("compile_status") == "TimeLimitExceeded":
                    output = f"Compilation timeout after {IVERILOG_CONFIGS['compile_timeout']} seconds"
                    _tool_call_stats["compile_errors"] += 1
                
                # Priority 3: Check for compile error status
                if not output and metadata.get("compile_status") == "Error":
                    compile_stderr = metadata.get("compile_stderr", "") or ""
                    output = f"Compile Error:\n{compile_stderr.strip()}" if compile_stderr.strip() else "Compile Error: (no error message)"
                    _tool_call_stats["compile_errors"] += 1
                
                # Priority 4: Check for successful run
                if not output and metadata.get("run_status") == "Finished":
                    stdout = metadata.get("stdout", "") or ""
                    stderr = metadata.get("stderr", "") or ""
                    if stdout and stderr:
                        output = stdout + f"\nRuntime Error:\n{stderr}"
                        _tool_call_stats["runtime_errors"] += 1
                    elif stdout:
                        output = stdout
                        _tool_call_stats["successes"] += 1
                    elif stderr:
                        output = f"Runtime Error:\n{stderr}"
                        _tool_call_stats["runtime_errors"] += 1
                    else:
                        output = "Simulation completed with no output"
                        _tool_call_stats["empty_outputs"] += 1
                        logger.warning(f"[iverilog-r1] Local iverilog: Success but output is empty, using fallback")
                        try:
                            saved_path = _save_empty_output_code(code, metadata)
                            logger.warning(f"[iverilog-r1] Saved code to: {saved_path}")
                        except Exception as e:
                            logger.error(f"[iverilog-r1] Failed to save empty output code: {e}")
                
                # Priority 5: Check for runtime timeout
                if not output and metadata.get("run_status") == "TimeLimitExceeded":
                    output = f"Execution timeout after {IVERILOG_CONFIGS['run_timeout']} seconds"
                    _tool_call_stats["runtime_errors"] += 1
                
                # Priority 6: Check for runtime error
                if not output and metadata.get("run_status") == "Error":
                    stderr = metadata.get("stderr", "") or ""
                    output = f"Runtime Error:\n{stderr}" if stderr else "Runtime Error: (no error message)"
                    _tool_call_stats["runtime_errors"] += 1
                
                # Priority 7: Check for API request errors
                if not output and metadata.get("api_request_error"):
                    output = f"API Request Error: {metadata.get('api_request_error')}"
                
                # Priority 8: Use metadata status as fallback
                if not output and metadata.get("status"):
                    status = metadata.get("status", "unknown")
                    output = f"Execution status: {status}"
                
                # Priority 9: Last resort
                if not output:
                    output = f"Execution failed (status: {metadata.get('status', 'unknown')}, "
                    output += f"api_status: {metadata.get('api_status', 'unknown')}, "
                    output += f"compile_status: {metadata.get('compile_status', 'unknown')}, "
                    output += f"run_status: {metadata.get('run_status', 'unknown')})"
                
                # Final safety check
                if not output or not output.strip():
                    output = f"Execution completed but no output available (status: {metadata.get('status', 'unknown') if metadata else 'no metadata'})"
            elif SANDBOX_FUSION_AVAILABLE and execution_method == "sandbox_fusion":
                # Option to use direct API call (bypass verl's _process_single_case)
                # This gives us more control and better debugging
                USE_DIRECT_API = os.getenv("USE_DIRECT_SANDBOX_API", "false").lower() == "true"
                
                if USE_DIRECT_API:
                    # Direct API call - bypass verl's _process_single_case
                    # Pass semaphore for concurrency control
                    logger.debug(f"[iverilog-r1] Using direct SandboxFusion API call")
                    api_response, error_msg = await _call_sandbox_fusion_direct(
                        IVERILOG_CONFIGS["sandbox_fusion_url"],
                        code,
                        IVERILOG_CONFIGS["compile_timeout"],
                        IVERILOG_CONFIGS["run_timeout"],
                        "verilog",
                        semaphore=SEMAPHORE  # Use semaphore for concurrency control
                    )
                    
                    if error_msg:
                        metadata = {
                            "status": "api_error",
                            "api_request_error": error_msg,
                            "api_status": "Failed",
                            "compile_status": None,
                            "run_status": None,
                            "stdout": None,
                            "stderr": None,
                        }
                        result_status = -1  # Error status
                    else:
                        # Parse API response into metadata format
                        metadata = _parse_sandbox_fusion_response(api_response)
                        # Derive result_status from metadata for consistency
                        status = metadata.get("status", "unknown")
                        if status == "success":
                            result_status = 0
                        elif status in ["compile_error", "compile_timeout"]:
                            result_status = 1
                        elif status in ["runtime_error", "timeout"]:
                            result_status = 2
                        else:
                            result_status = -1
                        
                        # DEBUG: Log full response for empty output cases
                        if metadata.get("run_status") == "Finished":
                            stdout = metadata.get("stdout", "") or ""
                            stderr = metadata.get("stderr", "") or ""
                            if not stdout and not stderr:
                                logger.warning(f"[iverilog-r1] Direct API: Empty output detected. "
                                             f"Full api_response: {json.dumps(api_response, indent=2)[:1000]}")
                else:
                    # Use verl's _process_single_case (original method)
                    import concurrent.futures
                    loop = asyncio.get_event_loop()
                    
                    # Use a thread pool executor to run the synchronous _process_single_case
                    with concurrent.futures.ThreadPoolExecutor() as executor:
                        # _process_single_case returns (result_status, metadata)
                        # We only need metadata for formatting the output
                        result_status, metadata = await loop.run_in_executor(
                            executor,
                            _process_single_case,
                            0,  # case_index
                            "",  # stdin_data
                            None,  # expected_output
                            IVERILOG_CONFIGS["sandbox_fusion_url"],
                            code,
                            max(IVERILOG_CONFIGS["compile_timeout"], IVERILOG_CONFIGS["run_timeout"]),  # timeout
                            "verilog",  # language
                            None,  # concurrent_semaphore (SandboxFusion handles concurrency internally)
                            None,  # fn_name
                        )
                
                # Only log detailed metadata for errors or warnings
                if not metadata:
                    logger.error(f"[iverilog-r1] SandboxFusion metadata is None!")
                elif metadata.get("status") not in ["success", "wrong_answer"]:
                    # Log detailed metadata only for non-success cases
                    logger.warning(f"[iverilog-r1] SandboxFusion result: result_status={result_status}, "
                                 f"status={metadata.get('status', 'N/A')}, "
                                 f"api_status={metadata.get('api_status', 'N/A')}, "
                                 f"compile_status={metadata.get('compile_status', 'N/A')}, "
                                 f"run_status={metadata.get('run_status', 'N/A')}")
                
                # Format the result similar to sandbox fusion output
                # Check all possible cases to ensure output is never empty
                # IMPORTANT: Check compile errors FIRST, before checking run_status
                # This ensures compile errors are always returned as feedback
                output = None
                
                # Priority 1: Check for compile errors (even if run_status exists)
                if metadata.get("compile_status") == "Finished" and metadata.get("compile_stderr"):
                    compile_stderr = metadata.get("compile_stderr", "") or ""
                    if compile_stderr.strip():
                        output = f"Compile Error:\n{compile_stderr.strip()}"
                        # Count compile error but don't log details
                        _tool_call_stats["compile_errors"] += 1
                    else:
                        # compile_stderr exists but is empty/whitespace, check if there's a compile error status
                        if metadata.get("status") == "compile_error":
                            output = "Compile Error: (no error message)"
                            # Count compile error but don't log details
                            _tool_call_stats["compile_errors"] += 1
                
                # Priority 2: Check for compile timeout
                if not output and metadata.get("compile_status") == "TimeLimitExceeded":
                    output = f"Compilation timeout after {IVERILOG_CONFIGS['compile_timeout']} seconds"
                    # Count compile error but don't log details
                    _tool_call_stats["compile_errors"] += 1
                
                # Priority 3: Check for compile error status (even if compile_stderr is missing)
                if not output and metadata.get("compile_status") == "Error":
                    compile_stderr = metadata.get("compile_stderr", "") or ""
                    output = f"Compile Error:\n{compile_stderr.strip()}" if compile_stderr.strip() else "Compile Error: (no error message)"
                    # Count compile error but don't log details
                    _tool_call_stats["compile_errors"] += 1
                
                # Priority 4: Check for successful run (only if no compile errors)
                if not output and metadata.get("run_status") == "Finished":
                    stdout = metadata.get("stdout", "") or ""
                    stderr = metadata.get("stderr", "") or ""
                    # Combine stdout and stderr
                    if stdout and stderr:
                        output = stdout + f"\nRuntime Error:\n{stderr}"
                        _tool_call_stats["runtime_errors"] += 1
                    elif stdout:
                        output = stdout
                        _tool_call_stats["successes"] += 1
                    elif stderr:
                        output = f"Runtime Error:\n{stderr}"
                        _tool_call_stats["runtime_errors"] += 1
                    else:
                        # Both stdout and stderr are empty - check if there's compile error info we missed
                        if metadata.get("compile_stderr"):
                            compile_stderr = metadata.get("compile_stderr", "") or ""
                            if compile_stderr.strip():
                                output = f"Compile Error:\n{compile_stderr.strip()}"
                                # Count compile error but don't log details
                                _tool_call_stats["compile_errors"] += 1
                            else:
                                output = "Simulation completed with no output"
                                # Count empty output and log (keep this log as requested)
                                _tool_call_stats["empty_outputs"] += 1
                                logger.warning(f"[iverilog-r1] SandboxFusion: Success but output is empty, using fallback")
                                # Save code for debugging
                                try:
                                    saved_path = _save_empty_output_code(code, metadata)
                                    logger.warning(f"[iverilog-r1] Saved code to: {saved_path}")
                                except Exception as e:
                                    logger.error(f"[iverilog-r1] Failed to save empty output code: {e}")
                        else:
                            output = "Simulation completed with no output"
                            # Count empty output and log (keep this log as requested)
                            _tool_call_stats["empty_outputs"] += 1
                            logger.warning(f"[iverilog-r1] SandboxFusion: Success but output is empty, using fallback")
                            # Save code for debugging
                            try:
                                saved_path = _save_empty_output_code(code, metadata)
                                logger.warning(f"[iverilog-r1] Saved code to: {saved_path}")
                            except Exception as e:
                                logger.error(f"[iverilog-r1] Failed to save empty output code: {e}")
                    # Ensure output is never empty or only whitespace
                    if not output or not output.strip():
                        output = "Simulation completed with no output"
                        # Count empty output and log (keep this log as requested)
                        _tool_call_stats["empty_outputs"] += 1
                        logger.warning(f"[iverilog-r1] SandboxFusion: Success but output is empty/whitespace, using fallback")
                        # Save code for debugging (only if not already saved above)
                        if output == "Simulation completed with no output":
                            try:
                                saved_path = _save_empty_output_code(code, metadata)
                                logger.warning(f"[iverilog-r1] Saved code to: {saved_path}")
                            except Exception as e:
                                logger.error(f"[iverilog-r1] Failed to save empty output code: {e}")
                    # Only log success if output is suspiciously short or long (potential issues)
                    if len(output) > 10000:
                        logger.warning(f"[iverilog-r1] SandboxFusion: Success with unusual output_length={len(output)}")
                
                # Priority 5: Check for runtime timeout (only if no compile errors and no successful run)
                if not output and metadata.get("run_status") == "TimeLimitExceeded":
                    output = f"Execution timeout after {IVERILOG_CONFIGS['run_timeout']} seconds"
                    logger.warning(f"[iverilog-r1] SandboxFusion: Execution timeout")
                
                # Priority 6: Check for runtime error (only if no compile errors and no successful run)
                if not output and metadata.get("run_status") == "Error":
                    stderr = metadata.get("stderr", "") or ""
                    output = f"Runtime Error:\n{stderr}" if stderr else "Runtime Error: (no error message)"
                    logger.warning(f"[iverilog-r1] SandboxFusion: Runtime error, output_length={len(output)}")
                
                # Priority 7: Check for API request errors
                if not output and metadata.get("api_request_error"):
                    output = f"API Request Error: {metadata.get('api_request_error')}"
                    logger.warning(f"[iverilog-r1] SandboxFusion: API request error, output={output[:200]}")
                
                # Priority 8: Use metadata status as fallback
                if not output and metadata.get("status"):
                    status = metadata.get("status", "unknown")
                    output = f"Execution status: {status}"
                    logger.warning(f"[iverilog-r1] SandboxFusion: Using status as output, status={status}")
                
                # Priority 9: Last resort - use a generic error message with metadata info
                if not output:
                    output = f"Execution failed (status: {metadata.get('status', 'unknown')}, "
                    output += f"api_status: {metadata.get('api_status', 'unknown')}, "
                    output += f"compile_status: {metadata.get('compile_status', 'unknown')}, "
                    output += f"run_status: {metadata.get('run_status', 'unknown')})"
                    logger.error(f"[iverilog-r1] SandboxFusion: Unexpected result, output={output}")
                
                # Final safety check: ensure output is never empty
                if not output or not output.strip():
                    output = f"Execution completed but no output available (status: {metadata.get('status', 'unknown') if metadata else 'no metadata'})"
                    logger.error(f"[iverilog-r1] SandboxFusion: Output was empty after formatting, using fallback: {output}")
            else:
                # Fallback to iverilog_server (should not happen if SandboxFusion is properly configured)
                # Use SANDBOX_URL or IVERILOG_URL from environment, or fallback to default
                fallback_url = os.getenv("SANDBOX_URL", os.getenv("IVERILOG_URL", "http://127.0.0.1:8000/run_code"))
                logger.warning(f"[iverilog-r1] SandboxFusion not available, using fallback iverilog_server at {fallback_url}")
                async with SEMAPHORE:
                    result = await iverilog_execute(
                        fallback_url,
                        code,
                        timeout=max(IVERILOG_CONFIGS["compile_timeout"], IVERILOG_CONFIGS["run_timeout"]),
                        compile_timeout=IVERILOG_CONFIGS["compile_timeout"],
                        run_timeout=IVERILOG_CONFIGS["run_timeout"],
                    )
                
                # Only log iverilog_server result for errors (should not happen if SandboxFusion is available)
                if result.get("status") != "Success":
                    logger.warning(f"[iverilog-r1] iverilog_server result: status={result.get('status', 'N/A')}")
                
                # Format the result similar to sandbox fusion output
                # Check all possible cases to ensure output is never empty
                output = None
                
                if result.get("status") == "Success":
                    stdout = result.get("run_result", {}).get("stdout", "") or ""
                    stderr = result.get("run_result", {}).get("stderr", "") or ""
                    output = stdout if stdout else ""
                    if stderr:
                        if output:
                            output += f"\nRuntime Error:\n{stderr}"
                        else:
                            output = f"Runtime Error:\n{stderr}"
                    # Ensure output is not empty even if both stdout and stderr are empty
                    if not output:
                        output = "Simulation completed with no output"
                        logger.warning(f"[iverilog-r1] iverilog_server: Success but output is empty, using fallback")
                        # Save code for debugging
                        try:
                            # Create a metadata-like dict from result
                            fake_metadata = {
                                "status": result.get("status", "unknown"),
                                "api_status": "N/A (iverilog_server)",
                                "compile_status": result.get("compile_result", {}).get("status", "N/A"),
                                "run_status": result.get("run_result", {}).get("status", "N/A"),
                                "compile_stderr": result.get("compile_result", {}).get("stderr", ""),
                                "stdout": result.get("run_result", {}).get("stdout", ""),
                                "stderr": result.get("run_result", {}).get("stderr", ""),
                                "exit_code": result.get("run_result", {}).get("return_code", "N/A"),
                            }
                            saved_path = _save_empty_output_code(code, fake_metadata)
                            logger.warning(f"[iverilog-r1] Saved code to: {saved_path}")
                        except Exception as e:
                            logger.error(f"[iverilog-r1] Failed to save empty output code: {e}")
                    # Only log success if output is suspiciously short or long (potential issues)
                    if len(output) == 0 or len(output) > 10000:
                        logger.warning(f"[iverilog-r1] iverilog_server: Success with unusual output_length={len(output)}")
                elif result.get("compile_result") and result["compile_result"].get("status") == "Error":
                    compile_stderr = result["compile_result"].get("stderr", "") or ""
                    output = f"Compile Error:\n{compile_stderr.strip()}" if compile_stderr.strip() else "Compile Error: (no error message)"
                    # Count compile error but don't log details
                    _tool_call_stats["compile_errors"] += 1
                elif result.get("status") == "Failed":
                    message = result.get("message", "")
                    compile_result = result.get("compile_result")
                    run_result = result.get("run_result")
                    
                    if compile_result and compile_result.get("status") == "TimeLimitExceeded":
                        output = f"Compilation timeout after {IVERILOG_CONFIGS['compile_timeout']} seconds"
                    elif run_result and run_result.get("status") == "TimeLimitExceeded":
                        output = f"Execution timeout after {IVERILOG_CONFIGS['run_timeout']} seconds"
                    elif message:
                        output = f"Execution failed: {message}"
                    else:
                        output = "Execution failed: (no error message)"
                    logger.warning(f"[iverilog-r1] iverilog_server: Failed, output_length={len(output)}")
                else:
                    message = result.get("message", "")
                    output = f"Execution failed: {message}" if message else f"Execution failed (status: {result.get('status', 'unknown')})"
                    logger.warning(f"[iverilog-r1] iverilog_server: Unexpected result, output={output[:200]}")
                
                # Final safety check: ensure output is never empty
                if not output or not output.strip():
                    output = f"Execution completed but no output available (status: {result.get('status', 'unknown')})"
                    logger.error(f"[iverilog-r1] iverilog_server: Output was empty after formatting, using fallback: {output}")
            
            # CRITICAL: Final check before formatting - ensure output is never empty
            if not output or not output.strip():
                logger.error(f"[iverilog-r1] Tool execution result is EMPTY before formatting! This should not happen. "
                           f"output={repr(output)}, output_type={type(output)}")
                output = "Tool execution completed but returned no output"
            
            if len(output) > 10000:
                logger.warning(f"[iverilog-r1] Tool execution result is very long: {len(output)} chars")
            
            # Format tool response - ensure output is not empty
            next_obs = f"\n\n<tool_response>{output}</tool_response>\n\n"
            
            # CRITICAL: Final check - ensure tool_response is not empty
            if not next_obs.strip() or "<tool_response></tool_response>" in next_obs:
                logger.error(f"[iverilog-r1] Formatted tool_response is EMPTY! output was: {repr(output[:200])}, "
                           f"output_length={len(output) if output else 0}, "
                           f"next_obs_length={len(next_obs)}, "
                           f"next_obs_preview={repr(next_obs[:200])}")
                # Last resort: use a non-empty fallback
                output = "Tool execution completed but returned no output"
                next_obs = f"\n\n<tool_response>{output}</tool_response>\n\n"
            
            done = False
        else:
            next_obs = "\n\n<tool_response>Error: No Verilog code found</tool_response>\n\n"
            done = False
    elif action == "answer":
        next_obs = ""
        done = True
    else:
        next_obs = (
            "\nMy previous action is invalid. "
            "If I want to execute Verilog code, I should put the code in a <tool_call> tag with format: "
            '<tool_call>{"name": "verilog_simulator", "arguments": {"code": "..."}}</tool_call>. '
            "If I want to give the final answer, I should put the answer between <answer> and </answer>. "
            "Let me try again.\n"
        )
        done = False
    
    return next_obs, done


async def generate(args, sample: Sample, sampling_params) -> Sample:
    """
    Custom generation function supporting multi-turn Verilog tool calls.
    
    This function implements a multi-turn conversation loop where the model can:
    1. Generate reasoning/answer
    2. Call iverilog tool to execute Verilog code
    3. Receive tool response
    4. Continue until final answer is provided
    """
    assert not args.partial_rollout, "Partial rollout is not supported for this function at the moment."
    
    state = GenerateState(args)
    url = f"http://{args.sglang_router_ip}:{args.sglang_router_port}/generate"
    
    # Handle partial rollout samples: continue generation from existing response
    prompt = sample.prompt
    if args.apply_chat_template:
        # When apply_chat_template is True, Dataset may have already applied the template
        # and stored a string, or it may have stored messages (list[dict])
        if isinstance(prompt, str):
            # Already formatted, use directly
            prompt_text = prompt
        elif isinstance(prompt, (list, np.ndarray)):
            # Messages format, apply chat template
            if isinstance(prompt, np.ndarray):
                prompt = prompt.tolist()
            prompt_text = state.tokenizer.apply_chat_template(
                prompt,
                tokenize=False,
                add_generation_prompt=True,
                **(args.apply_chat_template_kwargs or {}),
            )
        else:
            raise ValueError(f"Unexpected prompt type when apply_chat_template=True: {type(prompt)}")
    else:
        assert isinstance(prompt, str), "prompt should be a string when apply_chat_template is False"
        prompt_text = prompt
    
    prompt_tokens_ids = state.tokenizer(prompt_text, add_special_tokens=False)["input_ids"]
    
    # Check input length and handle gracefully if too long
    max_context_len = getattr(args, 'rollout_max_context_len', None) or 40960
    if len(prompt_tokens_ids) > max_context_len:
        logger.warning("="*80)
        logger.warning("WARNING: Input prompt exceeds maximum context length!")
        logger.warning(f"Prompt token count: {len(prompt_tokens_ids)}")
        logger.warning(f"Maximum context length: {max_context_len}")
        logger.warning(f"Exceeded by: {len(prompt_tokens_ids) - max_context_len} tokens")
        logger.warning("="*80)
        logger.warning("Sample details:")
        logger.warning(f"  Sample index: {getattr(sample, 'index', 'N/A')}")
        logger.warning(f"  Sample group_index: {getattr(sample, 'group_index', 'N/A')}")
        logger.warning(f"  Prompt type: {type(sample.prompt)}")
        logger.warning(f"  Prompt length (chars): {len(prompt_text) if isinstance(prompt_text, str) else 'N/A'}")
        logger.warning("="*80)
        logger.warning("Full prompt text (COMPLETE, NO TRUNCATION):")
        logger.warning("="*80)
        if isinstance(prompt_text, str):
            logger.warning(prompt_text)
        else:
            logger.warning(str(prompt_text))
        logger.warning("="*80)
        logger.warning("Original sample.prompt (before apply_chat_template):")
        logger.warning("-"*80)
        if isinstance(sample.prompt, str):
            logger.warning(sample.prompt)
        else:
            logger.warning(str(sample.prompt))
        logger.warning("-"*80)
        logger.warning("Sample metadata:")
        logger.warning(f"  {sample.metadata}")
        logger.warning("="*80)
        logger.warning("Prompt too long, marking as TRUNCATED and returning empty response")
        # Mark as truncated and return early with empty response
        sample.status = Sample.Status.TRUNCATED
        sample.tokens = prompt_tokens_ids
        sample.response_length = 0
        sample.response = ""
        sample.loss_mask = []
        sample.prompt = prompt_text
        return sample
    
    response = ""
    response_token_ids = []
    loss_mask = []
    rollout_log_probs = [] if IVERILOG_CONFIGS["return_logprob"] else None
    output = None  # Initialize output to handle early breaks
    
    for _turn_idx in range(IVERILOG_CONFIGS["max_turns"]):
        # Check total length before sending request
        current_text = prompt_text + response
        current_tokens = state.tokenizer(current_text, add_special_tokens=False)["input_ids"]
        max_new_tokens = sampling_params.get("max_new_tokens", 0)
        
        # Reserve some margin for special tokens that SGLang might add (e.g., BOS/EOS)
        # SGLang may reject requests where input + max_new_tokens >= max_context_len
        SAFETY_MARGIN = 100  # Reserve 100 tokens for special tokens and safety margin
        
        # If input itself exceeds max_context_len (with safety margin), stop and use current response as final answer
        if len(current_tokens) > max_context_len - SAFETY_MARGIN:
            logger.warning(f"Turn {_turn_idx}: Input (prompt + accumulated response) exceeds maximum context length (with safety margin)!")
            logger.warning(f"Current token count: {len(current_tokens)}, max (with margin): {max_context_len - SAFETY_MARGIN}")
            logger.warning(f"Exceeded by: {len(current_tokens) - (max_context_len - SAFETY_MARGIN)} tokens")
            logger.warning("Stopping generation and using current response as final answer")
            sample.status = Sample.Status.TRUNCATED
            break
        
        # Check if total length (input + max_new_tokens) would exceed limit (with safety margin)
        # Use >= instead of > to be more conservative, as SGLang may reject when input + max_new_tokens >= max_context_len
        if len(current_tokens) + max_new_tokens >= max_context_len - SAFETY_MARGIN:
            # logger.warning(f"Turn {_turn_idx}: Total length ({len(current_tokens)} + {max_new_tokens}) would exceed max_context_len ({max_context_len}, with {SAFETY_MARGIN} token safety margin), truncating response length")
            # Adjust max_new_tokens to fit within context (with safety margin)
            sampling_params["max_new_tokens"] = max(0, max_context_len - SAFETY_MARGIN - len(current_tokens))
            if sampling_params["max_new_tokens"] == 0:
                logger.warning("No room for new tokens, stopping generation")
                sample.status = Sample.Status.TRUNCATED
                break
        
        payload = {
            "text": current_text,
            "sampling_params": sampling_params,
        }
        # Add log probability collection if enabled
        if IVERILOG_CONFIGS["return_logprob"]:
            payload["return_logprob"] = True
        
        output = await post(url, payload)
        
        # abort
        if output["meta_info"]["finish_reason"]["type"] == "abort":
            sample.status = Sample.Status.ABORTED
            return sample
        
        cur_response = output["text"]
        
        # Extract tokens and log probs based on configuration
        if IVERILOG_CONFIGS["return_logprob"]:
            # Extract log probs from output - required for TIS metrics
            if "output_token_logprobs" not in output["meta_info"]:
                raise RuntimeError(
                    "output_token_logprobs not found in output meta_info. "
                    "Make sure 'return_logprob': True is set in the payload."
                )
            
            # Use token IDs and log probs directly from output_token_logprobs
            cur_response_token_ids = [item[1] for item in output["meta_info"]["output_token_logprobs"]]
            cur_response_log_probs = [item[0] for item in output["meta_info"]["output_token_logprobs"]]
        else:
            # When not collecting log probs, we can safely postprocess the response
            cur_response = postprocess_responses(cur_response)
            # Tokenize the (possibly postprocessed) response
            cur_response_token_ids = state.tokenizer(cur_response, add_special_tokens=False)["input_ids"]
        
        # DEBUG: Log current response for debugging tool call extraction
        logger.debug(f"[iverilog-r1] Turn {_turn_idx}: cur_response length={len(cur_response)}, "
                    f"has_tool_call={('<tool_call>' in cur_response)}, "
                    f"has_tool_response={('<tool_response>' in cur_response)}")
        if "<tool_call>" in cur_response:
            # Log tool call snippet for debugging
            tool_call_start = cur_response.find("<tool_call>")
            tool_call_snippet = cur_response[tool_call_start:tool_call_start+200] if tool_call_start >= 0 else ""
            logger.debug(f"[iverilog-r1] Turn {_turn_idx}: tool_call snippet: {tool_call_snippet}...")
        
        response += cur_response
        response_token_ids += cur_response_token_ids
        loss_mask += [1] * len(cur_response_token_ids)
        
        # Add log probs if enabled
        if IVERILOG_CONFIGS["return_logprob"]:
            rollout_log_probs += cur_response_log_probs
        
        if output["meta_info"]["finish_reason"]["type"] == "length":
            break
        
        # Extract tool calls from current response (not accumulated, to avoid duplicate extraction)
        next_obs, done = await execute_predictions(cur_response)
        
        # DEBUG: Log tool response insertion
        logger.debug(f"[iverilog-r1] Turn {_turn_idx}: next_obs length={len(next_obs)}, done={done}, "
                    f"has_tool_response={('<tool_response>' in next_obs) if next_obs else False}")
        
        if done:
            logger.debug(f"[iverilog-r1] Turn {_turn_idx}: Conversation done, breaking loop")
            break
        
        assert next_obs != "", "Next observation should not be empty."
        obs_tokens_ids = state.tokenizer(next_obs, add_special_tokens=False)["input_ids"]
        
        # DEBUG: Log before adding tool response to accumulated response
        response_before = response
        response += next_obs
        logger.debug(f"[iverilog-r1] Turn {_turn_idx}: Added tool response to accumulated response, "
                    f"response_length_before={len(response_before)}, "
                    f"response_length_after={len(response)}, "
                    f"added_length={len(next_obs)}, "
                    f"response_ends_with={response[-100:] if len(response) >= 100 else response}")
        response_token_ids += obs_tokens_ids
        loss_mask += [0] * len(obs_tokens_ids)
        
        # Add dummy log probs for observation tokens if enabled (they won't be used due to loss_mask=0)
        if IVERILOG_CONFIGS["return_logprob"]:
            rollout_log_probs += [0.0] * len(obs_tokens_ids)
            
            # Verify alignment when collecting log probs
            assert len(response_token_ids) == len(
                rollout_log_probs
            ), f"Token/logp length mismatch: {len(response_token_ids)} tokens vs {len(rollout_log_probs)} logps"
        
        # Check total length after adding tool feedback - if exceeds limit, stop and use current response
        # Use the same safety margin as before
        current_text_after_tool = prompt_text + response
        current_tokens_after_tool = state.tokenizer(current_text_after_tool, add_special_tokens=False)["input_ids"]
        if len(current_tokens_after_tool) > max_context_len - SAFETY_MARGIN:
            logger.warning(f"Turn {_turn_idx}: After tool feedback, total length ({len(current_tokens_after_tool)}) exceeds max_context_len ({max_context_len}, with {SAFETY_MARGIN} token safety margin)")
            logger.warning(f"Exceeded by: {len(current_tokens_after_tool) - (max_context_len - SAFETY_MARGIN)} tokens")
            logger.warning("Stopping generation and using current response as final answer")
            sample.status = Sample.Status.TRUNCATED
            break
    
    # Store statistics for wandb logging
    sample.tokens = prompt_tokens_ids + response_token_ids
    sample.response_length = len(response_token_ids)
    sample.response = response
    sample.loss_mask = loss_mask
    sample.prompt = prompt_text
    
    # Store log probs if enabled
    if IVERILOG_CONFIGS["return_logprob"]:
        sample.rollout_log_probs = rollout_log_probs if rollout_log_probs else None
    
    # Set status based on finish reason if available, otherwise keep existing status
    if output is not None:
        match output["meta_info"]["finish_reason"]["type"]:
            case "length":
                sample.status = Sample.Status.TRUNCATED
            case "abort":
                sample.status = Sample.Status.ABORTED
            case "stop":
                if sample.status != Sample.Status.TRUNCATED:  # Don't override TRUNCATED status
                    sample.status = Sample.Status.COMPLETED
    # If loop was broken early due to length limit, status is already set to TRUNCATED
    
    # Log statistics at the end of rollout (only if there were tool calls)
    if _tool_call_stats["total_calls"] > 0:
        compile_error_rate = _tool_call_stats["compile_errors"] / _tool_call_stats["total_calls"] * 100
        logger.info(f"[iverilog-r1] Rollout statistics: "
                   f"Total tool calls: {_tool_call_stats['total_calls']}, "
                   f"Compile errors: {_tool_call_stats['compile_errors']} ({compile_error_rate:.2f}%), "
                   f"Empty outputs: {_tool_call_stats['empty_outputs']}, "
                   f"Runtime errors: {_tool_call_stats['runtime_errors']}, "
                   f"Successes: {_tool_call_stats['successes']}")
    
    return sample


async def reward_func(args, sample, **kwargs):
    """
    The reward function for Verilog code generation tasks.
    
    IMPORTANT: This function extracts code WITHOUT testbench for reward calculation.
    During tool execution (in execute_predictions), code WITH testbench is used.
    
    This function implements the same reward logic as verl's compute_score function:
    
    离散模式下（reward_mode = "discrete"）的规则：
      1. 答案正确 且 格式为完整正确格式  → reward = 1.5  （答案 1.0 + 格式 0.5）
      2. 答案正确 且 格式不完全正确但没有严重错误 → reward = 1.0
      3. 答案正确 且 格式存在严重错误       → reward = 0.0
      4. 答案错误                       → reward = 0.0
    
    连续模式（"continuous"）保持原有逻辑，只根据 error_rate 出分。
    
    Args:
        args: the arguments
        sample: the sample to evaluate
        **kwargs: additional arguments including:
            - reward_mode: "discrete" or "continuous" (default: "discrete")
            - enable_format_reward: whether to enable format reward/penalty (default: True)
            - err_threshold: error threshold for continuous mode
            - reward_mapping: "threshold" or "zero" for continuous mode
            - gt_keys: list of keys to extract from ground_truth dict
    
    Returns:
        float: reward score
    """
    if not isinstance(sample, Sample):
        raise TypeError("Sample must be an instance of Sample class.")
    
    # Get reward configuration from kwargs
    reward_mode = kwargs.get("reward_mode", "discrete")
    assert reward_mode in ["discrete", "continuous"], "mode should be either 'discrete' or 'continuous'"
    
    enable_format_reward = kwargs.get("enable_format_reward", True)
    
    # Continuous mode parameters
    if reward_mode == "continuous":
        err_threshold = kwargs.get("err_threshold", None)
        reward_mapping = kwargs.get("reward_mapping", "threshold")
        assert err_threshold is not None, "err_threshold should be given when using continuous reward!"
        assert reward_mapping in ["threshold", "zero"], "reward_mapping should be either 'threshold' or 'zero'"
    else:
        err_threshold = None
        reward_mapping = "threshold"
    
    # Extract solution string
    solution_str = sample.prompt + sample.response
    
    # Handle ground_truth (may be dict with multiple keys)
    gt_keys = kwargs.get("gt_keys", None)
    ground_truth = sample.label
    if gt_keys is not None:
        assert isinstance(ground_truth, dict), "ground_truth should be a dict when gt_keys is given"
        gts = [ground_truth[key] for key in gt_keys]
    else:
        if isinstance(ground_truth, dict):
            # If ground_truth is a dict, extract the ground_truth field
            # Support multiple possible key names for compatibility
            ground_truth = ground_truth.get("ground_truth", ground_truth.get("code", ground_truth.get("verilog", "")))
        assert isinstance(ground_truth, str), "ground_truth should be a string when gt_keys is not given"
        gts = [ground_truth]
    
    # 1) 基础格式检查不过，直接 0 分
    if not _format_ok(solution_str):
        return 0.0
    
    # 2) 检查严重格式错误（不完整标签、过度重复等）
    format_penalty = 0.0
    penalty_reasons: List[str] = []
    has_serious_format_error = False
    if enable_format_reward:
        format_penalty, penalty_reasons = _check_format_penalties(solution_str)
        if penalty_reasons:
            has_serious_format_error = True
            logger.debug(
                f"[iverilog-r1] Format penalties: {penalty_reasons}, penalty: {format_penalty}"
            )
    
    # 3) 检查格式是否为「完整正确格式」
    format_reward = 0.0
    is_format_perfect = False
    if enable_format_reward:
        format_reward, is_format_perfect = _check_format_reward(solution_str)
        if is_format_perfect:
            logger.debug(
                f"[iverilog-r1] Format reward (perfect structure): {format_reward}"
            )
    
    def _calc_reward_one_gt(sol: str, gt: str) -> float:
        """Calculate reward for a single ground truth."""
        # 提取 & 清洗 verilog (without testbench)
        extracted = extract_verilog_from_generation(sol, require_complete=True, keep_testbench=False)
        cleaned = clean_verilog_code(extracted)
        if not cleaned:
            logger.warning(
                "[iverilog-r1] Failed to extract/clean verilog code from solution. "
                f"Extracted: {extracted[:200] if extracted else None}"
            )
            return 0.0
        
        # Use eda_tools for equivalence verification
        try:
            if verify_one_sample is None or run_function_with_timeout is None:
                logger.warning("[iverilog-r1] eda_tools not available, falling back to string comparison")
                # Fallback to string comparison
                if cleaned.strip() == gt.strip():
                    return 1.0
                return 0.0
            
            # CodeV 等价性验证
            result: Dict[str, Any] = run_function_with_timeout(verify_one_sample, gt, cleaned)
            if not isinstance(result, dict):
                return 0.0
            
            if result.get("correct", False):
                return 1.0
            
            if reward_mode == "discrete":
                # 离散模式下，代码不完全正确就是 0
                return 0.0
            
            # 连续模式：保留原逻辑
            if "error_rate" in result and err_threshold is not None and result["error_rate"] <= err_threshold:
                if reward_mapping == "threshold":
                    return 1.0 - float(result["error_rate"])
                return float(err_threshold) - float(result["error_rate"])
            
            return 0.0
        except Exception as e:
            logger.error(f"[iverilog-r1] Error during verification: {e}")
            # Fallback to string comparison on error
            if cleaned.strip() == gt.strip():
                return 1.0
            return 0.0
    
    # 4) 计算 correctness reward（答案是否功能等价）
    correctness_rewards = [_calc_reward_one_gt(solution_str, gt) for gt in gts]
    correctness_reward = float(max(correctness_rewards)) if correctness_rewards else 0.0
    
    # 连续模式：直接返回 correctness_reward（不做 4 档映射）
    if reward_mode == "continuous":
        return correctness_reward
    
    # ======== 离散模式：严格按四种情况映射 =========
    if correctness_reward <= 0.0:
        # 情况 4: 答案错误 → 0 分
        return 0.0
    
    # 此时 correctness_reward > 0，说明答案正确
    if has_serious_format_error:
        # 情况 3: 答案正确 + 严重格式错误 → 0 分
        logger.debug(
            "[iverilog-r1] Answer correct but serious format errors detected: "
            f"{penalty_reasons}. Reward = 0.0"
        )
        return 0.0
    
    if is_format_perfect:
        # 情况 1: 答案正确 + 完整正确格式 → 1.5 分
        logger.debug("[iverilog-r1] Answer correct and format perfect. Reward = 1.5")
        return 1.5
    
    # 情况 2: 答案正确 + 无严重格式错误但格式不完全正确 → 1.0 分
    logger.debug(
        "[iverilog-r1] Answer correct with acceptable but non-perfect format. Reward = 1.0"
    )
    return 1.0

