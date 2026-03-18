#!/usr/bin/env python3
import os
import json
import argparse
import resource
import subprocess
import shutil
import multiprocessing
import re
from pathlib import Path
from typing import Dict, Optional, Tuple, List
from collections import defaultdict

# Memory limit for pytest/cocotb/vvp subprocess tree (bytes).
# Prevents a single model-generated testbench from consuming unbounded RAM.
_SUBPROCESS_MEM_LIMIT_BYTES = 4 * 1024 * 1024 * 1024  # 4 GB


def _set_mem_limit():
    """preexec_fn: cap virtual address space for the subprocess tree."""
    try:
        resource.setrlimit(resource.RLIMIT_AS, (_SUBPROCESS_MEM_LIMIT_BYTES, _SUBPROCESS_MEM_LIMIT_BYTES))
    except (ValueError, OSError):
        pass

def parse_dotenv(dotenv_path: Path) -> Dict[str, str]:
    """解析 .env 文件获取环境变量"""
    env_vars = {}
    if not dotenv_path.exists():
        return env_vars
    with open(dotenv_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                env_vars[key.strip()] = value.strip()
    return env_vars

def write_file(path: Path, content: str):
    """写文件，确保目录存在"""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def clean_verilog_code(raw_code: str) -> str:
    """提取 Markdown 中的 Verilog 代码段"""
    if "```" in raw_code:
        match = re.search(r"```(?:verilog|systemverilog)?\s*(.*?)\s*```", raw_code, re.DOTALL | re.IGNORECASE)
        if match:
            return match.group(1).strip()
        else:
            return raw_code.replace("```", "").strip()
    return raw_code.strip()

def worker_wrapper(args: Tuple[str, str, Path, int, str, str]) -> Tuple[str, str, str, str, Optional[str]]:
    """
    单次采样测试 Worker
    args: (qid, code, template_dir, timeout, sample_tag, cid)
    """
    qid, raw_code, template_dir, timeout, sample_tag, cid = args
    
    # 物理隔离的运行目录，放在 template 同级，带上 tag
    # 路径形如: workspace/cid003/cvdp_..._0001_s0
    run_dir = template_dir.parent / f"{qid}_{sample_tag}"
    
    try:
        if run_dir.exists():
            shutil.rmtree(run_dir)
        shutil.copytree(template_dir, run_dir)

        env_vars = parse_dotenv(run_dir / "src" / ".env")
        target_rtl = "design.sv"
        if "VERILOG_SOURCES" in env_vars:
            target_rtl = Path(env_vars["VERILOG_SOURCES"]).name
            
        code_to_write = clean_verilog_code(raw_code)
        write_file(run_dir / "rtl" / target_rtl, code_to_write)

        process_env = os.environ.copy()

        # Add custom paths for iverilog, vvp, yosys (append to preserve current env priority)
        custom_bin_path = "/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin"
        current_path = process_env.get("PATH", "")
        if custom_bin_path not in current_path:
            process_env["PATH"] = f"{current_path}:{custom_bin_path}"

        process_env.update(env_vars)
        if "VERILOG_SOURCES" in process_env:
            process_env["VERILOG_SOURCES"] = process_env["VERILOG_SOURCES"].replace("/code/", "")

        # Use CVDP_PYTEST_PATH env var to avoid broken verl conda environment
        cvdp_pytest_path = os.environ.get("CVDP_PYTEST_PATH", "pytest")
        result = subprocess.run(
            [cvdp_pytest_path, "-v", "-s", "src/test_runner.py"],
            cwd=run_dir,
            capture_output=True,
            text=True,
            encoding="utf-8",
            env=process_env,
            timeout=timeout,
            preexec_fn=_set_mem_limit,
        )

        log_file = run_dir / f"test_{sample_tag}.log"
        with open(log_file, "w", encoding="utf-8") as f:
            f.write(result.stdout + "\n" + result.stderr)

        # 如果需要节省空间，取消下面这行的注释
        # shutil.rmtree(run_dir) 

        status = "PASSED" if result.returncode == 0 else "FAILED"
        return (qid, cid, sample_tag, status, None)

    except subprocess.TimeoutExpired:
        return (qid, cid, sample_tag, "TIMEOUT", f"超时 {timeout}s")
    except Exception as e:
        return (qid, cid, sample_tag, "ERROR", str(e))

def main():
    parser = argparse.ArgumentParser(description="CVDP Multi-sample Batch Tester (CID Layer Aware)")
    parser.add_argument("--jsonl", required=True, help="模型生成的 final.jsonl 路径")
    parser.add_argument("--workspace", default="workspace", help="预生成的测试模板根目录")
    parser.add_argument("--workers", type=int, default=8, help="并行进程数")
    parser.add_argument("--timeout", type=int, default=120, help="单次测试超时(秒)")
    args = parser.parse_args()

    workspace_root = Path(args.workspace)
    if not workspace_root.is_dir():
        print(f"错误: 找不到工作空间 {args.workspace}")
        return

    # 1. 扫描工作空间，建立 qid -> (cid, template_path) 的映射
    print("正在扫描工作空间以匹配 CID 层级...")
    qid_to_info = {}
    for meta_path in workspace_root.rglob("meta.json"):
        try:
            with open(meta_path, 'r') as m:
                meta = json.load(m)
                qid_to_info[meta["id"]] = {
                    "cid": meta.get("cid", "unknown"),
                    "path": meta_path.parent
                }
        except:
            continue

    # 2. 解析任务并手动进行采样编号
    tasks = []
    id_counter = defaultdict(int)
    
    with open(args.jsonl, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line: continue
            entry = json.loads(line)
            qid = entry.get("id")
            code = entry.get("completion")
            
            if qid in qid_to_info and code is not None:
                info = qid_to_info[qid]
                tag = f"s{id_counter[qid]}"
                id_counter[qid] += 1
                tasks.append((qid, code, info["path"], args.timeout, tag, info["cid"]))
            elif qid not in qid_to_info:
                print(f"⚠️ 警告: 题目 {qid} 在 workspace 中找不到对应的模板目录，跳过。")

    print(f"--- CVDP 批量测试开始 ---")
    print(f"总任务数: {len(tasks)} | 独立题目: {len(id_counter)}")
    print("-" * 40)

    # 3. 多进程执行
    results_map = defaultdict(list) # qid -> [status, ...]
    qid_to_cid = {} # qid -> cid (用于最后写报告)

    with multiprocessing.Pool(processes=args.workers) as pool:
        for qid, cid, tag, status, err in pool.imap_unordered(worker_wrapper, tasks):
            results_map[qid].append(status)
            qid_to_cid[qid] = cid
            icon = "✅" if status == "PASSED" else "❌" if status == "FAILED" else "⚠️"
            if status == "ERROR":
                print(f"{icon} [{cid}][{qid}] {tag}: {status} - {err}")
            else:
                print(f"{icon} [{cid}][{qid}] {tag}: {status}")

    # 4. 生成报告 (带 CID 信息以适配统计脚本)
    report_path = workspace_root / "multi_sample_report.txt"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(f"CVDP Evaluation Report\n")
        f.write("=" * 70 + "\n")
        
        # 为了方便正则匹配，按 Pass Count 分组输出
        # 先统计每道题的情况
        problem_summaries = []
        for qid in sorted(results_map.keys()):
            res_list = results_map[qid]
            n = len(res_list)
            passed = res_list.count("PASSED")
            cid = qid_to_cid[qid]
            problem_summaries.append((qid, cid, passed, n))

        # 按 Passed 数量排序输出（模拟原报告格式）
        for qid, cid, passed, n in sorted(problem_summaries, key=lambda x: x[2], reverse=True):
            # 关键格式：| qid | cid (category) | 后面跟 Pass Count
            line = f"| {qid:<40} | {cid:<10} | Pass Count: {passed}/{n}"
            f.write(line + "\n")
            print(line)

    print("\n" + "=" * 40)
    print(f"测试完成! 报告已保存至: {report_path}")

if __name__ == "__main__":
    main()