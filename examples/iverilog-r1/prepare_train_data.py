#!/usr/bin/env python3
"""
Prepare RL training data from filtered cid002/cid003 sampling results.

Reads progress files to find kept=True items, looks up full data from source
JSONL files, and converts to the parquet format expected by slime RL training.

Usage:
    python prepare_train_data.py \
        --cid002-progress cid002_filtered_200.jsonl.progress.jsonl \
        --cid002-source /path/to/r1sft_cid002_3.5k_scored.jsonl \
        --cid003-progress cid003_filtered_200.jsonl.progress.jsonl \
        --cid003-source /path/to/r1_sft_87k_top8107.jsonl \
        --n-per-dataset 100 \
        --output data/eda_tools_200/train.parquet
"""

import argparse
import json
import os
import sys

import pandas as pd

# ── Prompts & Tool Definitions (same as filter_by_sampling.py) ────────────────

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

VERILOG_TOOL_DEFINITION = json.dumps([{
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
}])


# ── Data extraction helpers (same logic as filter_by_sampling.py) ─────────────

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


# ── Loading helpers ───────────────────────────────────────────────────────────

def load_progress(path: str, n: int) -> list[str]:
    """Load first n kept=True problem_ids from a progress file."""
    kept_ids = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entry = json.loads(line)
            if entry.get("kept", False):
                kept_ids.append(str(entry["problem_id"]))
                if len(kept_ids) >= n:
                    break
    return kept_ids


def load_source_index(path: str) -> dict[str, dict]:
    """Load source JSONL into a dict keyed by problem_id."""
    index = {}
    with open(path, encoding="utf-8") as f:
        for i, line in enumerate(f):
            line = line.strip()
            if not line:
                continue
            item = json.loads(line)
            pid = get_problem_id(item, i)
            index[pid] = item
    return index


# ── Main ──────────────────────────────────────────────────────────────────────

def build_training_row(item: dict, data_type: str) -> dict:
    """Convert a source data item to RL training parquet row."""
    instruction = extract_instruction(item, data_type)
    gold_code = extract_golden_code(item, data_type)
    problem_id = get_problem_id(item, 0)

    prompt = [
        {"role": "system", "content": SYSTEM_PROMPT.strip()},
        {"role": "user", "content": USER_PROMPT_TEMPLATE.format(problem=instruction)},
    ]

    return {
        "prompt": prompt,
        "reward_model": {
            "ground_truth": gold_code,
            "style": "rule",
            "task_id": problem_id,
        },
        "tools": VERILOG_TOOL_DEFINITION,
        "question": prompt,
        "ability": "verilog",
        "data_source": "eda_tools_filtered",
        "extra_info": {
            "task_id": problem_id,
            "data_type": data_type,
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Prepare RL training data from filtered results")
    parser.add_argument("--cid002-progress", required=True, help="cid002 progress JSONL")
    parser.add_argument("--cid002-source", required=True, help="cid002 source scored JSONL")
    parser.add_argument("--cid003-progress", required=True, help="cid003 progress JSONL")
    parser.add_argument("--cid003-source", required=True, help="cid003 source scored JSONL")
    parser.add_argument("--n-per-dataset", type=int, default=100, help="Number of items per dataset")
    parser.add_argument("--output", required=True, help="Output parquet path")
    args = parser.parse_args()

    rows = []

    for data_type, progress_path, source_path in [
        ("cid002", args.cid002_progress, args.cid002_source),
        ("cid003", args.cid003_progress, args.cid003_source),
    ]:
        print(f"[{data_type}] Loading progress from {progress_path}")
        kept_ids = load_progress(progress_path, args.n_per_dataset)
        print(f"[{data_type}] Selected {len(kept_ids)} kept items")

        print(f"[{data_type}] Loading source from {source_path}")
        source_index = load_source_index(source_path)
        print(f"[{data_type}] Source index has {len(source_index)} items")

        found = 0
        for pid in kept_ids:
            if pid not in source_index:
                print(f"  WARNING: problem_id {pid} not found in source, skipping")
                continue
            item = source_index[pid]
            row = build_training_row(item, data_type)
            gold = row["reward_model"]["ground_truth"]
            if not gold or not gold.strip():
                print(f"  WARNING: empty gold_code for {pid}, skipping")
                continue
            rows.append(row)
            found += 1
        print(f"[{data_type}] Added {found} rows")

    print(f"\nTotal: {len(rows)} training rows")

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    df = pd.DataFrame(rows)
    df.to_parquet(args.output, index=False)
    print(f"Saved to {args.output}")
    print(f"Columns: {list(df.columns)}")
    print(f"Shape: {df.shape}")


if __name__ == "__main__":
    main()
