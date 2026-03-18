
import os
import json
import logging
import asyncio
import subprocess
import shutil
import glob
from typing import Any, List, Dict
from argparse import Namespace
from datetime import datetime
import pandas as pd
import numpy as np
import ray

from slime.rollout.base_types import RolloutFnEvalOutput
from slime.utils.types import Sample
from slime.rollout.sglang_rollout import GenerateState

# Add current directory to path to allow imports
import sys
sys.path.append(os.path.dirname(__file__))

# Import the custom generation function
try:
    from generate_with_iverilog import generate as custom_generate
except ImportError:
    logger = logging.getLogger(__name__)
    logger.warning("Could not import generate_with_iverilog directly, trying to add current file dir to path")
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))
    from generate_with_iverilog import generate as custom_generate

from slime.utils.async_utils import run

# Pause/resume the background rollout worker during eval so that
# (a) eval gets full SGLang capacity and (b) no stale-weight groups accumulate.
try:
    from iverilog_async_rollout import (
        flush_global_worker_queue,
        pause_global_worker,
        resume_global_worker,
    )
except ImportError:
    # Graceful fallback if eval is run standalone without the async rollout module.
    def pause_global_worker(): pass          # noqa: E704
    def resume_global_worker(): pass         # noqa: E704
    def flush_global_worker_queue(): return 0  # noqa: E704

logger = logging.getLogger(__name__)

# Tool definition for verilog_simulator (same as in train data)
VERILOG_TOOL_DEFINITION = [
    {
        "type": "function",
        "function": {
            "name": "verilog_simulator",
            "description": "A verilog simulation tool using iverilog. Executes Verilog code for functional verification. This tool requires a single string that contains ALL required modules including testbench.",
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


def custom_eval_cvdp(
    args: Namespace, rollout_id: int, data_source: Any, evaluation: bool = True
) -> RolloutFnEvalOutput:
    """
    Synchronous wrapper for the async evaluation function.

    Pauses the background rollout worker for the duration of eval so that
    (a) eval gets full SGLang server capacity and (b) no stale-weight
    groups accumulate in the output queue.
    """
    pause_global_worker()
    try:
        output, _ = run(_custom_eval_cvdp_async(args, rollout_id))
    finally:
        # Discard any groups that the worker's in-flight tasks may have
        # pushed to the queue while eval was running (generated with old
        # weights).  Then resume normal rollout.
        flushed = flush_global_worker_queue()
        logger.info(f"Eval done. Flushed {flushed} stale groups, resuming worker.")
        resume_global_worker()
    return output


async def _custom_eval_cvdp_async(
    args: Namespace, rollout_id: int
) -> tuple[RolloutFnEvalOutput, list[list[Sample]]]:
    """
    Async implementation of the CVDP custom evaluation.
    """
    logger.info(f"Starting CVDP custom evaluation for rollout {rollout_id}")

    # Configuration Paths — all configurable via environment variables.
    # Defaults point to paths within the slime repo (examples/iverilog-r1/).
    _THIS_DIR = os.path.dirname(os.path.abspath(__file__))
    BENCHMARK_PATH = os.environ.get(
        "CVDP_BENCHMARK_PATH",
        os.path.join(_THIS_DIR, "data/eval_parquet/cvdp-codegeneration-codev-tool-1.parquet"),
    )
    CODEV_TEST_ROOT = os.environ.get(
        "CODEV_TEST_ROOT",
        os.path.join(_THIS_DIR, "codev_test"),
    )
    # Filtered benchmark JSONL containing only cid002/cid003 (172 questions)
    BENCHMARK_JSONL_PATH = os.path.join(
        CODEV_TEST_ROOT, "benchmark/CVDP/data/raw/cvdp_v1.0.2_cid002_cid003.jsonl"
    )

    # 1. Load the Benchmark Data
    if not os.path.exists(BENCHMARK_PATH):
        logger.error(f"Benchmark file not found: {BENCHMARK_PATH}")
        return RolloutFnEvalOutput(data={}), []

    try:
        df = pd.read_parquet(BENCHMARK_PATH)
    except Exception as e:
        logger.error(f"Failed to read parquet file: {e}")
        return RolloutFnEvalOutput(data={}), []

    # 1.1 Filter to only cid002/cid003 questions (172 out of 302)
    # Load the filtered benchmark JSONL to get the valid task IDs
    cid_filter_ids = set()
    try:
        with open(BENCHMARK_JSONL_PATH) as f:
            for line in f:
                if not line.strip():
                    continue
                entry = json.loads(line)
                cid_filter_ids.add(entry["id"])
        logger.info(f"Loaded {len(cid_filter_ids)} cid002/cid003 task IDs from {BENCHMARK_JSONL_PATH}")
    except Exception as e:
        logger.warning(f"Failed to load filter JSONL {BENCHMARK_JSONL_PATH}: {e}, using all {len(df)} questions")

    if cid_filter_ids:
        df = df[df["task_id"].isin(cid_filter_ids)].reset_index(drop=True)
        logger.info(f"Filtered to {len(df)} cid002/cid003 questions")

    # How many independent samples to generate per problem.
    # pass@1  = average per-sample success rate  (unbiased estimate of single-sample probability)
    # pass@n  = fraction of problems where ≥1 of n samples passes
    n_eval_samples = max(1, getattr(args, "n_samples_per_eval_prompt", 1))
    logger.info(f"Eval: {len(df)} problems × {n_eval_samples} samples = {len(df) * n_eval_samples} total")

    # 2. Build Sample objects
    # IMPORTANT: Apply chat template WITH tools here, so the model sees tool definitions.
    # The generate function in generate_with_iverilog.py will see the prompt as a string
    # (already formatted) and use it directly, avoiding re-application without tools.
    state = GenerateState(args)
    sampling_params = state.sampling_params.copy()

    # Use eval-specific temperature if provided; otherwise fall back to rollout temperature.
    # NOTE: temperature=0 with CUDA flash-attention still has micro-level non-determinism
    # due to floating-point accumulation order differences across batches.  For reliable
    # repeatability, use temperature≥0.01 and rely on pass@n averaging instead.
    eval_temperature = getattr(args, "eval_temperature", None)
    if eval_temperature is None:
        eval_temperature = args.rollout_temperature
    if eval_temperature is not None and eval_temperature >= 0:
        sampling_params["temperature"] = eval_temperature

    # Build prompt texts indexed by problem (row index in df).
    # Each problem will be sampled n_eval_samples times.
    prompt_texts: dict[int, str] = {}
    task_ids: dict[int, str] = {}
    for idx, row in df.iterrows():
        prompt = row['question']
        if hasattr(prompt, 'tolist'):
            prompt = prompt.tolist()
        clean_messages = []
        for msg in prompt:
            if isinstance(msg, dict):
                clean_messages.append({str(k): str(v) for k, v in msg.items()})
            else:
                clean_messages.append(msg)

        task_id = row['task_id']
        task_ids[idx] = task_id

        if args.apply_chat_template:
            try:
                prompt_texts[idx] = state.tokenizer.apply_chat_template(
                    clean_messages,
                    tools=VERILOG_TOOL_DEFINITION,
                    tokenize=False,
                    add_generation_prompt=True,
                    **(args.apply_chat_template_kwargs or {}),
                )
            except Exception as e:
                logger.warning(f"apply_chat_template with tools failed for {task_id}: {e}, trying without tools")
                prompt_texts[idx] = state.tokenizer.apply_chat_template(
                    clean_messages,
                    tokenize=False,
                    add_generation_prompt=True,
                    **(args.apply_chat_template_kwargs or {}),
                )
        else:
            prompt_texts[idx] = clean_messages

    # 3. Generate Responses — n_eval_samples per problem, all concurrent
    # Each (problem, sample_idx) pair gets its own Sample object so that
    # generate_with_iverilog can mutate sampling_params independently.
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
        for idx in range(len(df))
        for s in range(n_eval_samples)
    ]
    logger.info(f"Submitting {len(tasks)} concurrent generation tasks")
    all_results: list[Sample] = list(await asyncio.gather(*tasks))

    # Group results back by problem index: results_by_prob[prob_idx] = [s0, s1, ...]
    results_by_prob: dict[int, list[Sample]] = {i: [] for i in range(len(df))}
    for r in all_results:
        prob_idx = r.group_index
        results_by_prob[prob_idx].append(r)

    logger.info("Generation completed.")

    # 4. Save Results to JSONL
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    eval_name = f"cvdp_eval_{rollout_id}_{timestamp}"
    result_dir = os.path.join(CODEV_TEST_ROOT, "results", "test", "cvdp-v1.0.2", "codegen", eval_name)
    os.makedirs(result_dir, exist_ok=True)

    # Write one raw JSONL per sample (extract_verilog_from_jsonl.py only handles a single
    # string response per line, not a list — so we must run the pipeline once per sample).
    logger.info(f"Saving raw results to {result_dir} ({n_eval_samples} files, 1 response/task each)")
    per_sample_raw_paths = []
    for s in range(n_eval_samples):
        raw_s_path = os.path.join(result_dir, f"raw_s{s}.jsonl")
        per_sample_raw_paths.append(raw_s_path)
        with open(raw_s_path, "w") as f:
            for prob_idx in range(len(df)):
                task_id = task_ids[prob_idx]
                samples_for_prob = results_by_prob[prob_idx]
                response = samples_for_prob[s].response if s < len(samples_for_prob) else ""
                f.write(json.dumps({"task_id": task_id, "responses": response}) + "\n")

    # Also write a combined raw.jsonl for reference / debugging
    raw_jsonl_path = os.path.join(result_dir, "raw.jsonl")
    with open(raw_jsonl_path, "w") as f:
        for prob_idx in range(len(df)):
            task_id = task_ids[prob_idx]
            responses = [smp.response for smp in results_by_prob[prob_idx]]
            f.write(json.dumps({"task_id": task_id, "responses": responses}) + "\n")

    # 5. Run Test Pipeline — once per sample, all samples concurrent
    env = os.environ.copy()
    env["PYTHONPATH"] = f"{CODEV_TEST_ROOT}:{env.get('PYTHONPATH', '')}"

    # pass@1  = sum(pass counts) / sum(total counts)  — per-sample average
    # pass@n  = fraction of problems where ≥1 sample passes (n = n_eval_samples)
    pass1_pass = 0      # numerator for pass@1  (total passing samples across all problems)
    pass1_total = 0     # denominator for pass@1 (total samples = n_problems × n_eval_samples)
    passn_pass = 0      # numerator for pass@n  (problems with ≥1 passing sample)
    passn_total = 0     # denominator for pass@n (n_problems)

    # Per-category tracking (cid002/cid003) — same pass@1 / pass@n breakdown
    cat_pass = {}   # category -> pass@1 numerator
    cat_total = {}  # category -> pass@1 denominator
    cat_passn = {}  # category -> pass@n numerator
    cat_passn_total = {}  # category -> pass@n denominator

    # Load training-set problem IDs so we can classify eval results into
    # easy / medium (training set) / hard.
    _STAGED_DIR = os.environ.get(
        "CVDP_STAGED_DATA_DIR",
        os.path.join(_THIS_DIR, "data/cvdp_testbench_staged"),
    )
    _STAGE1_PATH = os.path.join(_STAGED_DIR, "stage1_medium.jsonl")
    _STAGE2_PATH = os.path.join(_STAGED_DIR, "stage2_hard.jsonl")
    medium_ids = set()
    hard_ids = set()
    for path, id_set in [(_STAGE1_PATH, medium_ids), (_STAGE2_PATH, hard_ids)]:
        try:
            with open(path, "r") as fj:
                for ln in fj:
                    ln = ln.strip()
                    if ln:
                        entry = json.loads(ln)
                        # task_id lives inside extra_info, not at top level
                        tid = entry.get("extra_info", {}).get("task_id", "")
                        if tid:
                            id_set.add(tid)
        except Exception:
            pass
    logger.info(f"Difficulty classification: {len(medium_ids)} medium IDs, {len(hard_ids)} hard IDs")
    diff_pass = {"easy": 0, "medium": 0, "hard": 0}
    diff_total = {"easy": 0, "medium": 0, "hard": 0}

    EXTRACT_SCRIPT = os.environ.get(
        "CVDP_EXTRACT_SCRIPT",
        os.path.join(CODEV_TEST_ROOT, "scripts/extract_verilog_from_jsonl.py"),
    )

    def _parse_report(report_path):
        """Parse multi_sample_report.txt → {task_id: (passed: bool, cid: str)}."""
        results = {}
        if not os.path.exists(report_path):
            logger.warning(f"Report file not found: {report_path}")
            return results
        with open(report_path, "r") as f:
            for line in f:
                if "Pass Count:" not in line:
                    continue
                parts = [p.strip() for p in line.split("|")]
                if len(parts) < 4:
                    continue
                problem_id = parts[1]
                cid = parts[2]
                pass_info = parts[3]
                counts = pass_info.split("Pass Count:")[1].strip().split("/")
                if len(counts) != 2:
                    continue
                try:
                    passed = int(counts[0]) > 0
                except ValueError:
                    continue
                results[problem_id] = (passed, cid)
        return results

    async def _run_sample_pipeline(s):
        """Extract + test for a single sample index; returns {task_id: (passed, cid)}."""
        raw_s_path = per_sample_raw_paths[s]
        final_s_path = os.path.join(result_dir, f"final_s{s}.jsonl")
        custom_test_s = os.path.join(result_dir, f"custom_test_s{s}")

        # Step 5.1: Extract Verilog
        logger.info(f"[s{s}] Running extract_verilog_from_jsonl.py...")
        await asyncio.to_thread(subprocess.run, [
            "python", EXTRACT_SCRIPT,
            "--in_path", raw_s_path,
            "--out_path", final_s_path,
        ], env=env, check=True)

        # Step 5.2: Preprocess (creates testbench workspace)
        logger.info(f"[s{s}] Running cvdp_preprocess.py...")
        await asyncio.to_thread(subprocess.run, [
            "python", "scripts/custom_test/cvdp_preprocess.py",
            "--jsonl", "benchmark/CVDP/data/raw/cvdp_v1.0.2_cid002_cid003.jsonl",
            "--outdir", custom_test_s,
        ], cwd=CODEV_TEST_ROOT, env=env, check=True)

        # Step 5.3: Run Tests
        logger.info(f"[s{s}] Running cvdp_run_test.py...")
        await asyncio.to_thread(subprocess.run, [
            "python", "scripts/custom_test/cvdp_run_test.py",
            "--jsonl", final_s_path,
            "--workspace", custom_test_s,
            "--workers", "16",
        ], cwd=CODEV_TEST_ROOT, env=env, check=True)

        # Step 5.4: Parse Report
        report_path = os.path.join(custom_test_s, "multi_sample_report.txt")
        logger.info(f"[s{s}] Parsing report from {report_path}")
        return _parse_report(report_path)

    try:
        logger.info(f"Running test pipeline for {n_eval_samples} samples concurrently...")
        # sample_results[s] = {task_id: (passed, cid)}
        sample_results: list[dict] = list(
            await asyncio.gather(*[_run_sample_pipeline(s) for s in range(n_eval_samples)])
        )

        # Step 6: Aggregate per-problem pass counts across samples
        # per_problem_info[task_id] = {"pass_count": int, "cid": str}
        per_problem_info: dict[str, dict] = {}
        for s_results in sample_results:
            for task_id, (passed, cid) in s_results.items():
                if task_id not in per_problem_info:
                    per_problem_info[task_id] = {"pass_count": 0, "cid": cid}
                if passed:
                    per_problem_info[task_id]["pass_count"] += 1

        for task_id, info in per_problem_info.items():
            p = info["pass_count"]           # passing samples out of n_eval_samples
            n = n_eval_samples
            cid = info["cid"]
            any_pass = 1 if p > 0 else 0

            # Overall cid002+cid003
            if cid in ["cid002", "cid003"]:
                pass1_pass += p
                pass1_total += n
                passn_pass += any_pass
                passn_total += 1

            # Per-category
            cat_pass[cid] = cat_pass.get(cid, 0) + p
            cat_total[cid] = cat_total.get(cid, 0) + n
            cat_passn[cid] = cat_passn.get(cid, 0) + any_pass
            cat_passn_total[cid] = cat_passn_total.get(cid, 0) + 1

            # Per-difficulty
            if task_id in medium_ids:
                diff_key = "medium"
            elif task_id in hard_ids:
                diff_key = "hard"
            else:
                diff_key = "easy"
            diff_pass[diff_key] += p
            diff_total[diff_key] += n

        pass1_rate = pass1_pass / pass1_total if pass1_total > 0 else 0.0
        passn_rate = passn_pass / passn_total if passn_total > 0 else 0.0
        logger.info(
            f"CVDP cid002+cid003  pass@1={pass1_rate:.4f} ({pass1_pass}/{pass1_total})"
            f"  pass@{n_eval_samples}={passn_rate:.4f} ({passn_pass}/{passn_total})"
        )
        for dk in ["easy", "medium", "hard"]:
            dt = diff_total[dk]
            dp = diff_pass[dk]
            logger.info(f"  {dk}: {dp}/{dt} ({dp/dt:.4f})" if dt > 0 else f"  {dk}: 0/0")

    except subprocess.CalledProcessError as e:
        logger.error(f"External script execution failed: {e}")
    except Exception as e:
        logger.error(f"Unexpected error during CVDP evaluation: {e}")

    # 7. Return Result
    # Use pass@1 as the primary score (per-sample average; comparable across different n_eval_samples).
    score = pass1_rate

    # Assign score to each sample so _compute_zero_std_metrics doesn't crash.
    reward_key = getattr(args, "reward_key", None)
    for s in all_results:
        if reward_key:
            s.reward = {reward_key: score}
        else:
            s.reward = score

    eval_results = {
        "cvdp_score": {
            "rewards": [score] * len(all_results),
            "truncated": [s.status == Sample.Status.TRUNCATED for s in all_results],
            "samples": all_results,
        }
    }

    # Build extra metrics dict for wandb
    extra_metrics = {
        # pass@1: per-sample average success rate
        "eval/cvdp_pass1":       pass1_pass,
        "eval/cvdp_pass1_total": pass1_total,
        "eval/cvdp_pass1_rate":  pass1_rate,
        # pass@n: fraction of problems with ≥1 passing sample
        f"eval/cvdp_pass{n_eval_samples}":       passn_pass,
        f"eval/cvdp_pass{n_eval_samples}_total": passn_total,
        f"eval/cvdp_pass{n_eval_samples}_rate":  passn_rate,
        # keep legacy key for dashboard continuity
        "eval/cvdp_score": pass1_rate,
    }

    for dk in ["easy", "medium", "hard"]:
        dt = diff_total[dk]
        dp = diff_pass[dk]
        extra_metrics[f"eval/cvdp_{dk}_pass1"] = dp
        extra_metrics[f"eval/cvdp_{dk}_total"] = dt
        extra_metrics[f"eval/cvdp_{dk}_pass1_rate"] = dp / dt if dt > 0 else 0.0

    for cid in cat_total:
        cp = cat_pass.get(cid, 0)
        ct = cat_total[cid]
        cpn = cat_passn.get(cid, 0)
        ctn = cat_passn_total.get(cid, 0)
        extra_metrics[f"eval/cvdp_{cid}_pass1"] = cp
        extra_metrics[f"eval/cvdp_{cid}_total"] = ct
        extra_metrics[f"eval/cvdp_{cid}_pass1_rate"] = cp / ct if ct > 0 else 0.0
        extra_metrics[f"eval/cvdp_{cid}_pass{n_eval_samples}_rate"] = cpn / ctn if ctn > 0 else 0.0

    # Dynamic curriculum: problems where 1 ≤ pass_count ≤ n-1 are "medium difficulty"
    # for the current model — not trivially solved, not completely unsolvable.
    # Pass as a private key (prefixed with "_") so it is not logged to wandb but
    # is forwarded to the driver in train_async.py to update the training filter.
    medium_task_ids = [
        tid for tid, info in per_problem_info.items()
        if 0 < info["pass_count"] < n_eval_samples
    ]
    extra_metrics["_train_filter_task_ids"] = medium_task_ids
    logger.info(
        f"Dynamic curriculum: {len(medium_task_ids)} medium problems "
        f"(1–{n_eval_samples-1}/{n_eval_samples} pass) selected as next training set"
    )

    return RolloutFnEvalOutput(data=eval_results, metrics=extra_metrics), []
