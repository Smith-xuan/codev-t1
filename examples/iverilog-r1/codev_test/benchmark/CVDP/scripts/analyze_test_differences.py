#!/usr/bin/env python3
"""
分析两个测试运行日志的差异
"""

import sys
import re
from collections import defaultdict

def analyze_log(log_file):
    """分析日志文件"""
    stats = {
        'timeouts': [],
        'errors': [],
        'test_cases': set(),
        'input_file': None,
        'total_lines': 0
    }
    
    with open(log_file, 'r') as f:
        for line_num, line in enumerate(f, 1):
            stats['total_lines'] = line_num
            
            # 查找输入文件
            if 'File path in local inference model' in line or 'answer_to_import' in line:
                match = re.search(r'answer_to_import[^/\s]*', line)
                if match:
                    stats['input_file'] = match.group(0)
            
            # 查找超时
            if 'Timeout' in line and 'expired' in line:
                match = re.search(r'/([^/]+)/harness/(\d+)/run_docker_harness_([^.]+)', line)
                if match:
                    test_name, harness_num, harness_type = match.groups()
                    stats['timeouts'].append({
                        'test': test_name,
                        'harness': f"{harness_num}_{harness_type}",
                        'line': line_num
                    })
            
            # 查找错误
            if '[ERROR]' in line:
                stats['errors'].append({
                    'line': line_num,
                    'content': line.strip()
                })
            
            # 提取测试用例
            if 'Starting' in line and 'repository execution' in line:
                matches = re.findall(r'cvdp_copilot_\w+_\d+', line)
                stats['test_cases'].update(matches)
    
    return stats

def main():
    if len(sys.argv) < 3:
        print("用法: python analyze_test_differences.py <原日志> <新日志>")
        sys.exit(1)
    
    old_log = sys.argv[1]
    new_log = sys.argv[2]
    
    print("=" * 70)
    print("测试日志差异分析")
    print("=" * 70)
    print()
    
    old_stats = analyze_log(old_log)
    new_stats = analyze_log(new_log)
    
    print("【基本信息】")
    print(f"原日志文件: {old_log}")
    print(f"  总行数: {old_stats['total_lines']}")
    print(f"  输入文件: {old_stats['input_file'] or '未找到'}")
    print(f"  测试用例数: {len(old_stats['test_cases'])}")
    print()
    
    print(f"新日志文件: {new_log}")
    print(f"  总行数: {new_stats['total_lines']}")
    print(f"  输入文件: {new_stats['input_file'] or '未找到'}")
    print(f"  测试用例数: {len(new_stats['test_cases'])}")
    print()
    
    print("【关键差异】")
    
    # 输入文件差异
    if old_stats['input_file'] != new_stats['input_file']:
        print(f"⚠️  输入文件不同！")
        print(f"  原: {old_stats['input_file']}")
        print(f"  新: {new_stats['input_file']}")
        print("  这是导致结果差异的主要原因！")
        print()
    
    # 测试用例差异
    old_only = old_stats['test_cases'] - new_stats['test_cases']
    new_only = new_stats['test_cases'] - old_stats['test_cases']
    if old_only or new_only:
        print(f"⚠️  测试用例不同！")
        if old_only:
            print(f"  只在原日志中: {len(old_only)} 个")
            for tc in sorted(list(old_only))[:10]:
                print(f"    - {tc}")
            if len(old_only) > 10:
                print(f"    ... 还有 {len(old_only) - 10} 个")
        if new_only:
            print(f"  只在新日志中: {len(new_only)} 个")
            for tc in sorted(list(new_only))[:10]:
                print(f"    - {tc}")
            if len(new_only) > 10:
                print(f"    ... 还有 {len(new_only) - 10} 个")
        print()
    
    # 超时统计
    print("【超时统计】")
    print(f"原日志超时数: {len(old_stats['timeouts'])}")
    print(f"新日志超时数: {len(new_stats['timeouts'])}")
    
    # 统计超时的测试用例
    old_timeout_tests = set(t['test'] for t in old_stats['timeouts'])
    new_timeout_tests = set(t['test'] for t in new_stats['timeouts'])
    
    if old_timeout_tests != new_timeout_tests:
        print("⚠️  超时的测试用例不同！")
        only_old = old_timeout_tests - new_timeout_tests
        only_new = new_timeout_tests - old_timeout_tests
        if only_old:
            print(f"  只在原日志中超时: {only_old}")
        if only_new:
            print(f"  只在新日志中超时: {only_new}")
    print()
    
    # 错误统计
    print("【错误统计】")
    print(f"原日志错误数: {len(old_stats['errors'])}")
    print(f"新日志错误数: {len(new_stats['errors'])}")
    print()
    
    # 异常重试统计
    print("【异常重试统计】")
    with open(old_log, 'r') as f:
        old_exceptions = sum(1 for line in f if 'Exception occurred' in line)
    with open(new_log, 'r') as f:
        new_exceptions = sum(1 for line in f if 'Exception occurred' in line)
    print(f"原日志异常重试: {old_exceptions}")
    print(f"新日志异常重试: {new_exceptions}")
    if new_exceptions > old_exceptions:
        print(f"⚠️  新日志有更多异常重试（多 {new_exceptions - old_exceptions} 次）")
    print()
    
    print("=" * 70)
    print("【结论】")
    print("=" * 70)
    
    issues = []
    if old_stats['input_file'] != new_stats['input_file']:
        issues.append("1. ⚠️  使用了不同的输入文件，这是导致结果差异的主要原因")
    if len(new_stats['timeouts']) > len(old_stats['timeouts']):
        issues.append(f"2. ⚠️  新测试有更多超时（多 {len(new_stats['timeouts']) - len(old_stats['timeouts'])} 个）")
    if new_exceptions > old_exceptions:
        issues.append(f"3. ⚠️  新测试有更多异常重试（多 {new_exceptions - old_exceptions} 次）")
    if old_stats['test_cases'] != new_stats['test_cases']:
        issues.append("4. ⚠️  测试用例集合不同")
    
    if issues:
        for issue in issues:
            print(issue)
    else:
        print("未发现明显差异，可能由其他因素导致（如随机性、环境变化等）")
    
    print()
    print("【建议】")
    print("1. 确保使用相同的输入文件进行测试")
    print("2. 检查 Docker 环境是否一致")
    print("3. 检查系统资源（CPU、内存、磁盘）是否充足")
    print("4. 检查网络连接是否正常（影响镜像拉取和 API 调用）")

if __name__ == "__main__":
    main()




