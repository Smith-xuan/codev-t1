"""
Verilog Code Extraction Utilities

This module provides functions for extracting and cleaning Verilog code from generation text.
Adapted from verl/utils/reward_score/codev_multiturn_tool.py
"""

import re
import logging
from typing import Optional, List, Dict, Any

logger = logging.getLogger(__name__)

# Fix siliconcompiler compatibility: Chip was renamed to Design in v0.35.0
# This must be done BEFORE importing eda_tools, as eda_tools imports Chip immediately
try:
    import siliconcompiler
    if not hasattr(siliconcompiler, 'Chip') and hasattr(siliconcompiler, 'Design'):
        siliconcompiler.Chip = siliconcompiler.Design
        logger.debug("Created compatibility alias: siliconcompiler.Chip = siliconcompiler.Design")
except ImportError:
    # siliconcompiler not available, will fail later when importing eda_tools
    pass

# Import eda_tools for verification
try:
    from eda_tools.core import verify_one_sample, run_function_with_timeout
except ImportError as e:
    logger.warning(f"eda_tools not found. Verification functions will not be available. Error: {e}")
    verify_one_sample = None
    run_function_with_timeout = None
except Exception as e:
    logger.warning(f"Error importing eda_tools: {e}. Verification functions will not be available.")
    import traceback
    logger.debug(traceback.format_exc())
    verify_one_sample = None
    run_function_with_timeout = None


def _parse_tool_call_json(json_str: str, keep_testbench: bool = True) -> Optional[str]:
    """Parse tool_call JSON text and extract arguments.code (verilog).
    
    Note: This function always returns the complete code including testbench.
    The keep_testbench parameter is for interface consistency but doesn't affect behavior
    since this function only extracts code from JSON, it doesn't remove testbench.
    """
    import json

    # 1) try normal JSON parsing first
    try:
        data = json.loads(json_str)
        # new format: {"name": "...", "arguments": {"code": "..."}}
        if isinstance(data, dict) and "arguments" in data and isinstance(data["arguments"], dict):
            code = data["arguments"].get("code")
            if isinstance(code, str):
                return code
        # old format: {"function": {"arguments": "{\"code\": \"...\"}"}}
        if isinstance(data, dict) and "function" in data and isinstance(data["function"], dict):
            args = data["function"].get("arguments")
            if isinstance(args, str):
                try:
                    inner = json.loads(args)
                    code = inner.get("code")
                    if isinstance(code, str):
                        return code
                except Exception:
                    # Fallback: try to extract from string literal
                    code_match = re.search(r'"code"\s*:\s*"([^"]*)"', args, re.DOTALL)
                    if code_match:
                        code = code_match.group(1)
                        # Handle escape sequences
                        code = code.replace(r"\"", '"').replace(r"\n", "\n").replace(r"\t", "\t")
                        if "module" in code.lower():
                            return code
    except Exception:
        pass

    # 2) fallback: regex search for `"code": "..."` in possibly truncated JSON
    code_match = re.search(r'(?:\\?"code"\\?)\s*:\s*\\?"', json_str, re.DOTALL)
    if not code_match:
        return None

    start_pos = code_match.end()
    code_content = json_str[start_pos:]

    end_pos = None
    i = 0
    while i < len(code_content):
        if code_content[i] == "\\":
            i += 2
            continue
        if code_content[i] == '"':
            remaining = code_content[i + 1 :].strip()
            if not remaining or remaining.startswith("}") or remaining.startswith(","):
                end_pos = i
                break
        i += 1

    if end_pos is not None:
        code = code_content[:end_pos]
    else:
        # no closing quote – treat rest as body
        code = code_content

    code = code.replace(r"\"", '"').replace(r"\n", "\n").replace(r"\t", "\t").replace(r"\r", "\r")
    if "module" in code.lower():
        return code
    return None


def remove_testbench(code: Optional[str]) -> Optional[str]:
    """Remove any testbench modules from the verilog code."""
    if not code:
        return code

    # strict-ish testbench module pattern
    testbench_pattern = re.compile(
        r"module\s+\w*testbench\w*\s*[^;]*?;[\s\S]*?endmodule",
        re.DOTALL | re.IGNORECASE,
    )
    cleaned_code = testbench_pattern.sub("", code)

    # if module is truncated (no endmodule), strip until file end
    incomplete_testbench_pattern = re.compile(
        r"module\s+\w*testbench\w*\s*[^;]*?;[\s\S]*$",
        re.DOTALL | re.IGNORECASE,
    )
    cleaned_code = incomplete_testbench_pattern.sub("", cleaned_code)
    cleaned_code = re.sub(r"\n{3,}", "\n\n", cleaned_code).strip()
    return cleaned_code


def is_complete_verilog_code(code: Optional[str]) -> bool:
    """Check whether verilog code looks complete (at least one module...endmodule)."""
    if not code or "module" not in code.lower():
        return False
    if "endmodule" not in code.lower():
        return False

    # strip comments first
    code_without_comments = re.sub(r"/\*[\s\S]*?\*/", "", code)  # /* ... */
    lines = code_without_comments.split("\n")
    code_without_comments = "\n".join([line.split("//")[0] for line in lines])  # //

    endmodule_pos = code_without_comments.lower().rfind("endmodule")
    if endmodule_pos == -1:
        return False

    remaining = code_without_comments[endmodule_pos + len("endmodule") :].strip()
    if remaining and re.search(r"\bmodule\s+", remaining, re.IGNORECASE):
        return False

    module_matches = list(re.finditer(r"\bmodule\s+", code_without_comments, re.IGNORECASE))
    endmodule_matches = list(re.finditer(r"\bendmodule\b", code_without_comments, re.IGNORECASE))
    if not module_matches or not endmodule_matches:
        return False
    if len(module_matches) > len(endmodule_matches):
        return False
    if module_matches[-1].start() >= endmodule_matches[-1].start():
        return False
    return True


def extract_from_answer_block(text: str) -> Optional[str]:
    """Extract the last *complete* verilog block from all <answer> ... </answer> segments."""
    if not text:
        return None

    answer_pattern = r"<answer>([\s\S]*?)</answer>"
    answer_matches = list(re.finditer(answer_pattern, text, re.IGNORECASE | re.DOTALL))

    if not answer_matches:
        # try incomplete <answer> ... (truncated at end)
        incomplete_pattern = r"<answer>([\s\S]*?)$"
        incomplete_matches = list(re.finditer(incomplete_pattern, text, re.IGNORECASE | re.DOTALL))
        if incomplete_matches:
            answer_matches = incomplete_matches

    if not answer_matches:
        return None

    verilog_patterns = [
        r"```verilog\s*([\s\S]*?)```",
        r"```systemverilog\s*([\s\S]*?)```",
        r"```\s*(module\s+[\s\S]*?endmodule)```",
    ]

    candidates: list[tuple[int, str]] = []
    for answer_match in answer_matches:
        answer_content = answer_match.group(1)
        answer_start_pos = answer_match.start()
        for pattern in verilog_patterns:
            matches = list(re.finditer(pattern, answer_content, re.IGNORECASE | re.DOTALL))
            for match in matches:
                code = match.group(1).strip()
                if is_complete_verilog_code(code):
                    code_pos_in_answer = match.end()
                    total_pos = answer_start_pos + code_pos_in_answer
                    candidates.append((total_pos, code))

    if not candidates:
        return None

    candidates.sort(key=lambda x: x[0], reverse=True)
    return candidates[0][1]


def extract_from_tool_call(text: str, require_complete: bool = True, keep_testbench: bool = False) -> Optional[str]:
    """Extract verilog code from the last valid <tool_call> ... </tool_call>.
    
    Args:
        text: Input text containing tool calls
        require_complete: If True, only return code that passes is_complete_verilog_code check.
                         If False, return code as long as it contains 'module' keyword.
        keep_testbench: If True, keep testbench in the extracted code (for tool execution).
                       If False, remove testbench (for reward calculation).
    """
    if not text:
        return None

    tool_call_pattern = r"<tool_call>\s*([\s\S]*?)</tool_call>"
    tool_call_matches = list(re.finditer(tool_call_pattern, text, re.IGNORECASE | re.DOTALL))

    if tool_call_matches:
        for match in reversed(tool_call_matches):
            json_str = match.group(1).strip()
            code = _parse_tool_call_json(json_str, keep_testbench=True)  # Always parse with testbench first
            if code and "module" in code.lower():
                if keep_testbench:
                    # For tool execution: keep testbench, but still check completeness if required
                    if not require_complete or is_complete_verilog_code(code):
                        return code.strip()
                else:
                    # For reward calculation: remove testbench
                    code_without_tb = remove_testbench(code)
                    if code_without_tb and code_without_tb.strip():
                        if not require_complete or is_complete_verilog_code(code_without_tb):
                            return code_without_tb.strip()

    # fallback: possibly truncated last <tool_call>
    incomplete_tool_call_pattern = r"<tool_call>\s*([\s\S]*?)$"
    incomplete_match = re.search(incomplete_tool_call_pattern, text, re.IGNORECASE | re.DOTALL)
    if incomplete_match:
        json_str = incomplete_match.group(1).strip()
        code = _parse_tool_call_json(json_str, keep_testbench=True)  # Always parse with testbench first
        if code and "module" in code.lower():
            if keep_testbench:
                # For tool execution: keep testbench
                if not require_complete or is_complete_verilog_code(code):
                    return code.strip()
            else:
                # For reward calculation: remove testbench
                code_without_tb = remove_testbench(code)
                if code_without_tb and code_without_tb.strip():
                    if not require_complete or is_complete_verilog_code(code_without_tb):
                        return code_without_tb.strip()

    return None


def extract_verilog_from_generation(generation_text: str, require_complete: bool = True, keep_testbench: bool = False) -> Optional[str]:
    """High-level extractor: prefer <answer> blocks, then <tool_call> blocks.
    
    Args:
        generation_text: Input text containing generation output
        require_complete: If True, only return code that passes is_complete_verilog_code check.
                         If False, return code as long as it contains 'module' keyword.
        keep_testbench: If True, keep testbench in the extracted code (for tool execution).
                       If False, remove testbench (for reward calculation).
    """
    if not generation_text:
        return None

    # 1) try <answer> blocks first
    code = extract_from_answer_block(generation_text)
    if code:
        if not keep_testbench:
            code = remove_testbench(code)
        if code and code.strip():
            # For answer blocks, we still require complete code
            if is_complete_verilog_code(code):
                return code.strip()

    # 2) fall back to <tool_call> blocks
    code = extract_from_tool_call(generation_text, require_complete=require_complete, keep_testbench=keep_testbench)
    if code:
        return code

    return None


def clean_verilog_code(verilog_code: Optional[str]) -> Optional[str]:
    """Clean verilog code: remove testbench, trim to last complete module, normalize blank lines."""
    if not verilog_code:
        return None

    verilog_code = verilog_code.strip()
    if not verilog_code:
        return None

    verilog_code = remove_testbench(verilog_code)
    if not verilog_code or not verilog_code.strip():
        return None

    if "endmodule" not in verilog_code.lower():
        module_matches = list(re.finditer(r"(module\s+[\s\S]*?endmodule)", verilog_code, re.IGNORECASE | re.DOTALL))
        if module_matches:
            verilog_code = module_matches[-1].group(1)
        else:
            last_module_match = list(re.finditer(r"module\s+", verilog_code, re.IGNORECASE))
            if last_module_match:
                last_module_pos = last_module_match[-1].start()
                verilog_code = verilog_code[last_module_pos:]
            else:
                return None
    else:
        last_endmodule_pos = verilog_code.lower().rfind("endmodule")
        if last_endmodule_pos != -1:
            remaining = verilog_code[last_endmodule_pos + len("endmodule") :].strip()
            if remaining and "module" not in remaining.lower():
                verilog_code = verilog_code[: last_endmodule_pos + len("endmodule")]

    lines = verilog_code.split("\n")
    cleaned_lines: list[str] = []
    prev_empty = False
    for line in lines:
        stripped = line.rstrip()
        if stripped:
            cleaned_lines.append(stripped)
            prev_empty = False
        else:
            if not prev_empty:
                cleaned_lines.append("")
                prev_empty = True

    cleaned_code = "\n".join(cleaned_lines).strip()
    if not cleaned_code.strip():
        return None
    return cleaned_code


def _format_ok(generation_text: str) -> bool:
    """Loose format check for multi-turn tool calls.

    Requirements (relaxed, to be robust under truncation):
      - At least one <tool_call> ... </tool_call> before the final answer, OR
        generation contains a valid verilog code we can extract.
      - The text may contain multiple <think>, <answer>, <tool_call>, <tool_response> blocks.
      - If truncated, as long as there exists a prefix from which we can
        extract a complete verilog module, we accept the format.
      - If we can't extract from <answer>, we automatically try to extract from the last <tool_call>.
    """
    if not generation_text:
        return False

    # Try to extract complete verilog code (prefer <answer>, then <tool_call>)
    code = extract_verilog_from_generation(generation_text, require_complete=True, keep_testbench=False)
    if code and is_complete_verilog_code(code):
        return True

    return False


def _detect_excessive_repetition(text: str, min_repeat: int = 100, max_pattern_len: int = 50) -> tuple[bool, Optional[str], int]:
    """
    Detect any excessive repetition pattern in the text using a sliding window approach.
    
    This function checks for any substring that repeats consecutively at least min_repeat times.
    It uses an efficient algorithm that checks patterns of different lengths.
    
    Args:
        text: Input text to check
        min_repeat: Minimum number of repetitions to consider excessive (default: 100)
        max_pattern_len: Maximum length of pattern to check (default: 50)
    
    Returns:
        tuple: (has_repetition, pattern, repeat_count)
        has_repetition: True if excessive repetition found
        pattern: The repeated pattern (if found, truncated to 30 chars for readability)
        repeat_count: Number of consecutive repetitions
    """
    if not text or len(text) < min_repeat:
        return False, None, 0
    
    # We need at least min_repeat characters to have a repetition
    min_text_len = min_repeat
    if len(text) < min_text_len:
        return False, None, 0
    
    # Check patterns of different lengths (1 to max_pattern_len)
    # Start from shorter patterns (more likely to repeat) and work up
    for pattern_len in range(1, min(max_pattern_len + 1, len(text) // min_repeat + 1)):
        # Use regex with backreference to find repeated patterns
        # Pattern: (.{pattern_len})\1{min_repeat-1,} means:
        # - Capture a group of pattern_len characters
        # - That group repeats at least (min_repeat-1) more times (total min_repeat times)
        pattern_regex = r'(.{' + str(pattern_len) + r'})\1{' + str(min_repeat - 1) + r',}'
        
        try:
            match = re.search(pattern_regex, text, re.DOTALL)
            if match:
                pattern = match.group(1)
                matched_text = match.group(0)
                
                # Count exact consecutive repetitions
                repeat_count = len(matched_text) // len(pattern)
                
                if repeat_count >= min_repeat:
                    # Return a readable representation of the pattern
                    # Escape special characters for display
                    pattern_repr = repr(pattern[:30]) if len(pattern) > 30 else repr(pattern)
                    return True, pattern_repr, repeat_count
        except re.error:
            # Skip invalid regex patterns
            continue
    
    return False, None, 0


def _check_format_penalties(generation_text: str) -> tuple[float, List[str]]:
    """
    Check for format penalties in the generation text.
    
    Currently only checks for excessive repetition. Other format issues (incomplete tags)
    are ignored to be more lenient.
    
    Returns:
        tuple: (penalty_score, list of penalty reasons)
        penalty_score: negative value indicating penalty (e.g., -0.5)
        reasons: list of strings describing the penalties found
    """
    if not generation_text:
        return 0.0, []
    
    penalties = []
    penalty_score = 0.0
    
    # Only check for excessive repetition (any pattern repeated 100+ times)
    # This is the only serious format error we care about
    has_repetition, pattern, repeat_count = _detect_excessive_repetition(generation_text, min_repeat=100)
    if has_repetition:
        penalties.append(f"excessive_repetition_pattern_{repeat_count}times")
        if repeat_count >= 100:
            penalty_score -= 0.5
    
    # Note: Other format issues are ignored:
    # - Incomplete fence tags at end (may be false positives from code comparison operators)
    # - Incomplete tags in the middle (may be acceptable in some cases)
    
    return penalty_score, penalties


def _check_format_reward(generation_text: str) -> tuple[float, bool]:
    """
    Check if the generation follows the correct format and give reward.
    
    Expected format:
    - Multiple rounds of: <think>...</think> <answer>...</answer> 
      <tool_call>...</tool_call> <tool_response>...</tool_response>
    - Final round: <think>...</think> <answer>...</answer>
    - Each block can be empty but tags should be complete
    
    Note: This function checks for <think> tags, but if your implementation uses
    <think> instead, you may need to adjust the tag patterns.
    
    Returns:
        tuple: (reward_score, is_format_correct)
        reward_score: positive value for correct format (e.g., 0.3)
        is_format_correct: boolean indicating if format is correct
    """
    if not generation_text:
        return 0.0, False

    # 1) 所有标签是否成对完整
    # Required tags: <answer>, <tool_call>, <tool_response>
    tag_pairs = [
        (r"<answer>", r"</answer>"),
        (r"<tool_call>", r"</tool_call>"),
        (r"<tool_response>", r"</tool_response>"),
    ]
    
    # Optional tags: <think> (from verl)
    optional_tag_pairs = [
        (r"<think>", r"</think>"),
    ]

    tag_counts: Dict[str, Dict[str, int]] = {}
    # Check required tags
    for open_tag, close_tag in tag_pairs:
        open_count = len(re.findall(open_tag, generation_text, re.IGNORECASE))
        close_count = len(re.findall(close_tag, generation_text, re.IGNORECASE))
        tag_counts[open_tag] = {"open": open_count, "close": close_count}
        if open_count != close_count:
            return 0.0, False
    
    # Check optional tags (if they exist, they must be paired)
    for open_tag, close_tag in optional_tag_pairs:
        open_count = len(re.findall(open_tag, generation_text, re.IGNORECASE))
        close_count = len(re.findall(close_tag, generation_text, re.IGNORECASE))
        # Only check pairing if the tag exists
        if open_count > 0 or close_count > 0:
            if open_count != close_count:
                return 0.0, False

    # 2) 找出最后一个 <answer>...</answer>，要求：
    #    - 这是整个对话的最后一个 answer
    #    - 在它之后不再出现 tool_call / tool_response
    #    - 能从该 answer 中提取出完整 verilog 代码
    answer_matches = list(
        re.finditer(r"<answer>([\s\S]*?)</answer>", generation_text, re.IGNORECASE)
    )
    if not answer_matches:
        return 0.0, False

    final_answer_match = answer_matches[-1]
    final_answer_start = final_answer_match.start()
    final_answer_end = final_answer_match.end()
    final_answer_content = final_answer_match.group(1)

    # 2.1 最后一个 answer 之后不能再有工具相关标签
    if re.search(r"<tool_call>", generation_text[final_answer_end :], re.IGNORECASE):
        return 0.0, False
    if re.search(r"<tool_response>", generation_text[final_answer_end :], re.IGNORECASE):
        return 0.0, False

    # 2.2 尝试仅从最后一个 answer 中提取 verilog 代码
    def _extract_verilog_from_single_answer(answer_body: str) -> Optional[str]:
        verilog_patterns = [
            r"```verilog\s*([\s\S]*?)```",
            r"```systemverilog\s*([\s\S]*?)```",
            r"```\s*(module\s+[\s\S]*?endmodule)```",
        ]
        candidates: List[tuple[int, str]] = []
        for pattern in verilog_patterns:
            matches = list(
                re.finditer(pattern, answer_body, re.IGNORECASE | re.DOTALL)
            )
            for m in matches:
                code = m.group(1).strip()
                if is_complete_verilog_code(code):
                    candidates.append((m.end(), code))
        if not candidates:
            return None
        candidates.sort(key=lambda x: x[0], reverse=True)
        return candidates[0][1]

    final_answer_verilog = _extract_verilog_from_single_answer(final_answer_content)
    if not final_answer_verilog:
        return 0.0, False

    # 3) 检查前面是否有工具调用轮次
    #    [至少一轮]<think>/<answer> ... <tool_call>...</tool_call> <tool_response>...</tool_response>
    #    其中每轮的 <think>/<answer> 至少出现一个，且在该轮的 <tool_call> 之前。
    prefix_text = generation_text[:final_answer_start]

    # 所有 tool_call / tool_response 标签（限制在 prefix 内）
    tool_call_iter = list(
        re.finditer(r"<tool_call>", prefix_text, re.IGNORECASE)
    )
    tool_response_iter = list(
        re.finditer(r"<tool_response>", prefix_text, re.IGNORECASE)
    )

    # 如果前面完全没有工具调用轮次，则认为"结构可接受但非完美"
    if not tool_call_iter and not tool_response_iter:
        return 0.0, False

    # tool_call / tool_response 数量必须一致
    if len(tool_call_iter) != len(tool_response_iter):
        return 0.0, False

    # 构造按顺序的成对轮次：<tool_call>...</tool_call> 后跟 <tool_response>...</tool_response>
    pair_pattern = re.compile(
        r"<tool_call>[\s\S]*?</tool_call>[\s\S]*?<tool_response>[\s\S]*?</tool_response>",
        re.IGNORECASE,
    )
    pair_matches = list(pair_pattern.finditer(prefix_text))

    # 每一个 <tool_call> / <tool_response> 必须都在某个 pair 里
    if len(pair_matches) != len(tool_call_iter) or len(pair_matches) != len(
        tool_response_iter
    ):
        return 0.0, False

    # 预先解析所有 <think> / <answer> span 位置，用于轮次内检查
    think_spans: List[tuple[int, int]] = []
    # Check for <think> tags (from verl)
    think_spans.extend([
        (m.start(), m.end())
        for m in re.finditer(r"<think>[\s\S]*?</think>", generation_text, re.IGNORECASE)
    ])
    
    answer_spans: List[tuple[int, int]] = [
        (m.start(), m.end())
        for m in re.finditer(
            r"<answer>[\s\S]*?</answer>", generation_text, re.IGNORECASE
        )
    ]

    def _has_think_or_answer_before_tc(
        round_start: int, tc_start: int
    ) -> bool:
        # 至少有一个 <think> 或 <answer> 的 span 在 tc_start 之前结束
        # 并且与 [round_start, tc_start) 区间有重叠（允许部分重叠）
        for s, e in think_spans + answer_spans:
            # 条件1：结束位置必须在 tc_start 之前（确保在 tool_call 之前）
            # 条件2：开始位置必须在 tc_start 之前（确保在 tool_call 之前）
            # 条件3：与 [round_start, tc_start) 区间有重叠
            if s < tc_start and e <= tc_start and e > round_start:
                return True
        return False

    prev_end = 0
    for m in pair_matches:
        pair_start = m.start()
        pair_end = m.end()

        # 找到该 pair 内部的 <tool_call> 起始位置
        inner = prefix_text[pair_start:pair_end]
        tc_rel = re.search(r"<tool_call>", inner, re.IGNORECASE)
        if not tc_rel:
            return 0.0, False
        tc_start = pair_start + tc_rel.start()

        if not _has_think_or_answer_before_tc(prev_end, tc_start):
            # 本轮在调用工具之前没有出现过 <think>/<answer>
            return 0.0, False

        prev_end = pair_end

    # 满足所有更严格的结构要求，给格式奖励
    format_reward = 0.3
    return format_reward, True

