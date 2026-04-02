#!/usr/bin/env python3
"""
Benchmark TB Evaluation: Compare strict equivalence vs functional TB checking.

Evaluates two testbench verification methods against ground truth from official
benchmark reports and computes confusion matrices.

Method 1: Strict equivalence checking (eda_tools verify_one_sample)
Method 2: Functional TB (LLM-refined testbench)

Usage
-----
    python benchmark_tb_evaluation.py \
        --results-dir /nfs_global/.../results \
        --prompts /workspace/.../prompts_test.jsonl \
        --output tb_eval_results.json \
        --workers 8 --llm-workers 16

Environment variables
---------------------
    EDA_TOOLS_PATH    Path to eda_tools package root
    ARK_API_KEY       火山引擎 Ark API Key（与 generate_instruction_for_non_r1.py 一致）
    ARK_BASE_URL      默认 https://ark.cn-beijing.volces.com/api/v3
    IVERILOG_PATH     iverilog binary
    VVP_PATH          vvp binary
    YOSYS_PATH        yosys binary

方法一若长时间无输出，多为每条任务在跑 yosys/iverilog（单条可接近 ``--strict-timeout`` 秒），
并非 tmp 撑爆磁盘；``verify_one_sample`` 会清理临时文件。

LLM 调用与 ``generate_instruction_for_non_r1.py`` 相同：``volcenginesdkarkruntime.Ark`` +
接入点 ID 见同目录 ``ark_llm.MODEL_MAPPING``；默认逻辑模型名为 ``ds-v3.2``。

依赖: ``pip install volcenginesdkarkruntime``
"""

import argparse
import glob
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import traceback
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor, as_completed
from pathlib import Path

# ── EDA tools ─────────────────────────────────────────────────────────────────
DEFAULT_EDA_TOOLS_PATH = os.environ.get(
    "EDA_TOOLS_PATH",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "eda_tools"),
)
if DEFAULT_EDA_TOOLS_PATH not in sys.path:
    sys.path.insert(0, DEFAULT_EDA_TOOLS_PATH)

try:
    import siliconcompiler
    if not hasattr(siliconcompiler, "Chip") and hasattr(siliconcompiler, "Design"):
        siliconcompiler.Chip = siliconcompiler.Design
except ImportError:
    pass

from eda_tools.utils import eda_tools as EdaTools  # noqa: E402
from eda_tools.core import verify_one_sample, run_function_with_timeout  # noqa: E402

_DEFAULT_IVERILOG = "/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/iverilog"
_DEFAULT_VVP = "/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/vvp"
_DEFAULT_YOSYS = "/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/yosys"

_IVERILOG_BIN = os.environ.get("IVERILOG_PATH", _DEFAULT_IVERILOG)
_VVP_BIN = os.environ.get("VVP_PATH", _DEFAULT_VVP)
_YOSYS_BIN = os.environ.get("YOSYS_PATH", _DEFAULT_YOSYS)
_SIM_TIMEOUT = int(os.environ.get("SIM_TIMEOUT", "60"))

# Propagate defaults into env so eda_tools.utils also picks them up
os.environ.setdefault("IVERILOG_PATH", _DEFAULT_IVERILOG)
os.environ.setdefault("VVP_PATH", _DEFAULT_VVP)
os.environ.setdefault("YOSYS_PATH", _DEFAULT_YOSYS)

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)
from ark_llm import ask_llm, build_ark_client  # noqa: E402


# ═══════════════════════════════════════════════════════════════════════════════
#  Step 1 — Parse report.txt
# ═══════════════════════════════════════════════════════════════════════════════

def parse_report(report_path: str) -> dict[str, str]:
    """Parse one report.txt → {problem_id: "pass"|"fail"}."""
    with open(report_path) as f:
        content = f.read()

    results: dict[str, str] = {}

    fail_section = re.search(
        r"=== Failing Problems ===(.*?)(?:=== Passing Problems ===|$)",
        content, re.DOTALL,
    )
    if fail_section:
        for m in re.finditer(
            r"\|\s*\d+\s*\|\s*(cvdp_copilot_\S+?)\s*\|",
            fail_section.group(1),
        ):
            results[m.group(1)] = "fail"

    pass_section = re.search(r"=== Passing Problems ===(.*?)$", content, re.DOTALL)
    if pass_section:
        for m in re.finditer(
            r"\|\s*\d+\s*\|\s*(cvdp_copilot_\S+?)\s*\|",
            pass_section.group(1),
        ):
            results[m.group(1)] = "pass"

    return results


def parse_all_reports(results_dir: str, num_samples: int = 5) -> dict[str, dict[int, str]]:
    """Parse all sample reports → {problem_id: {sample_idx: "pass"|"fail"}}."""
    all_results: dict[str, dict[int, str]] = defaultdict(dict)
    for i in range(1, num_samples + 1):
        rpath = os.path.join(results_dir, f"sample_{i}", "report.txt")
        if not os.path.exists(rpath):
            print(f"[warn] Report not found: {rpath}")
            continue
        sr = parse_report(rpath)
        for pid, status in sr.items():
            all_results[pid][i] = status
        n_pass = sum(1 for v in sr.values() if v == "pass")
        print(f"[parse] sample_{i}: {n_pass} pass, {len(sr) - n_pass} fail, total {len(sr)}")
    return dict(all_results)


# ═══════════════════════════════════════════════════════════════════════════════
#  Step 2 — Load code files
# ═══════════════════════════════════════════════════════════════════════════════

def problem_id_to_path(problem_id: str) -> tuple[str, int]:
    """cvdp_copilot_XXX_YYYY → (dir_name, variant_int)."""
    dir_name, variant_str = problem_id.rsplit("_", 1)
    return dir_name, int(variant_str)


def load_code(results_dir: str, problem_id: str, sample_idx: int) -> str | None:
    dir_name, variant = problem_id_to_path(problem_id)
    rtl_dir = os.path.join(
        results_dir, f"sample_{sample_idx}", dir_name,
        "harness", str(variant), "rtl",
    )
    if not os.path.isdir(rtl_dir):
        return None
    files = glob.glob(os.path.join(rtl_dir, "*.v")) + \
            glob.glob(os.path.join(rtl_dir, "*.sv"))
    if not files:
        return None
    with open(files[0]) as f:
        return f.read()


# ═══════════════════════════════════════════════════════════════════════════════
#  Step 3 — Build golden / test pairs
# ═══════════════════════════════════════════════════════════════════════════════

def build_test_cases(
    all_results: dict[str, dict[int, str]],
    results_dir: str,
) -> list[dict]:
    eligible = {
        pid: st for pid, st in all_results.items()
        if any(s == "pass" for s in st.values())
    }
    print(f"[build] {len(eligible)} problems have ≥1 passing sample")

    test_cases: list[dict] = []
    skipped = 0
    for pid in sorted(eligible):
        statuses = eligible[pid]
        passing = [i for i, s in statuses.items() if s == "pass"]
        golden_idx = random.choice(passing)
        golden_code = load_code(results_dir, pid, golden_idx)
        if not golden_code:
            skipped += 1
            continue
        for sidx in sorted(statuses):
            if sidx == golden_idx:
                continue
            dut_code = load_code(results_dir, pid, sidx)
            if not dut_code:
                continue
            test_cases.append({
                "problem_id": pid,
                "golden_sample_idx": golden_idx,
                "test_sample_idx": sidx,
                "golden_code": golden_code,
                "dut_code": dut_code,
                "ground_truth": statuses[sidx],
            })
    if skipped:
        print(f"[build] Skipped {skipped} problems (code not found)")
    print(f"[build] {len(test_cases)} test pairs from {len(eligible) - skipped} problems")
    return test_cases


# ═══════════════════════════════════════════════════════════════════════════════
#  Step 4 — Method 1: Strict equivalence
# ═══════════════════════════════════════════════════════════════════════════════

def _strict_check_one(gold_code: str, dut_code: str, timeout: int) -> bool:
    """Worker: returns True if codes are equivalent per strict check."""
    try:
        result = run_function_with_timeout(
            verify_one_sample, gold_code, dut_code, timeout=timeout,
        )
        return result.get("correct", False)
    except Exception:
        return False


# ═══════════════════════════════════════════════════════════════════════════════
#  Step 5 — Method 2: Functional TB
# ═══════════════════════════════════════════════════════════════════════════════

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


def generate_strict_tb(golden_code: str) -> dict:
    """Generate strict TB and renamed golden for one problem (subprocess-safe)."""
    tmp_dir = tempfile.mkdtemp(prefix="bench_stb_")
    try:
        eda = EdaTools(quiet=True)
        golden_top = eda.auto_top(golden_code)

        gold_path = os.path.join(tmp_dir, "gold.v")
        with open(gold_path, "w") as f:
            f.write(golden_code)

        ipw, opw, cpol, rpol = eda.extract_golden_ports(gold_path, golden_top)
        strict_tb = eda.generate_testbench(ipw, opw, cpol, rpol, golden_top, golden_top)
        golden_renamed = eda.process_verilog(golden_code, eda.golden_suffix)

        return {
            "golden_top": golden_top,
            "golden_code_renamed": golden_renamed,
            "strict_tb": strict_tb,
            "status": "ok",
        }
    except Exception:
        return {"status": "failed", "error": traceback.format_exc()}
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def llm_refine_tb(
    problem_desc: str,
    golden_code_renamed: str,
    strict_tb: str,
    client,
    model_name: str = "ds-v3.2",
    use_batch: bool = False,
    enable_thinking: bool = True,
    temperature: float = 0.2,
) -> str | None:
    """调用火山 Ark（与 generate_instruction_for_non_r1.ask_llm 一致）生成 functional TB。"""
    user_msg = (
        f"## Problem Description\n\n{problem_desc}\n\n"
        f"## Golden Implementation\n\n```verilog\n{golden_code_renamed}\n```\n\n"
        f"## Strict Testbench (modify only the trigger assignment)\n\n"
        f"```verilog\n{strict_tb}\n```\n\n"
        f"Return the complete modified testbench in a ```verilog``` code block."
    )
    try:
        resp = ask_llm(
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
        content = resp.choices[0].message.content
        matches = re.findall(r"```verilog\s*(.*?)```", content, re.DOTALL)
        return matches[-1].strip() if matches else None
    except Exception as e:
        print(f"[llm] Error: {e}")
        return None


def _run_functional_sim(
    golden_code_renamed: str,
    tb_code: str,
    dut_code: str,
    golden_top: str,
    timeout: int = _SIM_TIMEOUT,
) -> bool:
    """Compile golden+TB and DUT, simulate. Returns True on pass."""
    eda = EdaTools(quiet=True)
    try:
        dut_top = eda.auto_top(dut_code)
    except Exception:
        return False

    if dut_top != golden_top:
        dut_code = re.sub(
            rf"\bmodule\s+{re.escape(dut_top)}\b",
            f"module {golden_top}",
            dut_code,
        )
    dut_renamed = eda.process_verilog(dut_code, eda.gate_suffix)

    tmp_dir = tempfile.mkdtemp(prefix="ftb_sim_")
    try:
        gold_tb = os.path.join(tmp_dir, "gold_and_tb.v")
        with open(gold_tb, "w") as f:
            f.write(golden_code_renamed + "\n\n" + tb_code)

        gate = os.path.join(tmp_dir, "gate.v")
        with open(gate, "w") as f:
            f.write(dut_renamed)

        vvp = os.path.join(tmp_dir, "tb.vvp")
        comp = subprocess.run(
            f"{_IVERILOG_BIN} -g2012 -s testbench -o {vvp} {gold_tb} {gate}",
            shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=timeout,
        )
        if comp.returncode != 0:
            return False

        sim = subprocess.run(
            f"{_VVP_BIN} -n {vvp}",
            shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            timeout=timeout,
        )
        return "All tests passed." in sim.stdout.decode(errors="replace")
    except subprocess.TimeoutExpired:
        return False
    except Exception:
        return False
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def _functional_sim_one(item: tuple[dict, dict]) -> tuple[str, int, bool]:
    """
    Top-level worker for functional simulation.
    Use with ThreadPoolExecutor to avoid multiprocessing pickling issues.
    """
    tc_, entry_ = item
    try:
        ftb = entry_.get("functional_tb") or entry_["strict_tb"]
        ok = _run_functional_sim(
            entry_["golden_code_renamed"],
            ftb,
            tc_["dut_code"],
            entry_["golden_top"],
        )
    except Exception:
        ok = False
    return tc_["problem_id"], tc_["test_sample_idx"], ok


# ═══════════════════════════════════════════════════════════════════════════════
#  Step 6 — Confusion matrix
# ═══════════════════════════════════════════════════════════════════════════════

def compute_confusion(results: list[dict], key: str) -> dict:
    tp = fp = tn = fn = 0
    for r in results:
        gt_pos = r["ground_truth"] == "pass"
        pred_pos = r[key]
        if gt_pos and pred_pos:
            tp += 1
        elif gt_pos and not pred_pos:
            fn += 1
        elif not gt_pos and pred_pos:
            fp += 1
        else:
            tn += 1
    total = tp + fp + tn + fn
    return {
        "TP": tp, "FP": fp, "TN": tn, "FN": fn, "total": total,
        "accuracy": (tp + tn) / total if total else 0,
        "FPR": fp / (fp + tn) if (fp + tn) else 0,
        "FNR": fn / (fn + tp) if (fn + tp) else 0,
        "precision": tp / (tp + fp) if (tp + fp) else 0,
        "recall": tp / (tp + fn) if (tp + fn) else 0,
        "F1": (2 * tp / (2 * tp + fp + fn)) if (2 * tp + fp + fn) else 0,
    }


def print_cm(name: str, cm: dict):
    print(f"\n{'=' * 60}")
    print(f"  {name}")
    print(f"{'=' * 60}")
    print(f"                  Predicted Pass   Predicted Fail")
    print(f"  Actual Pass       TP = {cm['TP']:>4d}       FN = {cm['FN']:>4d}")
    print(f"  Actual Fail       FP = {cm['FP']:>4d}       TN = {cm['TN']:>4d}")
    print(f"  {'─' * 48}")
    print(f"  Total:     {cm['total']}")
    print(f"  Accuracy:  {cm['accuracy']:.4f}")
    print(f"  FPR:       {cm['FPR']:.4f}")
    print(f"  FNR:       {cm['FNR']:.4f}")
    print(f"  Precision: {cm['precision']:.4f}")
    print(f"  Recall:    {cm['recall']:.4f}")
    print(f"  F1:        {cm['F1']:.4f}")


# ═══════════════════════════════════════════════════════════════════════════════
#  Persistence helpers
# ═══════════════════════════════════════════════════════════════════════════════

def _save(data: dict, path: str):
    parent = os.path.dirname(os.path.abspath(path))
    if parent:
        os.makedirs(parent, exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, default=str)
    os.replace(tmp, path)


def _load_existing(path: str) -> dict:
    if os.path.exists(path):
        with open(path) as f:
            d = json.load(f)
        print(f"[resume] Loaded existing results from {path}")
        return d
    return {}


# ═══════════════════════════════════════════════════════════════════════════════
#  Main
# ═══════════════════════════════════════════════════════════════════════════════

def parse_args():
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("--results-dir", required=True,
                    help="Directory containing sample_1..sample_5")
    p.add_argument("--prompts", required=True, help="Path to prompts_test.jsonl")
    p.add_argument("--output", default="tb_eval_results.json", help="Output JSON")
    p.add_argument("--workers", type=int, default=8,
                    help="Parallel workers for strict check / TB gen / simulation")
    p.add_argument("--llm-workers", type=int, default=16,
                    help="Parallel threads for LLM refinement")
    p.add_argument("--strict-timeout", type=int, default=120,
                    help="Timeout per strict equiv check (seconds)")
    p.add_argument(
        "--progress-every",
        type=int,
        default=5,
        metavar="N",
        help="方法一/二各阶段每完成 N 条打印进度（首条完成时也会打印）",
    )
    p.add_argument("--num-samples", type=int, default=5)
    p.add_argument("--skip-strict", action="store_true",
                    help="Skip Method 1 (strict equivalence)")
    p.add_argument("--skip-functional", action="store_true",
                    help="Skip Method 2 (functional TB)")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--api-key", default=None, help="Ark API Key，默认读 ARK_API_KEY")
    p.add_argument(
        "--api-base",
        default=None,
        help="Ark Base URL，默认 https://ark.cn-beijing.volces.com/api/v3",
    )
    p.add_argument(
        "--model",
        default=None,
        help="逻辑模型名（如 ds-v3.2），对应 MODEL_MAPPING 中的接入点 ID",
    )
    p.add_argument(
        "--batch",
        action="store_true",
        help="使用 batch_chat（与 generate_instruction_for_non_r1 --batch 一致）",
    )
    p.add_argument(
        "--no-thinking",
        action="store_true",
        help="不传 extra_body thinking（默认开启 thinking）",
    )
    p.add_argument("--limit", type=int, default=None,
                    help="Limit number of problems (for testing)")
    return p.parse_args()


def main():
    args = parse_args()
    random.seed(args.seed)

    # ── Load prompts ──────────────────────────────────────────────────────────
    print(f"[load] Reading prompts: {args.prompts}")
    pid_to_desc: dict[str, str] = {}
    with open(args.prompts) as f:
        for line in f:
            obj = json.loads(line.strip())
            pid_to_desc[obj["id"]] = obj.get("user", "")
    print(f"[load] {len(pid_to_desc)} prompts")

    # ── Parse reports ─────────────────────────────────────────────────────────
    print(f"[parse] Reports dir: {args.results_dir}")
    all_results = parse_all_reports(args.results_dir, args.num_samples)
    print(f"[parse] {len(all_results)} total problems")

    # ── Build test cases ──────────────────────────────────────────────────────
    test_cases = build_test_cases(all_results, args.results_dir)
    if args.limit:
        pids_seen: set[str] = set()
        limited = []
        for tc in test_cases:
            pids_seen.add(tc["problem_id"])
            if len(pids_seen) <= args.limit:
                limited.append(tc)
        test_cases = limited
        print(f"[limit] → {len(test_cases)} pairs from {min(args.limit, len(pids_seen))} problems")

    if not test_cases:
        print("[error] No test cases generated. Exiting.")
        return

    # ── Resume support ────────────────────────────────────────────────────────
    saved = _load_existing(args.output)
    result_idx: dict[tuple[str, int], dict] = {}
    for r in saved.get("results", []):
        result_idx[(r["problem_id"], r["test_sample_idx"])] = r
    tb_cache: dict[str, dict] = saved.get("tb_cache", {})

    # Ensure every test_case has an entry
    for tc in test_cases:
        key = (tc["problem_id"], tc["test_sample_idx"])
        if key not in result_idx:
            result_idx[key] = {
                "problem_id": tc["problem_id"],
                "golden_sample_idx": tc["golden_sample_idx"],
                "test_sample_idx": tc["test_sample_idx"],
                "ground_truth": tc["ground_truth"],
            }

    # ══════════════════════════════════════════════════════════════════════════
    #  Method 1 — Strict equivalence
    # ══════════════════════════════════════════════════════════════════════════
    if not args.skip_strict:
        todo = [
            tc for tc in test_cases
            if "strict_result" not in result_idx.get(
                (tc["problem_id"], tc["test_sample_idx"]), {}
            )
        ]
        cached = len(test_cases) - len(todo)
        print(f"\n[method1] Strict equivalence — {len(todo)} to check, {cached} cached")
        if todo:
            pe = max(1, args.progress_every)
            print(
                f"[method1] 每条: yosys 端口提取 + iverilog 仿真，单条上限约 {args.strict_timeout}s；"
                f"进度每 {pe} 条打印（首条完成即打一行）。",
                flush=True,
            )

        if todo:
            with ProcessPoolExecutor(max_workers=args.workers) as pool:
                futs = {
                    pool.submit(
                        _strict_check_one,
                        tc["golden_code"], tc["dut_code"], args.strict_timeout,
                    ): tc
                    for tc in todo
                }
                done = 0
                for fut in as_completed(futs):
                    tc = futs[fut]
                    key = (tc["problem_id"], tc["test_sample_idx"])
                    try:
                        passed = fut.result()
                    except Exception:
                        passed = False
                    result_idx[key]["strict_result"] = passed
                    done += 1
                    if done == 1 or done == len(todo) or (done % pe == 0):
                        _save({"results": list(result_idx.values()), "tb_cache": tb_cache},
                              args.output)
                        print(f"  [strict {done}/{len(todo)}]", flush=True)

            _save({"results": list(result_idx.values()), "tb_cache": tb_cache}, args.output)
        print("[method1] Done")

    # ══════════════════════════════════════════════════════════════════════════
    #  Method 2 — Functional TB
    # ══════════════════════════════════════════════════════════════════════════
    if not args.skip_functional:
        # Phase A: strict TB generation
        unique_pids = {tc["problem_id"] for tc in test_cases}
        gen_todo = {
            pid: next(tc["golden_code"] for tc in test_cases if tc["problem_id"] == pid)
            for pid in unique_pids
            if pid not in tb_cache or tb_cache[pid].get("status") != "ok"
        }
        if gen_todo:
            print(f"\n[method2a] Generating strict TBs for {len(gen_todo)} problems ...")
            with ProcessPoolExecutor(max_workers=args.workers) as pool:
                futs = {pool.submit(generate_strict_tb, code): pid
                        for pid, code in gen_todo.items()}
                pe = max(1, args.progress_every)
                done = 0
                for fut in as_completed(futs):
                    pid = futs[fut]
                    tb_cache[pid] = fut.result()
                    done += 1
                    if done == 1 or done == len(gen_todo) or (done % pe == 0):
                        print(f"  [strict TB {done}/{len(gen_todo)}]", flush=True)
            ok = sum(1 for v in tb_cache.values() if v.get("status") == "ok")
            print(f"[method2a] {ok}/{len(tb_cache)} strict TBs ok")
            _save({"results": list(result_idx.values()), "tb_cache": tb_cache}, args.output)

        # Phase B: LLM refinement（火山 Ark，与 generate_instruction_for_non_r1 一致）
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
            print(f"[method2b] ERROR: {e}")
            sys.exit(1)

        refine_todo = {
            pid: entry for pid, entry in tb_cache.items()
            if entry.get("status") == "ok"
            and "functional_tb" not in entry
            and pid in pid_to_desc
        }
        if refine_todo:
            print(f"[method2b] LLM-refining {len(refine_todo)} TBs ...")

            def _do_refine(pid_entry):
                pid, entry = pid_entry
                desc = pid_to_desc.get(pid, "")
                ftb = llm_refine_tb(
                    desc,
                    entry["golden_code_renamed"],
                    entry["strict_tb"],
                    client,
                    model_name=model_name,
                    use_batch=args.batch,
                    enable_thinking=not args.no_thinking,
                )
                return pid, ftb

            with ThreadPoolExecutor(max_workers=args.llm_workers) as pool:
                futs = {pool.submit(_do_refine, (pid, e)): pid
                        for pid, e in refine_todo.items()}
                pe = max(1, args.progress_every)
                done = 0
                for fut in as_completed(futs):
                    pid, ftb = fut.result()
                    if ftb:
                        tb_cache[pid]["functional_tb"] = ftb
                    else:
                        tb_cache[pid]["functional_tb_error"] = "LLM returned no code"
                    done += 1
                    if done == 1 or done == len(refine_todo) or (done % pe == 0):
                        _save({"results": list(result_idx.values()),
                               "tb_cache": tb_cache}, args.output)
                        print(f"  [LLM {done}/{len(refine_todo)}]", flush=True)

            ok = sum(1 for v in tb_cache.values() if v.get("functional_tb"))
            print(f"[method2b] {ok}/{len(tb_cache)} functional TBs ready")

        # Phase C: functional simulation
        sim_todo = []
        for tc in test_cases:
            key = (tc["problem_id"], tc["test_sample_idx"])
            if "functional_result" in result_idx.get(key, {}):
                continue
            pid = tc["problem_id"]
            entry = tb_cache.get(pid, {})
            ftb = entry.get("functional_tb") or entry.get("strict_tb")
            if not ftb or not entry.get("golden_code_renamed") or not entry.get("golden_top"):
                continue
            sim_todo.append((tc, entry))

        cached_sim = len(test_cases) - len(sim_todo)
        no_tb = len(test_cases) - cached_sim - len(sim_todo)
        print(f"\n[method2c] Simulating {len(sim_todo)} pairs, {cached_sim} cached")

        if sim_todo:
            # Use threads here: simulation is an external process (iverilog/vvp),
            # and threads avoid multiprocessing pickling issues with local functions.
            with ThreadPoolExecutor(max_workers=args.workers) as pool:
                futs = {pool.submit(_functional_sim_one, item): item for item in sim_todo}
                pe = max(1, args.progress_every)
                done = 0
                for fut in as_completed(futs):
                    pid, sidx, passed = fut.result()
                    result_idx[(pid, sidx)]["functional_result"] = passed
                    done += 1
                    if done == 1 or done == len(sim_todo) or (done % pe == 0):
                        _save({"results": list(result_idx.values()),
                               "tb_cache": tb_cache}, args.output)
                        print(f"  [sim {done}/{len(sim_todo)}]", flush=True)

        _save({"results": list(result_idx.values()), "tb_cache": tb_cache}, args.output)
        print("[method2] Done")

    # ══════════════════════════════════════════════════════════════════════════
    #  Results
    # ══════════════════════════════════════════════════════════════════════════
    all_r = list(result_idx.values())

    strict_r = [r for r in all_r if "strict_result" in r]
    func_r = [r for r in all_r if "functional_result" in r]

    if strict_r:
        cm1 = compute_confusion(strict_r, "strict_result")
        print_cm("Method 1: Strict Equivalence Check (eda_tools)", cm1)

    if func_r:
        cm2 = compute_confusion(func_r, "functional_result")
        print_cm("Method 2: Functional TB (LLM-refined)", cm2)

    both = [r for r in all_r if "strict_result" in r and "functional_result" in r]
    if both:
        agree = sum(1 for r in both if r["strict_result"] == r["functional_result"])
        print(f"\n[compare] {len(both)} pairs have both methods — "
              f"agreement {agree}/{len(both)} ({100 * agree / len(both):.1f}%)")

        disagree = [r for r in both if r["strict_result"] != r["functional_result"]]
        if disagree:
            print(f"\n  Disagreements ({len(disagree)}):")
            for r in disagree[:20]:
                gt = r["ground_truth"]
                s = "PASS" if r["strict_result"] else "FAIL"
                f_ = "PASS" if r["functional_result"] else "FAIL"
                print(f"    {r['problem_id']} sample_{r['test_sample_idx']}: "
                      f"GT={gt}  strict={s}  func={f_}")
            if len(disagree) > 20:
                print(f"    ... and {len(disagree) - 20} more")

    # Final save
    save_data: dict = {"results": all_r}
    if tb_cache:
        save_data["tb_cache"] = tb_cache
    if strict_r:
        save_data["confusion_strict"] = compute_confusion(strict_r, "strict_result")
    if func_r:
        save_data["confusion_functional"] = compute_confusion(func_r, "functional_result")
    _save(save_data, args.output)

    gt_pass = sum(1 for r in all_r if r["ground_truth"] == "pass")
    gt_fail = sum(1 for r in all_r if r["ground_truth"] == "fail")
    print(f"\n[summary] {len(all_r)} total pairs (GT: {gt_pass} pass, {gt_fail} fail)")
    print(f"[done] Saved to {args.output}")


if __name__ == "__main__":
    main()
