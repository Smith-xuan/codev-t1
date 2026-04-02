"""
Functional-testbench reward function for Verilog RL training.

This module provides a reward_func compatible with slime's rollout reward
interface.  It evaluates generated Verilog code by running it against a
pre-generated *functional* testbench (created offline by
preprocess_functional_tb.py) and returns a binary 0/1 reward.

Design
------
  - Pre-generated TBs are stored in a JSON file (see preprocess_functional_tb.py).
    Each entry is keyed by problem_id and contains:
      golden_top          : name of the top module in the golden design
      golden_code_renamed : golden Verilog with "_gold" suffix on all modules
      functional_tb       : testbench module (checks only functionally
                            important outputs)
      strict_tb           : original strict TB (kept for reference / fallback)
      status              : "success" | "strict_ok" | "strict_failed" | ...

  - At reward time, for each sample:
    1. Get problem_id from sample.metadata.
    2. Look up the pre-generated entry.
    3. Extract the last valid Verilog module from the rollout generation.
    4. Rename the generated module with the "_gate" suffix.
    5. Write gold_and_tb.v (golden_renamed + functional_tb) and gate.v to a
       temp directory.
    6. Compile with iverilog and run with vvp.
    7. Return 1.0 if "All tests passed." else 0.0.

Environment variables
---------------------
  FUNCTIONAL_TB_PATH    Path to the JSON file produced by
                        preprocess_functional_tb.py.
  EDA_TOOLS_PATH        Path to eda_tools package root.
  IVERILOG_PATH         iverilog binary path (default: "iverilog").
  VVP_PATH              vvp binary path (default: "vvp").
  FUNCTIONAL_TB_TIMEOUT Simulation timeout in seconds (default: 60).
"""

import asyncio
import logging
import os
import re
import shutil
import subprocess
import sys
import tempfile
from functools import lru_cache
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# ── EDA tools ──────────────────────────────────────────────────────────────────
_EDA_TOOLS_PATH = os.environ.get(
    "EDA_TOOLS_PATH",
    "/workspace/S/shiwenxuan/verl/eda_tools",
)
if _EDA_TOOLS_PATH not in sys.path:
    sys.path.insert(0, _EDA_TOOLS_PATH)

from eda_tools.utils import eda_tools as EdaTools  # noqa: E402

# ── Config ─────────────────────────────────────────────────────────────────────
_FUNCTIONAL_TB_PATH = os.environ.get("FUNCTIONAL_TB_PATH", "")
_IVERILOG_BIN = os.environ.get("IVERILOG_PATH", shutil.which("iverilog") or "iverilog")
_VVP_BIN = os.environ.get("VVP_PATH", shutil.which("vvp") or "vvp")
_SIM_TIMEOUT = int(os.environ.get("FUNCTIONAL_TB_TIMEOUT", "60"))

# ── TB cache (loaded once per process) ────────────────────────────────────────
_TB_CACHE: Optional[dict] = None
_TB_CACHE_PATH: str = ""


def _load_tb_cache(path: str) -> dict:
    global _TB_CACHE, _TB_CACHE_PATH
    if _TB_CACHE is not None and _TB_CACHE_PATH == path:
        return _TB_CACHE
    import json
    with open(path) as f:
        _TB_CACHE = json.load(f)
    _TB_CACHE_PATH = path
    logger.info(f"[functional_tb_reward] Loaded {len(_TB_CACHE)} TB entries from {path}")
    return _TB_CACHE


def get_tb_cache() -> dict:
    path = _FUNCTIONAL_TB_PATH
    if not path:
        raise RuntimeError(
            "FUNCTIONAL_TB_PATH env var not set. "
            "Run preprocess_functional_tb.py first and set the path."
        )
    return _load_tb_cache(path)


# ── Code extraction ────────────────────────────────────────────────────────────
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

from verilog_utils import extract_verilog_from_generation  # noqa: E402


# ── Simulation ─────────────────────────────────────────────────────────────────

def _run_simulation(
    golden_code_renamed: str,
    functional_tb: str,
    dut_code_renamed: str,
    timeout: int = _SIM_TIMEOUT,
) -> tuple[bool, str]:
    """
    Compile and simulate golden + functional_tb + dut in a temp dir.

    Returns (passed: bool, output: str).
    """
    tmp_dir = tempfile.mkdtemp(prefix="ftb_reward_")
    try:
        # gold_and_tb.v = renamed golden + functional testbench module
        gold_tb_path = os.path.join(tmp_dir, "gold_and_tb.v")
        with open(gold_tb_path, "w") as f:
            f.write(golden_code_renamed)
            f.write("\n\n")
            f.write(functional_tb)

        # gate.v = renamed DUT
        gate_path = os.path.join(tmp_dir, "gate.v")
        with open(gate_path, "w") as f:
            f.write(dut_code_renamed)

        vvp_path = os.path.join(tmp_dir, "tb.vvp")
        compile_cmd = (
            f"{_IVERILOG_BIN} -g2012 -s testbench -o {vvp_path} "
            f"{gold_tb_path} {gate_path}"
        )
        comp = subprocess.run(
            compile_cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        if comp.returncode != 0:
            return False, f"[compile error]\n{comp.stderr.decode(errors='replace')}"

        run_cmd = f"{_VVP_BIN} -n {vvp_path}"
        sim = subprocess.run(
            run_cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        stdout = sim.stdout.decode(errors="replace")
        passed = "All tests passed." in stdout
        return passed, stdout

    except subprocess.TimeoutExpired:
        return False, "[timeout]"
    except Exception as e:
        return False, f"[exception] {e}"
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def _evaluate_one(problem_id: str, generation: str) -> float:
    """
    Evaluate a single generated response.  Returns 1.0 or 0.0.
    """
    cache = get_tb_cache()
    pid_str = str(problem_id)

    entry = cache.get(pid_str)
    if entry is None:
        logger.warning(f"[functional_tb_reward] No TB entry for problem_id={pid_str}")
        return 0.0

    status = entry.get("status", "")
    functional_tb = entry.get("functional_tb") or entry.get("strict_tb")
    if not functional_tb:
        # Fall back to strict TB if LLM refinement was not run
        if status == "strict_ok":
            functional_tb = entry.get("strict_tb")
        if not functional_tb:
            logger.warning(
                f"[functional_tb_reward] No usable TB for problem_id={pid_str} (status={status})"
            )
            return 0.0

    golden_code_renamed = entry.get("golden_code_renamed", "")
    golden_top = entry.get("golden_top", "")
    if not golden_code_renamed or not golden_top:
        return 0.0

    # Extract Verilog from generation
    dut_code = extract_verilog_from_generation(generation, require_complete=True, keep_testbench=False)
    if not dut_code:
        return 0.0

    # Rename DUT modules with _gate suffix
    eda = EdaTools(quiet=True)
    try:
        dut_top = eda.auto_top(dut_code)
    except Exception:
        return 0.0

    # If DUT top module name differs from golden, rename it to match
    # so the testbench instantiation (golden_top_gate) resolves correctly.
    if dut_top != golden_top:
        # Rename only the top-level module declaration
        dut_code = re.sub(
            rf"\bmodule\s+{re.escape(dut_top)}\b",
            f"module {golden_top}",
            dut_code,
        )
    dut_code_renamed = eda.process_verilog(dut_code, eda.gate_suffix)

    passed, output = _run_simulation(golden_code_renamed, functional_tb, dut_code_renamed)
    logger.debug(
        f"[functional_tb_reward] problem_id={pid_str} passed={passed} "
        f"output_tail={output[-200:].strip()!r}"
    )
    return 1.0 if passed else 0.0


# ── Slime reward function interface ───────────────────────────────────────────

async def reward_func(samples, **kwargs) -> list[float]:
    """
    Slime reward function.  Evaluates generated Verilog via functional TB.

    Each sample must have sample.metadata['problem_id'] set to the problem_id
    from the training parquet (loaded by slime's DataSource).

    Returns a list of floats (0.0 or 1.0) aligned with the input samples.
    """
    loop = asyncio.get_event_loop()
    rewards = []

    for sample in samples:
        # Try multiple metadata key names for robustness
        problem_id = (
            sample.metadata.get("problem_id")
            or sample.metadata.get("task_id")
            or sample.metadata.get("id")
        )

        if problem_id is None:
            logger.warning("[functional_tb_reward] sample has no problem_id in metadata; reward=0")
            rewards.append(0.0)
            continue

        generation = sample.response
        # Run blocking simulation in thread executor to keep async event loop free
        reward = await loop.run_in_executor(
            None, _evaluate_one, problem_id, generation
        )
        rewards.append(reward)

    return rewards


# ── CLI for local testing ──────────────────────────────────────────────────────

def _cli():
    import argparse
    parser = argparse.ArgumentParser(
        description="Test functional_tb_reward on a single (problem_id, generation) pair"
    )
    parser.add_argument("--tb-path", required=True, help="Path to functional_tb.json")
    parser.add_argument("--problem-id", required=True, help="Problem ID to test")
    parser.add_argument("--generation", required=True, help="Path to file containing LLM generation text")
    args = parser.parse_args()

    os.environ["FUNCTIONAL_TB_PATH"] = args.tb_path

    with open(args.generation) as f:
        generation = f.read()

    reward = _evaluate_one(args.problem_id, generation)
    print(f"Reward: {reward}")


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    _cli()
