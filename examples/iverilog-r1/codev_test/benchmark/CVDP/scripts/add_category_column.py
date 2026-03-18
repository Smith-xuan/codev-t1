#!/usr/bin/env python3
"""
为summary.txt的详细题目列表添加分区列
从jsonl文件中读取每个题目的categories字段的第一个元素，作为分区信息
"""

import json
import sys
from pathlib import Path
import re


def load_category_map(jsonl_path):
    """
    从jsonl文件中加载id到category的映射
    返回字典：{problem_id: category}
    """
    category_map = {}
    
    try:
        with open(jsonl_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                
                try:
                    data = json.loads(line)
                    problem_id = data.get('id')
                    categories = data.get('categories', [])
                    
                    if problem_id and categories:
                        # 取categories的第一个元素作为分区
                        category = categories[0]
                        category_map[problem_id] = category
                except json.JSONDecodeError as e:
                    print(f"Warning: Failed to parse JSON line: {e}", file=sys.stderr)
                    continue
    
    except Exception as e:
        print(f"Error reading jsonl file {jsonl_path}: {e}", file=sys.stderr)
        sys.exit(1)
    
    return category_map


def parse_summary_file(summary_path):
    """
    解析summary.txt文件，提取详细题目列表部分的内容
    返回：
    - header_lines: 详细题目列表之前的所有行
    - table_lines: 详细题目列表的行（包括表头和数据行）
    - footer_lines: 详细题目列表之后的所有行
    """
    try:
        with open(summary_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading summary file {summary_path}: {e}", file=sys.stderr)
        sys.exit(1)
    
    # 查找详细题目列表的开始和结束位置
    start_idx = None
    end_idx = None
    
    for i, line in enumerate(lines):
        if '详细题目列表' in line:
            start_idx = i
        elif start_idx is not None and '统计信息' in line:
            end_idx = i
            break
    
    if start_idx is None:
        print("Error: Could not find '详细题目列表' section", file=sys.stderr)
        sys.exit(1)
    
    if end_idx is None:
        end_idx = len(lines)
    
    header_lines = lines[:start_idx]
    table_lines = lines[start_idx:end_idx]
    footer_lines = lines[end_idx:]
    
    return header_lines, table_lines, footer_lines


def add_category_column(table_lines, category_map):
    """
    为表格行添加分区列
    返回更新后的表格行列表
    """
    updated_lines = []
    
    for line in table_lines:
        line_original = line
        line = line.rstrip('\n')
        
        # 跳过分隔线
        if line.startswith('=') or line.startswith('-'):
            updated_lines.append(line_original)
            continue
        
        # 处理表头行
        if '题目ID' in line:
            # 更新表头，添加分区列
            # 原格式: 题目ID 正确性 工具调用次数 完成生成
            # 新格式: 题目ID 分区 正确性 工具调用次数 完成生成
            updated_header = f"{'题目ID':<60} {'分区':<12} {'正确性':<10} {'工具调用次数':<15} {'完成生成':<10}\n"
            updated_lines.append(updated_header)
            continue
        
        # 处理数据行
        # 格式: cvdp_copilot_xxx  Fail       7               Yes
        # 使用split按空格分割，但保留题目ID（可能包含空格）
        parts = line.split()
        if len(parts) >= 4:
            # 找到第一个非ID的字段（正确性字段通常是 Pass/Fail）
            # 题目ID可能在前面，我们需要找到正确性字段的位置
            problem_id = None
            correctness = None
            tool_calls = None
            completed = None
            
            # 尝试找到正确性字段（Pass/Fail）
            for i, part in enumerate(parts):
                if part in ['Pass', 'Fail', 'Unknown']:
                    correctness = part
                    # 题目ID是前面所有部分的组合
                    problem_id = ' '.join(parts[:i]).strip()
                    # 工具调用次数应该在下一个位置
                    if i + 1 < len(parts):
                        tool_calls = parts[i + 1]
                    # 完成生成应该在最后一个位置
                    if i + 2 < len(parts):
                        completed = parts[i + 2]
                    break
            
            if problem_id and correctness and tool_calls and completed:
                # 获取分区信息
                category = category_map.get(problem_id, 'Unknown')
                
                # 格式化新行
                updated_line = f"{problem_id:<60} {category:<12} {correctness:<10} {tool_calls:<15} {completed:<10}\n"
                updated_lines.append(updated_line)
            else:
                # 如果无法解析，保持原样
                updated_lines.append(line_original)
        else:
            # 如果无法匹配，保持原样
            updated_lines.append(line_original)
    
    return updated_lines


def main():
    if len(sys.argv) < 3:
        print("Usage: python add_category_column.py <jsonl_file> <summary_file>")
        print("  jsonl_file: cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl 文件路径")
        print("  summary_file: summary.txt 文件路径")
        sys.exit(1)
    
    jsonl_path = Path(sys.argv[1])
    summary_path = Path(sys.argv[2])
    
    if not jsonl_path.exists():
        print(f"Error: JSONL file {jsonl_path} does not exist", file=sys.stderr)
        sys.exit(1)
    
    if not summary_path.exists():
        print(f"Error: Summary file {summary_path} does not exist", file=sys.stderr)
        sys.exit(1)
    
    # 加载category映射
    print(f"Loading category map from {jsonl_path}...")
    category_map = load_category_map(jsonl_path)
    print(f"Loaded {len(category_map)} category mappings")
    
    # 解析summary文件
    print(f"Parsing summary file {summary_path}...")
    header_lines, table_lines, footer_lines = parse_summary_file(summary_path)
    
    # 添加分区列
    print("Adding category column...")
    updated_table_lines = add_category_column(table_lines, category_map)
    
    # 合并所有行
    all_lines = header_lines + updated_table_lines + footer_lines
    
    # 写回文件
    print(f"Writing updated summary to {summary_path}...")
    with open(summary_path, 'w', encoding='utf-8') as f:
        f.writelines(all_lines)
    
    print("Done!")


if __name__ == '__main__':
    main()

