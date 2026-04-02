#!/usr/bin/env python3
"""
Preprocess a training parquet to generate functional (LLM-refined) testbenches.

Workflow for each sample:
  1. Extract golden Verilog code and problem description.
  2. Auto-generate a *strict* equivalence testbench via eda_tools (full-cycle,
     full-signal comparison).
  3. Send (problem description + golden code + strict TB) to DeepSeek to
     produce a *functional* testbench that only checks the signals the problem
     actually cares about.
  4. Write results to a JSON file indexed by problem_id.

The output JSON is consumed by functional_tb_reward.py during RL training.

Usage
-----
    python preprocess_functional_tb.py \\
        --parquet /nfs_global/.../train.parquet \\
        --output  /nfs_global/.../functional_tb.json \\
        --workers 8 \\
        --llm-workers 16

Environment variables
---------------------
    EDA_TOOLS_PATH   Path to eda_tools package root (default: see DEFAULT_EDA_TOOLS_PATH)
    ARK_API_KEY        火山 Ark API Key（与 generate_instruction_for_non_r1.py 一致）
    ARK_BASE_URL       默认 https://ark.cn-beijing.volces.com/api/v3
    ARK_MODEL          逻辑模型名，默认 ds-v3.2（见 ark_llm.MODEL_MAPPING）
    IVERILOG_PATH    iverilog binary path (default: "iverilog")
    VVP_PATH         vvp binary path (default: "vvp")
    YOSYS_PATH       yosys binary path (default: "yosys")

LLM 使用 volcenginesdkarkruntime.Ark，逻辑同 generate_instruction_for_non_r1.py。
"""

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
import traceback
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor, as_completed
from pathlib import Path

import pandas as pd

# ── EDA tools ──────────────────────────────────────────────────────────────────
DEFAULT_EDA_TOOLS_PATH = os.environ.get(
    "EDA_TOOLS_PATH",
    "/workspace/S/shiwenxuan/verl/eda_tools",
)
if DEFAULT_EDA_TOOLS_PATH not in sys.path:
    sys.path.insert(0, DEFAULT_EDA_TOOLS_PATH)

from eda_tools.utils import eda_tools as EdaTools  # noqa: E402

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)
from ark_llm import ask_llm, build_ark_client  # noqa: E402

# ── LLM ────────────────────────────────────────────────────────────────────────
_LLM_SYSTEM_PROMPT = """\
You are an expert digital circuit verification engineer.

You are given:
  1. A hardware design problem description.
  2. The golden (reference) Verilog implementation.
  3. A strict equivalence testbench that compares ALL output signals between
     a golden design and a DUT across many random input cycles.

The strict testbench is overly conservative: it treats the two designs as
non-equivalent if ANY output differs at ANY cycle—even for signals that are
not required by the problem (e.g., a reset-forced-low output that is
technically a don't-care once the circuit is in normal operation).

Your task: modify ONLY the trigger signal assignment inside the
  always @(*) begin … end
block so that `trigger` fires only when the *functionally important* outputs
differ.  "Functionally important" means: the outputs that the problem
description explicitly requires to be correct.

Rules:
- Keep ALL other parts of the testbench exactly as-is (module declarations,
  wire/reg declarations, port connections, random input generation, clock
  toggling, reset tasks, error counting, initial block, etc.).
- Do NOT add, remove, or rename any signals.
- Do NOT change the testbench module name or port list.
- Return ONLY the complete modified testbench module wrapped in a
  ```verilog … ``` code block.  No prose outside the code block.\
"""


def _llm_refine_tb(
    problem_desc: str,
    golden_code: str,
    strict_tb: str,
    client,
    model_name: str = "ds-v3.2",
    use_batch: bool = False,
    enable_thinking: bool = True,
    temperature: float = 0.2,
) -> str | None:
    """Call LLM to refine strict TB into a functional TB.

    Returns the refined testbench string, or None on failure.
    """
    user_msg = f"""\
## Problem Description

{problem_desc}

## Golden Implementation

```verilog
{golden_code}
```

## Strict Testbench (modify only the trigger assignment)

```verilog
{strict_tb}
```

Return the complete modified testbench in a ```verilog``` code block.\
"""
    response = ask_llm(
        client,
        messages=[
            {"role": "system", "content": _LLM_SYSTEM_PROMPT},
            {"role": "user", "content": user_msg},
        ],
        model_name=model_name,
        use_batch=use_batch,
        enable_thinking=enable_thinking,
        temperature=temperature,
    )
    content = response.choices[0].message.content
    matches = re.findall(r"```verilog\s*(.*?)```", content, re.DOTALL)
    if matches:
        return matches[-1].strip()
    return None


# ── Strict TB generation (runs in worker process) ──────────────────────────────

def _generate_strict_tb_for_row(row_data: dict) -> dict:
    """
    Generate a strict testbench for one parquet row.
    Runs in a subprocess worker (no LLM call here).

    Returns a result dict with keys:
        problem_id, golden_top, golden_code_renamed, strict_tb,
        status ('strict_ok' | 'strict_failed'), error
    """
    problem_id = row_data["problem_id"]
    golden_code = row_data["golden_code"]

    result: dict = {
        "problem_id": problem_id,
        "golden_top": None,
        "golden_code_renamed": None,
        "strict_tb": None,
        "functional_tb": None,   # filled in LLM phase
        "status": "pending",
        "error": None,
    }

    tmp_dir = tempfile.mkdtemp(prefix=f"preproc_{str(problem_id)[:8]}_")
    try:
        eda = EdaTools(quiet=True)

        # Detect top module
        golden_top = eda.auto_top(golden_code)
        gate_top = golden_top  # DUT will have the same module name

        # Write golden to a temp file so yosys can read it
        gold_path = os.path.join(tmp_dir, "gold.v")
        with open(gold_path, "w") as f:
            f.write(golden_code)

        # Extract ports via yosys
        (
            input_port_width,
            output_port_width,
            clock_port_polarity,
            reset_port_polarity_sync,
        ) = eda.extract_golden_ports(gold_path, golden_top)

        # Generate strict testbench module
        strict_tb = eda.generate_testbench(
            input_port_width,
            output_port_width,
            clock_port_polarity,
            reset_port_polarity_sync,
            golden_top,   # golden suffix (_gold) applied inside generate_testbench
            gate_top,     # gate suffix (_gate) applied inside generate_testbench
        )

        # Rename golden code modules with _gold suffix (saved for reward time)
        golden_code_renamed = eda.process_verilog(golden_code, eda.golden_suffix)

        result.update(
            {
                "golden_top": golden_top,
                "golden_code_renamed": golden_code_renamed,
                "strict_tb": strict_tb,
                "status": "strict_ok",
            }
        )

    except Exception:
        result["status"] = "strict_failed"
        result["error"] = traceback.format_exc()
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)

    return result


# ── LLM refinement (runs in thread worker) ────────────────────────────────────

def _refine_one(
    entry: dict,
    problem_desc: str,
    client,
    model_name: str,
    use_batch: bool,
    enable_thinking: bool,
) -> dict:
    """
    Refine one strict TB with LLM.  Mutates entry in-place with
    functional_tb and updated status.
    """
    try:
        functional_tb = _llm_refine_tb(
            problem_desc=problem_desc,
            golden_code=entry["golden_code_renamed"],  # show renamed version for clarity
            strict_tb=entry["strict_tb"],
            client=client,
            model_name=model_name,
            use_batch=use_batch,
            enable_thinking=enable_thinking,
        )
        if functional_tb:
            entry["functional_tb"] = functional_tb
            entry["status"] = "success"
        else:
            entry["status"] = "llm_no_code"
            entry["error"] = "LLM returned no ```verilog``` block"
    except Exception:
        entry["status"] = "llm_failed"
        entry["error"] = traceback.format_exc()
    return entry


# ── Helpers ────────────────────────────────────────────────────────────────────

def _get_user_content(question) -> str:
    """Extract the 'user' role message content from the question array."""
    for msg in question:
        if isinstance(msg, dict) and msg.get("role") == "user":
            return msg.get("content", "")
    return ""


def _load_existing(output_path: str) -> dict:
    """Load partially completed results (for resume support)."""
    if os.path.exists(output_path):
        with open(output_path) as f:
            data = json.load(f)
        print(f"[resume] Loaded {len(data)} existing entries from {output_path}")
        return data
    return {}


def _save(results: dict, output_path: str) -> None:
    tmp = output_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    os.replace(tmp, output_path)


# ── Main ───────────────────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--parquet", required=True, help="Path to training parquet file")
    p.add_argument("--output", required=True, help="Output JSON file path")
    p.add_argument("--workers", type=int, default=8, help="Parallel workers for TB generation (yosys)")
    p.add_argument("--llm-workers", type=int, default=16, help="Parallel workers for LLM refinement")
    p.add_argument("--skip-llm", action="store_true", help="Only run strict TB generation phase (no LLM)")
    p.add_argument("--llm-only", action="store_true", help="Only run LLM refinement phase (skip already strict_ok entries)")
    p.add_argument("--api-key", default=None, help="Ark API key（默认 ARK_API_KEY）")
    p.add_argument(
        "--api-base",
        default=None,
        help="Ark Base URL（默认 https://ark.cn-beijing.volces.com/api/v3）",
    )
    p.add_argument(
        "--model",
        default=None,
        help="逻辑模型名如 ds-v3.2（默认 ARK_MODEL 或 ds-v3.2）",
    )
    p.add_argument("--batch", action="store_true", help="使用 batch_chat 接口")
    p.add_argument("--no-thinking", action="store_true", help="关闭 extra_body thinking")
    p.add_argument("--limit", type=int, default=None, help="Process only first N rows (for testing)")
    return p.parse_args()


def main():
    args = parse_args()

    # ── Load parquet ──────────────────────────────────────────────────────────
    print(f"[load] Reading {args.parquet}")
    df = pd.read_parquet(args.parquet)
    if args.limit:
        df = df.head(args.limit)
    print(f"[load] {len(df)} rows")

    # ── Load existing results (resume) ────────────────────────────────────────
    results: dict[str, dict] = _load_existing(args.output)

    # ── Phase 1: Strict TB generation ─────────────────────────────────────────
    if not args.llm_only:
        rows_to_process = []
        for _, row in df.iterrows():
            pid = str(row["problem_id"])
            if pid in results and results[pid].get("status") not in ("pending", "strict_failed"):
                continue  # already done
            golden_code = row["reward_model"]["ground_truth"]
            rows_to_process.append({"problem_id": row["problem_id"], "golden_code": golden_code})

        print(f"[phase1] Generating strict TBs for {len(rows_to_process)} samples "
              f"({args.workers} workers) ...")

        with ProcessPoolExecutor(max_workers=args.workers) as pool:
            futures = {pool.submit(_generate_strict_tb_for_row, r): r for r in rows_to_process}
            done_count = 0
            fail_count = 0
            for fut in as_completed(futures):
                entry = fut.result()
                pid = str(entry["problem_id"])
                results[pid] = entry
                done_count += 1
                if entry["status"] != "strict_ok":
                    fail_count += 1
                if done_count % 100 == 0:
                    _save(results, args.output)
                    print(f"  [{done_count}/{len(rows_to_process)}] "
                          f"ok={done_count-fail_count} fail={fail_count}")

        _save(results, args.output)
        ok = sum(1 for v in results.values() if v["status"] == "strict_ok")
        print(f"[phase1] done: {ok}/{len(results)} strict TBs generated successfully")

    # ── Phase 2: LLM refinement ───────────────────────────────────────────────
    if args.skip_llm:
        print("[phase2] Skipped (--skip-llm)")
        return

    api_key = args.api_key or os.environ.get("ARK_API_KEY") \
        or os.environ.get("VOLCENGINE_API_KEY") \
        or os.environ.get("DEEPSEEK_API_KEY")
    api_base = args.api_base or os.environ.get(
        "ARK_BASE_URL", "https://ark.cn-beijing.volces.com/api/v3"
    )
    model_name = args.model or os.environ.get("ARK_MODEL", "ds-v3.2")

    try:
        client = build_ark_client(api_key=api_key, base_url=api_base)
    except RuntimeError as e:
        print(f"[phase2] ERROR: {e}")
        sys.exit(1)

    # Build problem_desc lookup from parquet
    pid_to_desc: dict[str, str] = {}
    for _, row in df.iterrows():
        pid_to_desc[str(row["problem_id"])] = _get_user_content(row["question"])

    # Select entries needing LLM refinement
    to_refine = [
        (pid, entry)
        for pid, entry in results.items()
        if entry.get("status") == "strict_ok"
        and pid in pid_to_desc
    ]
    print(f"[phase2] Refining {len(to_refine)} TBs with LLM ({args.llm_workers} threads) ...")

    with ThreadPoolExecutor(max_workers=args.llm_workers) as pool:
        futures = {
            pool.submit(
                _refine_one,
                entry,
                pid_to_desc[pid],
                client,
                model_name,
                args.batch,
                not args.no_thinking,
            ): pid
            for pid, entry in to_refine
        }
        done_count = 0
        fail_count = 0
        for fut in as_completed(futures):
            pid = futures[fut]
            entry = fut.result()
            results[pid] = entry
            done_count += 1
            if entry["status"] != "success":
                fail_count += 1
            if done_count % 50 == 0:
                _save(results, args.output)
                print(f"  [{done_count}/{len(to_refine)}] "
                      f"ok={done_count-fail_count} fail={fail_count}")

    _save(results, args.output)
    ok = sum(1 for v in results.values() if v["status"] == "success")
    print(f"[phase2] done: {ok}/{len(results)} entries have functional TBs")
    print(f"[done] Results saved to {args.output}")


if __name__ == "__main__":
    main()
