#!/usr/bin/env python3
"""
检查仓库中所有 Dockerfile 和构建脚本中的 cocotb 版本指定
"""

import os
import re
import glob
import json
from pathlib import Path

def check_dockerfile(filepath):
    """检查 Dockerfile 中的 cocotb 安装指令"""
    issues = []
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
            for i, line in enumerate(lines, 1):
                if 'cocotb' in line.lower() and ('RUN' in line or 'pip' in line):
                    # 检查是否指定了版本
                    if re.search(r'cocotb[=<>!]', line) or re.search(r'cocotb.*==', line):
                        issues.append({
                            'file': filepath,
                            'line': i,
                            'content': line.strip(),
                            'status': '✓ 已指定版本'
                        })
                    else:
                        issues.append({
                            'file': filepath,
                            'line': i,
                            'content': line.strip(),
                            'status': '✗ 未指定版本'
                        })
    except Exception as e:
        pass
    return issues

def check_jsonl_dataset(filepath):
    """检查数据集 JSONL 文件中的 Dockerfile 指令"""
    issues = []
    try:
        with open(filepath, 'r') as f:
            for line_num, line in enumerate(f, 1):
                try:
                    data = json.loads(line)
                    for key, value in data.items():
                        if isinstance(value, str) and 'cocotb' in value.lower() and 'RUN' in value:
                            # 提取包含 cocotb 的行
                            for l in value.split('\n'):
                                if 'cocotb' in l.lower() and 'RUN' in l:
                                    # 检查是否指定了版本
                                    if re.search(r'cocotb[=<>!]', l) or re.search(r'cocotb.*==', l):
                                        issues.append({
                                            'file': filepath,
                                            'line': line_num,
                                            'field': key,
                                            'content': l.strip(),
                                            'status': '✓ 已指定版本'
                                        })
                                    else:
                                        issues.append({
                                            'file': filepath,
                                            'line': line_num,
                                            'field': key,
                                            'content': l.strip(),
                                            'status': '✗ 未指定版本'
                                        })
                                    break
                except:
                    continue
    except Exception as e:
        pass
    return issues

def main():
    project_root = Path(__file__).parent.parent
    
    print("=" * 70)
    print("检查 cocotb 版本指定情况")
    print("=" * 70)
    print()
    
    all_issues = []
    
    # 1. 检查仓库中的 Dockerfile
    print("【1. 检查仓库中的 Dockerfile】")
    print("-" * 70)
    dockerfiles = list(project_root.glob("**/Dockerfile*"))
    dockerfiles = [f for f in dockerfiles if 'work' not in str(f)]  # 排除 work 目录
    
    for df in dockerfiles:
        issues = check_dockerfile(df)
        all_issues.extend(issues)
        if issues:
            print(f"\n文件: {df.relative_to(project_root)}")
            for issue in issues:
                print(f"  行 {issue['line']}: {issue['status']}")
                print(f"    {issue['content']}")
    
    if not any('Dockerfile' in str(i['file']) for i in all_issues):
        print("  未找到包含 cocotb 的 Dockerfile")
    print()
    
    # 2. 检查数据集文件
    print("【2. 检查数据集文件中的 Dockerfile 指令】")
    print("-" * 70)
    dataset_files = list(project_root.glob("example_dataset/*.jsonl"))
    dataset_files.extend(project_root.glob("data/raw/*.jsonl"))
    
    dataset_issues = []
    for df in dataset_files[:10]:  # 检查前10个文件
        issues = check_jsonl_dataset(df)
        dataset_issues.extend(issues)
        if issues:
            print(f"\n文件: {df.relative_to(project_root)}")
            for issue in issues:
                print(f"  记录 {issue['line']}, 字段 {issue.get('field', 'N/A')}: {issue['status']}")
                print(f"    {issue['content']}")
    
    all_issues.extend(dataset_issues)
    
    if not dataset_issues:
        print("  未找到包含 cocotb 的数据集文件")
    print()
    
    # 3. 检查 work 目录中的实际构建的 Dockerfile（示例）
    print("【3. 检查实际构建的 Dockerfile（work 目录示例）】")
    print("-" * 70)
    work_dockerfiles = list(project_root.glob("work/**/Dockerfile"))
    if work_dockerfiles:
        sample_df = work_dockerfiles[0]
        issues = check_dockerfile(sample_df)
        if issues:
            print(f"\n示例文件: {sample_df.relative_to(project_root)}")
            for issue in issues:
                print(f"  行 {issue['line']}: {issue['status']}")
                print(f"    {issue['content']}")
        else:
            print("  示例文件中未找到 cocotb 安装指令")
    else:
        print("  未找到 work 目录中的 Dockerfile")
    print()
    
    # 4. 总结
    print("=" * 70)
    print("【总结】")
    print("=" * 70)
    
    with_version = [i for i in all_issues if '✓' in i['status']]
    without_version = [i for i in all_issues if '✗' in i['status']]
    
    print(f"总共找到 {len(all_issues)} 个 cocotb 安装指令")
    print(f"  ✓ 已指定版本: {len(with_version)} 个")
    print(f"  ✗ 未指定版本: {len(without_version)} 个")
    print()
    
    if without_version:
        print("⚠️  发现未指定版本的 cocotb 安装指令！")
        print("\n建议:")
        print("1. 在 Dockerfile 中指定 cocotb 版本，例如:")
        print("   RUN pip3 install 'cocotb>=1.6.0' cocotb-bus")
        print("   或")
        print("   RUN pip3 install 'cocotb==1.8.0' cocotb-bus")
        print()
        print("2. 在数据集文件的 Dockerfile 指令中也指定版本")
        print()
        print("3. 确保版本包含 cocotb.runner 模块（cocotb 1.6.0+）")
    else:
        print("✓ 所有 cocotb 安装指令都已指定版本")

if __name__ == "__main__":
    main()




