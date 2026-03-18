import os
import glob
import re
import json
import subprocess


def _extract_code_from_tool_json(tool_json_text):
    """从<tool_call>...</tool_call>内部JSON文本中提取code字段。

    兼容两种格式：
    1) 旧格式（带function包裹，arguments为字符串JSON）：
       {
         "id": ..., "type": "function",
         "function": {"name": "verilog_simulator", "arguments": "{\"code\": \"...\"}"}
       }

    2) 新格式（顶层直接name/arguments，arguments为对象）：
       {"name": "verilog_simulator", "arguments": {"code": "..."}}
    """
    try:
        obj = json.loads(tool_json_text)
    except json.JSONDecodeError:
        return None

    # 统一获取 name 与 arguments
    func_name = None
    arguments = None

    if isinstance(obj, dict) and "function" in obj and isinstance(obj["function"], dict):
        # 旧格式
        func = obj["function"]
        func_name = func.get("name")
        arguments = func.get("arguments")
    else:
        # 新格式（或扁平化）
        func_name = obj.get("name")
        arguments = obj.get("arguments")

    if func_name not in ["verilog_simulator", "ppa_analyzer"]:
        return None

    # 解析 arguments 可能是 str(JSON) 或 dict
    if isinstance(arguments, str):
        try:
            arguments = json.loads(arguments)
        except json.JSONDecodeError:
            return None

    if not isinstance(arguments, dict):
        return None

    code = arguments.get("code")
    if isinstance(code, str) and code.strip():
        return code.strip()
    return None


def extract_verilog_from_generation(generation_text):
    """从generation文本中提取所有tool call中的代码和最后一段非tool call代码（兼容两种JSON格式）。"""

    all_verilog_codes = []

    # 策略1: 查找所有的tool call
    tool_call_pattern = r'<tool_call>\s*(.*?)</tool_call>'
    tool_call_matches = re.findall(tool_call_pattern, generation_text, re.DOTALL)

    for tool_call in tool_call_matches:
        code = _extract_code_from_tool_json(tool_call)
        if code:
            all_verilog_codes.append(code)
        else:
            # 如果JSON解析失败，尝试直接提取可能的代码
            if 'module' in tool_call and 'endmodule' in tool_call:
                module_match = re.search(r'(module\s+\w+.*?endmodule)', tool_call, re.DOTALL)
                if module_match:
                    all_verilog_codes.append(module_match.group(1).strip())

    # 策略2: 查找最后一段非tool call的代码
    verilog_patterns = [
        r'```verilog\s*(.*?)```',
        r'```(.*?module.*?endmodule.*?)```',
        r'```\s*module\s+.*?```',
    ]

    code_positions = []

    for i, pattern in enumerate(verilog_patterns):
        matches = list(re.finditer(pattern, generation_text, re.DOTALL))
        for match in matches:
            in_tool_call = False
            for tool_call_match in re.finditer(tool_call_pattern, generation_text, re.DOTALL):
                if (match.start() >= tool_call_match.start() and 
                    match.end() <= tool_call_match.end()):
                    in_tool_call = True
                    break
            if not in_tool_call:
                code_positions.append((i, match.start(), match.end(), match.group(1).strip()))

    module_pattern = r'(module\s+\w+.*?endmodule)'
    module_matches = list(re.finditer(module_pattern, generation_text, re.DOTALL))
    for match in module_matches:
        in_tool_call = False
        for tool_call_match in re.finditer(tool_call_pattern, generation_text, re.DOTALL):
            if (match.start() >= tool_call_match.start() and 
                match.end() <= tool_call_match.end()):
                in_tool_call = True
                break
        if not in_tool_call:
            code_positions.append((99, match.start(), match.end(), match.group(1).strip()))

    code_positions.sort(key=lambda x: (x[2], -x[0], -x[1]))

    if code_positions:
        last_non_tool_code = code_positions[-1][3]
        if last_non_tool_code not in all_verilog_codes:
            all_verilog_codes.append(last_non_tool_code)

    return all_verilog_codes


def extract_final_verilog_from_generation(generation_text):
    """从generation文本中提取最终的Verilog代码（保持原有逻辑）。"""
    all_codes = extract_verilog_from_generation(generation_text)
    return all_codes[-1] if all_codes else None


def clean_verilog_code(verilog_code):
    """清理提取的Verilog代码。"""
    if not verilog_code:
        return None

    if isinstance(verilog_code, list):
        if not verilog_code:
            return None
        verilog_code = verilog_code[-1]

    lines = verilog_code.split('\n')
    cleaned_lines = []

    for line in lines:
        stripped_line = line.strip()
        if stripped_line:
            cleaned_lines.append(line.rstrip())

    cleaned_code = '\n'.join(cleaned_lines)

    if cleaned_code and not cleaned_code.strip().endswith('endmodule'):
        last_endmodule = cleaned_code.rfind('endmodule')
        if last_endmodule != -1:
            cleaned_code = cleaned_code[:last_endmodule + len('endmodule')]

    testbench_pattern = re.compile(
        r'module\s+\w*testbench\w*\s*;.*?endmodule',
        re.DOTALL | re.IGNORECASE
    )

    all_modules_pattern = re.compile(r'module\s+.*?endmodule', re.DOTALL)
    all_modules = all_modules_pattern.findall(cleaned_code)

    if len(all_modules) > 1 and testbench_pattern.search(cleaned_code):
        cleaned_code = testbench_pattern.sub('', cleaned_code)
        cleaned_code = re.sub(r'\n{3,}', '\n\n', cleaned_code).strip()

    return cleaned_code


if __name__ == '__main__':
    cot_base = '/nfs_global/projects/cvdp_benchmark/results/qwen3_8b_10epochs/cot'
    test_base = '/nfs_global/projects/cvdp_benchmark/results/experiment_qwen_3_8b_10epochs_tool'
    # 示例：你可以在此调整任务列表
    tasks = ['prim_max_0001', 'swizzler_0014']

    for task in tasks:
        task = task.split('_')
        task, num = '_'.join(task[:-1]), int(task[-1])
        for i in range(1, 2):
            cot_path = f'{cot_base}/cvdp_copilot_{task}_{num:04}'
            test_path = f'{test_base}/sample_{i}/cvdp_copilot_{task}/harness/{num}'
            print(cot_path)
            print(test_path)

            with open(f'{cot_path}/t{i}.v', 'r') as f:
                generation = f.read().strip()

            all_verilog_codes = extract_verilog_from_generation(generation)
            cleaned_codes = [clean_verilog_code(code) for code in all_verilog_codes if clean_verilog_code(code)]

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

