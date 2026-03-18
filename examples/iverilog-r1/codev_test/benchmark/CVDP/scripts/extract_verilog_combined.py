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


def extract_module_from_code_block(code_block):
    """从代码块中提取第一个 module 到最后一个 endmodule 之间的内容。
    
    返回从第一个 module 到最后一个 endmodule 的内容（包括这两个词），
    如果找不到完整的 module...endmodule，返回 None。
    """
    if not code_block:
        return None
    
    # 查找第一个 module（排除注释中的）
    first_module_pos = None
    lines = code_block.split('\n')
    current_pos = 0
    
    for line in lines:
        # 检查是否在单行注释中
        comment_pos = line.find('//')
        if comment_pos != -1:
            line_code = line[:comment_pos]
        else:
            line_code = line
        
        # 在非注释部分查找 module
        module_match = re.search(r'\bmodule\s+', line_code, re.IGNORECASE)
        if module_match:
            first_module_pos = current_pos + line.find(module_match.group(0))
            break
        
        current_pos += len(line) + 1  # +1 for newline
    
    if first_module_pos is None:
        return None
    
    # 查找最后一个 endmodule（排除注释中的）
    last_endmodule_pos = None
    
    # 计算每行的起始位置
    line_starts = [0]
    for i in range(len(lines)):
        line_starts.append(line_starts[i] + len(lines[i]) + 1)  # +1 for newline
    
    for i in range(len(lines) - 1, -1, -1):  # 从后往前查找
        line = lines[i]
        # 检查是否在单行注释中
        comment_pos = line.find('//')
        if comment_pos != -1:
            line_code = line[:comment_pos]
        else:
            line_code = line
        
        # 在非注释部分查找 endmodule
        endmodule_match = re.search(r'\bendmodule\b', line_code, re.IGNORECASE)
        if endmodule_match:
            # 计算在整个代码块中的位置
            line_start = line_starts[i]
            match_start_in_line = line.find(endmodule_match.group(0))
            last_endmodule_pos = line_start + match_start_in_line + len('endmodule')
            break
    
    if last_endmodule_pos is None:
        return None
    
    # 确保 endmodule 在 module 之后
    if last_endmodule_pos <= first_module_pos:
        return None
    
    # 提取从第一个 module 到最后一个 endmodule 的内容
    extracted = code_block[first_module_pos:last_endmodule_pos]
    return extracted.strip() if extracted.strip() else None


def extract_verilog_from_generation(generation_text):
    """提取单个文本中的最后一个 Verilog 代码块。
    
    策略：
    1. 提取所有 ``` ... ``` 代码块（不限制语言标识），然后从中提取 module...endmodule
    2. 提取所有 <tool_call>...</tool_call> 中的 JSON 内容并解析出代码
    3. 按位置排序，取最后一个（两种pattern合在一起的最后一个）
    4. 如果最后一个来自 tool_call，则去除 testbench
    """
    if not generation_text:
        return None
    
    all_candidates = []  # (position, code, is_from_tool_call)
    
    # 1. 提取所有 ``` ... ``` 代码块（不限制语言标识）
    # 匹配 ``` 后面可能有语言标识（如 verilog, systemverilog 等）或没有
    code_block_pattern = r'```[^\n]*\n?([\s\S]*?)```'
    code_block_matches = list(re.finditer(code_block_pattern, generation_text, re.IGNORECASE | re.DOTALL))
    
    for match in code_block_matches:
        code_block = match.group(1).strip()
        # 从代码块中提取第一个 module 到最后一个 endmodule
        extracted_code = extract_module_from_code_block(code_block)
        if extracted_code:
            # 记录位置（使用结束位置）
            position = match.end()
            all_candidates.append((position, extracted_code, False))
    
    # 2. 提取所有 tool_call/tools 块中的 JSON 内容
    # 支持所有可能的标签组合：
    # - <tool_call>...JSON...</tool_call>
    # - <tools>...JSON...</tool_call>
    # - <tool_call>...JSON...</tools>
    # - <tools>...JSON...</tools>
    # - </tools>...JSON...</tool_call> (没有开始标签)
    
    # 2a. 处理有开始和结束标签的完整块
    tool_patterns = [
        (r'<tool_call>\s*([\s\S]*?)</tool_call>', 'tool_call-tool_call'),
        (r'<tools>\s*([\s\S]*?)</tool_call>', 'tools-tool_call'),
        (r'<tool_call>\s*([\s\S]*?)</tools>', 'tool_call-tools'),
        (r'<tools>\s*([\s\S]*?)</tools>', 'tools-tools'),
    ]
    
    for pattern, desc in tool_patterns:
        matches = list(re.finditer(pattern, generation_text, re.IGNORECASE | re.DOTALL))
        for match in matches:
            json_str = match.group(1).strip()
            code = _parse_tool_call_json(json_str)
            if code and 'module' in code.lower():
                # 记录位置（使用结束位置）
                position = match.end()
                all_candidates.append((position, code, True))
    
    # 2b. 处理没有开始标签的格式：</tools>...JSON...</tool_call>
    # 或者直接查找 </tool_call> 或 </tools> 前面的 JSON 内容
    end_patterns = [r'</tool_call>', r'</tools>']
    
    for end_pattern in end_patterns:
        end_matches = list(re.finditer(end_pattern, generation_text, re.IGNORECASE))
        
        for match in end_matches:
            # 从结束标签向前查找 JSON 内容
            end_pos = match.start()
            # 向前查找，找到 JSON 的开始
            search_start = max(0, end_pos - 10000)  # 最多向前查找 10000 字符
            search_text = generation_text[search_start:end_pos]
            
            # 查找可能的开始标签位置
            start_tags = ['</tools>', '<tool_call>', '<tools>']
            json_start_offset = None
            
            # 首先尝试查找开始标签
            for start_tag in start_tags:
                tag_pos = search_text.rfind(start_tag)
                if tag_pos >= 0:
                    # 从标签后面开始查找 JSON（跳过可能的换行和空白）
                    json_start_in_search = tag_pos + len(start_tag)
                    # 跳过空白字符
                    while json_start_in_search < len(search_text) and search_text[json_start_in_search] in ' \n\r\t':
                        json_start_in_search += 1
                    json_start_offset = json_start_in_search
                    break
            
            # 如果没有找到开始标签，查找最后一个 {，这应该是 JSON 的开始
            if json_start_offset is None:
                last_brace = search_text.rfind('{')
                if last_brace >= 0:
                    json_start_offset = last_brace
            
            if json_start_offset is not None:
                json_candidate = search_text[json_start_offset:]
                # 尝试解析 JSON
                try:
                    # 先尝试直接解析
                    parsed = json.loads(json_candidate.strip())
                    if isinstance(parsed, dict) and 'arguments' in parsed:
                        code = _parse_tool_call_json(json_candidate.strip())
                        if code and 'module' in code.lower():
                            position = match.end()
                            all_candidates.append((position, code, True))
                            continue
                except Exception:
                    pass
                
                # 如果解析失败，使用原来的 _parse_tool_call_json 函数
                code = _parse_tool_call_json(json_candidate.strip())
                if code and 'module' in code.lower():
                    position = match.end()
                    all_candidates.append((position, code, True))
    
    # 3. 如果没有找到完整的 tool_call，尝试查找最后一个不完整的 tool_call（被截断）
    # 查找以 <tool_call> 或 <tools> 开始但没有结束标签的
    incomplete_patterns = [
        r'<tool_call>\s*([\s\S]*?)$',
        r'<tools>\s*([\s\S]*?)$',
    ]
    
    for pattern in incomplete_patterns:
        incomplete_match = re.search(pattern, generation_text, re.IGNORECASE | re.DOTALL)
        if incomplete_match:
            json_str = incomplete_match.group(1).strip()
            code = _parse_tool_call_json(json_str)
            if code and 'module' in code.lower():
                # 记录位置（使用结束位置）
                position = incomplete_match.end()
                all_candidates.append((position, code, True))
    
    # 4. 按位置排序，取最后一个
    if not all_candidates:
        return None
    
    all_candidates.sort(key=lambda x: x[0])
    last_position, last_code, is_from_tool_call = all_candidates[-1]
    
    # 5. 如果最后一个来自 tool_call，则去除 testbench
    if is_from_tool_call:
        last_code = remove_testbench(last_code)
    
    # 检查代码是否完整
    if last_code and last_code.strip() and is_complete_verilog_code(last_code):
        return last_code.strip()
    
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
    """处理 JSONL 文件，提取 Verilog 代码。"""
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
            responses = item.get('responses') or item.get('generation') or []

            completion = ""
            # 从 responses 的最后一个开始向前，找到最后一个能提取到 Verilog 的文本
            for resp in reversed(responses):
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
        description='从 origin_results.jsonl 提取最后一个 Verilog 代码（合并 verilog 代码块和 tool_call），输出为 id/completion JSONL'
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

