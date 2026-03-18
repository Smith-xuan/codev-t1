#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从报告中提取不通过的问题，随机选择30%，然后从jsonl文件中筛选掉对应的条目
"""

import json
import random
import re
from collections import defaultdict
from pathlib import Path

def parse_report(report_path):
    """解析报告文件，提取各分区的不通过问题"""
    with open(report_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 找到"全部不通过的问题列表"部分
    start_marker = "3. 全部不通过的问题列表"
    if start_marker not in content:
        raise ValueError("未找到'全部不通过的问题列表'部分")
    
    # 提取该部分之后的内容
    start_idx = content.find(start_marker)
    problem_section = content[start_idx:]
    
    # 按分区组织问题
    problems_by_category = defaultdict(list)
    
    # 解析每一行
    lines = problem_section.split('\n')
    for line in lines:
        # 跳过标题行和分隔线
        if '#' in line and 'Problem ID' in line:
            continue
        if '---' in line or not line.strip():
            continue
        
        # 匹配格式: 数字    problem_id    category
        # 例如: "1     cvdp_copilot_64b66b_decoder_0011                             cid002"
        match = re.match(r'\s*\d+\s+(\S+)\s+(\S+)', line)
        if match:
            problem_id = match.group(1)
            category = match.group(2)
            problems_by_category[category].append(problem_id)
    
    return problems_by_category

def random_sample_30_percent(problems):
    """从问题列表中随机选择30%"""
    total = len(problems)
    sample_size = max(1, int(total * 0.3))  # 至少选择1个
    return random.sample(problems, sample_size)

def filter_jsonl(input_path, output_path, problem_ids_to_remove):
    """从jsonl文件中筛选掉指定的problem_id对应的条目"""
    removed_entries = []
    kept_entries = []
    removed_count_by_problem = defaultdict(int)
    total_lines = 0
    
    with open(input_path, 'r', encoding='utf-8') as f_in:
        for line_num, line in enumerate(f_in, 1):
            line = line.strip()
            if not line:
                continue
            
            total_lines += 1
            try:
                entry = json.loads(line)
                task_id = entry.get('task_id', '')
                
                # 检查是否需要移除
                if task_id in problem_ids_to_remove:
                    removed_entries.append({
                        'line_num': line_num,
                        'task_id': task_id,
                        'entry': entry
                    })
                    removed_count_by_problem[task_id] += 1
                else:
                    kept_entries.append(line)
            except json.JSONDecodeError as e:
                print(f"警告: 第{line_num}行JSON解析失败: {e}")
                # 保留无法解析的行
                kept_entries.append(line)
    
    # 写入筛选后的文件
    with open(output_path, 'w', encoding='utf-8') as f_out:
        for line in kept_entries:
            f_out.write(line + '\n')
    
    return removed_entries, removed_count_by_problem, total_lines

def main():
    # 文件路径
    report_path = '/nfs_global/projects/cvdp_benchmark/results/qwen3_8b_10epochs_32k/comprehensive_report.txt'
    jsonl_input_path = '/nfs_global/NeMo-Skills/openmathreasoning-verilog/solution-sdg-cvdp/cvdp_problems_left_output_complete_prompt/merged-complete.jsonl'
    jsonl_output_path = '/nfs_global/NeMo-Skills/openmathreasoning-verilog/solution-sdg-cvdp/cvdp_problems_left_output_complete_prompt/output-merged_filtered.jsonl'
    log_path = '/nfs_global/projects/cvdp_benchmark/results/qwen3_8b_10epochs_32k/filter_log.txt'
    
    # 设置随机种子以便结果可复现
    random.seed(42)
    
    print("1. 解析报告文件...")
    problems_by_category = parse_report(report_path)
    
    print(f"\n2. 各分区不通过问题统计:")
    for category in sorted(problems_by_category.keys()):
        print(f"   {category}: {len(problems_by_category[category])} 个问题")
    
    print("\n3. 从各分区随机选择30%的问题...")
    selected_problems_by_category = {}
    all_selected_problems = set()
    
    for category in sorted(problems_by_category.keys()):
        problems = problems_by_category[category]
        selected = random_sample_30_percent(problems)
        selected_problems_by_category[category] = selected
        all_selected_problems.update(selected)
        print(f"   {category}: 共{len(problems)}个，选择{len(selected)}个 (30%)")
        print(f"     选中的problem_id: {', '.join(selected)}")
    
    print(f"\n4. 总共选择了 {len(all_selected_problems)} 个problem_id")
    
    print("\n5. 从jsonl文件中筛选数据...")
    removed_entries, removed_count_by_problem, total_lines = filter_jsonl(
        jsonl_input_path, 
        jsonl_output_path, 
        all_selected_problems
    )
    
    print(f"   原始文件条目数: {total_lines}")
    print(f"   筛选掉的条目数: {len(removed_entries)}")
    print(f"   保留的条目数: {total_lines - len(removed_entries)}")
    
    # 按分区统计筛选掉的条目
    print("\n6. 按分区统计筛选掉的条目:")
    removed_by_category = defaultdict(lambda: defaultdict(int))
    
    for entry_info in removed_entries:
        task_id = entry_info['task_id']
        # 找到这个task_id属于哪个分区
        for category, selected in selected_problems_by_category.items():
            if task_id in selected:
                removed_by_category[category][task_id] += 1
                break
    
    # 生成日志文件
    with open(log_path, 'w', encoding='utf-8') as f_log:
        f_log.write("=" * 80 + "\n")
        f_log.write("问题筛选日志\n")
        f_log.write("=" * 80 + "\n\n")
        
        f_log.write("1. 各分区选择的问题列表 (30%)\n")
        f_log.write("-" * 80 + "\n")
        for category in sorted(selected_problems_by_category.keys()):
            selected = selected_problems_by_category[category]
            f_log.write(f"\n分区 {category}:\n")
            f_log.write(f"  总问题数: {len(problems_by_category[category])}\n")
            f_log.write(f"  选择数量: {len(selected)} (30%)\n")
            f_log.write(f"  选中的problem_id:\n")
            for pid in selected:
                f_log.write(f"    - {pid}\n")
        
        f_log.write("\n\n2. 筛选掉的条目统计\n")
        f_log.write("-" * 80 + "\n")
        f_log.write(f"总共筛选掉的条目数: {len(removed_entries)}\n\n")
        
        f_log.write("按分区统计:\n")
        for category in sorted(removed_by_category.keys()):
            category_total = sum(removed_by_category[category].values())
            f_log.write(f"\n分区 {category}:\n")
            f_log.write(f"  筛选掉的条目总数: {category_total}\n")
            f_log.write(f"  各problem_id筛选掉的条目数:\n")
            for task_id, count in sorted(removed_by_category[category].items()):
                f_log.write(f"    - {task_id}: {count} 条\n")
        
        f_log.write("\n\n3. 所有筛选掉的条目详情\n")
        f_log.write("-" * 80 + "\n")
        for entry_info in removed_entries:
            f_log.write(f"行号 {entry_info['line_num']}: task_id = {entry_info['task_id']}\n")
    
    print("\n7. 统计结果:")
    for category in sorted(removed_by_category.keys()):
        category_total = sum(removed_by_category[category].values())
        print(f"   分区 {category}: 筛选掉 {category_total} 条")
        for task_id, count in sorted(removed_by_category[category].items()):
            print(f"     - {task_id}: {count} 条")
    
    print(f"\n8. 结果已保存:")
    print(f"   筛选后的jsonl文件: {jsonl_output_path}")
    print(f"   详细日志文件: {log_path}")

if __name__ == '__main__':
    main()

