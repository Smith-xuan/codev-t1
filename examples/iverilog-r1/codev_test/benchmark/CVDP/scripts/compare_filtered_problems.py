#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从filter_log.txt提取被选中的problem_id，并比较它们在两个composite_report.txt中的通过率
"""

import re
from pathlib import Path

def extract_selected_problems(filter_log_path):
    """从filter_log.txt中提取所有被选中的problem_id"""
    selected_problems = set()
    
    with open(filter_log_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 找到"1. 各分区选择的问题列表 (30%)"部分
    start_marker = "1. 各分区选择的问题列表 (30%)"
    end_marker = "2. 筛选掉的条目统计"
    
    start_idx = content.find(start_marker)
    end_idx = content.find(end_marker)
    
    if start_idx == -1 or end_idx == -1:
        print("警告: 无法找到指定的部分")
        return selected_problems
    
    section = content[start_idx:end_idx]
    
    # 提取所有problem_id（格式: - cvdp_copilot_xxx）
    pattern = r'-\s+(cvdp_copilot_\w+)'
    matches = re.findall(pattern, section)
    
    selected_problems = set(matches)
    
    return selected_problems

def extract_pass_fail_problems(report_path):
    """从composite_report.txt中提取通过和未通过的problem_id"""
    passed_problems = set()
    failed_problems = set()
    
    with open(report_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 找到"=== Problems by Pass Count (Pass@1, n=1) ==="部分
    in_section = False
    current_status = None  # 'passed' or 'failed'
    
    for i, line in enumerate(lines):
        if "=== Problems by Pass Count (Pass@1, n=1) ===" in line:
            in_section = True
            continue
        
        if not in_section:
            continue
        
        # 检查Pass Count状态
        if "Pass Count: 0/1" in line:
            current_status = 'failed'
            continue
        elif "Pass Count: 1/1" in line:
            current_status = 'passed'
            continue
        
        # 提取problem_id（格式: | cvdp_copilot_xxx | cidxxx (difficulty) |）
        # 注意：有些行可能是 || 开头，有些是 | 开头
        if current_status and ('|' in line) and 'cvdp_copilot_' in line:
            # 提取problem_id - 它在第一个|和第二个|之间
            parts = line.split('|')
            if len(parts) >= 2:
                problem_id = parts[1].strip()
                if problem_id.startswith('cvdp_copilot_'):
                    if current_status == 'passed':
                        passed_problems.add(problem_id)
                    elif current_status == 'failed':
                        failed_problems.add(problem_id)
    
    return passed_problems, failed_problems

def main():
    # 文件路径
    filter_log_path = Path("/nfs_global/projects/cvdp_benchmark/results/qwen3_8b_10epochs_32k/filter_log.txt")
    report1_path = Path("/nfs_global/projects/cvdp_benchmark/results/qwen3_8b_sft_87k_r1/result/composite_report.txt")
    report2_path = Path("/nfs_global/projects/cvdp_benchmark/results/qwen3_32b_sft_with_all_cvdp_3samples_filter_somerror/result/composite_report.txt")
    
    # 提取数据
    print("正在提取被选中的problem_id...")
    selected_problems = extract_selected_problems(filter_log_path)
    print(f"从filter_log.txt中提取到 {len(selected_problems)} 个被选中的problem_id\n")
    
    print("正在从第一个报告文件中提取通过/未通过的problem_id...")
    passed1, failed1 = extract_pass_fail_problems(report1_path)
    print(f"报告1: 通过 {len(passed1)} 个, 未通过 {len(failed1)} 个\n")
    
    print("正在从第二个报告文件中提取通过/未通过的problem_id...")
    passed2, failed2 = extract_pass_fail_problems(report2_path)
    print(f"报告2: 通过 {len(passed2)} 个, 未通过 {len(failed2)} 个\n")
    
    # 找出被筛选出来的题目在两个报告中的状态
    filtered_passed1 = selected_problems & passed1
    filtered_failed1 = selected_problems & failed1
    filtered_not_in_report1 = selected_problems - (passed1 | failed1)
    
    filtered_passed2 = selected_problems & passed2
    filtered_failed2 = selected_problems & failed2
    filtered_not_in_report2 = selected_problems - (passed2 | failed2)
    
    # 计算通过率
    total_in_report1 = len(filtered_passed1) + len(filtered_failed1)
    total_in_report2 = len(filtered_passed2) + len(filtered_failed2)
    
    pass_rate1 = (len(filtered_passed1) / total_in_report1 * 100) if total_in_report1 > 0 else 0
    pass_rate2 = (len(filtered_passed2) / total_in_report2 * 100) if total_in_report2 > 0 else 0
    
    # 输出结果
    print("=" * 80)
    print("被筛选出来的题目在两个报告中的通过率比较")
    print("=" * 80)
    print(f"\n被选中的题目总数: {len(selected_problems)}")
    print(f"\n{'='*80}")
    print("报告1 (qwen3_32b_sft_with_all_cvdp_3samples):")
    print(f"{'='*80}")
    print(f"  在报告中的题目数: {total_in_report1}")
    print(f"  通过: {len(filtered_passed1)} 个")
    print(f"  未通过: {len(filtered_failed1)} 个")
    if filtered_not_in_report1:
        print(f"  不在报告中: {len(filtered_not_in_report1)} 个")
    print(f"  通过率: {pass_rate1:.2f}%")
    
    print(f"\n{'='*80}")
    print("报告2 (qwen3_32b_sft_with_all_cvdp_3samples_filter_somerror):")
    print(f"{'='*80}")
    print(f"  在报告中的题目数: {total_in_report2}")
    print(f"  通过: {len(filtered_passed2)} 个")
    print(f"  未通过: {len(filtered_failed2)} 个")
    if filtered_not_in_report2:
        print(f"  不在报告中: {len(filtered_not_in_report2)} 个")
    print(f"  通过率: {pass_rate2:.2f}%")
    
    print(f"\n{'='*80}")
    print("详细对比:")
    print(f"{'='*80}")
    
    # 找出在两个报告中状态不同的题目
    both_passed = filtered_passed1 & filtered_passed2
    both_failed = filtered_failed1 & filtered_failed2
    passed_in_1_failed_in_2 = filtered_passed1 & filtered_failed2
    failed_in_1_passed_in_2 = filtered_failed1 & filtered_passed2
    
    print(f"\n两个报告都通过: {len(both_passed)} 个")
    print(f"两个报告都未通过: {len(both_failed)} 个")
    print(f"报告1通过但报告2未通过: {len(passed_in_1_failed_in_2)} 个")
    print(f"报告1未通过但报告2通过: {len(failed_in_1_passed_in_2)} 个")
    
    # 输出详细列表
    if passed_in_1_failed_in_2:
        print(f"\n报告1通过但报告2未通过的题目:")
        for pid in sorted(passed_in_1_failed_in_2):
            print(f"  - {pid}")
    
    if failed_in_1_passed_in_2:
        print(f"\n报告1未通过但报告2通过的题目:")
        for pid in sorted(failed_in_1_passed_in_2):
            print(f"  - {pid}")
    
    # 输出所有被选中题目的状态对比表
    print(f"\n{'='*80}")
    print("所有被选中题目的状态对比:")
    print(f"{'='*80}")
    print(f"{'Problem ID':<50} {'报告1':<12} {'报告2':<12}")
    print("-" * 80)
    
    for pid in sorted(selected_problems):
        status1 = "✓通过" if pid in filtered_passed1 else ("✗未通过" if pid in filtered_failed1 else "不在报告")
        status2 = "✓通过" if pid in filtered_passed2 else ("✗未通过" if pid in filtered_failed2 else "不在报告")
        print(f"{pid:<50} {status1:<12} {status2:<12}")
    
    # 输出总结
    print(f"\n{'='*80}")
    print("总结:")
    print(f"{'='*80}")
    print(f"被筛选出来的题目总数: {len(selected_problems)}")
    print(f"\n报告1 (qwen3_32b_sft_with_all_cvdp_3samples):")
    print(f"  - 通过率: {pass_rate1:.2f}% ({len(filtered_passed1)}/{total_in_report1})")
    print(f"\n报告2 (qwen3_32b_sft_with_all_cvdp_3samples_filter_somerror):")
    print(f"  - 通过率: {pass_rate2:.2f}% ({len(filtered_passed2)}/{total_in_report2})")
    print(f"\n差异:")
    print(f"  - 报告1比报告2多通过: {len(passed_in_1_failed_in_2)} 个题目")
    print(f"  - 报告2比报告1多通过: {len(failed_in_1_passed_in_2)} 个题目")
    print(f"  - 通过率差异: {pass_rate1 - pass_rate2:.2f} 个百分点")

if __name__ == "__main__":
    main()

