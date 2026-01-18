"""
Generate function for multi-turn Python tool calling in slime (ToRL).

This module implements a custom generation function that supports multi-turn
conversation with Python code execution via SandboxFusion, similar to iverilog-r1
but for Python code execution.

Adapted from verl framework's Python execution tool and iverilog-r1's generate_with_iverilog.py.
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
    logger.warning(f"Failed to import SandboxFusion utilities: {e}.")
    logger.warning(f"Error details: {type(e).__name__}: {str(e)}")
    import traceback
    logger.debug(f"Traceback: {traceback.format_exc()}")
    SANDBOX_FUSION_AVAILABLE = False
    _process_single_case = None

# Global statistics for tool calls
_tool_call_stats = {
    "total_calls": 0,
    "syntax_errors": 0,
    "empty_outputs": 0,
    "runtime_errors": 0,
    "successes": 0,
}

# Configuration for ToRL
TORL_CONFIGS = {
    # ============== General Configuration ==============
    "max_turns": 6,  # Maximum number of tool call turns
    "python_concurrency": 32,  # Maximum concurrent Python executions
    # ============== Execution Method Configuration ==============
    # Options: "sandbox_fusion"
    # - "sandbox_fusion": Use SandboxFusion API (required for Python execution)
    "execution_method": os.getenv("TORL_EXECUTION_METHOD", "sandbox_fusion"),
    # ============== SandboxFusion Configuration ==============
    # Use SandboxFusion URL (can be overridden by environment variable SANDBOX_URL)
    "sandbox_fusion_url": os.getenv("SANDBOX_URL", "http://127.0.0.1:8181/run_code"),
    "compile_timeout": 30,  # Compile timeout in seconds (for Python, this is syntax check)
    "run_timeout": 30,  # Execution timeout in seconds
    # ============== Log Probability Collection ==============
    "return_logprob": True,  # Set to True to collect log probabilities for TIS metrics
}

# Create semaphore for concurrency control
if SANDBOX_FUSION_AVAILABLE:
    sandbox_concurrency = int(os.getenv("SANDBOX_FUSION_CONCURRENCY", str(TORL_CONFIGS["python_concurrency"])))
    SEMAPHORE = asyncio.Semaphore(sandbox_concurrency)
    logger.info(f"[torl] Using SandboxFusion with client-side concurrency limit: {sandbox_concurrency}")
else:
    SEMAPHORE = asyncio.Semaphore(TORL_CONFIGS["python_concurrency"])


def postprocess_predictions(prediction: str):
    """
    Extract action and content from prediction string.
    
    Returns:
        Tuple of (action, content) where:
        - action: "tool_call", "answer", or None
        - content: extracted content (Python code for tool_call, or answer text)
    """
    logger.debug(f"[torl] postprocess_predictions: prediction length={len(prediction)}, "
                f"has_tool_call_tag={('<tool_call>' in prediction)}, "
                f"has_tool_call_close={('</tool_call>' in prediction)}, "
                f"has_answer_tag={('<answer>' in prediction)}, "
                f"has_answer_close={('</answer>' in prediction)}")
    
    # Check for <tool_call> tags
    tool_call_pattern = r"<tool_call>\s*(\{.*?\})\s*</tool_call>"
    tool_call_match = re.search(tool_call_pattern, prediction, re.DOTALL)
    if tool_call_match:
        logger.debug(f"[torl] postprocess_predictions: Found complete <tool_call> tag")
        try:
            json_str = tool_call_match.group(1).strip()
            logger.debug(f"[torl] postprocess_predictions: JSON string length={len(json_str)}, "
                        f"preview={json_str[:200]}...")
            
            # Try to parse JSON
            try:
                tool_call_data = json.loads(json_str)
                tool_name = tool_call_data.get("name")
                arguments = tool_call_data.get("arguments", {})
                logger.debug(f"[torl] postprocess_predictions: Parsed tool_name={tool_name}, "
                           f"arguments_keys={list(arguments.keys()) if isinstance(arguments, dict) else 'N/A'}")
                
                # Support multiple possible tool names: python_executor, python, python_tool
                if tool_name in ["python_executor", "python", "python_tool"]:
                    code = arguments.get("code", "")
                    if code.strip():
                        logger.debug(f"[torl] postprocess_predictions: Extracted code length={len(code)}, "
                                   f"code_preview={code[:200]}...")
                        return "tool_call", code
                    else:
                        logger.warning(f"[torl] postprocess_predictions: tool_name={tool_name} but code is empty")
            except json.JSONDecodeError as e:
                logger.debug(f"[torl] postprocess_predictions: JSON parsing failed: {e}, "
                           f"trying regex extraction for truncated JSON")
                # Try to extract code using regex for truncated JSON
                code_match = re.search(r'"code"\s*:\s*"([^"]*(?:\\.[^"]*)*)"', json_str, re.DOTALL)
                if code_match:
                    code = code_match.group(1).replace('\\"', '"').replace('\\n', '\n')
                    if code.strip():
                        logger.debug(f"[torl] postprocess_predictions: Extracted code via regex, length={len(code)}")
                        return "tool_call", code
        except (KeyError, AttributeError) as e:
            logger.warning(f"[torl] postprocess_predictions: Exception extracting tool call: {e}")
            pass
    
    # Check for incomplete <tool_call> at the end (truncated)
    incomplete_tool_call_pattern = r"<tool_call>\s*(\{.*?)$"
    incomplete_tool_call_match = re.search(incomplete_tool_call_pattern, prediction, re.DOTALL)
    if incomplete_tool_call_match:
        logger.debug(f"[torl] postprocess_predictions: Found incomplete <tool_call> tag (truncated)")
        try:
            json_str = incomplete_tool_call_match.group(1).strip()
            code_match = re.search(r'"code"\s*:\s*"([^"]*(?:\\.[^"]*)*)"', json_str, re.DOTALL)
            if code_match:
                code = code_match.group(1).replace('\\"', '"').replace('\\n', '\n')
                if code.strip():
                    logger.debug(f"[torl] postprocess_predictions: Extracted code from incomplete tag, length={len(code)}")
                    return "tool_call", code
        except Exception as e:
            logger.warning(f"[torl] postprocess_predictions: Exception extracting from incomplete tag: {e}")
            pass
    
    # Check for <answer> tags
    answer_pattern = r"<answer>([\s\S]*?)</answer>"
    answer_match = re.search(answer_pattern, prediction, re.DOTALL)
    if answer_match:
        content = answer_match.group(1).strip()
        logger.debug(f"[torl] postprocess_predictions: Found complete <answer> tag, content_length={len(content)}")
        return "answer", content
    
    # Check for incomplete <answer> at the end
    incomplete_answer_pattern = r"<answer>([\s\S]*?)$"
    incomplete_answer_match = re.search(incomplete_answer_pattern, prediction, re.DOTALL)
    if incomplete_answer_match:
        content = incomplete_answer_match.group(1).strip()
        logger.debug(f"[torl] postprocess_predictions: Found incomplete <answer> tag, content_length={len(content)}")
        return "answer", content
    
    logger.debug(f"[torl] postprocess_predictions: No action found, returning None")
    return None, ""


def postprocess_responses(resp: str) -> str:
    """
    Post-process response to ensure tag completeness.
    Only used when TORL_CONFIGS["return_logprob"] is False.
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


async def _call_sandbox_fusion_direct(
    sandbox_fusion_url: str,
    code: str,
    compile_timeout: int,
    run_timeout: int,
    language: str = "python",
    semaphore: Optional[asyncio.Semaphore] = None
) -> tuple[Optional[Dict[str, Any]], Optional[str]]:
    """
    Directly call SandboxFusion API for Python code execution.
    
    Args:
        sandbox_fusion_url: The URL of the SandboxFusion API
        code: The Python code to execute
        compile_timeout: Compile timeout in seconds (for Python, this is syntax check)
        run_timeout: Run timeout in seconds
        language: Language (default: "python")
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
                logger.warning(f"[torl] Direct API call: Success but stdout and stderr are empty. "
                             f"Full response keys: {list(api_response.keys())}, "
                             f"run_result keys: {list(run_result.keys()) if run_result else 'None'}")
        
        return api_response, None
        
    except requests.exceptions.Timeout as e:
        error_msg = f"API Request Timeout: {e}"
        logger.error(f"[torl] Direct API call timeout: {error_msg}")
        return None, error_msg
    except requests.exceptions.RequestException as e:
        error_msg = f"API Request Error: {e}"
        logger.error(f"[torl] Direct API call error: {error_msg}")
        return None, error_msg
    except json.JSONDecodeError as e:
        error_msg = f"JSON Decode Error: {e}"
        logger.error(f"[torl] Direct API call JSON error: {error_msg}")
        return None, error_msg
    except Exception as e:
        error_msg = f"Unexpected Error: {e}"
        logger.error(f"[torl] Direct API call unexpected error: {error_msg}")
        return None, error_msg


def _parse_sandbox_fusion_response(api_response: Dict[str, Any]) -> Dict[str, Any]:
    """
    Parse SandboxFusion API response into metadata format.
    
    Args:
        api_response: The raw API response from SandboxFusion
    
    Returns:
        Metadata dictionary
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
    
    # Extract compile information (for Python, this is syntax check)
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
                metadata["status"] = "syntax_error"  # For Python, compile error is syntax error
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
    
    Uses SandboxFusion to execute Python code.
    
    Args:
        prediction: The model's prediction string
    
    Returns:
        Tuple of (next_obs, done) where:
        - next_obs: Next observation to append to the conversation
        - done: Whether the conversation is complete
    """
    logger.debug(f"[torl] execute_predictions: prediction length={len(prediction)}, "
                f"preview={prediction[:200]}...")
    
    action, content = postprocess_predictions(prediction)
    
    logger.debug(f"[torl] execute_predictions: action={action}, "
                f"content_length={len(content) if content else 0}, "
                f"content_preview={content[:100] if content else 'None'}...")
    
    if action == "tool_call":
        # Content is the Python code
        code = content.strip()
        if code:
            # Count tool call
            _tool_call_stats["total_calls"] += 1
            
            if not hasattr(execute_predictions, '_logged_url'):
                logger.info(f"[torl] Using SandboxFusion URL: {TORL_CONFIGS['sandbox_fusion_url']}")
                execute_predictions._logged_url = True
            
            # Use SandboxFusion for Python execution
            if not SANDBOX_FUSION_AVAILABLE:
                logger.error("[torl] SandboxFusion not available! Cannot execute Python code.")
                next_obs = "\n\n<tool_response>Error: SandboxFusion is not available. Cannot execute Python code.</tool_response>\n\n"
                done = False
                return next_obs, done
            
            # Use direct API call for better control
            USE_DIRECT_API = os.getenv("USE_DIRECT_SANDBOX_API", "true").lower() == "true"
            
            if USE_DIRECT_API:
                logger.debug(f"[torl] Using direct SandboxFusion API call")
                api_response, error_msg = await _call_sandbox_fusion_direct(
                    TORL_CONFIGS["sandbox_fusion_url"],
                    code,
                    TORL_CONFIGS["compile_timeout"],
                    TORL_CONFIGS["run_timeout"],
                    "python",
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
                else:
                    # Parse API response into metadata format
                    metadata = _parse_sandbox_fusion_response(api_response)
            else:
                # Use verl's _process_single_case
                import concurrent.futures
                loop = asyncio.get_event_loop()
                
                with concurrent.futures.ThreadPoolExecutor() as executor:
                    result_status, metadata = await loop.run_in_executor(
                        executor,
                        _process_single_case,
                        0,  # case_index
                        "",  # stdin_data
                        None,  # expected_output
                        TORL_CONFIGS["sandbox_fusion_url"],
                        code,
                        max(TORL_CONFIGS["compile_timeout"], TORL_CONFIGS["run_timeout"]),  # timeout
                        "python",  # language
                        None,  # concurrent_semaphore
                        None,  # fn_name
                    )
            
            # Format the result
            output = None
            
            # Priority 1: Check for syntax errors (compile errors for Python)
            if metadata.get("compile_status") == "Finished" and metadata.get("compile_stderr"):
                compile_stderr = metadata.get("compile_stderr", "") or ""
                if compile_stderr.strip():
                    output = f"Syntax Error:\n{compile_stderr.strip()}"
                    _tool_call_stats["syntax_errors"] += 1
                else:
                    if metadata.get("status") == "syntax_error":
                        output = "Syntax Error: (no error message)"
                        _tool_call_stats["syntax_errors"] += 1
            
            # Priority 2: Check for compile timeout
            if not output and metadata.get("compile_status") == "TimeLimitExceeded":
                output = f"Syntax check timeout after {TORL_CONFIGS['compile_timeout']} seconds"
                _tool_call_stats["syntax_errors"] += 1
            
            # Priority 3: Check for syntax error status
            if not output and metadata.get("compile_status") == "Error":
                compile_stderr = metadata.get("compile_stderr", "") or ""
                output = f"Syntax Error:\n{compile_stderr.strip()}" if compile_stderr.strip() else "Syntax Error: (no error message)"
                _tool_call_stats["syntax_errors"] += 1
            
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
                    output = "Execution completed with no output"
                    _tool_call_stats["empty_outputs"] += 1
                    logger.warning(f"[torl] Success but output is empty")
            
            # Priority 5: Check for runtime timeout
            if not output and metadata.get("run_status") == "TimeLimitExceeded":
                output = f"Execution timeout after {TORL_CONFIGS['run_timeout']} seconds"
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
            
            # Format tool response
            next_obs = f"\n\n<tool_response>{output}</tool_response>\n\n"
            
            # Final check - ensure tool_response is not empty
            if not next_obs.strip() or "<tool_response></tool_response>" in next_obs:
                logger.error(f"[torl] Formatted tool_response is EMPTY! output was: {repr(output[:200])}")
                output = "Tool execution completed but returned no output"
                next_obs = f"\n\n<tool_response>{output}</tool_response>\n\n"
            
            done = False
        else:
            next_obs = "\n\n<tool_response>Error: No Python code found</tool_response>\n\n"
            done = False
    elif action == "answer":
        next_obs = ""
        done = True
    else:
        next_obs = (
            "\nMy previous action is invalid. "
            "If I want to execute Python code, I should put the code in a <tool_call> tag with format: "
            '<tool_call>{"name": "python_executor", "arguments": {"code": "..."}}</tool_call>. '
            "If I want to give the final answer, I should put the answer between <answer> and </answer>. "
            "Let me try again.\n"
        )
        done = False
    
    return next_obs, done


async def generate(args, sample: Sample, sampling_params) -> Sample:
    """
    Custom generation function supporting multi-turn Python tool calls.
    
    This function implements a multi-turn conversation loop where the model can:
    1. Generate reasoning/answer
    2. Call Python executor tool to execute Python code
    3. Receive tool response
    4. Continue until final answer is provided
    """
    assert not args.partial_rollout, "Partial rollout is not supported for this function at the moment."
    
    state = GenerateState(args)
    url = f"http://{args.sglang_router_ip}:{args.sglang_router_port}/generate"
    
    # Handle partial rollout samples: continue generation from existing response
    prompt = sample.prompt
    if args.apply_chat_template:
        if isinstance(prompt, str):
            prompt_text = prompt
        elif isinstance(prompt, (list, np.ndarray)):
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
        logger.warning("Prompt too long, marking as TRUNCATED and returning empty response")
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
    rollout_log_probs = [] if TORL_CONFIGS["return_logprob"] else None
    output = None  # Initialize output to handle early breaks
    
    for _turn_idx in range(TORL_CONFIGS["max_turns"]):
        # Check total length before sending request
        current_text = prompt_text + response
        current_tokens = state.tokenizer(current_text, add_special_tokens=False)["input_ids"]
        max_new_tokens = sampling_params.get("max_new_tokens", 0)
        
        # Reserve some margin for special tokens
        SAFETY_MARGIN = 100
        
        # If input itself exceeds max_context_len (with safety margin), stop
        if len(current_tokens) > max_context_len - SAFETY_MARGIN:
            logger.warning(f"Turn {_turn_idx}: Input exceeds maximum context length (with safety margin)!")
            logger.warning("Stopping generation and using current response as final answer")
            sample.status = Sample.Status.TRUNCATED
            break
        
        # Check if total length would exceed limit
        if len(current_tokens) + max_new_tokens >= max_context_len - SAFETY_MARGIN:
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
        if TORL_CONFIGS["return_logprob"]:
            payload["return_logprob"] = True
        
        output = await post(url, payload)
        
        # abort
        if output["meta_info"]["finish_reason"]["type"] == "abort":
            sample.status = Sample.Status.ABORTED
            return sample
        
        cur_response = output["text"]
        
        # Extract tokens and log probs based on configuration
        if TORL_CONFIGS["return_logprob"]:
            if "output_token_logprobs" not in output["meta_info"]:
                raise RuntimeError(
                    "output_token_logprobs not found in output meta_info. "
                    "Make sure 'return_logprob': True is set in the payload."
                )
            
            cur_response_token_ids = [item[1] for item in output["meta_info"]["output_token_logprobs"]]
            cur_response_log_probs = [item[0] for item in output["meta_info"]["output_token_logprobs"]]
        else:
            cur_response = postprocess_responses(cur_response)
            cur_response_token_ids = state.tokenizer(cur_response, add_special_tokens=False)["input_ids"]
        
        logger.debug(f"[torl] Turn {_turn_idx}: cur_response length={len(cur_response)}, "
                    f"has_tool_call={('<tool_call>' in cur_response)}, "
                    f"has_tool_response={('<tool_response>' in cur_response)}")
        
        response += cur_response
        response_token_ids += cur_response_token_ids
        loss_mask += [1] * len(cur_response_token_ids)
        
        # Add log probs if enabled
        if TORL_CONFIGS["return_logprob"]:
            rollout_log_probs += cur_response_log_probs
        
        if output["meta_info"]["finish_reason"]["type"] == "length":
            break
        
        # Extract tool calls from current response
        next_obs, done = await execute_predictions(cur_response)
        
        logger.debug(f"[torl] Turn {_turn_idx}: next_obs length={len(next_obs)}, done={done}, "
                    f"has_tool_response={('<tool_response>' in next_obs) if next_obs else False}")
        
        if done:
            logger.debug(f"[torl] Turn {_turn_idx}: Conversation done, breaking loop")
            break
        
        assert next_obs != "", "Next observation should not be empty."
        obs_tokens_ids = state.tokenizer(next_obs, add_special_tokens=False)["input_ids"]
        
        response += next_obs
        response_token_ids += obs_tokens_ids
        loss_mask += [0] * len(obs_tokens_ids)
        
        # Add dummy log probs for observation tokens if enabled
        if TORL_CONFIGS["return_logprob"]:
            rollout_log_probs += [0.0] * len(obs_tokens_ids)
            
            # Verify alignment when collecting log probs
            assert len(response_token_ids) == len(
                rollout_log_probs
            ), f"Token/logp length mismatch: {len(response_token_ids)} tokens vs {len(rollout_log_probs)} logps"
        
        # Check total length after adding tool feedback
        current_text_after_tool = prompt_text + response
        current_tokens_after_tool = state.tokenizer(current_text_after_tool, add_special_tokens=False)["input_ids"]
        if len(current_tokens_after_tool) > max_context_len - SAFETY_MARGIN:
            logger.warning(f"Turn {_turn_idx}: After tool feedback, total length exceeds max_context_len")
            logger.warning("Stopping generation and using current response as final answer")
            sample.status = Sample.Status.TRUNCATED
            break
    
    # Store statistics
    sample.tokens = prompt_tokens_ids + response_token_ids
    sample.response_length = len(response_token_ids)
    sample.response = response
    sample.loss_mask = loss_mask
    sample.prompt = prompt_text
    
    # Store log probs if enabled
    if TORL_CONFIGS["return_logprob"]:
        sample.rollout_log_probs = rollout_log_probs if rollout_log_probs else None
    
    # Set status based on finish reason if available
    if output is not None:
        match output["meta_info"]["finish_reason"]["type"]:
            case "length":
                sample.status = Sample.Status.TRUNCATED
            case "abort":
                sample.status = Sample.Status.ABORTED
            case "stop":
                if sample.status != Sample.Status.TRUNCATED:
                    sample.status = Sample.Status.COMPLETED
    
    # Log statistics at the end of rollout
    if _tool_call_stats["total_calls"] > 0:
        syntax_error_rate = _tool_call_stats["syntax_errors"] / _tool_call_stats["total_calls"] * 100
        logger.info(f"[torl] Rollout statistics: "
                   f"Total tool calls: {_tool_call_stats['total_calls']}, "
                   f"Syntax errors: {_tool_call_stats['syntax_errors']} ({syntax_error_rate:.2f}%), "
                   f"Empty outputs: {_tool_call_stats['empty_outputs']}, "
                   f"Runtime errors: {_tool_call_stats['runtime_errors']}, "
                   f"Successes: {_tool_call_stats['successes']}")
    
    return sample


async def reward_func(args, sample, **kwargs):
    """
    The reward function for Python code generation tasks (ToRL).
    
    This function implements reward calculation based on code correctness.
    For ToRL, we typically use string comparison or execution-based verification.
    
    Args:
        args: the arguments
        sample: the sample to evaluate
        **kwargs: additional arguments
    
    Returns:
        float: reward score
    """
    if not isinstance(sample, Sample):
        raise TypeError("Sample must be an instance of Sample class.")
    
    # Extract solution string
    solution_str = sample.prompt + sample.response
    
    # Handle ground_truth
    gt_keys = kwargs.get("gt_keys", None)
    ground_truth = sample.label
    if gt_keys is not None:
        assert isinstance(ground_truth, dict), "ground_truth should be a dict when gt_keys is given"
        gts = [ground_truth[key] for key in gt_keys]
    else:
        if isinstance(ground_truth, dict):
            ground_truth = ground_truth.get("ground_truth", ground_truth.get("code", ground_truth.get("python", "")))
        assert isinstance(ground_truth, str), "ground_truth should be a string when gt_keys is not given"
        gts = [ground_truth]
    
    # Extract Python code from solution
    # Look for code blocks or tool_call results
    python_code_pattern = r"```python\s*(.*?)```|```\s*(.*?)```|<tool_call>.*?\"code\"\s*:\s*\"(.*?)\".*?</tool_call>"
    matches = re.findall(python_code_pattern, solution_str, re.DOTALL)
    
    extracted_codes = []
    for match in matches:
        code = match[0] or match[1] or match[2]
        if code.strip():
            extracted_codes.append(code.strip())
    
    # If no code found, try to extract from answer tag
    if not extracted_codes:
        answer_pattern = r"<answer>([\s\S]*?)</answer>"
        answer_match = re.search(answer_pattern, solution_str, re.DOTALL)
        if answer_match:
            answer_content = answer_match.group(1).strip()
            # Try to extract code from answer
            code_matches = re.findall(python_code_pattern, answer_content, re.DOTALL)
            for match in code_matches:
                code = match[0] or match[1] or match[2]
                if code.strip():
                    extracted_codes.append(code.strip())
    
    # If still no code, use the entire response as potential code
    if not extracted_codes:
        # Check if response looks like code
        if any(keyword in solution_str for keyword in ["def ", "import ", "print(", "="]):
            extracted_codes.append(solution_str.strip())
    
    if not extracted_codes:
        logger.warning("[torl] Failed to extract Python code from solution")
        return 0.0
    
    # Compare with ground truth (simple string comparison for now)
    # In practice, you might want to use execution-based verification
    best_reward = 0.0
    for extracted_code in extracted_codes:
        for gt in gts:
            # Normalize whitespace for comparison
            extracted_normalized = re.sub(r'\s+', ' ', extracted_code.strip())
            gt_normalized = re.sub(r'\s+', ' ', gt.strip())
            
            if extracted_normalized == gt_normalized:
                best_reward = max(best_reward, 1.0)
            else:
                # Partial match (substring or similarity)
                # You can implement more sophisticated comparison here
                if extracted_normalized in gt_normalized or gt_normalized in extracted_normalized:
                    best_reward = max(best_reward, 0.5)
    
    return best_reward

