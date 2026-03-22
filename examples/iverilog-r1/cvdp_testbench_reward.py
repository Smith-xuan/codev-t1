"""
cvdp_testbench_reward.py
========================
Reward function that evaluates generated Verilog code by running the official
CVDP testbench for each task, rather than checking equivalence against golden code.

Usage in launch script
----------------------
  --custom-rm-path cvdp_testbench_reward.reward_func

Required one-time setup
-----------------------
Pre-generate the 172 test-environment templates once:

    cd /workspace/S/shiwenxuan/codev_test
    python scripts/custom_test/cvdp_preprocess.py \
        --jsonl benchmark/CVDP/data/raw/cvdp_v1.0.2_cid002_cid003.jsonl \
        --outdir /workspace/S/shiwenxuan/codev_test/train_testenv

Then set CVDP_TESTENV_ROOT (or rely on the default):
    export CVDP_TESTENV_ROOT=/workspace/S/shiwenxuan/codev_test/train_testenv

How it works (per rollout sample)
-----------------------------------
1. Check sample.label["ground_truth"] == "__CVDP_TESTBENCH__".
2. Get task_id from sample.label["task_id"].
3. Extract the final ```verilog``` block from sample.response.
4. Look up pre-generated test environment: {CVDP_TESTENV_ROOT}/{cid}/{task_id}/
5. Create an isolated run directory in TMPDIR (copy of template).
6. Write the generated code to rtl/{VERILOG_SOURCES filename}.
7. Run pytest on src/test_runner.py with a timeout.
8. PASSED → reward 1.0, FAILED/TIMEOUT/ERROR → reward 0.0.

The format reward (+0.5 for clean final code block) from generate_with_iverilog is
NOT applied here; the testbench result alone determines the reward.
"""

import asyncio
import json
import logging
import os
import resource
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Optional

# Memory limit for pytest/cocotb/vvp subprocess tree (bytes).
# Prevents a single model-generated testbench from consuming unbounded RAM
# (e.g. 1.8 TB) via cocotb → vvp.  The limit is inherited by child processes.
_SUBPROCESS_MEM_LIMIT_BYTES = 4 * 1024 * 1024 * 1024  # 4 GB


def _set_mem_limit():
    """preexec_fn: cap virtual address space for the subprocess tree."""
    try:
        resource.setrlimit(resource.RLIMIT_AS, (_SUBPROCESS_MEM_LIMIT_BYTES, _SUBPROCESS_MEM_LIMIT_BYTES))
    except (ValueError, OSError):
        pass

from slime.utils.types import Sample

# Import the canonical Verilog extraction logic.
# This is the same script called by custom_eval_cvdp.py so training and eval
# use identical extraction rules.
_EXTRACT_SCRIPT_DIR = os.environ.get(
    "CODEV_TEST_ROOT",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "codev_test"),
)
_EXTRACT_SCRIPT_DIR = os.path.join(_EXTRACT_SCRIPT_DIR, "scripts")
if _EXTRACT_SCRIPT_DIR not in sys.path:
    sys.path.insert(0, _EXTRACT_SCRIPT_DIR)
from extract_verilog_from_jsonl import (  # noqa: E402
    clean_verilog_code,
    extract_verilog_from_generation,
)

logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────────────────────
# Constants
# ────────────────────────────────────────────────────────────────────────────

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))

CVDP_TESTENV_ROOT = os.environ.get(
    "CVDP_TESTENV_ROOT",
    os.path.join(_THIS_DIR, "codev_test", "train_testenv"),
)

# Additional binary directory that provides iverilog / vvp / yosys.
# Defaults to the directory containing IVERILOG_PATH so cocotb_tools'
# shutil.which("iverilog") can find the binary even when PATH is not set.
_iverilog_bin = os.environ.get("IVERILOG_PATH", "")
_iverilog_dir = os.path.dirname(_iverilog_bin) if _iverilog_bin else ""
# Ray runtime-env always sets CVDP_EXTRA_BIN_PATH (often to "").  Using .get(..., default)
# would not fall back when the key exists but is empty; cocotb then cannot find iverilog on PATH.
EXTRA_BIN_PATH = os.environ.get("CVDP_EXTRA_BIN_PATH", "").strip() or _iverilog_dir

# Determine the pytest command to use for CVDP testbench runs.
# Priority:
#   1. CVDP_PYTEST_PATH env var — set this to an absolute path when pytest/cocotb
#      live in a separate Python environment from the one running this reward function.
#   2. sys.executable -m pytest — uses the *same* Python that runs this reward
#      function, guaranteed to be on disk even without a modified PATH.
_cvdp_pytest_override = os.environ.get("CVDP_PYTEST_PATH", "")
# Only use the override if it points to an actual file; bare names like "pytest"
# are NOT trusted because Ray workers may not have it on PATH.
if _cvdp_pytest_override and os.path.isfile(_cvdp_pytest_override):
    CVDP_PYTEST_CMD = [_cvdp_pytest_override]
else:
    CVDP_PYTEST_CMD = [sys.executable, "-m", "pytest"]

# Per-test timeout (seconds) – keep equal to cvdp_run_test.py default
TEST_TIMEOUT = 120

# Special marker stored in reward_model.ground_truth
CVDP_TESTBENCH_MARKER = "__CVDP_TESTBENCH__"

# Cache: task_id → Path of pre-generated template directory
_TASK_DIR_CACHE: dict[str, Optional[Path]] = {}
_TASK_DIR_CACHE_BUILT = False


# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

def _build_task_dir_cache(testenv_root: str) -> None:
    """Scan testenv_root once and populate _TASK_DIR_CACHE."""
    global _TASK_DIR_CACHE_BUILT
    root = Path(testenv_root)
    if not root.is_dir():
        logger.warning(f"[cvdp_testbench] CVDP_TESTENV_ROOT not found: {root}. "
                       f"Run cvdp_preprocess.py first.")
        _TASK_DIR_CACHE_BUILT = True
        return

    for meta_path in root.rglob("meta.json"):
        try:
            with open(meta_path, "r") as f:
                meta = json.load(f)
            task_id = meta.get("id")
            if task_id:
                _TASK_DIR_CACHE[task_id] = meta_path.parent
        except Exception:
            pass

    logger.info(f"[cvdp_testbench] Loaded {len(_TASK_DIR_CACHE)} task dirs from {root}")
    _TASK_DIR_CACHE_BUILT = True


def _get_task_dir(task_id: str) -> Optional[Path]:
    """Return the pre-generated template directory for task_id, or None."""
    if not _TASK_DIR_CACHE_BUILT:
        _build_task_dir_cache(CVDP_TESTENV_ROOT)
    return _TASK_DIR_CACHE.get(task_id)


def _extract_final_verilog(response: str) -> Optional[str]:
    """
    Extract the final Verilog code from a (potentially multi-turn) model response.

    Delegates to extract_verilog_from_generation + clean_verilog_code from
    /workspace/S/shiwenxuan/cvdp_benchmark/scripts/extract_verilog_from_jsonl.py,
    the same script that custom_eval_cvdp.py invokes for offline evaluation.
    Extraction priority:
      1. Last complete ```verilog/sv``` block inside the last <answer> tag.
      2. Last complete Verilog code extracted from <tool_call> arguments
         (multi-turn trajectory), with testbench modules removed.
    Returns None if no complete module…endmodule is found.
    """
    code = extract_verilog_from_generation(response)
    if not code:
        return None
    cleaned = clean_verilog_code(code)
    return cleaned if cleaned else None


def _parse_dotenv(dotenv_path: Path) -> dict:
    """Parse a .env file into a dict of key→value strings."""
    env_vars = {}
    if not dotenv_path.exists():
        return env_vars
    with open(dotenv_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                env_vars[key.strip()] = value.strip()
    return env_vars


def _run_test_sync(task_id: str, code: str, template_dir: Path) -> bool:
    """
    Synchronous test runner (called via asyncio.to_thread).

    Creates an isolated run directory, writes the generated code, runs pytest,
    and returns True iff pytest exits with code 0.
    """
    # Create isolated run dir in TMPDIR (fast local storage, not NFS)
    run_dir = Path(tempfile.mkdtemp(prefix=f"cvdp_{task_id[:20]}_{uuid.uuid4().hex[:6]}_"))
    try:
        # Copy template
        shutil.copytree(str(template_dir), str(run_dir), dirs_exist_ok=True)

        # Determine RTL file name from .env
        env_vars = _parse_dotenv(run_dir / "src" / ".env")
        verilog_sources = env_vars.get("VERILOG_SOURCES", "/code/rtl/design.sv")
        target_rtl = Path(verilog_sources).name  # e.g. "16qam_mapper.sv"

        # Write generated code to rtl/{target_rtl}
        rtl_path = run_dir / "rtl" / target_rtl
        rtl_path.parent.mkdir(parents=True, exist_ok=True)
        rtl_path.write_text(code, encoding="utf-8")

        # Build subprocess environment.
        # CVDP_PYTEST_CMD uses sys.executable -m pytest by default so that
        # pytest is always findable (no PATH dependency in Ray workers).
        # EXTRA_BIN_PATH is still appended to PATH so that iverilog / vvp /
        # yosys binaries remain discoverable by cocotb.
        proc_env = os.environ.copy()
        current_path = proc_env.get("PATH", "")
        if EXTRA_BIN_PATH and EXTRA_BIN_PATH not in current_path:
            proc_env["PATH"] = f"{current_path}:{EXTRA_BIN_PATH}"
        proc_env.update(env_vars)
        # Fix VERILOG_SOURCES path: strip docker-style /code/ prefix
        if "VERILOG_SOURCES" in proc_env:
            proc_env["VERILOG_SOURCES"] = proc_env["VERILOG_SOURCES"].replace("/code/", "")

        result = subprocess.run(
            CVDP_PYTEST_CMD + ["-v", "-s", "src/test_runner.py"],
            cwd=str(run_dir),
            capture_output=True,
            text=True,
            encoding="utf-8",
            env=proc_env,
            timeout=TEST_TIMEOUT,
            preexec_fn=_set_mem_limit,
        )
        if result.returncode != 0:
            # Log the first 2000 chars of pytest output to diagnose silent failures
            output_snippet = (result.stdout + result.stderr)[:2000]
            logger.warning(
                f"[cvdp_testbench] pytest FAILED (rc={result.returncode}) "
                f"for task {task_id}. Output:\n{output_snippet}"
            )
        return result.returncode == 0

    except subprocess.TimeoutExpired:
        logger.warning(f"[cvdp_testbench] Timeout ({TEST_TIMEOUT}s) for task {task_id}")
        return False
    except Exception as e:
        logger.warning(f"[cvdp_testbench] Error running test for {task_id}: {e}")
        return False
    finally:
        try:
            shutil.rmtree(str(run_dir), ignore_errors=True)
        except Exception:
            pass


# ────────────────────────────────────────────────────────────────────────────
# Public reward function
# ────────────────────────────────────────────────────────────────────────────

async def reward_func(args, sample, **kwargs) -> float:
    """
    CVDP testbench-based reward function.

    Returns:
        1.0  – testbench passed
        0.0  – testbench failed / timeout / no code extracted / task not found
    """
    if not isinstance(sample, Sample):
        raise TypeError("sample must be an instance of Sample.")

    # ── 1. Extract task_id and verify marker ──────────────────────────────
    label = sample.label
    if not isinstance(label, dict):
        logger.debug("[cvdp_testbench] label is not a dict, returning 0.")
        return 0.0

    marker = label.get("ground_truth", "")
    task_id = label.get("task_id", "")

    if marker != CVDP_TESTBENCH_MARKER or not task_id:
        logger.debug(f"[cvdp_testbench] Not a CVDP testbench sample "
                     f"(marker={marker!r}, task_id={task_id!r}), returning 0.")
        return 0.0

    # ── 2. Extract final Verilog code ─────────────────────────────────────
    code = _extract_final_verilog(sample.response)
    if not code:
        logger.info(f"[cvdp_testbench] No verilog block found in response for {task_id}.")
        return 0.0

    # ── 3. Find pre-generated test environment ────────────────────────────
    template_dir = _get_task_dir(task_id)
    if template_dir is None:
        logger.warning(f"[cvdp_testbench] No test env found for task_id={task_id}. "
                       f"Run cvdp_preprocess.py to generate environments.")
        return 0.0

    # ── 4. Run test in a thread (subprocess is blocking) ──────────────────
    import time as _time
    _t0 = _time.monotonic()
    passed = await asyncio.to_thread(_run_test_sync, task_id, code, template_dir)
    t_reward = _time.monotonic() - _t0

    # Attach reward timing to sample so iverilog_async_rollout can aggregate it
    if not hasattr(sample, '_timing'):
        sample._timing = {}
    sample._timing['t_reward'] = t_reward

    reward = 1.0 if passed else 0.0
    logger.info(f"[cvdp_testbench] task={task_id} passed={passed} reward={reward}")
    return reward
