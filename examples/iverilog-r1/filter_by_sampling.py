#!/usr/bin/env python3
"""
Filter training data by model sampling for RL training.

For each item (sorted by educational value score), generate N samples using
the SFT model with multi-turn tool calling (iverilog). Keep items where
1 to N-1 samples are correct (not trivially solved, not impossible).
Target: 200 items each for cid002 and cid003 datasets.

Uses OpenAI-compatible /v1/chat/completions API (works with SGLang & vLLM).

Usage examples:
  python filter_by_sampling.py \\
      --input .../r1sft_cid002_3.5k_scored.jsonl \\
      --output ./cid002_filtered_200.jsonl \\
      --data-type cid002 \\
      --api-url http://localhost:30000 \\
      --model-name default \\
      --target-count 5

  python filter_by_sampling.py \\
      --input .../r1_sft_87k_top8107.jsonl \\
      --output ./cid003_filtered_200.jsonl \\
      --data-type cid003 \\
      --api-url http://localhost:30000 \\
      --model-name default \\
      --target-count 200
"""

import argparse
import asyncio
import json
import logging
import os
import re
import signal
import subprocess
import sys
import tempfile
import shutil
import time
import uuid
import resource
import threading
from typing import Optional, List, Dict, Any, Tuple

import aiohttp
from transformers import AutoTokenizer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from verilog_utils import (
    extract_verilog_from_generation,
    clean_verilog_code,
    _parse_tool_call_json,
    verify_one_sample,
    run_function_with_timeout,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("filter_by_sampling")

# ──────────────────────────────────────────────────────────────────────────────
# Prompts & Tool Definitions  (from generate_codev_ds32_vllm_local_tools.py)
# ──────────────────────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """You are a Verilog coding expert who will write Verilog code after careful consideration. 
Your goal is to deliver functionally correct, synthesizable, and efficient RTL that meets the user's requirements.

Principles:
- Reason carefully about the specification, interfaces, and corner cases.
- Validate behavior and iterate as needed using any available tools.
- Iverilog Compatibility: Use robust Verilog-2001 or SystemVerilog-2012 constructs.
  - You should prefer `logic`, `always_ff`, and `always_comb`.
  - Avoid complex SystemVerilog features that have limited support in iverilog (e.g., specialized interfaces, program blocks, or nested struct assignments).
- Prefer clean, portable RTL: separate combinational/sequential logic, avoid unintended latches, avoid unsynthesizable constructs in design code.
- Use clear resets, parameterize widths when appropriate, and write readable, well-commented code.
- When a testbench is requested or required (e.g. by tools), follow these rules:
  1. Clearly state the expected behavior/results in the testbench (e.g. as comments).
  2. Ensure the testbench checks that simulation outputs exactly match the expected results; any mismatch means the design is still buggy.
  3. If the module has a reset signal, include proper reset testing in the testbench.
  4. Provide sufficient and diverse stimulus: cover normal cases, boundary conditions, and corner cases (e.g. 0, maximum values, negative numbers, sign-bit cases, etc.) instead of testing only a single scenario.
  5. Use $display for textual checks. If you emit errors, surface them clearly.
  6. DO NOT use `$monitor` or print signals every clock cycle. This will exceed the context limit.

After thinking, when you finally reach a conclusion, enclose the final verilog code in verilog code block within code tags. i.e.,
```verilog
module top_module(in, out, ...);
  ...
endmodule
```
"""

USER_PROMPT_TEMPLATE = """Design a functionally correct, synthesizable, and efficient Verilog module for the following problem. 
Use any available tools during the process to validate and refine your design if you think it's needed.

The problem is as follows:
{problem}"""

VERILOG_TOOL_DEFINITION = [{
    "type": "function",
    "function": {
        "name": "verilog_simulator",
        "description": (
            "A verilog simulation tool using iverilog. Executes Verilog code for "
            "functional verification. This tool requires a single string that "
            "contains ALL required modules including testbench."
        ),
        "parameters": {
            "type": "object",
            "properties": {
                "code": {
                    "type": "string",
                    "description": (
                        "A single string containing the FULL Verilog source to simulate. "
                        "Must include:\n"
                        "  - The DUT and any submodules.\n"
                        "  - A testbench module named `testbench` that instantiates the "
                        "DUT and provides stimulus.\n"
                        "Constraints:\n"
                        "  - Use synthesizable RTL logic and standard SystemVerilog 2012 "
                        "syntax supported by iverilog."
                        "  - Do not rely on external files, include directives, or paths.\n"
                        "  - Use $display for textual checks. If you emit errors, surface "
                        "them clearly.\n"
                        "  - Avoid $monitor or excessive cycle-by-cycle logging.\n"
                        "  - Design code should be synthesizable; testbench may use "
                        "non-synthesizable constructs."
                    ),
                }
            },
            "required": ["code"],
        },
    },
}]

_VVP_MEM_LIMIT_BYTES = 4 * 1024 * 1024 * 1024


def _set_vvp_resource_limits():
    try:
        resource.setrlimit(resource.RLIMIT_AS, (_VVP_MEM_LIMIT_BYTES, _VVP_MEM_LIMIT_BYTES))
    except (ValueError, OSError):
        pass


# ──────────────────────────────────────────────────────────────────────────────
# Data Loading
# ──────────────────────────────────────────────────────────────────────────────

def load_data(input_path: str) -> List[dict]:
    items = []
    with open(input_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                items.append(json.loads(line))
    items.sort(key=lambda x: x.get("gap_score_total", 0), reverse=True)
    logger.info(f"Loaded {len(items)} items from {input_path}")
    if items:
        scores = [x.get("gap_score_total", 0) for x in items]
        logger.info(f"Score range: {min(scores)} – {max(scores)}")
    return items


def extract_instruction(item: dict, data_type: str) -> str:
    if data_type == "cid002":
        return item.get("instruction", "")
    elif data_type == "cid003":
        for msg in item.get("question", []):
            if isinstance(msg, dict) and msg.get("role") == "user":
                return msg.get("content", "")
        return ""
    raise ValueError(f"Unknown data_type: {data_type}")


def extract_golden_code(item: dict, data_type: str) -> str:
    if data_type == "cid002":
        return item.get("code", "")
    elif data_type == "cid003":
        gt = item.get("ground_truth", "")
        if isinstance(gt, list):
            for entry in gt:
                if isinstance(entry, dict):
                    return entry.get("content", "")
        elif isinstance(gt, dict):
            return gt.get("content", "")
        elif isinstance(gt, str):
            return gt
        return ""
    raise ValueError(f"Unknown data_type: {data_type}")


def get_problem_id(item: dict, idx: int) -> str:
    return str(item.get("problem_id", idx))


# ──────────────────────────────────────────────────────────────────────────────
# SGLang Server Management  (optional auto-start)
# ──────────────────────────────────────────────────────────────────────────────

_sglang_log_fh = None  # kept open for server lifetime


def start_sglang_server(
    model_path: str, port: int = 30000, tp_size: int = 1, mem_fraction: float = 0.9,
    context_length: Optional[int] = None,
) -> subprocess.Popen:
    global _sglang_log_fh
    cmd = [
        sys.executable, "-m", "sglang.launch_server",
        "--model-path", model_path, "--port", str(port),
        "--host", "0.0.0.0", "--tp-size", str(tp_size),
        "--mem-fraction-static", str(mem_fraction), "--trust-remote-code",
    ]
    if context_length:
        cmd += ["--context-length", str(context_length)]
    logger.info(f"Starting SGLang server: {' '.join(cmd)}")

    log_path = os.path.join(os.getcwd(), "sglang_server.log")
    _sglang_log_fh = open(log_path, "w")
    logger.info(f"SGLang server log → {log_path}")
    return subprocess.Popen(
        cmd, stdout=_sglang_log_fh, stderr=subprocess.STDOUT, preexec_fn=os.setsid,
    )


def stop_sglang_server(proc: Optional[subprocess.Popen]):
    global _sglang_log_fh
    if proc is None:
        return
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        proc.wait(timeout=10)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            proc.wait(timeout=5)
        except Exception:
            pass
    if _sglang_log_fh:
        _sglang_log_fh.close()
        _sglang_log_fh = None
    logger.info("SGLang server stopped.")


# ──────────────────────────────────────────────────────────────────────────────
# Server Health Check
# ──────────────────────────────────────────────────────────────────────────────

async def check_server_health(api_url: str, timeout: int = 600) -> bool:
    """Verify the inference server is reachable.  Tries multiple endpoints."""
    endpoints = [
        f"{api_url}/health",
        f"{api_url}/v1/models",
    ]
    start = time.time()
    async with aiohttp.ClientSession() as session:
        while time.time() - start < timeout:
            for ep in endpoints:
                try:
                    async with session.get(ep, timeout=aiohttp.ClientTimeout(total=5)) as resp:
                        if resp.status == 200:
                            body = await resp.text()
                            logger.info(f"Server health OK via {ep} → {body[:200]}")
                            return True
                except (aiohttp.ClientError, asyncio.TimeoutError):
                    pass
            elapsed = int(time.time() - start)
            logger.info(f"Waiting for server at {api_url} … ({elapsed}s / {timeout}s)")
            await asyncio.sleep(5)
    logger.error(f"Server at {api_url} not reachable after {timeout}s")
    return False


async def probe_server_quick(api_url: str) -> bool:
    """Non-blocking single-shot probe (used when --api-url is given)."""
    async with aiohttp.ClientSession() as session:
        for ep in [f"{api_url}/health", f"{api_url}/v1/models"]:
            try:
                async with session.get(ep, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                    if resp.status == 200:
                        logger.info(f"Server probe OK: {ep}")
                        return True
            except (aiohttp.ClientError, asyncio.TimeoutError):
                pass
    return False


# ──────────────────────────────────────────────────────────────────────────────
# Local Iverilog Execution
# ──────────────────────────────────────────────────────────────────────────────

_IVERILOG_TMP_BASE: Optional[str] = None

_DEFAULT_IVERILOG = "/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/iverilog"
_DEFAULT_VVP = "/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/vvp"


def _get_iverilog_bin() -> str:
    return os.getenv("IVERILOG_PATH") or shutil.which("iverilog") or _DEFAULT_IVERILOG


def _get_vvp_bin() -> str:
    return os.getenv("VVP_PATH") or shutil.which("vvp") or _DEFAULT_VVP


def _ensure_iverilog_tmp_base() -> str:
    global _IVERILOG_TMP_BASE
    if _IVERILOG_TMP_BASE is None:
        base = os.getenv("IVERILOG_TMP_DIR", "/tmp/iverilog_filter_tmp")
        os.makedirs(base, exist_ok=True)
        _IVERILOG_TMP_BASE = base
    return _IVERILOG_TMP_BASE


def _write_file_sync(path: str, content: str):
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


async def execute_iverilog_local(
    code: str,
    compile_timeout: int = 30,
    run_timeout: int = 10,
    semaphore: Optional[asyncio.Semaphore] = None,
) -> str:
    MAX_OUTPUT = 50 * 1024
    tmp_dir = None
    compile_proc = None
    run_proc = None

    async def _run():
        nonlocal tmp_dir, compile_proc, run_proc
        base = _ensure_iverilog_tmp_base()
        tmp_dir = await asyncio.to_thread(
            tempfile.mkdtemp, prefix=f"iv_{uuid.uuid4().hex[:8]}_", dir=base,
        )
        sv_file = os.path.join(tmp_dir, "design.sv")
        await asyncio.to_thread(_write_file_sync, sv_file, code)

        iverilog_bin = _get_iverilog_bin()
        vvp_file = os.path.join(tmp_dir, "test.vvp")
        compile_proc = await asyncio.create_subprocess_exec(
            iverilog_bin, "-Wall", "-Winfloop", "-Wno-timescale",
            "-g2012", "-s", "testbench", "-o", vvp_file, sv_file,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
            cwd=tmp_dir, preexec_fn=_set_vvp_resource_limits,
        )
        try:
            _, c_err = await asyncio.wait_for(compile_proc.communicate(), timeout=compile_timeout)
        except asyncio.TimeoutError:
            try:
                compile_proc.kill(); await asyncio.wait_for(compile_proc.wait(), timeout=2)
            except Exception:
                pass
            return f"Compilation timeout after {compile_timeout}s"
        if compile_proc.returncode != 0:
            msg = c_err.decode("utf-8", errors="ignore")[:MAX_OUTPUT].strip()
            return f"Compile Error:\n{msg}" if msg else "Compile Error: (no message)"

        vvp_bin = _get_vvp_bin()
        run_proc = await asyncio.create_subprocess_exec(
            vvp_bin, "-n", vvp_file,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
            cwd=tmp_dir, preexec_fn=_set_vvp_resource_limits,
        )
        try:
            r_out, r_err = await asyncio.wait_for(run_proc.communicate(), timeout=run_timeout)
        except asyncio.TimeoutError:
            try:
                run_proc.kill(); await asyncio.wait_for(run_proc.wait(), timeout=2)
            except Exception:
                pass
            return f"Execution timeout after {run_timeout}s"

        stdout = r_out.decode("utf-8", errors="ignore")[:MAX_OUTPUT]
        stderr = r_err.decode("utf-8", errors="ignore")[:MAX_OUTPUT]
        if stdout and stderr:
            return stdout + f"\nRuntime Error:\n{stderr}"
        if stdout:
            return stdout
        if stderr:
            return f"Runtime Error:\n{stderr}"
        return "Simulation completed with no output"

    try:
        if semaphore:
            async with semaphore:
                return await _run()
        return await _run()
    except Exception as e:
        return f"Execution error: {e}"
    finally:
        for p in [compile_proc, run_proc]:
            if p and p.returncode is None:
                try:
                    p.kill(); await asyncio.wait_for(p.wait(), timeout=1)
                except Exception:
                    pass
        if tmp_dir:
            await asyncio.to_thread(shutil.rmtree, tmp_dir, True)


# ──────────────────────────────────────────────────────────────────────────────
# Content-based fallback parser  (when server doesn't return tool_calls)
# ──────────────────────────────────────────────────────────────────────────────

def _extract_action_from_content(text: str) -> Tuple[str, Optional[str]]:
    """Return ("tool_call", code), ("answer", content), or ("none", None)."""
    m = re.search(r"<tool_call>\s*(\{.*?\})\s*</tool_call>", text, re.DOTALL)
    if m:
        code = _try_extract_code(m.group(1))
        if code:
            return "tool_call", code
    m = re.search(r"<tool_call>\s*(\{.*?)$", text, re.DOTALL)
    if m:
        code = _try_extract_code(m.group(1))
        if code:
            return "tool_call", code
    m = re.search(r"<answer>([\s\S]*?)</answer>", text, re.DOTALL)
    if m:
        return "answer", m.group(1).strip()
    m = re.search(r"<answer>([\s\S]*?)$", text, re.DOTALL)
    if m:
        return "answer", m.group(1).strip()
    return "none", None


def _try_extract_code(json_str: str) -> Optional[str]:
    json_str = json_str.strip()
    try:
        data = json.loads(json_str)
        if data.get("name") == "verilog_simulator":
            c = data.get("arguments", {}).get("code", "")
            if c.strip():
                return c
    except json.JSONDecodeError:
        pass
    code = _parse_tool_call_json(json_str, keep_testbench=True)
    if code and "module" in code.lower():
        return code
    return None


# ──────────────────────────────────────────────────────────────────────────────
# Multi-Turn Generation  (OpenAI-compatible /v1/chat/completions)
# ──────────────────────────────────────────────────────────────────────────────

MAX_CONTEXT_LENGTH = 40960  # overridden by --max-context-length
CONTEXT_SAFETY_MARGIN = 64

_tokenizer: Optional[AutoTokenizer] = None


def load_tokenizer(model_path: str):
    global _tokenizer
    logger.info(f"Loading tokenizer from {model_path} …")
    _tokenizer = AutoTokenizer.from_pretrained(model_path, trust_remote_code=True)
    logger.info("Tokenizer loaded.")


def count_message_tokens(messages: List[Dict[str, Any]]) -> int:
    """Use the tokenizer's chat template to get the exact input token count."""
    if _tokenizer is None:
        raise RuntimeError("Tokenizer not loaded; call load_tokenizer() first")
    try:
        token_ids = _tokenizer.apply_chat_template(
            messages, tokenize=True, add_generation_prompt=True,
            tools=VERILOG_TOOL_DEFINITION,
        )
        return len(token_ids)
    except Exception:
        token_ids = _tokenizer.apply_chat_template(
            messages, tokenize=True, add_generation_prompt=True,
        )
        return len(token_ids)


async def generate_one_sample(
    messages_init: List[Dict[str, str]],
    api_url: str,
    session: aiohttp.ClientSession,
    model_name: str,
    sampling_params: dict,
    max_turns: int = 8,
    iverilog_sem: Optional[asyncio.Semaphore] = None,
    trace: bool = False,
    trace_label: str = "",
) -> str:
    """Single sample: multi-turn generation via /v1/chat/completions.

    Returns concatenated assistant content (including tool-response markers)
    for downstream Verilog extraction.

    If trace=True, prints the full trajectory of every turn to stdout.
    """
    messages = [dict(m) for m in messages_init]
    all_content = ""
    max_new_tokens_cap = sampling_params["max_new_tokens"]

    def _trace_print(text: str):
        if trace:
            print(text, flush=True)

    for turn in range(max_turns):
        input_tokens = await asyncio.to_thread(count_message_tokens, messages)
        max_tokens_this_turn = min(
            max_new_tokens_cap,
            MAX_CONTEXT_LENGTH - CONTEXT_SAFETY_MARGIN - input_tokens,
        )
        if max_tokens_this_turn <= 128:
            logger.warning(
                f"Turn {turn}: context nearly full "
                f"(input_tokens={input_tokens}, room={max_tokens_this_turn}), stopping"
            )
            _trace_print(f"\n[TRACE {trace_label}] Turn {turn}: STOPPED — context full "
                         f"(input={input_tokens}, room={max_tokens_this_turn})")
            break

        logger.debug(
            f"Turn {turn}: input_tokens={input_tokens}, "
            f"max_tokens={max_tokens_this_turn}"
        )

        payload = {
            "model": model_name,
            "messages": messages,
            "tools": VERILOG_TOOL_DEFINITION,
            "tool_choice": "auto",
            "temperature": sampling_params["temperature"],
            "max_tokens": max_tokens_this_turn,
            "top_p": sampling_params.get("top_p", 0.95),
            "stream": False,
        }

        try:
            async with session.post(
                f"{api_url}/v1/chat/completions",
                json=payload,
                timeout=aiohttp.ClientTimeout(total=600),
            ) as resp:
                if resp.status != 200:
                    body = await resp.text()
                    logger.warning(f"HTTP {resp.status} turn {turn}: {body[:500]}")
                    _trace_print(f"\n[TRACE {trace_label}] Turn {turn}: HTTP {resp.status}\n{body[:500]}")
                    break
                data = await resp.json()
        except asyncio.TimeoutError:
            logger.warning(f"Timeout (600s) at turn {turn}")
            _trace_print(f"\n[TRACE {trace_label}] Turn {turn}: TIMEOUT")
            break
        except aiohttp.ClientError as e:
            logger.warning(f"Connection error turn {turn}: {type(e).__name__}: {e}")
            break

        choices = data.get("choices", [])
        if not choices:
            logger.warning(f"Empty choices at turn {turn}")
            break

        msg = choices[0].get("message", {})
        finish_reason = choices[0].get("finish_reason", "")
        content = msg.get("content", "") or ""
        tool_calls = msg.get("tool_calls", None)

        logger.debug(
            f"Turn {turn}: finish={finish_reason}, "
            f"content_len={len(content)}, "
            f"tool_calls={len(tool_calls) if tool_calls else 0}"
        )

        all_content += content

        # ── Path A: server parsed tool_calls (standard OpenAI format) ─────
        if tool_calls:
            _trace_print(f"\n{'─'*80}\n[TRACE {trace_label}] Turn {turn} "
                         f"(Path A: structured tool_calls, finish={finish_reason})\n"
                         f"── Assistant content ({len(content)} chars) ──\n{content}\n")

            assistant_msg: Dict[str, Any] = {"role": "assistant", "content": content, "tool_calls": tool_calls}
            messages.append(assistant_msg)

            for tc in tool_calls:
                func = tc.get("function", {})
                tc_id = tc.get("id", f"call_{turn}")

                if func.get("name") == "verilog_simulator":
                    try:
                        code = json.loads(func.get("arguments", "{}")).get("code", "")
                    except (json.JSONDecodeError, AttributeError):
                        code = ""
                    output = await execute_iverilog_local(code, semaphore=iverilog_sem) if code.strip() else "Error: empty code"
                else:
                    output = f"Error: unknown tool '{func.get('name')}'"

                _trace_print(f"── Tool response ({len(output)} chars) ──\n{output}\n")
                messages.append({"role": "tool", "tool_call_id": tc_id, "content": output})
                all_content += f"\n<tool_response>{output}</tool_response>\n"
            continue

        # ── Path B: no tool_calls; check content for <tool_call> tags ─────
        action, tc_code = _extract_action_from_content(content)
        if action == "tool_call" and tc_code:
            _trace_print(f"\n{'─'*80}\n[TRACE {trace_label}] Turn {turn} "
                         f"(Path B: <tool_call> in content, finish={finish_reason})\n"
                         f"── Assistant content ({len(content)} chars) ──\n{content}\n")

            output = await execute_iverilog_local(tc_code, semaphore=iverilog_sem)

            _trace_print(f"── Tool response ({len(output)} chars) ──\n{output}\n")

            all_content += f"\n<tool_response>{output}</tool_response>\n"
            messages.append({"role": "assistant", "content": content})
            messages.append({"role": "user", "content": f"<tool_response>{output}</tool_response>"})
            continue

        # ── Path C: final answer or nothing actionable ────────────────────
        _trace_print(f"\n{'─'*80}\n[TRACE {trace_label}] Turn {turn} "
                     f"(Path C: final/no-action, finish={finish_reason})\n"
                     f"── Assistant content ({len(content)} chars) ──\n{content}\n")

        messages.append({"role": "assistant", "content": content})
        break

    _trace_print(f"\n{'━'*80}\n[TRACE {trace_label}] Generation ended after "
                 f"{min(turn + 1, max_turns)} turns, all_content={len(all_content)} chars\n{'━'*80}")

    return all_content


# ──────────────────────────────────────────────────────────────────────────────
# Equivalence Checking
# ──────────────────────────────────────────────────────────────────────────────

def _check_equiv_sync(golden: str, generated: str, timeout: int = 60) -> Dict[str, Any]:
    """Return the full result dict from verify_one_sample.

    Always returns a dict with at least {"correct": bool}.  Extra keys
    (parse_error, test_error, error_rate, detail) are preserved so that
    the caller can inspect *why* the check failed.
    """
    if not golden or not generated:
        return {"correct": False, "_reason": "empty golden or generated code"}
    if verify_one_sample is None or run_function_with_timeout is None:
        logger.error("eda_tools unavailable – cannot verify equivalence")
        return {"correct": False, "_reason": "eda_tools unavailable"}
    try:
        result = run_function_with_timeout(verify_one_sample, golden, generated, timeout=timeout)
        if isinstance(result, dict):
            return result
        return {"correct": False, "_reason": f"unexpected return type: {type(result)}"}
    except Exception as e:
        logger.warning(f"Equivalence check exception: {e}")
        return {"correct": False, "_reason": f"exception: {e}"}


async def check_equivalence(golden: str, generated: str, timeout: int = 60) -> Dict[str, Any]:
    return await asyncio.to_thread(_check_equiv_sync, golden, generated, timeout)


# ──────────────────────────────────────────────────────────────────────────────
# Per-Item Processing
# ──────────────────────────────────────────────────────────────────────────────

def _extract_plain_verilog_blocks(text: str) -> Optional[str]:
    """Fallback: extract verilog from plain ```verilog ... ``` code blocks.

    Used when the model doesn't wrap output in <answer>/<tool_call> tags
    (common with OpenAI tool-calling format).
    """
    patterns = [
        r"```verilog\s*([\s\S]*?)```",
        r"```systemverilog\s*([\s\S]*?)```",
        r"```\s*(module\s+[\s\S]*?endmodule[\s\S]*?)```",
    ]
    candidates: List[Tuple[int, str]] = []
    for pat in patterns:
        for m in re.finditer(pat, text, re.IGNORECASE | re.DOTALL):
            code = m.group(1).strip()
            if code and "module" in code.lower() and "endmodule" in code.lower():
                candidates.append((m.end(), code))
    if not candidates:
        return None
    candidates.sort(key=lambda x: x[0], reverse=True)
    return candidates[0][1]


async def process_one_item(
    item: dict, idx: int, data_type: str,
    messages_init: List[Dict[str, str]],
    golden_code: str,
    api_url: str, session: aiohttp.ClientSession,
    model_name: str, sampling_params: dict,
    n_samples: int, max_turns: int,
    iverilog_sem: asyncio.Semaphore,
    debug: bool = False,
) -> Dict[str, Any]:
    pid = get_problem_id(item, idx)
    logger.info(f"[{pid}] Generating {n_samples} samples …")

    if debug:
        responses: List[Any] = []
        for s in range(n_samples):
            print(f"\n{'#'*80}\n[DEBUG] [{pid}] sample {s}/{n_samples}\n{'#'*80}", flush=True)
            try:
                resp = await generate_one_sample(
                    messages_init, api_url, session, model_name,
                    sampling_params, max_turns, iverilog_sem,
                    trace=True, trace_label=f"{pid}/s{s}",
                )
            except Exception as e:
                resp = e
            responses.append(resp)
    else:
        tasks = [
            generate_one_sample(
                messages_init, api_url, session, model_name,
                sampling_params, max_turns, iverilog_sem,
            )
            for _ in range(n_samples)
        ]
        responses = list(await asyncio.gather(*tasks, return_exceptions=True))

    n_correct = 0
    sample_details: List[dict] = []
    debug_extracted_codes: List[Optional[str]] = []
    debug_equiv_results: List[Optional[Dict[str, Any]]] = []

    for s_idx, resp in enumerate(responses):
        if isinstance(resp, Exception):
            logger.warning(f"[{pid}] sample {s_idx} exception: {resp}")
            if debug:
                print(f"\n{'='*80}")
                print(f"[DEBUG] [{pid}] sample {s_idx}: EXCEPTION")
                print(f"  {type(resp).__name__}: {resp}")
                print(f"{'='*80}")
            sample_details.append({"correct": False, "error": str(resp)})
            debug_extracted_codes.append(None)
            debug_equiv_results.append({"correct": False, "_reason": f"exception: {resp}"})
            continue

        verilog = extract_verilog_from_generation(resp, require_complete=True, keep_testbench=False)
        cleaned = clean_verilog_code(verilog)

        if not cleaned:
            plain = _extract_plain_verilog_blocks(resp)
            if plain:
                cleaned = clean_verilog_code(plain)
                if cleaned and debug:
                    print(f"\n[DEBUG] [{pid}] sample {s_idx}: "
                          f"extracted via plain code block fallback")

        if not cleaned:
            if debug:
                print(f"\n{'='*80}")
                print(f"[DEBUG] [{pid}] sample {s_idx}: NO CODE EXTRACTED")
                print(f"  Response length: {len(resp)} chars")
                print(f"  Has <answer> tags: {'<answer>' in resp}")
                print(f"  Has <tool_call> tags: {'<tool_call>' in resp}")
                print(f"  Has ```verilog blocks: {'```verilog' in resp.lower()}")
                print(f"  Has 'module' keyword: {'module' in resp.lower()}")
                print(f"  Has 'endmodule' keyword: {'endmodule' in resp.lower()}")
                print(f"\n  ── Full response content ({len(resp)} chars) ──")
                print(resp[:8000] if len(resp) > 8000 else resp)
                if len(resp) > 8000:
                    print(f"  … (truncated, {len(resp) - 8000} more chars)")
                print(f"{'='*80}")
            sample_details.append({"correct": False, "no_code": True})
            debug_extracted_codes.append(None)
            debug_equiv_results.append({"correct": False, "_reason": "no code extracted"})
            continue

        equiv_result = await check_equivalence(golden_code, cleaned)
        correct = equiv_result.get("correct", False)
        if correct:
            n_correct += 1

        debug_extracted_codes.append(cleaned)
        debug_equiv_results.append(equiv_result)

        if debug and not correct:
            print(f"\n{'='*80}")
            print(f"[DEBUG] [{pid}] sample {s_idx}: CODE EXTRACTED but INCORRECT")
            print(f"  equiv_result = {equiv_result}")
            print(f"{'='*80}")
        elif debug and correct:
            print(f"\n[DEBUG] [{pid}] sample {s_idx}: CORRECT ✓")

        sample_details.append({"correct": correct})

    # ── 当全部 sample 都不正确时，打印完整的诊断信息 ──
    if debug and n_correct == 0:
        print(f"\n{'█'*80}")
        print(f"[DEBUG-DIAG] [{pid}] ALL {n_samples} SAMPLES FAILED (n_correct=0)")
        print(f"{'█'*80}")

        print(f"\n{'─'*80}")
        print(f"[DEBUG-DIAG] [{pid}] GOLDEN CODE ({len(golden_code)} chars):")
        print(f"{'─'*80}")
        print(golden_code)
        print(f"{'─'*80}")

        for s_idx in range(len(responses)):
            print(f"\n{'─'*80}")
            print(f"[DEBUG-DIAG] [{pid}] SAMPLE {s_idx}/{n_samples} "
                  f"── Extracted Code ──")
            print(f"{'─'*80}")
            code = debug_extracted_codes[s_idx] if s_idx < len(debug_extracted_codes) else None
            if code is None:
                print("  (no code extracted)")
            else:
                print(code)

            print(f"\n[DEBUG-DIAG] [{pid}] SAMPLE {s_idx}/{n_samples} "
                  f"── EDA Equiv Result ──")
            er = debug_equiv_results[s_idx] if s_idx < len(debug_equiv_results) else None
            if er is None:
                print("  (no equiv result)")
            else:
                for k, v in er.items():
                    print(f"  {k}: {v}")
            print(f"{'─'*80}")

        print(f"{'█'*80}\n")

    kept = 1 <= n_correct <= (n_samples - 1)
    logger.info(f"[{pid}] correct={n_correct}/{n_samples}  kept={kept}")
    return {
        "problem_id": pid, "n_correct": n_correct,
        "n_total": n_samples, "kept": kept, "samples": sample_details,
    }


# ──────────────────────────────────────────────────────────────────────────────
# Progress / Resume
# ──────────────────────────────────────────────────────────────────────────────

_progress_lock = threading.Lock()


def load_progress(path: str) -> Dict[str, dict]:
    progress: Dict[str, dict] = {}
    if not os.path.exists(path):
        return progress
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                progress[str(obj["problem_id"])] = obj
            except Exception:
                continue
    return progress


def append_progress(path: str, result: dict):
    with _progress_lock:
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(result, ensure_ascii=False) + "\n")


# ──────────────────────────────────────────────────────────────────────────────
# Main Pipeline
# ──────────────────────────────────────────────────────────────────────────────

async def run_filter(args):
    api_url = args.api_url

    # ── Optional auto-start ───────────────────────────────────────────────
    sglang_proc = None
    if args.auto_start_model:
        port = args.port
        api_url = f"http://localhost:{port}"
        sglang_proc = start_sglang_server(
            args.auto_start_model, port, args.tp_size, args.mem_fraction,
            context_length=args.max_context_length,
        )

    try:
        # ── Health check ──────────────────────────────────────────────────
        if sglang_proc:
            ok = await check_server_health(api_url, timeout=args.server_timeout)
        else:
            ok = await probe_server_quick(api_url)
        if not ok:
            logger.error(f"Cannot reach server at {api_url}. Aborting.")
            return

        await _run_filter_inner(args, api_url)
    finally:
        stop_sglang_server(sglang_proc)


async def _run_filter_inner(args, api_url: str):
    global MAX_CONTEXT_LENGTH
    MAX_CONTEXT_LENGTH = args.max_context_length
    logger.info(f"Max context length = {MAX_CONTEXT_LENGTH}")

    tokenizer_path = args.tokenizer or args.auto_start_model
    if not tokenizer_path:
        logger.error("No tokenizer path. Use --tokenizer or --auto-start-model."); return
    load_tokenizer(tokenizer_path)

    items = load_data(args.input)
    if not items:
        logger.error("No items loaded."); return

    # ── Resume ────────────────────────────────────────────────────────────
    progress_path = args.output + ".progress.jsonl"
    progress: Dict[str, dict] = {}
    if args.resume:
        progress = load_progress(progress_path)
        logger.info(f"Resuming: {len(progress)} items already processed")

    already_kept = sum(1 for v in progress.values() if v.get("kept"))
    if already_kept >= args.target_count:
        logger.info(f"Already have {already_kept} ≥ {args.target_count} kept items.")
        _save_final_output(items, args.data_type, progress, args.output, args.target_count)
        return

    # ── Build messages cache ────────────────────────────────────────────────
    logger.info("Building messages …")
    messages_cache: Dict[int, List[Dict[str, str]]] = {}
    golden_codes: Dict[int, str] = {}
    for i, item in enumerate(items):
        instruction = extract_instruction(item, args.data_type)
        if not instruction:
            continue
        messages_cache[i] = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": USER_PROMPT_TEMPLATE.format(problem=instruction)},
        ]
        golden_codes[i] = extract_golden_code(item, args.data_type)

    sampling_params = {
        "temperature": args.temperature,
        "max_new_tokens": args.max_new_tokens,
        "top_p": 0.95,
    }

    # ── Concurrent processing ─────────────────────────────────────────────
    iverilog_sem = asyncio.Semaphore(args.iverilog_concurrency)
    item_sem = asyncio.Semaphore(args.max_concurrent)
    kept_count = already_kept
    processed_count = len(progress)
    stop_event = asyncio.Event()
    item_ptr = 0
    ptr_lock = asyncio.Lock()
    stats_lock = asyncio.Lock()
    total_items = len(items)

    conn = aiohttp.TCPConnector(limit=args.max_concurrent * args.n_samples * 2)
    async with aiohttp.ClientSession(connector=conn) as session:

        async def worker():
            nonlocal item_ptr, kept_count, processed_count
            while True:
                if stop_event.is_set():
                    return
                async with ptr_lock:
                    if item_ptr >= total_items or stop_event.is_set():
                        return
                    idx = item_ptr; item_ptr += 1

                item = items[idx]
                pid = get_problem_id(item, idx)
                if pid in progress or idx not in messages_cache:
                    continue

                async with item_sem:
                    if stop_event.is_set():
                        return
                    try:
                        result = await process_one_item(
                            item, idx, args.data_type,
                            messages_cache[idx], golden_codes[idx],
                            api_url, session, args.model_name,
                            sampling_params, args.n_samples,
                            args.max_turns, iverilog_sem,
                            debug=args.debug,
                        )
                    except Exception as e:
                        logger.error(f"[{pid}] Unhandled error: {e}")
                        result = {"problem_id": pid, "n_correct": 0,
                                  "n_total": args.n_samples, "kept": False, "error": str(e)}

                append_progress(progress_path, result)
                async with stats_lock:
                    processed_count += 1
                    progress[pid] = result
                    if result.get("kept"):
                        kept_count += 1
                        logger.info(f"★ Kept {kept_count}/{args.target_count}  (processed {processed_count}/{total_items})")
                    if kept_count >= args.target_count:
                        stop_event.set()

        workers = [asyncio.create_task(worker()) for _ in range(args.max_concurrent)]
        await asyncio.gather(*workers, return_exceptions=True)

    logger.info(f"Finished. Processed {processed_count}, kept {kept_count}.")
    _save_final_output(items, args.data_type, progress, args.output, args.target_count)


def _save_final_output(items, data_type, progress, output_path, target_count):
    kept = []
    for i, item in enumerate(items):
        pid = get_problem_id(item, i)
        res = progress.get(pid, {})
        if res.get("kept"):
            item_out = dict(item)
            item_out["_filter_n_correct"] = res.get("n_correct", 0)
            item_out["_filter_n_total"] = res.get("n_total", 0)
            kept.append(item_out)
        if len(kept) >= target_count:
            break
    with open(output_path, "w", encoding="utf-8") as f:
        for item in kept:
            f.write(json.dumps(item, ensure_ascii=False) + "\n")
    logger.info(f"Saved {len(kept)} items to {output_path}")


# ──────────────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser(description="Filter RL training data by model sampling")

    p.add_argument("--input", required=True, help="Scored JSONL input file")
    p.add_argument("--output", required=True, help="Filtered JSONL output file")
    p.add_argument("--data-type", required=True, choices=["cid002", "cid003"])

    p.add_argument("--api-url", required=True,
                    help="Base URL of inference server (e.g. http://localhost:30000)")
    p.add_argument("--model-name", default="default",
                    help="Model name for /v1/chat/completions (use 'default' for SGLang)")

    p.add_argument("--auto-start-model", default=None,
                    help="If set, auto-start SGLang with this HF model path")
    p.add_argument("--tokenizer", default=None,
                    help="HF model/tokenizer path for token counting "
                         "(defaults to --auto-start-model)")
    p.add_argument("--port", type=int, default=30000)
    p.add_argument("--tp-size", type=int, default=4)
    p.add_argument("--mem-fraction", type=float, default=0.7)
    p.add_argument("--server-timeout", type=int, default=600)

    p.add_argument("--n-samples", type=int, default=5)
    p.add_argument("--target-count", type=int, default=200)
    p.add_argument("--max-turns", type=int, default=8)
    p.add_argument("--temperature", type=float, default=1.0)
    p.add_argument("--max-new-tokens", type=int, default=32768,
                    help="Max tokens per generation turn (default 16384; auto-adjusted "
                         "per turn based on remaining context)")
    p.add_argument("--max-context-length", type=int, default=40960,
                    help="Model context window size (default 40960)")

    p.add_argument("--max-concurrent", type=int, default=8)
    p.add_argument("--iverilog-concurrency", type=int, default=32)

    p.add_argument("--resume", action="store_true")
    p.add_argument("--debug", action="store_true",
                    help="Debug mode: print detailed per-sample diagnostics")

    args = p.parse_args()

    if args.debug:
        args.max_concurrent = min(args.max_concurrent, 1)
        logging.getLogger("filter_by_sampling").setLevel(logging.DEBUG)
        logger.info("Debug mode ON: max_concurrent=1, verbose output enabled")

    os.makedirs("./tmp/testcase", exist_ok=True)
    os.makedirs("./tmp/work", exist_ok=True)

    asyncio.run(run_filter(args))


if __name__ == "__main__":
    main()
