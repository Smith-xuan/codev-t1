"""
Combined evaluation function:
  Part A — Dynamic curriculum filtering on the training set using eda_tools
           (verify_one_sample with auto-generated testbenches).
  Part B — CVDP benchmark testing (reuses existing custom_eval_cvdp logic).

Usage in launch script:
    --eval-function-path custom_eval_combined.custom_eval_combined
    --eval-dynamic-curriculum
"""

import asyncio
import json
import logging
import os
import sys
import time
from argparse import Namespace
from typing import Any

import pandas as pd

from slime.rollout.base_types import RolloutFnEvalOutput
from slime.utils.types import Sample
from slime.rollout.sglang_rollout import GenerateState
from slime.utils.async_utils import run

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generate_with_iverilog import generate as custom_generate
from eda_tools_reward import _extract_final_verilog, _verify_sync

# Import CVDP eval async function for Part B
from custom_eval_cvdp import _custom_eval_cvdp_async

# Pause/resume the background rollout worker during eval
try:
    from iverilog_async_rollout import (
        flush_global_worker_queue,
        pause_global_worker,
        resume_global_worker,
    )
except ImportError:
    def pause_global_worker(): pass          # noqa: E704
    def resume_global_worker(): pass         # noqa: E704
    def flush_global_worker_queue(): return 0  # noqa: E704

logger = logging.getLogger(__name__)

# Tool definition (same as training)
VERILOG_TOOL_DEFINITION = [
    {
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
                            "A single string containing the FULL Verilog source to simulate.\n"
                            "Must include:\n"
                            "  - The DUT and any submodules.\n"
                            "  - A testbench module named `testbench` that instantiates the DUT and provides stimulus.\n"
                            "Constraints:\n"
                            "  - Do not rely on external files, include directives, or paths.\n"
                            "  - Use $display for textual checks. If you emit errors, surface them clearly.\n"
                            "  - Design code should be synthesizable; testbench may use non-synthesizable constructs."
                        ),
                    }
                },
                "required": ["code"],
            },
        },
    }
]


def custom_eval_combined(
    args: Namespace, rollout_id: int, data_source: Any, evaluation: bool = True
) -> RolloutFnEvalOutput:
    """
    Synchronous wrapper. Pauses background rollout worker during eval.
    """
    pause_global_worker()
    try:
        output = run(_custom_eval_combined_async(args, rollout_id))
    finally:
        flushed = flush_global_worker_queue()
        logger.info(f"Combined eval done. Flushed {flushed} stale groups, resuming worker.")
        resume_global_worker()
    return output


async def _custom_eval_combined_async(
    args: Namespace, rollout_id: int,
) -> RolloutFnEvalOutput:
    """
    Async combined evaluation:
      Part A: Dynamic curriculum on training set (eda_tools verify_one_sample)
      Part B: CVDP benchmark testing (existing pipeline)
    """
    logger.info(f"Starting combined evaluation for rollout {rollout_id}")

    # Run Part A and Part B concurrently
    part_a_task = asyncio.create_task(_eval_training_set_curriculum(args, rollout_id))
    part_b_task = asyncio.create_task(_custom_eval_cvdp_async(args, rollout_id))

    (curriculum_metrics, train_filter_ids), (cvdp_output, _) = await asyncio.gather(
        part_a_task, part_b_task,
    )

    # Merge metrics: CVDP metrics as primary, training set metrics as secondary
    cvdp_metrics = cvdp_output.metrics or {}

    # Override _train_filter_task_ids with Part A's curriculum (training set based)
    all_metrics = {}
    all_metrics.update(cvdp_metrics)
    all_metrics.update(curriculum_metrics)
    all_metrics["_train_filter_task_ids"] = train_filter_ids

    return RolloutFnEvalOutput(data=cvdp_output.data, metrics=all_metrics)


async def _eval_training_set_curriculum(
    args: Namespace, rollout_id: int,
) -> tuple[dict, list[str]]:
    """
    Part A: Evaluate the training set to compute dynamic curriculum.

    For each training problem, generate n_eval_samples, verify with eda_tools,
    and select medium-difficulty problems (1 <= pass_count < n_eval_samples).

    Returns (metrics_dict, medium_task_ids).
    """
    t0 = time.monotonic()

    # Load training data
    train_data_path = args.prompt_data
    if isinstance(train_data_path, (list, tuple)):
        train_data_path = train_data_path[0]

    if not os.path.exists(train_data_path):
        logger.error(f"Training data not found: {train_data_path}")
        return {}, []

    try:
        df = pd.read_parquet(train_data_path)
    except Exception as e:
        logger.error(f"Failed to read training parquet: {e}")
        return {}, []

    n_eval_samples = max(1, getattr(args, "n_samples_per_eval_prompt", 3))
    n_problems = len(df)
    logger.info(
        f"[Curriculum] Evaluating {n_problems} training problems × "
        f"{n_eval_samples} samples = {n_problems * n_eval_samples} total"
    )

    # Build prompts
    state = GenerateState(args)
    sampling_params = state.sampling_params.copy()

    eval_temperature = getattr(args, "eval_temperature", None)
    if eval_temperature is None:
        eval_temperature = args.rollout_temperature
    if eval_temperature is not None and eval_temperature >= 0:
        sampling_params["temperature"] = eval_temperature

    prompt_texts = {}
    task_ids = {}
    gold_codes = {}

    for idx, row in df.iterrows():
        prompt = row["prompt"]
        if hasattr(prompt, "tolist"):
            prompt = prompt.tolist()
        clean_messages = []
        for msg in prompt:
            if isinstance(msg, dict):
                clean_messages.append({str(k): str(v) for k, v in msg.items()})
            else:
                clean_messages.append(msg)

        rm = row["reward_model"]
        task_id = rm.get("task_id", str(idx))
        task_ids[idx] = task_id
        gold_codes[idx] = rm.get("ground_truth", "")

        if args.apply_chat_template:
            try:
                prompt_texts[idx] = state.tokenizer.apply_chat_template(
                    clean_messages,
                    tools=VERILOG_TOOL_DEFINITION,
                    tokenize=False,
                    add_generation_prompt=True,
                    **(args.apply_chat_template_kwargs or {}),
                )
            except Exception:
                prompt_texts[idx] = state.tokenizer.apply_chat_template(
                    clean_messages,
                    tokenize=False,
                    add_generation_prompt=True,
                    **(args.apply_chat_template_kwargs or {}),
                )
        else:
            prompt_texts[idx] = clean_messages

    # Generate responses
    async def generate_single(prompt_text, prob_idx, sample_idx):
        sample = Sample(
            prompt=prompt_text,
            index=prob_idx * n_eval_samples + sample_idx,
            group_index=prob_idx,
            metadata={"id": task_ids[prob_idx], "sample_idx": sample_idx},
        )
        return await custom_generate(args, sample, sampling_params.copy())

    tasks = [
        generate_single(prompt_texts[idx], idx, s)
        for idx in range(n_problems)
        for s in range(n_eval_samples)
    ]
    logger.info(f"[Curriculum] Submitting {len(tasks)} generation tasks")
    all_results = list(await asyncio.gather(*tasks))

    # Group by problem
    results_by_prob = {i: [] for i in range(n_problems)}
    for r in all_results:
        results_by_prob[r.group_index].append(r)

    # Verify each sample against golden code using eda_tools
    logger.info("[Curriculum] Verifying generated code against golden references...")

    async def verify_sample(prob_idx, sample):
        gold = gold_codes[prob_idx]
        if not gold:
            return False
        dut = _extract_final_verilog(sample.response)
        if not dut:
            return False
        return await asyncio.to_thread(_verify_sync, gold, dut)

    # Build verification tasks grouped by problem
    per_problem_info = {}
    verify_tasks = []
    verify_keys = []  # (prob_idx, sample_idx)

    for prob_idx in range(n_problems):
        for s_idx, sample in enumerate(results_by_prob[prob_idx]):
            verify_tasks.append(verify_sample(prob_idx, sample))
            verify_keys.append((prob_idx, s_idx))

    verify_results = await asyncio.gather(*verify_tasks)

    # Aggregate pass counts
    pass_counts = {i: 0 for i in range(n_problems)}
    for (prob_idx, _), passed in zip(verify_keys, verify_results):
        if passed:
            pass_counts[prob_idx] += 1

    # Compute metrics and select medium-difficulty problems
    train_pass1_pass = 0
    train_pass1_total = 0
    train_passn_pass = 0
    train_passn_total = 0
    medium_task_ids = []

    for prob_idx in range(n_problems):
        p = pass_counts[prob_idx]
        n = n_eval_samples
        tid = task_ids[prob_idx]

        train_pass1_pass += p
        train_pass1_total += n
        if p > 0:
            train_passn_pass += 1
        train_passn_total += 1

        # Medium difficulty: not trivially solved, not impossible
        if 0 < p < n:
            medium_task_ids.append(tid)

    train_pass1_rate = train_pass1_pass / train_pass1_total if train_pass1_total > 0 else 0.0
    train_passn_rate = train_passn_pass / train_passn_total if train_passn_total > 0 else 0.0

    elapsed = time.monotonic() - t0
    logger.info(
        f"[Curriculum] Done in {elapsed:.1f}s. "
        f"pass@1={train_pass1_rate:.4f} ({train_pass1_pass}/{train_pass1_total}), "
        f"pass@{n_eval_samples}={train_passn_rate:.4f} ({train_passn_pass}/{train_passn_total}), "
        f"medium problems: {len(medium_task_ids)}/{n_problems}"
    )

    metrics = {
        "eval/train_pass1": train_pass1_pass,
        "eval/train_pass1_total": train_pass1_total,
        "eval/train_pass1_rate": train_pass1_rate,
        f"eval/train_pass{n_eval_samples}": train_passn_pass,
        f"eval/train_pass{n_eval_samples}_total": train_passn_total,
        f"eval/train_pass{n_eval_samples}_rate": train_passn_rate,
        "eval/train_medium_count": len(medium_task_ids),
    }

    return metrics, medium_task_ids
