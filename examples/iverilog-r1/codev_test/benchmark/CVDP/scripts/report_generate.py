#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import argparse
import sys
from collections import defaultdict
from pathlib import Path

def parse_problem_results_table(content):
    """解析Problem Results by Category表格"""
    pattern = r'\| (cid\d+)\s+\|\s+(\d+)\s+\|\s+(\d+)\s+\|\s+(\d+)\s+\|\s+([\d.]+)%'
    matches = re.findall(pattern, content)
    
    results = {}
    for cat, total, pass_count, fail_count, rate in matches:
        results[cat] = {
            'total': int(total),
            'pass': int(pass_count),
            'fail': int(fail_count),
            'rate': float(rate)
        }
    return results

def parse_problems_section(content, section_name):
    """解析Failing Problems或Passing Problems部分"""
    # 找到section开始位置
    start_pattern = f'=== {section_name} ==='
    start_idx = content.find(start_pattern)
    if start_idx == -1:
        return []
    
    # 找到下一个section或文件结束
    # 从start_idx之后开始查找，避免找到当前section
    # 查找下一个以"=== "开头的section标题（不是表格分隔线）
    search_start = start_idx + len(start_pattern)
    # 使用正则表达式查找下一个section标题
    next_section_match = re.search(r'\n=== [A-Za-z ]+ ===', content[search_start:])
    if next_section_match:
        next_section = search_start + next_section_match.start()
        section_content = content[start_idx:next_section]
    else:
        section_content = content[start_idx:]
    
    # 提取Problem ID和Category
    # 格式: | 1   | cvdp_copilot_xxx | cid002 (easy) | ...
    # 注意：Problem ID可能包含下划线，Category格式是 cid002 (easy) 或 cid002 (medium)
    # 需要匹配以数字开头的行（主问题行），跳过以 ↳ 开头的测试行
    # Problem ID可能很长，有很多空格填充，需要匹配到下一个 | 之前的所有内容
    lines = section_content.split('\n')
    matches = []
    for line in lines:
        # 跳过以 ↳ 开头的行和分隔线
        if '↳' in line or line.strip().startswith('+') or not line.strip():
            continue
        # 匹配格式: | 数字 | Problem ID (可能有很多空格) | Category (difficulty) | ...
        # 使用更灵活的正则：Problem ID可能包含下划线和数字，后面可能有空格
        # 注意：Problem ID后面可能有大量空格填充，需要匹配到下一个|之前
        match = re.search(r'\|\s+\d+\s+\|\s+([a-zA-Z0-9_]+)\s+\|\s+(cid\d+)\s+\([^)]+\)', line)
        if match:
            problem_id = match.group(1).strip()
            category = match.group(2).strip()
            matches.append((problem_id, category))
    
    problems = []
    seen = set()  # 避免重复
    for problem_id, category in matches:
        if problem_id not in seen:
            problems.append({
                'problem_id': problem_id,
                'category': category
            })
            seen.add(problem_id)
    
    return problems

def main():
    parser = argparse.ArgumentParser(
        description='分析多个CVDP benchmark报告文件，生成综合报告',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
示例用法:
  python analyze_reports.py report1.txt report2.txt report3.txt report4.txt report5.txt
  python analyze_reports.py -o output.txt report1.txt report2.txt report3.txt report4.txt report5.txt
        '''
    )
    parser.add_argument(
        'reports',
        nargs='+',
        help='5个report文件的路径（可以指定5个或更多文件，但只会使用前5个）'
    )
    parser.add_argument(
        '-o', '--output',
        default=None,
        help='输出文件路径（默认：在第一个report文件所在目录生成comprehensive_report.txt）'
    )
    
    args = parser.parse_args()
    
    # 检查文件数量
    if len(args.reports) < 5:
        print(f"错误: 需要至少5个report文件，但只提供了{len(args.reports)}个", file=sys.stderr)
        sys.exit(1)
    
    # 使用前5个文件
    report_files = args.reports[:5]
    
    # 验证文件是否存在
    for report_file in report_files:
        if not Path(report_file).exists():
            print(f"错误: 文件不存在: {report_file}", file=sys.stderr)
            sys.exit(1)
    
    # 确定输出文件路径
    if args.output:
        output_file = Path(args.output)
    else:
        # 默认输出到第一个report文件所在目录
        output_file = Path(report_files[0]).parent / 'comprehensive_report.txt'
    
    # 读取所有report文件
    all_problem_results = []
    all_failing_problems = []
    all_passing_problems = []
    
    for i, report_file in enumerate(report_files, 1):
        file_path = Path(report_file)
        print(f"正在处理 [{i}/5] {file_path.name}...")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            print(f"错误: 无法读取文件 {report_file}: {e}", file=sys.stderr)
            sys.exit(1)
        
        # 解析Problem Results by Category
        problem_results = parse_problem_results_table(content)
        all_problem_results.append(problem_results)
        
        # 解析Failing Problems
        failing = parse_problems_section(content, 'Failing Problems')
        all_failing_problems.append(failing)
        print(f"  - 失败问题数: {len(failing)}")
        
        # 解析Passing Problems
        passing = parse_problems_section(content, 'Passing Problems')
        all_passing_problems.append(passing)
        print(f"  - 通过问题数: {len(passing)}")
    
    # 1. 计算Problem Results by Category的平均值
    print("\n" + "="*80)
    print("1. Problem Results by Category (n=5, Pass@1平均值)")
    print("="*80)
    
    # 收集所有category
    all_categories = set()
    for results in all_problem_results:
        all_categories.update(results.keys())
    
    avg_results = {}
    for cat in sorted(all_categories):
        total_sum = 0
        pass_sum = 0
        rate_sum = 0
        
        for results in all_problem_results:
            if cat in results:
                total_sum += results[cat]['total']
                pass_sum += results[cat]['pass']
                rate_sum += results[cat]['rate']
        
        avg_results[cat] = {
            'total': total_sum // 5,  # 应该是一样的
            'pass': pass_sum / 5,
            'rate': rate_sum / 5
        }
    
    # 打印表格
    print(f"{'Cat':<10} {'Total':<10} {'Pass (avg)':<15} {'Rate (avg)':<15}")
    print("-" * 60)
    total_pass_sum = 0
    total_total_sum = 0
    for cat in sorted(avg_results.keys()):
        data = avg_results[cat]
        print(f"{cat:<10} {data['total']:<10} {data['pass']:<15.2f} {data['rate']:<15.2f}%")
        total_pass_sum += data['pass']
        total_total_sum += data['total']
    
    overall_rate = (total_pass_sum / total_total_sum) * 100 if total_total_sum > 0 else 0
    print("-" * 60)
    print(f"{'Total':<10} {total_total_sum:<10} {total_pass_sum:<15.2f} {overall_rate:<15.2f}%")
    
    # 2. 统计每个problem在5次测试中的通过次数
    print("\n" + "="*80)
    print("2. 统计每个Problem在5次测试中的通过情况")
    print("="*80)
    
    problem_stats = defaultdict(lambda: {'category': None, 'pass_count': 0, 'total_tests': 0})
    
    # 首先收集所有唯一的problem ID和category（从所有report中）
    all_problem_ids = set()
    problem_categories = {}
    
    for passing_list in all_passing_problems:
        for problem in passing_list:
            all_problem_ids.add(problem['problem_id'])
            problem_categories[problem['problem_id']] = problem['category']
    
    for failing_list in all_failing_problems:
        for problem in failing_list:
            all_problem_ids.add(problem['problem_id'])
            if problem['problem_id'] not in problem_categories:
                problem_categories[problem['problem_id']] = problem['category']
    
    # 初始化所有问题的统计
    for problem_id in all_problem_ids:
        problem_stats[problem_id]['category'] = problem_categories[problem_id]
        problem_stats[problem_id]['total_tests'] = len(all_passing_problems)  # 应该是5
    
    # 统计每个report中通过的次数
    for passing_list in all_passing_problems:
        passing_ids = {p['problem_id'] for p in passing_list}
        for problem_id in all_problem_ids:
            if problem_id in passing_ids:
                problem_stats[problem_id]['pass_count'] += 1
    
    # 分类统计
    passed_problems = []  # 至少通过1次
    failed_problems = []  # 全部不通过
    
    for problem_id, stats in problem_stats.items():
        if stats['pass_count'] > 0:
            passed_problems.append({
                'problem_id': problem_id,
                'category': stats['category'],
                'pass_count': stats['pass_count']
            })
        else:
            failed_problems.append({
                'problem_id': problem_id,
                'category': stats['category']
            })
    
    print(f"\n至少通过1次的问题数量: {len(passed_problems)}")
    print(f"全部不通过的问题数量: {len(failed_problems)}")
    
    # 显示通过次数分布
    pass_count_dist = defaultdict(int)
    for problem_id, stats in problem_stats.items():
        pass_count_dist[stats['pass_count']] += 1
    
    print("\n通过次数分布:")
    for pass_count in sorted(pass_count_dist.keys(), reverse=True):
        print(f"  通过{pass_count}次: {pass_count_dist[pass_count]}个问题")
    
    # 3. 计算Pass@5（按category分组）
    print("\n" + "="*80)
    print("3. Pass@5 by Category (至少通过1次就算通过)")
    print("="*80)
    
    category_pass5 = defaultdict(lambda: {'total': 0, 'passed': 0})
    
    # 统计每个category的总数和通过数
    for problem_id, stats in problem_stats.items():
        cat = stats['category']
        category_pass5[cat]['total'] += 1
        if stats['pass_count'] > 0:
            category_pass5[cat]['passed'] += 1
    
    print(f"{'Cat':<10} {'Total':<10} {'Passed':<10} {'Pass@5 Rate':<15}")
    print("-" * 55)
    
    total_problems = 0
    total_passed = 0
    
    for cat in sorted(category_pass5.keys()):
        data = category_pass5[cat]
        rate = (data['passed'] / data['total'] * 100) if data['total'] > 0 else 0
        print(f"{cat:<10} {data['total']:<10} {data['passed']:<10} {rate:<15.2f}%")
        total_problems += data['total']
        total_passed += data['passed']
    
    overall_pass5_rate = (total_passed / total_problems * 100) if total_problems > 0 else 0
    print("-" * 55)
    print(f"{'Total':<10} {total_problems:<10} {total_passed:<10} {overall_pass5_rate:<15.2f}%")
    
    # 4. 输出详细列表（可选）
    print("\n" + "="*80)
    print("4. 全部不通过的问题列表")
    print("="*80)
    print(f"{'#':<5} {'Problem ID':<60} {'Category':<15}")
    print("-" * 80)
    for idx, problem in enumerate(sorted(failed_problems, key=lambda x: (x['category'], x['problem_id'])), 1):
        print(f"{idx:<5} {problem['problem_id']:<60} {problem['category']:<15}")
    
    # 保存结果到文件
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("="*80 + "\n")
        f.write("综合报告 (n=5)\n")
        f.write("="*80 + "\n\n")
        
        f.write("1. Problem Results by Category (n=5, Pass@1平均值)\n")
        f.write("-"*80 + "\n")
        f.write(f"{'Cat':<10} {'Total':<10} {'Pass (avg)':<15} {'Rate (avg)':<15}\n")
        f.write("-"*60 + "\n")
        for cat in sorted(avg_results.keys()):
            data = avg_results[cat]
            f.write(f"{cat:<10} {data['total']:<10} {data['pass']:<15.2f} {data['rate']:<15.2f}%\n")
        f.write("-"*60 + "\n")
        f.write(f"{'Total':<10} {total_total_sum:<10} {total_pass_sum:<15.2f} {overall_rate:<15.2f}%\n\n")
        
        f.write("2. Pass@5 by Category (至少通过1次就算通过)\n")
        f.write("-"*80 + "\n")
        f.write(f"{'Cat':<10} {'Total':<10} {'Passed':<10} {'Pass@5 Rate':<15}\n")
        f.write("-"*55 + "\n")
        for cat in sorted(category_pass5.keys()):
            data = category_pass5[cat]
            rate = (data['passed'] / data['total'] * 100) if data['total'] > 0 else 0
            f.write(f"{cat:<10} {data['total']:<10} {data['passed']:<10} {rate:<15.2f}%\n")
        f.write("-"*55 + "\n")
        f.write(f"{'Total':<10} {total_problems:<10} {total_passed:<10} {overall_pass5_rate:<15.2f}%\n\n")
        
        f.write("3. 全部不通过的问题列表\n")
        f.write("-"*80 + "\n")
        f.write(f"{'#':<5} {'Problem ID':<60} {'Category':<15}\n")
        f.write("-"*80 + "\n")
        for idx, problem in enumerate(sorted(failed_problems, key=lambda x: (x['category'], x['problem_id'])), 1):
            f.write(f"{idx:<5} {problem['problem_id']:<60} {problem['category']:<15}\n")
    
    print(f"\n结果已保存到: {output_file}")

if __name__ == '__main__':
    main()

