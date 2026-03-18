import os
import glob
import re
import json
import subprocess


def extract_verilog_from_generation(generation_text):
    """从generation文本中提取所有tool call中的代码和最后一段非tool call代码"""
    
    all_verilog_codes = []
    
    # 策略1: 查找所有的tool call
    tool_call_pattern = r'<tool_call>\s*(.*?)</tool_call>'
    tool_call_matches = re.findall(tool_call_pattern, generation_text, re.DOTALL)
    
    for tool_call in tool_call_matches:
        try:
            tool_data = json.loads(tool_call)['function']
            if 'name' in tool_data and 'arguments' in tool_data:
                # 检查是否是相关的工具调用
                if tool_data['name'] in ['verilog_simulator', 'ppa_analyzer']:
                    arguments = json.loads(tool_data['arguments'])
                    if 'code' in arguments and arguments['code'].strip():
                        all_verilog_codes.append(arguments['code'].strip())
        except json.JSONDecodeError:
            # 如果JSON解析失败，尝试直接提取可能的代码
            if 'module' in tool_call and 'endmodule' in tool_call:
                # 尝试提取module和endmodule之间的内容
                module_match = re.search(r'(module\s+\w+.*?endmodule)', tool_call, re.DOTALL)
                if module_match:
                    all_verilog_codes.append(module_match.group(1).strip())
    
    # 策略2: 查找最后一段非tool call的代码
    # 先找到所有可能的代码块位置
    verilog_patterns = [
        r'```verilog\s*(.*?)```',  # 标记为verilog的代码块
        r'```(.*?module.*?endmodule.*?)```',  # 包含module...endmodule的代码块
        r'```\s*module\s+.*?```',  # 以module开头的代码块
    ]
    
    # 记录所有代码块的位置
    code_positions = []
    
    for i, pattern in enumerate(verilog_patterns):
        matches = list(re.finditer(pattern, generation_text, re.DOTALL))
        for match in matches:
            # 检查这个代码块是否在tool call内部
            in_tool_call = False
            for tool_call_match in re.finditer(tool_call_pattern, generation_text, re.DOTALL):
                if (match.start() >= tool_call_match.start() and 
                    match.end() <= tool_call_match.end()):
                    in_tool_call = True
                    break
            
            if not in_tool_call:
                code_positions.append((i, match.start(), match.end(), match.group(1).strip()))
                # print(pattern, match.start(), match.end())
    
    # 兜底：查找任何包含module关键字的代码块
    module_pattern = r'(module\s+\w+.*?endmodule)'
    module_matches = list(re.finditer(module_pattern, generation_text, re.DOTALL))
    for match in module_matches:
        # 检查这个代码块是否在tool call内部
        in_tool_call = False
        for tool_call_match in re.finditer(tool_call_pattern, generation_text, re.DOTALL):
            if (match.start() >= tool_call_match.start() and 
                match.end() <= tool_call_match.end()):
                in_tool_call = True
                break
        
        if not in_tool_call:
            code_positions.append((99, match.start(), match.end(), match.group(1).strip()))
            # print(module_pattern, match.start(), match.end())
    
    # 按位置排序并去重
    code_positions.sort(key=lambda x: (x[2], -x[0], -x[1]))
    # for start, end, code in code_positions:
    #     print(start, end, len(code))
    
    # 如果有非tool call的代码块，添加最后一个
    if code_positions:
        last_non_tool_code = code_positions[-1][3]
        # 只有当最后一个非tool call代码不在已提取的tool call代码中时才添加
        if last_non_tool_code not in all_verilog_codes:
            all_verilog_codes.append(last_non_tool_code)
    
    return all_verilog_codes


def extract_final_verilog_from_generation(generation_text):
    """从generation文本中提取最终的Verilog代码（保持原有逻辑）"""
    all_codes = extract_verilog_from_generation(generation_text)
    return all_codes[-1] if all_codes else None


def clean_verilog_code(verilog_code):
    """清理提取的Verilog代码"""
    if not verilog_code:
        return None
    
    # 如果传入的是列表，只清理最后一个（保持向后兼容）
    if isinstance(verilog_code, list):
        if not verilog_code:
            return None
        verilog_code = verilog_code[-1]
    
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


if __name__ == '__main__':
    cot_base = '/nfs_global/projects/cvdp_benchmark/results/qwen3_8b_10epochs/cot'
    test_base = '/nfs_global/projects/cvdp_benchmark/results/experiment_qwen_3_8b_10epochs_tool'
    # tasks = ['galois_encryption_0001', 'generic_nbit_counter_0036', 'line_buffer_0003', 'modified_booth_mul_0002', 'montgomery_0002', 'prim_max_0001', 'swizzler_0014']
    tasks = ['prim_max_0001', 'swizzler_0014']
    
    for task in tasks:
        task = task.split('_')
        task, num = '_'.join(task[:-1]), int(task[-1])
        for i in range(1, 6):
            cot_path = f'{cot_base}/cvdp_copilot_{task}_{num:04}'
            test_path = f'{test_base}/sample_{i}/cvdp_copilot_{task}/harness/{num}'
            print(cot_path)
            print(test_path)
            
            with open(f'{cot_path}/t{i}.v', 'r') as f:
                generation = f.read().strip()
                
            # 提取所有verilog代码
            all_verilog_codes = extract_verilog_from_generation(generation)
            # 清理所有代码
            cleaned_codes = [clean_verilog_code(code) for code in all_verilog_codes if clean_verilog_code(code)]
            
            # print(f"找到 {len(cleaned_codes)} 个Verilog代码片段:")
            # for idx, code in enumerate(all_verilog_codes):
            #     print(f"\n--- 片段 {idx+1} ---")
            #     print(code[:500] + "..." if len(code) > 500 else code)  # 只打印前500字符
            # continue

            results = []
            for code in cleaned_codes:
                verilog_file = glob.glob(f'{test_path}/rtl/*.sv')[0]
                with open(verilog_file, 'w') as f:
                    f.write(code)
                
                script_path = glob.glob(f'{test_path}/run_docker_*.sh')[0]
                if os.path.exists(script_path):
                    result = subprocess.run(['bash', script_path], capture_output=True, text=True)
                    # print(f"输出: {result.stdout}")
                    # pattern = r'=+\s+(\d+)\s+(?:failed,\s+)?(\d+)?\s*passed\s+in\s+([\d.]+)([smh])\s*=+'
                    pattern = r'===+\s*\d+.*?(?:failed|passed).*?\d+\.\d+[smh].*===+'
                    matches = re.findall(pattern, result.stdout, re.MULTILINE | re.IGNORECASE)
                    print(matches)
                    assert len(matches) == 1
                    results.append(matches[0])
                else:
                    print(f"脚本不存在: {script_path}")
            # print('\n'.join(results))