#!/usr/bin/env python3
import re
import json
import argparse


def _parse_tool_call_json(json_str):
    """从<tool_call> JSON文本中解析出 arguments.code，兼容两种结构。
    
    如果 JSON 不完整或被截断，尝试用正则表达式直接提取 code 字段的内容。
    """
    # 首先尝试正常解析 JSON
    try:
        data = json.loads(json_str)
        # 新格式：{"name": "verilog_simulator", "arguments": {"code": "..."}}
        if isinstance(data, dict) and 'arguments' in data and isinstance(data['arguments'], dict):
            code = data['arguments'].get('code')
            if isinstance(code, str):
                return code
        # 旧格式：{"function": {"arguments": "{\"code\": \"...\"}"}}
        if isinstance(data, dict) and 'function' in data and isinstance(data['function'], dict):
            args = data['function'].get('arguments')
            if isinstance(args, str):
                inner = json.loads(args)
                code = inner.get('code')
                if isinstance(code, str):
                    return code
    except Exception:
        pass
    
    # 如果 JSON 解析失败（可能是被截断），尝试用正则表达式提取
    # 查找 "code": "..." 的模式，需要处理多行字符串和转义字符
    # 策略：找到 "code": "，然后匹配到最后一个可能的结束引号（可能被截断）
    
    # 首先尝试匹配完整的 JSON 字符串（包括转义字符）
    code_match = re.search(r'"code"\s*:\s*"', json_str, re.DOTALL)
    if code_match:
        start_pos = code_match.end()
        # 从开始位置开始，查找最后一个可能的结束引号
        # 但要注意：如果字符串被截断，可能没有结束引号
        code_content = json_str[start_pos:]
        
        # 尝试找到结束引号（考虑转义）
        end_pos = None
        i = 0
        while i < len(code_content):
            if code_content[i] == '\\':
                i += 2  # 跳过转义字符
                continue
            elif code_content[i] == '"':
                # 检查后面是否还有内容（可能是嵌套的 JSON）
                # 如果后面紧跟 }, 或 }，说明这是结束引号
                remaining = code_content[i+1:].strip()
                if remaining.startswith('}') or remaining.startswith(',') or not remaining:
                    end_pos = i
                    break
            i += 1
        
        if end_pos is not None:
            code = code_content[:end_pos]
        else:
            # 没有找到结束引号，说明可能被截断了，使用全部内容
            code = code_content
        
        # 处理转义字符
        if code:
            code = code.replace('\\"', '"').replace('\\n', '\n').replace('\\t', '\t').replace('\\r', '\r')
            if 'module' in code.lower():
                return code
    
    return None


def remove_testbench(code):
    """移除代码中的所有 testbench 模块。"""
    if not code:
        return code
    
    # 匹配 testbench 模块（包括名称中包含 testbench 的）
    # 使用更宽松的匹配，处理可能不完整的模块
    testbench_pattern = re.compile(
        r'module\s+\w*testbench\w*\s*[^;]*?;[\s\S]*?endmodule',
        re.DOTALL | re.IGNORECASE
    )
    
    # 移除所有 testbench 模块
    cleaned_code = testbench_pattern.sub('', code)
    
    # 如果模块被截断（没有 endmodule），尝试匹配到文件末尾
    incomplete_testbench_pattern = re.compile(
        r'module\s+\w*testbench\w*\s*[^;]*?;[\s\S]*$',
        re.DOTALL | re.IGNORECASE
    )
    cleaned_code = incomplete_testbench_pattern.sub('', cleaned_code)
    
    # 清理多余的空行
    cleaned_code = re.sub(r'\n{3,}', '\n\n', cleaned_code).strip()
    
    return cleaned_code


def is_complete_verilog_code(code):
    """检查 Verilog 代码是否完整（包含完整的 module...endmodule）。"""
    if not code or 'module' not in code.lower():
        return False
    
    # 检查是否有 endmodule
    if 'endmodule' not in code.lower():
        return False
    
    # 检查最后一个 endmodule 后面是否还有 module（说明可能不完整）
    # 但要排除注释中的 module
    endmodule_pos = code.lower().rfind('endmodule')
    remaining = code[endmodule_pos + len('endmodule'):].strip()
    
    # 检查 remaining 中是否有 module（排除注释）
    if remaining:
        # 逐行检查，排除注释部分
        remaining_lines = remaining.split('\n')
        for line in remaining_lines:
            comment_pos = line.find('//')
            if comment_pos != -1:
                line_code = line[:comment_pos]
            else:
                line_code = line
            
            # 检查非注释部分是否有 module
            if re.search(r'\bmodule\s+', line_code, re.IGNORECASE):
                return False
    
    # 查找所有 module 和 endmodule，但排除注释中的
    module_matches = []
    endmodule_matches = []
    
    lines = code.split('\n')
    current_pos = 0
    
    for line in lines:
        line_lower = line.lower()
        
        # 检查是否在单行注释中（跳过注释部分）
        comment_pos = line.find('//')
        if comment_pos != -1:
            line_code = line[:comment_pos]
        else:
            line_code = line
        
        # 在非注释部分查找 module
        # 使用 \bmodule\s+ 确保匹配独立的 module 关键字
        for match in re.finditer(r'\bmodule\s+', line_code, re.IGNORECASE):
            module_matches.append(current_pos + match.start())
        
        # 查找 endmodule（也在非注释部分）
        for match in re.finditer(r'\bendmodule\b', line_code, re.IGNORECASE):
            endmodule_matches.append(current_pos + match.start())
        
        current_pos += len(line) + 1  # +1 for newline
    
    if len(module_matches) > len(endmodule_matches):
        # module 数量多于 endmodule，说明可能不完整
        return False
    
    # 确保至少有一个完整的 module...endmodule 对
    if len(module_matches) == 0 or len(endmodule_matches) == 0:
        return False
    
    # 确保最后一个 module 在最后一个 endmodule 之前
    if module_matches[-1] >= endmodule_matches[-1]:
        return False
    
    return True


def extract_from_answer_block(text):
    """从最后一个 <answer> 块中提取完整的 Verilog 代码块。
    
    优先检查最后一个 answer 块中是否有完整的 ```verilog ...``` 代码块。
    如果最后一个 answer 块中的代码被截断，会往前查找其他 answer 块中的完整代码。
    """
    if not text:
        return None
    
    # 找到所有 <answer> 块
    answer_pattern = r'<answer>([\s\S]*?)</answer>'
    answer_matches = list(re.finditer(answer_pattern, text, re.IGNORECASE | re.DOTALL))
    if not answer_matches:
        return None
    
    # 在所有 answer 块中查找 Verilog 代码块（支持 verilog 和 systemverilog）
    verilog_patterns = [
        r'```verilog\s*([\s\S]*?)```',
        r'```systemverilog\s*([\s\S]*?)```',
        r'```\s*(module\s+[\s\S]*?endmodule)```',  # 兜底：任何包含 module...endmodule 的代码块
    ]
    
    # 优先检查最后一个 answer 块
    last_answer_match = answer_matches[-1]
    last_answer_content = last_answer_match.group(1)
    
    # 在最后一个 answer 块中查找 Verilog 代码块
    for pattern in verilog_patterns:
        matches = list(re.finditer(pattern, last_answer_content, re.IGNORECASE | re.DOTALL))
        # 从最后一个代码块开始检查（最靠后的）
        for match in reversed(matches):
            code = match.group(1).strip()
            # 检查是否完整
            if is_complete_verilog_code(code):
                return code
    
    # 如果最后一个 answer 块中没有完整代码，往前查找其他 answer 块
    # 收集所有完整的代码块，记录位置（answer 块的位置 + 代码块在 answer 块中的位置）
    all_candidates = []  # (total_pos, code)
    
    for answer_match in answer_matches:
        answer_content = answer_match.group(1)
        answer_start_pos = answer_match.start()
        
        for pattern in verilog_patterns:
            matches = list(re.finditer(pattern, answer_content, re.IGNORECASE | re.DOTALL))
            for match in matches:
                code = match.group(1).strip()
                # 检查是否完整
                if is_complete_verilog_code(code):
                    # 计算代码在整个文本中的位置
                    code_pos_in_answer = match.end()
                    total_pos = answer_start_pos + code_pos_in_answer
                    all_candidates.append((total_pos, code))
    
    if all_candidates:
        # 按位置排序，返回最后一个（最靠后的完整代码）
        all_candidates.sort(key=lambda x: x[0], reverse=True)
        return all_candidates[0][1]
    
    return None


def extract_from_tool_call(text):
    """从最后一个完整的 <tool_call> 块中提取完整的 Verilog 代码。
    
    只查找完整的 tool_call 块（有结束标签），并确保提取的代码是完整的。
    如果最后一个不完整，会往前查找。
    如果所有完整的 tool_call 都没有完整代码，也会检查最后一个不完整的 tool_call。
    """
    if not text:
        return None
    
    # 找到所有完整的 <tool_call> 块
    tool_call_pattern = r'<tool_call>\s*([\s\S]*?)</tool_call>'
    tool_call_matches = list(re.finditer(tool_call_pattern, text, re.IGNORECASE | re.DOTALL))
    
    # 从最后一个 tool_call 开始向前查找完整的代码
    if tool_call_matches:
        for match in reversed(tool_call_matches):
            json_str = match.group(1).strip()
            code = _parse_tool_call_json(json_str)
            
            if code and 'module' in code.lower():
                # 先移除 testbench 模块，然后再检查完整性
                code_without_tb = remove_testbench(code)
                
                # 如果移除 testbench 后还有代码，检查是否完整
                if code_without_tb and code_without_tb.strip():
                    # 检查代码是否完整（移除 testbench 后检查）
                    if is_complete_verilog_code(code_without_tb):
                        return code_without_tb.strip()
    
    # 如果没有找到完整的 tool_call 中有完整代码，尝试查找最后一个不完整的 tool_call（被截断）
    incomplete_tool_call_pattern = r'<tool_call>\s*([\s\S]*?)$'
    incomplete_match = re.search(incomplete_tool_call_pattern, text, re.IGNORECASE | re.DOTALL)
    if incomplete_match:
        json_str = incomplete_match.group(1).strip()
        code = _parse_tool_call_json(json_str)
        
        if code and 'module' in code.lower():
            # 先移除 testbench 模块，然后再检查完整性
            code_without_tb = remove_testbench(code)
            
            # 如果移除 testbench 后还有代码，检查是否完整
            if code_without_tb and code_without_tb.strip():
                # 检查代码是否完整（移除 testbench 后检查）
                if is_complete_verilog_code(code_without_tb):
                    return code_without_tb.strip()
    
    return None


def extract_verilog_from_generation(generation_text):
    """提取单个文本中的最后一个完整的 Verilog 代码块。
    
    策略：
    1. 优先从所有 <answer> 块中提取最后一个完整的 Verilog 代码
       - 如果最后一个 answer 块中的代码被截断，会往前查找其他 answer 块中的完整代码
    2. 如果 answer 块中没有完整的代码，从最后一个完整的 <tool_call> 块中提取
       - 如果最后一个 tool_call 中的代码不完整，会往前查找其他完整的 tool_call 块
       - 自动移除 testbench 模块
    3. 确保总是返回完整的代码（包含完整的 module...endmodule）
    """
    if not generation_text:
        return None
    
    # 策略 1: 优先从所有 <answer> 块中提取完整的代码
    code = extract_from_answer_block(generation_text)
    if code:
        # 移除 testbench（虽然 answer 块中通常不会有，但为了保险）
        code = remove_testbench(code)
        if code and code.strip() and is_complete_verilog_code(code):
            return code.strip()
    
    # 策略 2: 从完整的 <tool_call> 块中提取（会自动移除 testbench 并检查完整性）
    code = extract_from_tool_call(generation_text)
    if code:
        return code
    
    return None


def clean_verilog_code(verilog_code):
    """清理 Verilog 代码：移除多余空行，确保以 endmodule 结尾。"""
    if not verilog_code:
        return None
    
    # 移除前后空白
    verilog_code = verilog_code.strip()
    
    if not verilog_code:
        return None
    
    # 首先移除 testbench（如果存在）
    verilog_code = remove_testbench(verilog_code)
    
    if not verilog_code.strip():
        return None
    
    # 确保代码以 endmodule 结尾（如果被截断）
    if 'endmodule' not in verilog_code.lower():
        # 如果没有 endmodule，尝试找到最后一个完整的 module...endmodule
        module_matches = list(re.finditer(r'(module\s+[\s\S]*?endmodule)', verilog_code, re.IGNORECASE | re.DOTALL))
        if module_matches:
            # 返回最后一个完整的模块
            verilog_code = module_matches[-1].group(1)
        else:
            # 如果连完整的模块都没有，尝试找到最后一个 module 开始的位置
            # 并保留从那里到文件末尾的内容（可能是不完整的模块）
            last_module_match = list(re.finditer(r'module\s+', verilog_code, re.IGNORECASE))
            if last_module_match:
                # 保留最后一个 module 开始后的所有内容
                last_module_pos = last_module_match[-1].start()
                verilog_code = verilog_code[last_module_pos:]
            else:
                # 如果连 module 都没有，返回 None
                return None
    else:
        # 如果有 endmodule，找到最后一个 endmodule 的位置
        last_endmodule_pos = verilog_code.lower().rfind('endmodule')
        if last_endmodule_pos != -1:
            # 检查最后一个 endmodule 后面是否还有内容
            remaining = verilog_code[last_endmodule_pos + len('endmodule'):].strip()
            if remaining:
                # 如果后面还有内容，检查是否有新的 module 开始
                if 'module' not in remaining.lower():
                    # 如果没有新的 module，截断到最后一个 endmodule
                    verilog_code = verilog_code[:last_endmodule_pos + len('endmodule')]
            else:
                # 如果后面没有内容，直接截断到最后一个 endmodule
                verilog_code = verilog_code[:last_endmodule_pos + len('endmodule')]
    
    # 清理多余的空行
    lines = verilog_code.split('\n')
    cleaned_lines = []
    prev_empty = False
    for line in lines:
        stripped = line.rstrip()
        if stripped:
            cleaned_lines.append(stripped)
            prev_empty = False
        else:
            # 只在不是连续空行时添加一个空行
            if not prev_empty:
                cleaned_lines.append('')
                prev_empty = True
    
    cleaned_code = '\n'.join(cleaned_lines).strip()
    
    # 如果移除后为空，返回 None
    if not cleaned_code.strip():
        return None
    
    return cleaned_code


def process_jsonl(in_path, out_path):
    """处理 JSONL 文件，提取 Verilog 代码。
    
    支持两种数据格式：
    1. 旧格式：包含 'responses' 字段（字符串数组）
    2. 新格式：包含 'generation' 字段（字符串），其中可能包含 <tool_call> 和 <answer> 标签
    """
    with open(in_path, 'r', encoding='utf-8') as fin, open(out_path, 'w', encoding='utf-8') as fout:
        for line in fin:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except Exception:
                continue

            task_id = item.get('task_id') or item.get('id')
            completion = ""

            # 策略 1: 优先从 generation 字段中提取（新格式）
            generation = item.get('generation')
            if isinstance(generation, str) and generation.strip():
                code = extract_verilog_from_generation(generation)
                cleaned = clean_verilog_code(code)
                if cleaned:
                    completion = cleaned

            # 策略 2: 如果 generation 中没有，尝试从 responses 中提取（旧格式兼容）
            if not completion:
                responses = item.get('responses') or []
                # 从 responses 的最后一个开始向前，找到最后一个能提取到 Verilog 的文本
                for resp in reversed(responses):
                    if isinstance(resp, str):
                        code = extract_verilog_from_generation(resp)
                        cleaned = clean_verilog_code(code)
                        if cleaned:
                            completion = cleaned
                            break

            out_obj = {
                "id": task_id,
                "completion": completion
            }
            fout.write(json.dumps(out_obj, ensure_ascii=False) + "\n")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='从 origin_results.jsonl 提取最后一个 Verilog 代码，输出为 id/completion JSONL'
    )
    parser.add_argument(
        '--in_path', 
        type=str, 
        required=True, 
        help='输入 JSONL 文件路径（如 origin_results.jsonl）'
    )
    parser.add_argument(
        '--out_path', 
        type=str, 
        required=True, 
        help='输出 JSONL 文件路径（如 answer_to_import.jsonl 样式）'
    )
    args = parser.parse_args()
    process_jsonl(args.in_path, args.out_path)