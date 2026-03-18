"""
split_train_by_difficulty.py
============================
Parse report.txt to get per-task pass counts (out of 5 samples), then split
the 172-task CVDP training set into two staged subsets:

  Stage 1  (pass count 1-4 / 5):  Medium-difficulty tasks – best for RL to
                                   improve pass@1.  Tasks the model can
                                   sometimes solve, so they produce non-zero
                                   reward variance and survive the
                                   check_reward_nonzero_std filter.

  Stage 2  (pass count 0 / 5):    Hard tasks – the model never solved these
                                   in 5 samples.  Useful as a second stage
                                   after stage-1 training improves the model.

Tasks with pass count 5/5 are dropped entirely: they produce all-reward-1
groups which are filtered out by check_reward_nonzero_std (std=0), wasting
rollout budget.

Usage
-----
  python split_train_by_difficulty.py \\
      --report   /workspace/S/shiwenxuan/slime/examples/iverilog-r1/report.txt \\
      --train    /nfs_global/S/shiwenxuan/verl/data/codev/v1/cvdp_testbench_172/train.jsonl \\
      --outdir   /nfs_global/S/shiwenxuan/verl/data/codev/v1/cvdp_testbench_staged
"""

import argparse
import json
import os
import re
from collections import defaultdict
from pathlib import Path


# ──────────────────────────────────────────────────────────────────────────────
# Parse report.txt
# ──────────────────────────────────────────────────────────────────────────────

def parse_report(report_path: str) -> dict[str, int]:
    """
    Return {task_id: pass_count} for every problem listed in the report.
    The pass count section looks like:

      | Pass Count: 0/5  | Total: 145 problems |
      ...
      | cvdp_copilot_xxx | cid002 (medium)     |
      ...
      | Pass Count: 1/5  | Total: 31 problems  |
      ...
    """
    pass_count_re = re.compile(r"Pass Count:\s*(\d+)/5")
    problem_id_re = re.compile(r"^\|\s*(cvdp_\S+)\s*\|")

    task_pass_count: dict[str, int] = {}
    current_count = None

    with open(report_path, encoding="utf-8") as f:
        for line in f:
            # Detect "Pass Count: N/5" header
            m = pass_count_re.search(line)
            if m:
                current_count = int(m.group(1))
                continue

            # Detect a problem ID row
            if current_count is not None:
                m2 = problem_id_re.match(line)
                if m2:
                    task_id = m2.group(1).strip()
                    task_pass_count[task_id] = current_count

    return task_pass_count


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", default="/workspace/S/shiwenxuan/slime/examples/iverilog-r1/report.txt")
    parser.add_argument("--train",  default="/nfs_global/S/shiwenxuan/verl/data/codev/v1/cvdp_testbench_172/train.jsonl")
    parser.add_argument("--outdir", default="/nfs_global/S/shiwenxuan/verl/data/codev/v1/cvdp_testbench_staged")
    args = parser.parse_args()

    # 1. Parse report
    task_pass_count = parse_report(args.report)
    print(f"[report] Parsed {len(task_pass_count)} tasks total from report")

    # Show distribution across all tasks in report
    count_dist: dict[int, int] = defaultdict(int)
    for pc in task_pass_count.values():
        count_dist[pc] += 1
    print("[report] Pass-count distribution (all tasks in report):")
    for k in sorted(count_dist):
        print(f"  {k}/5: {count_dist[k]} tasks")

    # 2. Load train.jsonl
    with open(args.train, encoding="utf-8") as f:
        train_rows = [json.loads(line) for line in f]
    print(f"\n[train] Loaded {len(train_rows)} rows from {args.train}")

    # 3. Match rows to pass counts
    missing, perfect, stage1, stage2 = [], [], [], []
    train_dist: dict[int, int] = defaultdict(int)

    for row in train_rows:
        task_id = row["reward_model"]["task_id"]
        pc = task_pass_count.get(task_id)
        if pc is None:
            missing.append(task_id)
            continue
        train_dist[pc] += 1
        if pc == 5:
            perfect.append(row)
        elif 1 <= pc <= 4:
            stage1.append(row)
        else:  # pc == 0
            stage2.append(row)

    print(f"\n[train] Pass-count distribution (172 training tasks):")
    for k in sorted(train_dist):
        label = {0: "stage2 (hard)", 5: "dropped (trivial)"}.get(k, "stage1 (medium)")
        print(f"  {k}/5: {train_dist[k]} tasks  → {label}")

    if missing:
        print(f"\n[WARNING] {len(missing)} training task(s) not found in report:")
        for t in missing:
            print(f"  {t}")

    print(f"\n[summary]")
    print(f"  Dropped (5/5, trivial):  {len(perfect)} tasks")
    print(f"  Stage 1 (1-4/5):         {len(stage1)} tasks")
    print(f"  Stage 2 (0/5, hard):     {len(stage2)} tasks")

    # 4. Write output files
    out = Path(args.outdir)
    out.mkdir(parents=True, exist_ok=True)

    stage1_path = out / "stage1_medium.jsonl"
    stage2_path = out / "stage2_hard.jsonl"

    def write_jsonl(rows, path):
        with open(path, "w", encoding="utf-8") as f:
            for row in rows:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
        print(f"  Written {len(rows)} rows → {path}")

    write_jsonl(stage1, stage1_path)
    write_jsonl(stage2, stage2_path)

    # 5. Also copy parquet if present (for eval), and print next steps
    src_dir = Path(args.train).parent
    for suffix in ("train.parquet", "test.jsonl", "test.parquet"):
        src = src_dir / suffix
        dst = out / suffix
        if src.exists() and not dst.exists():
            import shutil
            shutil.copy2(src, dst)
            print(f"  Copied {src} → {dst}")

    print(f"""
Next steps
──────────
Stage 1 training (medium tasks, improve pass@1):
  --prompt-data {stage1_path}

Stage 2 training (hard tasks, push boundaries):
  --prompt-data {stage2_path}

Both stages use the same eval set and reward function.
""")


if __name__ == "__main__":
    main()
