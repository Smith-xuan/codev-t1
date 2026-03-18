import argparse
import json
import re
import os
from pathlib import Path

def extract_verilog_from_generation(generation_text):
    """从generation文本中提取最终的Verilog代码"""

    # 策略1: 查找最后一个<answer>块中的Verilog代码
    answer_pattern = r'<answer>(.*?)</answer>'
    answer_matches = re.findall(answer_pattern, generation_text, re.DOTALL)

    verilog_patterns = [
        r'```verilog\s*(.*?)```',  # 标记为verilog的代码块
        r'<tool_call>\s*(.*?)</tool_call>',  # 标记为verilog的代码块
        r'```(.*?module.*?endmodule.*?)```',  # 包含module...endmodule的代码块
        r'```\s*module\s+.*?```',  # 以module开头的代码块
    ]

    if answer_matches:
        # 获取最后一个answer块
        last_answer = answer_matches[-1]

        # 在最后一个answer块中查找Verilog代码块
        for pattern in verilog_patterns:
            matches = re.findall(pattern, last_answer, re.DOTALL)
            if matches:
                # 如果有多个verilog代码块，返回第一个
                if pattern != r'<tool_call>\s*(.*?)</tool_call>':
                    return matches[0].strip()
                else:
                    answer = json.loads(matches[0])
                    # if answer['function']['name'] in ['verilog_simulator', 'ppa_analyzer']:
                    return json.loads(answer['function']['arguments'])['code']

    # 如果没有answer块，或者answer块中没有verilog代码，则在全文中查找verilog代码块
    result = None
    pos = -1
    for pattern in verilog_patterns:
        # matches = re.findall(pattern, generation_text, re.DOTALL)
        matches = list(re.finditer(pattern, generation_text, re.DOTALL))
        if matches:
            pos1 = matches[-1].end()
            match_str = matches[-1].group(1)
            if pos == -1 or (pattern in [r'```verilog\s*(.*?)```', r'<tool_call>\s*(.*?)</tool_call>'] and pos1 > pos):
                pos = pos1
                if pattern != r'<tool_call>\s*(.*?)</tool_call>':
                    result = match_str.strip()
                else:
                    try:
                        answer = json.loads(match_str)
                        result = json.loads(answer['function']['arguments'])['code']
                    except:
                        pass
    if result:
        return result

    # 进一步兜底：查找任何包含module关键字的代码块
    module_pattern = r'(module\s+\w+.*?endmodule)'
    matches = re.findall(module_pattern, generation_text, re.DOTALL)
    if matches:
        return matches[-1].strip()

    return None

def clean_verilog_code(verilog_code):
    """清理提取的Verilog代码"""
    if not verilog_code:
        return None
    
    # 移除多余的换行符和空白
    lines = verilog_code.split('\n')
    cleaned_lines = []
    
    for line in lines:
        # 跳过空行和只包含空白的行
        stripped_line = line.strip()
        if stripped_line:
            cleaned_lines.append(line.rstrip())
    
    # 重新组合
    cleaned_code = '\n'.join(cleaned_lines)
    
    # 确保代码以endmodule结束
    if cleaned_code and not cleaned_code.strip().endswith('endmodule'):
        # 如果代码被截断，尝试找到最后一个完整的endmodule
        last_endmodule = cleaned_code.rfind('endmodule')
        if last_endmodule != -1:
            cleaned_code = cleaned_code[:last_endmodule + len('endmodule')]

    testbench_pattern = re.compile(
        r'module\s+\w*testbench\w*\s*;.*?endmodule',
        re.DOTALL | re.IGNORECASE
    )
    
    # 查找所有模块来判断是否存在多个模块
    all_modules_pattern = re.compile(r'module\s+.*?endmodule', re.DOTALL)
    all_modules = all_modules_pattern.findall(cleaned_code)
    
    # 只有当存在多个模块且包含testbench模块时才执行移除
    if len(all_modules) > 1 and testbench_pattern.search(cleaned_code):
        # 替换掉testbench模块，同时处理可能的空行
        cleaned_code = testbench_pattern.sub('', cleaned_code)
        # 清理替换后可能产生的多余空行
        cleaned_code = re.sub(r'\n{3,}', '\n\n', cleaned_code).strip()
    
    return cleaned_code

def process_jsonl_file(input_file, output_file):
    """处理JSONL文件并提取最终答案，并判断是否调用了工具"""
    
    extracted_answers = []
    success_count = 0
    
    with open(input_file, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            try:
                data = json.loads(line.strip())
                
                if 'generation' not in data:
                    print(f"Warning: Line {line_num} missing 'generation' field")
                    continue
                
                generation = data['generation']
                
                # 判断是否调用了工具
                # tool_calls 字段存在且非空（非None且非空列表）则为True，否则为False
                tool_calls_flag = False
                if 'tool_calls' in data and data['tool_calls']:
                    # 只要不是空列表或None就算调用了工具
                    if isinstance(data['tool_calls'], list):
                        tool_calls_flag = len(data['tool_calls']) > 0
                    else:
                        # 不是list但有内容也算
                        tool_calls_flag = True
                else:
                    tool_calls_flag = False

                # 提取Verilog代码
                verilog_code = extract_verilog_from_generation(generation)
                cleaned_code = clean_verilog_code(verilog_code)

                # print('problem id is', data['problem_id'])
                # if data['problem_id'] == 905582 and output_file.find('t1') >= 0:
                #     print('==' * 25 + 'cleaned code' + '==' * 25)
                #     print(verilog_code)
                #     # print(cleaned_code)
                
                # 创建新的记录
                extracted_record = {
                    'problem_id': data.get('problem_id', line_num),
                    'final_verilog_answer': cleaned_code if cleaned_code else "No Verilog code found",
                    'extraction_success': cleaned_code is not None,
                    'tool_calls': tool_calls_flag
                }
                
                if cleaned_code:
                    success_count += 1
                
                extracted_answers.append(extracted_record)
                
                # 显示前几个的详细信息用于调试
                if line_num <= 5:
                    print(f"Line {line_num}: {'SUCCESS' if cleaned_code else 'FAILED'}")
                    print(f"  tool_calls: {tool_calls_flag}")
                    if cleaned_code:
                        # 显示前200个字符
                        preview = cleaned_code[:200].replace('\n', '\\n')
                        print(f"  Preview: {preview}...")
                    else:
                        print(f"  No Verilog code found")
                
            except json.JSONDecodeError as e:
                print(f"Error parsing JSON on line {line_num}: {e}")
                continue
            except Exception as e:
                print(f"Error processing line {line_num}: {e}")
                continue
    
    # 写入输出文件
    with open(output_file, 'w', encoding='utf-8') as f:
        for record in extracted_answers:
            f.write(json.dumps(record, ensure_ascii=False) + '\n')
    
    print(f"Processed {len(extracted_answers)} records")
    print(f"Successfully extracted {success_count} Verilog codes")
    print(f"Success rate: {success_count/len(extracted_answers)*100:.1f}%")
    print(f"Output written to {output_file}")
    
    return len(extracted_answers), success_count

def main():
    parser = argparse.ArgumentParser(description='处理输入JSONL文件并输出结果')
    
    # 添加输入文件参数（支持多个文件，用空格分隔）
    parser.add_argument('--input', 
                       nargs='+',  # 接受一个或多个值
                       default=['/nfs_global/NeMo-Skills/RTLLM/no_tool_results/deepseek/deepseek/deepseek_concurrent_results_t5.jsonl'],
                       help='输入的JSONL文件路径（多个文件用空格分隔）')
    
    # 添加输出文件参数（支持多个文件，与输入文件一一对应）
    parser.add_argument('--output', 
                       nargs='+',  # 接受一个或多个值
                       default=['/nfs_global/NeMo-Skills/RTLLM/no_tool_results/deepseek/deepseek/extracted_answers_improved_notools_t5.jsonl'],
                       help='输出的JSONL文件路径（多个文件用空格分隔，需与输入文件数量一致）')
    
    # 添加模型名称参数（可选，默认使用Claude-4.0）
    parser.add_argument('--model', 
                       default='Claude-4.0', 
                       help='模型名称（默认：Claude-4.0）')
    
    # 解析命令行参数
    args = parser.parse_args()
    
    # 检查输入和输出文件数量是否一致
    if len(args.input) != len(args.output):
        raise ValueError(f"输入文件数量（{len(args.input)}）与输出文件数量（{len(args.output)}）不匹配")
    
    # 赋值给变量（与原代码逻辑保持一致）
    input_files = args.input
    output_files = args.output
    model_names = [args.model for _ in input_files]  # 每个输入文件对应一个模型名称

    total_processed = 0
    total_success = 0
    
    for input_file, output_file, model_name in zip(input_files, output_files, model_names):
        if os.path.exists(input_file):
            print(f"\n{'='*60}")
            print(f"处理模型: {model_name}")
            print(f"输入文件: {input_file}")
            print(f"输出文件: {output_file}")
            print('='*60)
            
            count, success = process_jsonl_file(input_file, output_file)
            total_processed += count
            total_success += success
        else:
            print(f"Warning: 文件不存在: {input_file}")
    
    print(f"\n{'='*60}")
    print(f"总体统计:")
    print(f"总共处理了 {total_processed} 条记录")
    print(f"成功提取了 {total_success} 个Verilog代码")
    print(f"总体成功率: {total_success/total_processed*100:.1f}%")
    print("提取完成!")
    print('='*60)

if __name__ == "__main__":
    main() 