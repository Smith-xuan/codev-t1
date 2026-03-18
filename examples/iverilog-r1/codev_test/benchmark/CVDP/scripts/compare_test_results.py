#!/usr/bin/env python3
"""
详细比较两个测试报告，找出从通过变为失败的测试用例
"""

import json
import sys
import re
from collections import defaultdict

def parse_report_json(report_file):
    """解析 report.json 文件"""
    try:
        with open(report_file, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"错误: 找不到文件 {report_file}")
        return None
    except json.JSONDecodeError as e:
        print(f"错误: 无法解析 JSON 文件 {report_file}: {e}")
        return None

def extract_test_results(report_data):
    """从报告数据中提取测试结果"""
    results = {
        'passed_tests': set(),
        'failed_tests': set(),
        'passed_problems': set(),
        'failed_problems': set(),
        'by_difficulty': defaultdict(lambda: {'passed': set(), 'failed': set()}),
        'by_category': defaultdict(lambda: {'passed': set(), 'failed': set()})
    }
    
    # 从 test_details 中提取测试结果
    test_details = report_data.get('test_details', {})
    passing_tests = test_details.get('passing_tests', [])
    failing_tests = test_details.get('failing_tests', [])
    
    for test in passing_tests:
        test_id = test.get('test_id', '')
        if test_id:
            results['passed_tests'].add(test_id)
            # 提取问题ID（test_id 可能是 problem_id.test_suffix 格式）
            problem_id = test_id.rsplit('.', 1)[0] if '.' in test_id else test_id
            if problem_id.startswith('cvdp_'):
                results['passed_problems'].add(problem_id)
            
            # 按难度分类
            difficulty = test.get('difficulty', '')
            if difficulty:
                results['by_difficulty'][difficulty]['passed'].add(test_id)
    
    for test in failing_tests:
        test_id = test.get('test_id', '')
        if test_id:
            results['failed_tests'].add(test_id)
            # 提取问题ID
            problem_id = test_id.rsplit('.', 1)[0] if '.' in test_id else test_id
            if problem_id.startswith('cvdp_'):
                results['failed_problems'].add(problem_id)
            
            # 按难度分类
            difficulty = test.get('difficulty', '')
            if difficulty:
                results['by_difficulty'][difficulty]['failed'].add(test_id)
    
    # 从类别数据中提取问题级别的结果
    for category, cat_data in report_data.items():
        if category in ['metadata', 'test_details', 'sample_index']:
            continue
        
        for difficulty in ['easy', 'medium', 'hard']:
            if difficulty not in cat_data:
                continue
            
            diff_data = cat_data[difficulty]
            if 'problems' not in diff_data:
                continue
            
            for problem in diff_data['problems']:
                problem_id = problem.get('id', '')
                if not problem_id:
                    continue
                
                passed = problem.get('Passed', 0)
                total = problem.get('Total', 0)
                
                if total > 0:
                    if passed == total:
                        results['passed_problems'].add(problem_id)
                        results['by_category'][category]['passed'].add(problem_id)
                    elif passed < total:
                        results['failed_problems'].add(problem_id)
                        results['by_category'][category]['failed'].add(problem_id)
    
    return results

def find_regressions(old_results, new_results):
    """找出从通过变为失败的测试"""
    regressions = {
        'tests': old_results['passed_tests'] & new_results['failed_tests'],
        'problems': old_results['passed_problems'] & new_results['failed_problems'],
        'by_difficulty': defaultdict(set),
        'by_category': defaultdict(set)
    }
    
    # 按难度分类
    for difficulty in ['easy', 'medium', 'hard']:
        old_passed = old_results['by_difficulty'][difficulty]['passed']
        new_failed = new_results['by_difficulty'][difficulty]['failed']
        regressions['by_difficulty'][difficulty] = old_passed & new_failed
    
    # 按类别分类
    for category in set(list(old_results['by_category'].keys()) + list(new_results['by_category'].keys())):
        old_passed = old_results['by_category'][category]['passed']
        new_failed = new_results['by_category'][category]['failed']
        regressions['by_category'][category] = old_passed & new_failed
    
    return regressions

def find_improvements(old_results, new_results):
    """找出从失败变为通过的测试"""
    improvements = {
        'tests': old_results['failed_tests'] & new_results['passed_tests'],
        'problems': old_results['failed_problems'] & new_results['passed_problems'],
        'by_difficulty': defaultdict(set),
        'by_category': defaultdict(set)
    }
    
    return improvements

def main():
    if len(sys.argv) < 3:
        print("用法: python compare_test_results.py <原报告.json> <新报告.json>")
        sys.exit(1)
    
    old_report_file = sys.argv[1]
    new_report_file = sys.argv[2]
    
    print("=" * 70)
    print("详细测试结果比较分析")
    print("=" * 70)
    print()
    
    # 解析报告
    print("正在解析报告文件...")
    old_report = parse_report_json(old_report_file)
    new_report = parse_report_json(new_report_file)
    
    if not old_report or not new_report:
        sys.exit(1)
    
    # 提取测试结果
    print("正在提取测试结果...")
    old_results = extract_test_results(old_report)
    new_results = extract_test_results(new_report)
    
    # 找出回归和改进
    print("正在分析差异...")
    regressions = find_regressions(old_results, new_results)
    improvements = find_improvements(old_results, new_results)
    
    print()
    print("=" * 70)
    print("【回归分析 - 从通过变为失败】")
    print("=" * 70)
    print()
    
    print(f"测试级别回归: {len(regressions['tests'])} 个")
    print(f"问题级别回归: {len(regressions['problems'])} 个")
    print()
    
    if regressions['problems']:
        print("【问题级别的回归（从通过变为失败）】")
        print("-" * 70)
        for problem_id in sorted(regressions['problems']):
            print(f"  ✗ {problem_id}")
        print()
    
    # 按难度分类
    print("【按难度分类的回归】")
    print("-" * 70)
    for difficulty in ['easy', 'medium', 'hard']:
        count = len(regressions['by_difficulty'][difficulty])
        if count > 0:
            print(f"{difficulty.capitalize()}: {count} 个测试")
            for test_id in sorted(list(regressions['by_difficulty'][difficulty]))[:10]:
                print(f"  - {test_id}")
            if count > 10:
                print(f"  ... 还有 {count - 10} 个")
            print()
    
    # 按类别分类
    print("【按类别分类的回归（前10个类别）】")
    print("-" * 70)
    category_regressions = sorted(
        [(cat, len(tests)) for cat, tests in regressions['by_category'].items() if tests],
        key=lambda x: x[1],
        reverse=True
    )[:10]
    
    for category, count in category_regressions:
        print(f"{category}: {count} 个测试")
        for test_id in sorted(list(regressions['by_category'][category]))[:5]:
            print(f"  - {test_id}")
        if count > 5:
            print(f"  ... 还有 {count - 5} 个")
        print()
    
    print("=" * 70)
    print("【改进分析 - 从失败变为通过】")
    print("=" * 70)
    print()
    
    print(f"测试级别改进: {len(improvements['tests'])} 个")
    print(f"问题级别改进: {len(improvements['problems'])} 个")
    print()
    
    if improvements['problems']:
        print("【问题级别的改进（从失败变为通过）】")
        print("-" * 70)
        for problem_id in sorted(improvements['problems']):
            print(f"  ✓ {problem_id}")
        print()
    
    print("=" * 70)
    print("【总结】")
    print("=" * 70)
    print()
    
    net_regression = len(regressions['problems']) - len(improvements['problems'])
    print(f"净回归: {net_regression} 个问题")
    print(f"  - 从通过变为失败: {len(regressions['problems'])}")
    print(f"  - 从失败变为通过: {len(improvements['problems'])}")
    print()
    
    if net_regression > 0:
        print("⚠️  测试结果确实下降了")
        print()
        print("【可能的原因】")
        print("1. 系统资源变化（CPU、内存、I/O性能）")
        print("2. Docker 容器执行时间变化（导致超时）")
        print("3. 测试执行的随机性或竞态条件")
        print("4. 系统重启后的环境差异")
        print("5. 测试用例本身的非确定性行为")
        print()
        print("【建议】")
        print("1. 检查这些回归的测试用例的详细日志")
        print("2. 查看是否有超时或资源限制问题")
        print("3. 考虑增加超时时间或系统资源")
        print("4. 多次运行测试以确认是否为随机性导致")

if __name__ == "__main__":
    main()

