#!/usr/bin/env python3
"""
从JSONL文件中提取responses字段里的Verilog代码
提取每个条目中最后一个```verilog ... ```或```systemverilog ... ```代码块中的代码
最后只保留id和completion这两个字段
"""

import argparse
import json
import re
import os
from pathlib import Path


def extract_verilog_from_text(text):
    """
    从文本中提取Verilog代码
    首先尝试从```verilog ... ```代码围栏中提取
    如果失败，则尝试提取最后一个完整的module ... endmodule块
    
    Args:
        text: 文本内容
        
    Returns:
        提取的Verilog代码，如果没有找到则返回None
    """
    if not text:
        return None
    
    # 方法1: 匹配```verilog ... ```代码块的正则表达式
    pattern = r'```verilog\s*\n(.*?)\n```'
    matches = re.findall(pattern, text, re.DOTALL | re.IGNORECASE)    
    if matches:
        # 返回最后一个匹配的代码块
        return matches[-1].strip()

    # 方法2: 匹配```systemverilog ... ```代码块
    system_pattern = r'```systemverilog\s*\n(.*?)\n```'
    system_matches = re.findall(system_pattern, text, re.DOTALL | re.IGNORECASE)
    if system_matches:
        return system_matches[-1].strip()
    
    # 方法3: 如果代码围栏提取失败，尝试提取最后一个完整的module ... endmodule块
    module_pattern = r'module\s+\w+.*?endmodule'
    module_matches = re.findall(module_pattern, text, re.DOTALL | re.IGNORECASE)
    
    if module_matches:
        # 返回最后一个匹配的module块
        return module_matches[-1].strip()
    
    return None


def extract_verilog_from_responses(responses):
    """
    从responses字段中提取Verilog代码
    responses可能是一个字符串或字符串数组
    
    Args:
        responses: responses字段的内容（字符串或字符串数组）
        
    Returns:
        提取的Verilog代码，如果没有找到则返回None
    """
    if not responses:
        return None
    
    # 如果responses是字符串，直接处理
    if isinstance(responses, str):
        return extract_verilog_from_text(responses)
    
    # 如果responses是列表，遍历所有元素
    if isinstance(responses, list):
        for response in reversed(responses):  # 从后往前遍历，优先提取最后一个
            if isinstance(response, str):
                verilog_code = extract_verilog_from_text(response)
                if verilog_code:
                    return verilog_code
    
    return None


def process_jsonl_file(input_file, output_file=None, extract_all=False):
    """
    处理JSONL文件，提取每个条目的Verilog代码
    
    Args:
        input_file: 输入的JSONL文件路径
        output_file: 输出的JSONL文件路径（可选）
        extract_all: 是否提取所有代码块（而不是只提取最后一个）
    """
    input_path = Path(input_file)
    
    if output_file is None:
        output_file = input_path.with_suffix('.verilog.jsonl')
    else:
        output_file = Path(output_file)
    
    print(f"处理文件: {input_file}")
    print(f"输出文件: {output_file}")
    
    processed_count = 0
    extracted_count = 0
    failed_count = 0
    
    try:
        with open(input_file, 'r', encoding='utf-8') as infile, \
             open(output_file, 'w', encoding='utf-8') as outfile:
            
            for line_num, line in enumerate(infile, 1):
                line = line.strip()
                if not line:
                    continue
                
                try:
                    # 解析JSON行
                    data = json.loads(line)
                    processed_count += 1
                    
                    # 提取字段，优先使用generation，如果没有则使用responses
                    responses = data.get('generation') or data.get('responses', [])
                    
                    if extract_all:
                        # 提取所有Verilog代码块
                        verilog_codes = []
                        
                        # 处理responses（可能是字符串或列表）
                        if isinstance(responses, str):
                            responses_list = [responses]
                        elif isinstance(responses, list):
                            responses_list = responses
                        else:
                            responses_list = []
                        
                        for response_text in responses_list:
                            if not isinstance(response_text, str):
                                continue
                            
                            # 提取所有verilog代码块
                            pattern = r'```verilog\s*\n(.*?)\n```'
                            matches = re.findall(pattern, response_text, re.DOTALL | re.IGNORECASE)
                            verilog_codes.extend([match.strip() for match in matches])
                            
                            # 提取所有systemverilog代码块
                            system_pattern = r'```systemverilog\s*\n(.*?)\n```'
                            system_matches = re.findall(system_pattern, response_text, re.DOTALL | re.IGNORECASE)
                            verilog_codes.extend([match.strip() for match in system_matches])
                            
                            # 如果代码围栏提取失败，尝试提取所有module块
                            if not verilog_codes:
                                module_pattern = r'module\s+\w+.*?endmodule'
                                module_matches = re.findall(module_pattern, response_text, re.DOTALL | re.IGNORECASE)
                                verilog_codes.extend([match.strip() for match in module_matches])
                    else:
                        # 只提取最后一个代码块
                        verilog_code = extract_verilog_from_responses(responses)
                        verilog_codes = [verilog_code] if verilog_code else []
                    
                    # 获取id字段，优先使用problem_id，然后是id，最后是task_id
                    entry_id = data.get('problem_id') or data.get('id') or data.get('task_id', f'line_{line_num}')
                    
                    # 创建输出数据，只保留id和completion字段
                    # 如果提取成功，使用提取的代码；如果失败，completion为空字符串
                    if verilog_codes:
                        completion_value = verilog_codes[0] if not extract_all else verilog_codes
                        extracted_count += 1
                        print(f"  行 {line_num}: 提取了 {len(verilog_codes)} 个代码块 (id: {entry_id})")
                    else:
                        completion_value = "" if not extract_all else []
                        print(f"  行 {line_num}: 未找到Verilog代码块，completion为空 (id: {entry_id})")
                    
                    output_data = {
                        'id': entry_id,
                        'completion': completion_value
                    }
                    
                    # 写入输出文件（无论是否提取成功都写入）
                    outfile.write(json.dumps(output_data, ensure_ascii=False) + '\n')
                        
                except json.JSONDecodeError as e:
                    print(f"  行 {line_num}: JSON解析错误 - {e}")
                    failed_count += 1
                except Exception as e:
                    print(f"  行 {line_num}: 处理错误 - {e}")
                    failed_count += 1
    
    except FileNotFoundError:
        print(f"错误: 找不到输入文件 {input_file}")
        return
    except Exception as e:
        print(f"错误: 处理文件时发生错误 - {e}")
        return
    
    print(f"\n处理完成:")
    print(f"  总处理行数: {processed_count}")
    print(f"  成功提取: {extracted_count}")
    print(f"  处理失败: {failed_count}")
    print(f"  输出文件: {output_file}")


def batch_process_directory(input_dir, output_dir=None, pattern="*.jsonl", extract_all=False):
    """
    批量处理目录中的所有JSONL文件
    
    Args:
        input_dir: 输入目录路径
        output_dir: 输出目录路径（可选）
        pattern: 文件匹配模式
        extract_all: 是否提取所有代码块
    """
    input_path = Path(input_dir)
    
    if output_dir is None:
        output_dir = input_dir
    else:
        os.makedirs(output_dir, exist_ok=True)
    
    jsonl_files = list(input_path.glob(pattern))
    
    if not jsonl_files:
        print(f"在 {input_dir} 中未找到匹配模式 '{pattern}' 的JSONL文件")
        return
    
    print(f"找到 {len(jsonl_files)} 个JSONL文件需要处理")
    
    for jsonl_file in jsonl_files:
        print(f"\n处理文件: {jsonl_file}")
        
        if output_dir == input_dir:
            output_file = jsonl_file.with_suffix('.verilog.jsonl')
        else:
            output_file = Path(output_dir) / jsonl_file.with_suffix('.verilog.jsonl').name
        
        process_jsonl_file(jsonl_file, output_file, extract_all)


def preview_extraction(input_file, num_lines=5):
    """
    预览提取结果，显示前几行的提取内容
    
    Args:
        input_file: 输入文件路径
        num_lines: 预览的行数
    """
    print(f"预览文件: {input_file}")
    print("=" * 50)
    
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, 1):
                if line_num > num_lines:
                    break
                
                line = line.strip()
                if not line:
                    continue
                
                try:
                    data = json.loads(line)
                    responses = data.get('generation', [])
                    verilog_code = extract_verilog_from_responses(responses)
                    
                    entry_id = data.get('problem_id') or data.get('id') or data.get('task_id', 'N/A')
                    print(f"\n行 {line_num} - ID: {entry_id}")
                    if verilog_code:
                        # 判断使用了哪种提取方法
                        response_text = responses[0] if isinstance(responses, list) and responses else (responses if isinstance(responses, str) else '')
                        if re.search(r'```verilog\s*\n.*?\n```', response_text, re.DOTALL | re.IGNORECASE):
                            method = "verilog代码围栏"
                        elif re.search(r'```systemverilog\s*\n.*?\n```', response_text, re.DOTALL | re.IGNORECASE):
                            method = "systemverilog代码围栏"
                        elif re.search(r'module\s+\w+.*?endmodule', response_text, re.DOTALL | re.IGNORECASE):
                            method = "module块"
                        else:
                            method = "未知"
                        
                        print(f"提取方法: {method}")
                        print("提取的Verilog代码:")
                        print("-" * 30)
                        print(verilog_code[:200] + "..." if len(verilog_code) > 200 else verilog_code)
                        print("-" * 30)
                    else:
                        print("未找到Verilog代码块")
                        
                except json.JSONDecodeError:
                    print(f"行 {line_num}: JSON解析错误")
                except Exception as e:
                    print(f"行 {line_num}: 处理错误 - {e}")
    
    except FileNotFoundError:
        print(f"错误: 找不到文件 {input_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="从JSONL文件中提取responses字段的Verilog代码")
    parser.add_argument("--input", "-i", required=True, help="输入JSONL文件或目录")
    parser.add_argument("--output", "-o", help="输出文件或目录")
    parser.add_argument("--batch", "-b", action="store_true", help="批量处理目录")
    parser.add_argument("--pattern", "-p", default="*.jsonl", help="批量处理时的文件匹配模式")
    parser.add_argument("--extract-all", "-a", action="store_true", help="提取所有代码块（而不是只提取最后一个）")
    parser.add_argument("--preview", action="store_true", help="预览提取结果（不生成输出文件）")
    parser.add_argument("--preview-lines", type=int, default=5, help="预览的行数（默认5行）")
    
    args = parser.parse_args()
    
    if args.preview:
        preview_extraction(args.input, args.preview_lines)
    elif args.batch:
        batch_process_directory(args.input, args.output, args.pattern, args.extract_all)
    else:
        process_jsonl_file(args.input, args.output, args.extract_all)

