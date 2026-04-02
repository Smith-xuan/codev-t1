"""
Reward function using eda_tools automated testbench generation & equivalence checking.

Instead of relying on pre-generated CVDP testbenches, this reward function uses
eda_tools.core.verify_one_sample() to automatically generate a testbench from the
golden reference code and check equivalence with the model's generated code.

Usage in launch script:
    --custom-rm-path eda_tools_reward.reward_func
"""

import asyncio
import logging
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from verilog_utils import extract_verilog_from_generation, clean_verilog_code

logger = logging.getLogger(__name__)

# Timeout for verify_one_sample (seconds)
VERIFY_TIMEOUT = int(os.environ.get("EDA_TOOLS_VERIFY_TIMEOUT", "120"))


def _extract_final_verilog(response: str):
    """Extract final Verilog code from a (potentially multi-turn) model response."""
    code = extract_verilog_from_generation(response)
    if not code:
        return None
    cleaned = clean_verilog_code(code)
    return cleaned if cleaned else None


def _verify_sync(gold_code: str, dut_code: str) -> bool:
    """
    Synchronous verification using eda_tools. Called via asyncio.to_thread.

    Uses run_function_with_timeout to prevent hangs in iverilog/verilator.
    """
    from eda_tools.core import verify_one_sample, run_function_with_timeout

    try:
        result = run_function_with_timeout(
            verify_one_sample, gold_code, dut_code, timeout=VERIFY_TIMEOUT,
        )
        return result.get("correct", False)
    except Exception as e:
        logger.warning(f"verify_one_sample raised: {e}")
        return False


async def reward_func(args, sample, **kwargs) -> float:
    """
    Compute reward using eda_tools automated testbench equivalence checking.

    Expects sample.label to be a dict with:
      - "ground_truth": golden Verilog code (NOT the "__CVDP_TESTBENCH__" marker)
      - "task_id": problem identifier (for logging)

    Returns 1.0 if the generated code is equivalent to the golden code, 0.0 otherwise.
    """
    t0 = time.monotonic()

    label = sample.label
    if not isinstance(label, dict):
        logger.debug("eda_tools_reward: label is not a dict, returning 0.0")
        return 0.0

    gold_code = label.get("ground_truth", "")
    task_id = label.get("task_id", "unknown")

    if not gold_code or gold_code == "__CVDP_TESTBENCH__":
        logger.debug(f"eda_tools_reward [{task_id}]: no gold_code or CVDP marker, returning 0.0")
        return 0.0

    dut_code = _extract_final_verilog(sample.response)
    if not dut_code:
        logger.debug(f"eda_tools_reward [{task_id}]: no verilog extracted from response")
        return 0.0

    passed = await asyncio.to_thread(_verify_sync, gold_code, dut_code)
    reward = 1.0 if passed else 0.0

    elapsed = time.monotonic() - t0
    logger.debug(f"eda_tools_reward [{task_id}]: reward={reward} ({elapsed:.1f}s)")

    return reward
