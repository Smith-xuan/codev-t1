#!/usr/bin/env python3
"""
Create a training dataset from the CVDP benchmark (cid002/cid003, 172 questions)
for testbench-based reward training.

The output format is identical to the existing training data
(cvdp_claude_256/train.jsonl), except:
  - reward_model.ground_truth = "__CVDP_TESTBENCH__"   (no golden code needed)
  - reward_model.task_id      = actual CVDP task ID     (used by reward function)

Usage:
    python create_cvdp_train_data.py \
        --benchmark /workspace/S/shiwenxuan/codev_test/benchmark/CVDP/data/raw/cvdp_v1.0.2_cid002_cid003.jsonl \
        --outdir    /nfs_global/S/shiwenxuan/verl/data/codev/v1/cvdp_testbench_172
"""

import argparse
import json
import os
from pathlib import Path

import pandas as pd

# ────────────────────────────────────────────────────────────────────────────
# Fixed content copied verbatim from the existing training data
# ────────────────────────────────────────────────────────────────────────────

SYSTEM_CONTENT = (
    "You are a Verilog coding expert who will write Verilog code after careful consideration. \n"
    "Your goal is to deliver functionally correct, synthesizable, and efficient RTL that meets the user's requirements.\n"
    "\n"
    "Principles:\n"
    "- Reason carefully about the specification, interfaces, and corner cases.\n"
    "- Validate behavior and iterate as needed using any available tools.\n"
    "- Prefer clean, portable RTL: separate combinational/sequential logic, avoid unintended latches, "
    "avoid unsynthesizable constructs in design code.\n"
    "- Use clear resets, parameterize widths when appropriate, and write readable, well-commented code.\n"
    "- When a testbench is requested or required (e.g. by tools), follow these rules:\n"
    "1. Clearly state the expected behavior/results in the testbench (e.g. as comments).\n"
    "2. Ensure the testbench checks that simulation outputs exactly match the expected results; "
    "any mismatch means the design is still buggy.\n"
    "3. If the module has a reset signal, include proper reset testing in the testbench.\n"
    "4. Provide sufficient and diverse stimulus: cover normal cases, boundary conditions, and corner cases "
    "(e.g. 0, maximum values, negative numbers, sign-bit cases, etc.) instead of testing only a single scenario.\n"
    "\n"
    "After thinking, when you finally reach a conclusion, enclose the final verilog code in verilog code block "
    "within code tags. i.e.,\n"
    "```verilog\n"
    "module top_module(in, out, ...);\n"
    "...\n"
    "endmodule\n"
    "```"
)

# Prefix + folder-structure context that wraps the raw CVDP prompt
USER_PREFIX = (
    "Design a functionally correct, synthesizable, and efficient Verilog module for the following problem. \n"
    "Use any available tools during the process to validate and refine your design if you think it's needed.\n"
    "\n"
    "The problem is as follows:"
    "You are a helpful assistance.\n"
    "Consider that you have a folder structure like the following:\n"
    "\n"
    "    - rtl/*   : Contains files which are RTL code.\n"
    "    - verif/* : Contains files which are used to verify the correctness of the RTL code.\n"
    "    - docs/*  : Contains files used to document the project, like Block Guides, RTL Plans and Verification Plans.\n"
    "\n"
    "When generating files, return the file name in the correct place at the folder structure.\n"
    "\n"
    "You are solving a 'Specification to RTL Translation' problem. To solve this problem correctly, "
    "you should only respond with the RTL code translated from the specification.\n"
    "\n"
    "\n"
    "\n"
    "Provide me one answer for this request: "
)

VERILOG_TOOL = [
    {
        "type": "function",
        "function": {
            "name": "verilog_simulator",
            "description": (
                "A verilog simulation tool using iverilog. Executes Verilog code for functional verification. "
                "This tool requires a single string that contains ALL required modules including testbench."
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

TOOLS_KWARGS = {"verilog_simulator": {"create_kwargs": {"dummy": None}}}


# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

def _get_target_file(entry: dict) -> str:
    """Return the RTL file path from output.context (e.g. 'rtl/16qam_mapper.sv')."""
    ctx = entry.get("output", {}).get("context", {})
    if ctx:
        return next(iter(ctx.keys()))
    return "rtl/design.sv"


def _build_user_content(prompt: str, target_file: str) -> str:
    suffix = (
        f"\nPlease provide your response as plain text without any JSON formatting. "
        f"Your response will be saved directly to: {target_file}.\n"
    )
    return prompt + suffix


def _build_record(entry: dict, index: int) -> dict:
    task_id = entry["id"]
    raw_prompt = entry["input"]["prompt"]
    target_file = _get_target_file(entry)

    messages = [
        {"role": "system", "content": SYSTEM_CONTENT},
        {"role": "user", "content": _build_user_content(raw_prompt, target_file)},
    ]

    reward_model = {
        "ground_truth": "__CVDP_TESTBENCH__",
        "task_id": task_id,
        "style": "rule",
    }

    extra_info = {
        "index": index,
        "split": "train",
        "task_id": task_id,
        "tools_kwargs": TOOLS_KWARGS,
    }

    return {
        "prompt": messages,
        "reward_model": reward_model,
        "tools": json.dumps(VERILOG_TOOL, ensure_ascii=False),  # stored as JSON string, matches existing data format
        "question": messages,       # same as prompt (convention in existing data)
        "ability": "verilog",
        "data_source": "cvdp_testbench",
        "extra_info": extra_info,
    }


# ────────────────────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="Create CVDP testbench training data.")
    ap.add_argument(
        "--benchmark",
        default="/workspace/S/shiwenxuan/codev_test/benchmark/CVDP/data/raw/cvdp_v1.0.2_cid002_cid003.jsonl",
        help="Path to the CVDP benchmark JSONL (cid002/cid003).",
    )
    ap.add_argument(
        "--outdir",
        default="/nfs_global/S/shiwenxuan/verl/data/codev/v1/cvdp_testbench_172",
        help="Output directory for train.jsonl and train.parquet.",
    )
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    records = []
    with open(args.benchmark, "r", encoding="utf-8") as f:
        for i, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            entry = json.loads(line)
            records.append(_build_record(entry, i))

    # Write JSONL
    jsonl_path = outdir / "train.jsonl"
    with open(jsonl_path, "w", encoding="utf-8") as f:
        for rec in records:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    print(f"Wrote {len(records)} records to {jsonl_path}")

    # Write Parquet
    # Use pyarrow directly to handle nested structures (list-of-dicts columns).
    # pandas + pyarrow can store nested structures natively; no JSON serialisation needed.
    import pyarrow as pa
    import pyarrow.parquet as pq

    parquet_path = outdir / "train.parquet"
    table = pa.Table.from_pylist(records)
    pq.write_table(table, str(parquet_path))
    print(f"Wrote {len(records)} records to {parquet_path}")


if __name__ == "__main__":
    main()
