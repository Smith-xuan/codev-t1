#!/usr/bin/env python3
"""
从JSONL文件中提取responses字段，并按task_id保存到子目录中
"""

import json
import os
import argparse
from pathlib import Path


def extract_responses(jsonl_path, output_dir, filename="t1.v"):
    """
    从JSONL文件中提取每个条目的responses字段，保存到以task_id命名的子目录中
    
    Args:
        jsonl_path: JSONL文件路径
        output_dir: 输出目录（cot文件夹）
        filename: 保存的文件名，默认为t1.v
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    count = 0
    with open(jsonl_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            
            try:
                data = json.loads(line)
                task_id = data.get('task_id')
                responses = data.get('responses', [])
                # task_id = data.get('problem_id')
                # responses = data.get('generation')
                
                if not task_id:
                    print(f"警告: 第 {line_num} 行缺少 task_id，跳过")
                    continue
                
                if not responses:
                    print(f"警告: task_id={task_id} 缺少 responses 字段，跳过")
                    continue
                
                # 由于只采样一次，取第一个response
                response_text = responses[0] if isinstance(responses, list) else responses
                
                # 创建以task_id命名的子目录
                task_dir = output_dir / task_id
                task_dir.mkdir(parents=True, exist_ok=True)
                
                # 保存response内容到文件（使用缩进格式）
                output_file = task_dir / filename
                with open(output_file, 'w', encoding='utf-8') as out_f:
                    # 如果response是字符串，直接写入
                    # 如果是字典/列表，使用JSON格式化
                    if isinstance(response_text, str):
                        out_f.write(response_text)
                    else:
                        out_f.write(json.dumps(response_text, indent=2, ensure_ascii=False))
                
                count += 1
                if count % 10 == 0:
                    print(f"已处理 {count} 个条目...")
                    
            except json.JSONDecodeError as e:
                print(f"错误: 第 {line_num} 行JSON解析失败: {e}")
                continue
            except Exception as e:
                print(f"错误: 处理第 {line_num} 行时出错: {e}")
                continue
    
    print(f"完成！共处理 {count} 个条目")
    print(f"输出目录: {output_dir}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="从JSONL文件中提取responses字段，按task_id保存到子目录"
    )
    parser.add_argument(
        '--jsonl_path',
        type=str,
        required=True,
        help='输入的JSONL文件路径'
    )
    parser.add_argument(
        '--output_dir',
        type=str,
        required=True,
        help='输出目录（cot文件夹）'
    )
    parser.add_argument(
        '--filename',
        type=str,
        default='t1.v',
        help='保存的文件名（默认: t1.v）'
    )
    
    args = parser.parse_args()
    
    extract_responses(args.jsonl_path, args.output_dir, args.filename)

