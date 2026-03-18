#!/usr/bin/env python3
"""
分析生成文件的完成度和工具调用统计
检查每个生成文件是否完成（以</answer>结尾），并统计工具调用次数
从composite_report.txt提取正确性信息，生成summary.txt
"""

import os
import re
import sys
from pathlib import Path
from collections import defaultdict


def is_complete(content):
    """检查生成是否完整（以</answer>结尾）"""
    # 检查是否以</answer>结尾（可能后面有空白字符）
    content = content.strip()
    return content.endswith('</answer>')


def count_tool_calls(content):
    """
    统计完整的工具调用次数
    一次完整的工具调用包括：<tool_call>...</tool_call> 和 <tool_response>...</tool_response>
    """
    # 匹配完整的<tool_call>块
    tool_call_pattern = r'<tool_call>.*?</tool_call>'
    # 匹配完整的<tool_response>块
    tool_response_pattern = r'<tool_response>.*?</tool_response>'
    
    tool_calls = re.findall(tool_call_pattern, content, re.DOTALL)
    tool_responses = re.findall(tool_response_pattern, content, re.DOTALL)
    
    # 返回较小的数量，因为一次完整的调用需要两者都有
    return min(len(tool_calls), len(tool_responses))


def parse_report_file(report_path):
    """
    解析composite_report.txt文件，提取每个题目的正确性
    返回字典：{problem_id: 'Pass' or 'Fail'}
    """
    correctness = {}
    
    try:
        with open(report_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 查找Pass Count: 0/1部分（失败题目）
        fail_section_match = re.search(
            r'Pass Count: 0/1.*?Total: \d+ problems.*?\n(.*?)(?=Pass Count: 1/1|$)',
            content,
            re.DOTALL
        )
        
        if fail_section_match:
            fail_section = fail_section_match.group(1)
            # 提取所有失败题目ID
            fail_matches = re.findall(r'\|\s+(cvdp_copilot_\S+)\s+\|', fail_section)
            for problem_id in fail_matches:
                correctness[problem_id.strip()] = 'Fail'
        
        # 查找Pass Count: 1/1部分（通过题目）
        pass_section_match = re.search(
            r'Pass Count: 1/1.*?Total: \d+ problems.*?\n(.*?)(?=Overall|$)',
            content,
            re.DOTALL
        )
        
        if pass_section_match:
            pass_section = pass_section_match.group(1)
            # 提取所有通过题目ID
            pass_matches = re.findall(r'\|\s+(cvdp_copilot_\S+)\s+\|', pass_section)
            for problem_id in pass_matches:
                correctness[problem_id.strip()] = 'Pass'
    
    except Exception as e:
        print(f"Error parsing report file {report_path}: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
    
    return correctness


def extract_problem_id(file_path):
    """从文件路径中提取题目ID"""
    # 路径格式: .../cot/cvdp_copilot_xxx/t1.v
    # 提取目录名作为题目ID
    parent_dir = file_path.parent.name
    return parent_dir


def analyze_file(file_path):
    """分析单个文件"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        is_completed = is_complete(content)
        tool_call_count = count_tool_calls(content)
        problem_id = extract_problem_id(file_path)
        
        return {
            'completed': is_completed,
            'tool_calls': tool_call_count,
            'file_path': file_path,
            'problem_id': problem_id
        }
    except Exception as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)
        return None


def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_generation_completeness.py <cot_directory> [report_file]")
        print("  cot_directory: 包含cot子文件夹的目录")
        print("  report_file: composite_report.txt文件路径（可选）")
        sys.exit(1)
    
    cot_dir = Path(sys.argv[1])
    if not cot_dir.exists():
        print(f"Error: Directory {cot_dir} does not exist", file=sys.stderr)
        sys.exit(1)
    
    # 解析报告文件（如果提供）
    correctness_map = {}
    if len(sys.argv) >= 3:
        report_file = Path(sys.argv[2])
        if report_file.exists():
            correctness_map = parse_report_file(report_file)
            print(f"Loaded correctness info for {len(correctness_map)} problems from report file\n")
        else:
            print(f"Warning: Report file {report_file} does not exist, skipping correctness info\n", file=sys.stderr)
    
    # 收集所有t1.v文件
    t1_files = list(cot_dir.glob("*/t1.v"))
    
    if not t1_files:
        print(f"Error: No t1.v files found in {cot_dir}", file=sys.stderr)
        sys.exit(1)
    
    print(f"Found {len(t1_files)} files to analyze\n")
    
    # 分析每个文件
    results = []
    for t1_file in sorted(t1_files):
        result = analyze_file(t1_file)
        if result:
            # 添加正确性信息
            problem_id = result['problem_id']
            result['correctness'] = correctness_map.get(problem_id, 'Unknown')
            results.append(result)
    
    # 统计完成情况
    completed_count = sum(1 for r in results if r['completed'])
    total_count = len(results)
    completion_rate = (completed_count / total_count * 100) if total_count > 0 else 0
    
    # 统计工具调用情况
    tool_call_counts = defaultdict(int)
    total_tool_calls = 0
    for r in results:
        tool_call_counts[r['tool_calls']] += 1
        total_tool_calls += r['tool_calls']
    
    # 输出结果
    print("=" * 80)
    print("生成完成度统计")
    print("=" * 80)
    print(f"总文件数: {total_count}")
    print(f"完成生成（以</answer>结尾）: {completed_count}")
    print(f"未完成生成（截断）: {total_count - completed_count}")
    print(f"完成率: {completion_rate:.2f}%")
    print()
    
    print("=" * 80)
    print("工具调用次数统计")
    print("=" * 80)
    print(f"总工具调用次数: {total_tool_calls}")
    print(f"平均每个文件的工具调用次数: {total_tool_calls / total_count:.2f}")
    print()
    print("工具调用次数分布:")
    print(f"{'调用次数':<15} {'文件数':<15} {'占比':<15}")
    print("-" * 45)
    for count in sorted(tool_call_counts.keys()):
        file_count = tool_call_counts[count]
        percentage = (file_count / total_count * 100) if total_count > 0 else 0
        print(f"{count:<15} {file_count:<15} {percentage:.2f}%")
    print()
    
    # 统计不同工具调用次数占所有生成的比例
    print("=" * 80)
    print("不同工具调用次数的生成占比")
    print("=" * 80)
    for count in sorted(tool_call_counts.keys()):
        file_count = tool_call_counts[count]
        percentage = (file_count / total_count * 100) if total_count > 0 else 0
        print(f"{count}次工具调用: {file_count}个文件 ({percentage:.2f}%)")
    print()
    
    # 统计完成和未完成的工具调用情况
    print("=" * 80)
    print("完成 vs 未完成的工具调用对比")
    print("=" * 80)
    completed_tool_calls = [r['tool_calls'] for r in results if r['completed']]
    incomplete_tool_calls = [r['tool_calls'] for r in results if not r['completed']]
    
    if completed_tool_calls:
        avg_completed = sum(completed_tool_calls) / len(completed_tool_calls)
        print(f"完成生成的文件的平均工具调用次数: {avg_completed:.2f}")
    
    if incomplete_tool_calls:
        avg_incomplete = sum(incomplete_tool_calls) / len(incomplete_tool_calls)
        print(f"未完成生成的文件的平均工具调用次数: {avg_incomplete:.2f}")
    print()
    
    # 输出未完成的文件列表（可选）
    incomplete_files = [r['file_path'] for r in results if not r['completed']]
    if incomplete_files:
        print("=" * 80)
        print(f"未完成的文件列表 (共{len(incomplete_files)}个):")
        print("=" * 80)
        for f in sorted(incomplete_files):
            tool_calls = next(r['tool_calls'] for r in results if r['file_path'] == f)
            print(f"  {f} (工具调用次数: {tool_calls})")
    
    # 生成summary.txt
    summary_path = cot_dir.parent / 'summary.txt'
    print(f"\n生成汇总文件: {summary_path}")
    
    with open(summary_path, 'w', encoding='utf-8') as f:
        f.write("=" * 100 + "\n")
        f.write("题目生成分析汇总\n")
        f.write("=" * 100 + "\n")
        f.write(f"总题目数: {total_count}\n")
        f.write(f"完成生成: {completed_count} ({completion_rate:.2f}%)\n")
        f.write(f"未完成生成: {total_count - completed_count}\n")
        f.write(f"总工具调用次数: {total_tool_calls}\n")
        f.write(f"平均工具调用次数: {total_tool_calls / total_count:.2f}\n")
        f.write("\n")
        
        # 统计正确性
        if correctness_map:
            pass_count = sum(1 for r in results if r.get('correctness') == 'Pass')
            fail_count = sum(1 for r in results if r.get('correctness') == 'Fail')
            unknown_count = sum(1 for r in results if r.get('correctness') == 'Unknown')
            f.write(f"通过题目: {pass_count}\n")
            f.write(f"失败题目: {fail_count}\n")
            if unknown_count > 0:
                f.write(f"未知正确性: {unknown_count}\n")
            f.write("\n")
        
        f.write("=" * 100 + "\n")
        f.write("详细题目列表\n")
        f.write("=" * 100 + "\n")
        f.write(f"{'题目ID':<60} {'正确性':<10} {'工具调用次数':<15} {'完成生成':<10}\n")
        f.write("-" * 100 + "\n")
        
        # 按题目ID排序
        sorted_results = sorted(results, key=lambda x: x['problem_id'])
        for r in sorted_results:
            problem_id = r['problem_id']
            correctness = r.get('correctness', 'Unknown')
            tool_calls = r['tool_calls']
            completed = 'Yes' if r['completed'] else 'No'
            f.write(f"{problem_id:<60} {correctness:<10} {tool_calls:<15} {completed:<10}\n")
        
        f.write("\n")
        f.write("=" * 100 + "\n")
        f.write("统计信息\n")
        f.write("=" * 100 + "\n")
        
        # 按正确性分组统计
        if correctness_map:
            f.write("\n按正确性分组的统计:\n")
            for correctness in ['Pass', 'Fail', 'Unknown']:
                group_results = [r for r in results if r.get('correctness') == correctness]
                if group_results:
                    group_completed = sum(1 for r in group_results if r['completed'])
                    group_total_tool_calls = sum(r['tool_calls'] for r in group_results)
                    group_avg_tool_calls = group_total_tool_calls / len(group_results) if group_results else 0
                    f.write(f"\n{correctness} ({len(group_results)}个题目):\n")
                    f.write(f"  完成生成: {group_completed} ({group_completed/len(group_results)*100:.2f}%)\n")
                    f.write(f"  平均工具调用次数: {group_avg_tool_calls:.2f}\n")
        
        # 按完成状态分组统计
        f.write("\n按完成状态分组的统计:\n")
        for completed_status in [True, False]:
            group_results = [r for r in results if r['completed'] == completed_status]
            if group_results:
                status_str = '完成' if completed_status else '未完成'
                group_total_tool_calls = sum(r['tool_calls'] for r in group_results)
                group_avg_tool_calls = group_total_tool_calls / len(group_results) if group_results else 0
                if correctness_map:
                    group_pass = sum(1 for r in group_results if r.get('correctness') == 'Pass')
                    group_fail = sum(1 for r in group_results if r.get('correctness') == 'Fail')
                    f.write(f"\n{status_str} ({len(group_results)}个题目):\n")
                    f.write(f"  通过: {group_pass}, 失败: {group_fail}\n")
                    f.write(f"  平均工具调用次数: {group_avg_tool_calls:.2f}\n")
                else:
                    f.write(f"\n{status_str} ({len(group_results)}个题目):\n")
                    f.write(f"  平均工具调用次数: {group_avg_tool_calls:.2f}\n")
    
    print(f"汇总文件已生成: {summary_path}")


if __name__ == '__main__':
    main()

