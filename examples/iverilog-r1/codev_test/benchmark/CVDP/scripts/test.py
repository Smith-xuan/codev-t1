#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import re
import statistics
from pathlib import Path
from typing import Any, Dict, Optional, List, Tuple

from src import subjective
from src.constants import SCORING_CONFIG

# =========================
# ===== 默认参数区域 ======
# =========================

DATASET_PATH = Path("data/raw/cvdp_v1.0.2_nonagentic_code_comprehension.jsonl")
ANSWERS_PATH = Path("../../results/test/cvdp-v1.0.2/codecomp/ds-v3.2-temp_default/final.jsonl")

CATEGORIES = {6, 8}
TOPK_IMPROVE = 10

# BEFORE: 复现你当前 baseline（常见是 header）
BEFORE_CODE_MODE = "header"   # "header" or "plain"

# AFTER: 仍然用 baseline 拼接出来的字符串，但整体外包 ```...```
# 建议用 plain（否则 FILE 行也会被包进 fenced code，可能降低 BLEU）
AFTER_CODE_MODE = "plain"     # "header" or "plain"

EXPORT_PATH = Path("/tmp/bleu_before_after_6_8.jsonl")  # None 表示不导出
SHOW_MULTI_TOP = 50

# =========================


def load_jsonl_to_dict(path: Path) -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            if "id" in obj:
                out[obj["id"]] = obj
    return out


def parse_completion(ans_obj: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    comp = ans_obj.get("completion")
    if comp is None:
        return None
    if isinstance(comp, dict):
        return comp
    if isinstance(comp, str):
        s = comp.strip()
        try:
            return json.loads(s)
        except Exception:
            return {"response": s}
    return None


def get_category(ds_obj: Dict[str, Any]) -> Optional[int]:
    cats = ds_obj.get("categories")
    if not cats:
        return None
    c0 = cats[0]
    if isinstance(c0, str) and c0.startswith("cid"):
        try:
            return int(c0[3:])
        except Exception:
            return None
    return None


def get_reference(ds_obj: Dict[str, Any]) -> str:
    if isinstance(ds_obj.get("subjective_reference"), str):
        return ds_obj["subjective_reference"]
    out = ds_obj.get("output", {})
    if isinstance(out, dict) and isinstance(out.get("response"), str):
        return out["response"]
    return ""


def count_code_blocks_and_files(comp: Dict[str, Any]) -> Tuple[int, int]:
    code = comp.get("code")
    if code is None:
        return 0, 0
    if isinstance(code, list):
        code_blocks = len(code)
        file_count = 0
        for d in code:
            if isinstance(d, dict):
                file_count += len(d)
            else:
                file_count += 1
        return code_blocks, file_count
    if isinstance(code, dict):
        return 1, len(code)
    return 1, 1


def build_uut_baseline(comp: Dict[str, Any], code_mode: str) -> str:
    if isinstance(comp.get("direct_text"), str) and comp["direct_text"].strip():
        return comp["direct_text"]
    if isinstance(comp.get("response"), str) and comp["response"].strip():
        return comp["response"]

    code = comp.get("code")
    if code is None:
        return str(comp)

    parts: List[str] = []
    if isinstance(code, list):
        for d in code:
            if isinstance(d, dict):
                for fn in sorted(d.keys()):
                    content = str(d[fn])
                    if code_mode == "header":
                        parts.append(f"FILE: {fn}\n{content}\n")
                    else:
                        parts.append(f"```\n{content}\n```")
            else:
                parts.append(str(d) + "\n")
    elif isinstance(code, dict):
        for fn in sorted(code.keys()):
            content = str(code[fn])
            if code_mode == "header":
                parts.append(f"FILE: {fn}\n{content}\n")
            else:
                parts.append(f"```\n{content}\n```")
    else:
        parts.append(str(code))

    return "\n".join(parts).strip()


# reference: 只把 ```xxx 统一成 ```
_FENCE_LINE_RE = re.compile(r"(?m)^\s*```[^\n]*\s*$")

def normalize_reference_lang_to_plain_fence(ref: str) -> str:
    return _FENCE_LINE_RE.sub("```", ref).strip()


def main():
    print("=" * 80)
    print("BLEU before/after (ref fence lang normalized + uut baseline then wrap once)")
    print(f"Dataset    : {DATASET_PATH}")
    print(f"Answers    : {ANSWERS_PATH}")
    print(f"Categories : {sorted(CATEGORIES)}")
    print(f"BEFORE uut : build_uut_baseline(code_mode={BEFORE_CODE_MODE})")
    print(f"AFTER  uut : wrap_one_fence(build_uut_baseline(code_mode={AFTER_CODE_MODE}))")
    print("=" * 80)

    if not DATASET_PATH.exists():
        raise SystemExit(f"Dataset not found: {DATASET_PATH}")
    if not ANSWERS_PATH.exists():
        raise SystemExit(f"Answers not found: {ANSWERS_PATH}")

    ds = load_jsonl_to_dict(DATASET_PATH)
    ans = load_jsonl_to_dict(ANSWERS_PATH)

    n_gram = SCORING_CONFIG.get("N_GRAM_DEFAULT", 2)

    rows: List[Dict[str, Any]] = []
    skipped = 0

    for id_, ds_obj in ds.items():
        cat = get_category(ds_obj)
        if cat not in CATEGORIES:
            continue
        if id_ not in ans:
            continue

        comp = parse_completion(ans[id_])
        if comp is None:
            skipped += 1
            continue

        ref_before = get_reference(ds_obj)
        if not ref_before.strip():
            skipped += 1
            continue

        uut_before = build_uut_baseline(comp, BEFORE_CODE_MODE)
        if not uut_before.strip():
            skipped += 1
            continue

        bleu_before = subjective.calculate_BLEU(uut_before, ref_before, n_gram)

        # AFTER: ref 只统一 ```xxx => ```, uut 用 baseline 拼接后整体包一层 fence
        ref_after = normalize_reference_lang_to_plain_fence(ref_before)
        uut_after = build_uut_baseline(comp, AFTER_CODE_MODE)
        bleu_after = subjective.calculate_BLEU(uut_after, ref_after, n_gram)

        code_blocks, file_count = count_code_blocks_and_files(comp)

        rows.append({
            "id": id_,
            "cat": cat,
            "code_blocks": int(code_blocks),
            "file_count": int(file_count),
            "bleu_before": float(bleu_before),
            "bleu_after": float(bleu_after),
            "delta": float(bleu_after - bleu_before),

            "uut_before_head": uut_before[:200],
            "ref_before_head": ref_before[:200],
            "uut_after_head": uut_after[:200],
            "ref_after_head": ref_after[:200],
        })

    if not rows:
        print("No valid samples found.")
        return

    before = [r["bleu_before"] for r in rows]
    after = [r["bleu_after"] for r in rows]
    deltas = [r["delta"] for r in rows]

    print(f"Samples analyzed: {len(rows)} (skipped {skipped})")
    print(f"n_gram: {n_gram}")
    print("-" * 80)
    print(f"BLEU before: mean={statistics.mean(before):.4f}  median={statistics.median(before):.4f}")
    print(f"BLEU after : mean={statistics.mean(after):.4f}  median={statistics.median(after):.4f}")
    print(f"Delta      : mean={statistics.mean(deltas):+.4f} median={statistics.median(deltas):+.4f} "
          f"max={max(deltas):+.4f} min={min(deltas):+.4f}")
    print("=" * 80)

    # Top improvements
    rows_sorted = sorted(rows, key=lambda r: r["delta"], reverse=True)
    print(f"\nTop {min(TOPK_IMPROVE, len(rows_sorted))} improvement samples (after - before):\n")
    for i, r in enumerate(rows_sorted[:TOPK_IMPROVE], 1):
        print("-" * 80)
        print(f"[{i}] id={r['id']}  cat={r['cat']}  code_blocks={r['code_blocks']}  file_count={r['file_count']}")
        print(f"    before={r['bleu_before']:.4f}  after={r['bleu_after']:.4f}  delta={r['delta']:+.4f}")
        print(f"    uut_before_head: {repr(r['uut_before_head'])}")
        print(f"    ref_before_head: {repr(r['ref_before_head'])}")
        print(f"    uut_after_head : {repr(r['uut_after_head'])}")
        print(f"    ref_after_head : {repr(r['ref_after_head'])}")

    # Multi subset
    multi = [r for r in rows if r["code_blocks"] > 1]
    print("\n" + "=" * 80)
    print("Subset: code_blocks > 1 (multi code blocks)")
    print(f"Count: {len(multi)} / {len(rows)}")
    if multi:
        mb = [r["bleu_before"] for r in multi]
        ma = [r["bleu_after"] for r in multi]
        md = [r["delta"] for r in multi]
        print(f"Multi before: mean={statistics.mean(mb):.4f} median={statistics.median(mb):.4f}")
        print(f"Multi after : mean={statistics.mean(ma):.4f} median={statistics.median(ma):.4f}")
        print(f"Multi delta : mean={statistics.mean(md):+.4f} median={statistics.median(md):+.4f} "
              f"max={max(md):+.4f} min={min(md):+.4f}")

        multi_sorted = sorted(multi, key=lambda r: r["delta"], reverse=True)
        to_show = multi_sorted if SHOW_MULTI_TOP <= 0 else multi_sorted[:SHOW_MULTI_TOP]
        print("-" * 80)
        print(f"Top {len(to_show)} multi samples by improvement:\n")
        for i, r in enumerate(to_show, 1):
            print("-" * 80)
            print(f"[multi {i}] id={r['id']}  cat={r['cat']}  code_blocks={r['code_blocks']}  file_count={r['file_count']}")
            print(f"    before={r['bleu_before']:.4f}  after={r['bleu_after']:.4f}  delta={r['delta']:+.4f}")
            print(f"    uut_before_head: {repr(r['uut_before_head'])}")
            print(f"    ref_before_head: {repr(r['ref_before_head'])}")
            print(f"    uut_after_head : {repr(r['uut_after_head'])}")
            print(f"    ref_after_head : {repr(r['ref_after_head'])}")
    print("=" * 80)

    if EXPORT_PATH:
        with EXPORT_PATH.open("w", encoding="utf-8") as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        print(f"\nExported detailed rows to {EXPORT_PATH}")


if __name__ == "__main__":
    main()
