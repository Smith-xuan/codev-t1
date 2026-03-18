#!/usr/bin/env python3
import os
import json
import argparse
from pathlib import Path

TEMPLATE_README = """# {id}

Categories: {categories}

This directory was generated from JSONL.
Run tests after placing/verifying RTL under rtl/ (or use run_cvdp_eval.py).
"""

def write_file(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def main():
    ap = argparse.ArgumentParser(description="Generate local test directories organized by CID.")
    ap.add_argument("--jsonl", required=True, help="Path to the original harness JSONL.")
    ap.add_argument("--outdir", default="workspace", help="Output workspace directory.")
    args = ap.parse_args()

    out_root = Path(args.outdir)
    out_root.mkdir(parents=True, exist_ok=True)

    count = 0
    with open(args.jsonl, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entry = json.loads(line)

            qid = entry.get("id", f"problem_{count}")
            categories = entry.get("categories", [])
            
            # --- 修改部分：获取 CID 层级 ---
            # 假设 categories 里的第一个元素是 cidXXX
            cid = "unknown_cid"
            for cat in categories:
                if cat.startswith("cid"):
                    cid = cat
                    break
            
            harness = entry.get("harness", {})
            files = harness.get("files", {})

            # 目录结构调整为: outdir / cid / qid
            prob_dir = out_root / cid / qid
            (prob_dir / "rtl").mkdir(parents=True, exist_ok=True)
            (prob_dir / "src").mkdir(parents=True, exist_ok=True)

            # 写入 harness 文件
            for rel_path, content in files.items():
                rel_path_norm = rel_path.lstrip("./")
                target_path = prob_dir / rel_path_norm
                write_file(target_path, content)

            # README + meta
            readme = TEMPLATE_README.format(id=qid, categories=", ".join(categories))
            write_file(prob_dir / "README.md", readme)

            meta = {
                "id": qid,
                "cid": cid,
                "categories": categories
            }
            write_file(prob_dir / "meta.json", json.dumps(meta, indent=2))

            count += 1

    print(f"Generated {count} problem directories organized by CID under {out_root.resolve()}")

if __name__ == "__main__":
    main()