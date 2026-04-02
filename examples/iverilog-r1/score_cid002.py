#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Score cid002 training instructions using DeepSeek V3 for RL data filtering.

Adapted from score_instructions.py to handle cid002 data format where the
instruction is in the `instruction` field (plain string) rather than the
`question[role=user].content` format used by cid003.

Usage:
    python score_cid002.py \
        --input /workspace/S/shiwenxuan/LLaMA-Factory/deduplicate/output/r1sft_cid002_3.5k.jsonl \
        --output /workspace/S/shiwenxuan/LLaMA-Factory/deduplicate/output/r1sft_cid002_3.5k_scored.jsonl \
        --max_workers 16 \
        --resume
"""

import argparse
import json
import os
import re
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional

from tqdm import tqdm
from volcenginesdkarkruntime import Ark

# ─── Configuration ────────────────────────────────────────────────────────────

MAX_INSTRUCTION_CHARS = 4000

MODEL_MAPPING = {
    "ds-v3.2": {"non_batch": "ep-20251207182251-w99km"},
}

# ─── Scoring Prompt (identical to score_instructions.py) ─────────────────────

SCORING_PROMPT = """You are an expert evaluator for Verilog/SystemVerilog training data. Your task is to score a given instruction (problem description) on how effectively it can train a student model to overcome its identified capability gaps.

## Scoring Criteria (0-12 points total)

Score each criterion independently, then sum for the total.

1. PROTOCOL_IMPLEMENTATION (0-2): Does the problem require implementing a standard hardware interface protocol (AXI, AXI-Stream, APB, SPI, Wishbone, etc.) with handshake signaling, backpressure, or transaction tracking?
   - 0: No protocol/interface involved
   - 1: Simple interface or basic handshake
   - 2: Full protocol with ready/valid, backpressure, multi-channel, or out-of-order handling

2. STATE_MACHINE_COMPLEXITY (0-2): Does the problem require a multi-state FSM with precise timing, concurrent operations, or complex transition logic?
   - 0: No state machine or trivial 2-3 state FSM
   - 1: Moderate FSM (4-8 states) with clear transitions
   - 2: Complex FSM with concurrent tracking, pipelined states, or cycle-accurate timing requirements

3. HARDWARE_ALGORITHM (0-1): Does the problem require implementing an algorithm in its natural hardware form, where software-style approaches (division/modulo, dynamic arrays, recursion) would be incorrect?
   - 0: Simple combinational logic or straightforward sequential logic
   - 1: Algorithm requiring hardware-specific implementation (e.g., shift-based arithmetic, bit-serial processing, parallel tree structures)

4. BIT_WIDTH_MANAGEMENT (0-1): Does the problem require careful bit-width analysis, overflow handling, signed/unsigned arithmetic, or fixed-point precision?
   - 0: No special width considerations
   - 1: Requires explicit width management, sign extension, saturation, or parameterized widths

5. MEMORY_STRUCTURE (0-1): Does the problem require complex memory/array structures, register files, CAMs, or parameterized storage?
   - 0: No complex memory structures
   - 1: Requires RAM arrays, register files, FIFOs, or multi-dimensional packed/unpacked arrays

6. SYSTEMVERILOG_CONSTRUCTS (0-1): Does the problem benefit from or require modern SystemVerilog constructs (always_ff, always_comb, interfaces, packages, structs)?
   - 0: Can be solved with basic Verilog
   - 1: Benefits from or requires modern SystemVerilog features

7. PIPELINE_SYNCHRONIZATION (0-1): Does the problem require precise data alignment through pipeline stages, registered coefficients, or multi-cycle synchronization?
   - 0: No pipeline or synchronization needs
   - 1: Requires pipeline stages, data alignment, or multi-clock-domain handling

8. SPECIFICATION_PRECISION (0-1): Does the problem have a detailed, precise specification with many constraints where deviation leads to failure?
   - 0: Vague or simple specification
   - 1: Detailed spec with many constraints, specific timing requirements, or exact behavioral descriptions

9. INSTRUCTION_FOLLOWING_DIFFICULTY (0-2): Does the instruction contain long lookup tables, truth tables, encoding tables, detailed FSM state descriptions, or many enumerated constraints that must be faithfully reproduced in the implementation?
   - 0: Short, simple description with no tables or enumerated data
   - 1: Some tables or enumerated data (moderate following difficulty)
   - 2: Extensive tables, lookup data, or many enumerated constraints requiring precise reproduction

## Output Format

Return ONLY a JSON object with this exact structure:
```json
{
  "protocol": <0-2>,
  "fsm": <0-2>,
  "hw_algo": <0-1>,
  "bitwidth": <0-1>,
  "memory": <0-1>,
  "sv_constructs": <0-1>,
  "pipeline": <0-1>,
  "spec_precision": <0-1>,
  "instruction_following": <0-2>,
  "total": <sum of all above>,
  "brief_reason": "<one sentence explaining the total score>"
}
```

## Instruction to Score:
"""


def build_client() -> Ark:
    api_key = os.environ.get("ARK_API_KEY", "f586fb6e-6d0f-43aa-b708-e9975c980281")
    return Ark(
        api_key=api_key,
        base_url="https://ark.cn-beijing.volces.com/api/v3",
        timeout=600,
    )


def extract_instruction_cid002(item: dict) -> str:
    """Extract instruction from cid002 format (plain 'instruction' field)."""
    return item.get("instruction", "")


def truncate_instruction(text: str, max_chars: int = MAX_INSTRUCTION_CHARS) -> str:
    if len(text) <= max_chars:
        return text
    return text[:max_chars] + "\n... [truncated]"


def extract_json_from_response(text: str) -> Optional[dict]:
    m = re.search(r"```json\s*(.*?)\s*```", text, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(1))
        except json.JSONDecodeError:
            pass
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    start = text.find("{")
    end = text.rfind("}") + 1
    if start >= 0 and end > start:
        try:
            return json.loads(text[start:end])
        except json.JSONDecodeError:
            pass
    return None


def parse_score(response_text: str) -> Optional[dict]:
    parsed = extract_json_from_response(response_text)
    if not parsed:
        return None
    expected_keys = ["protocol", "fsm", "hw_algo", "bitwidth", "memory",
                     "sv_constructs", "pipeline", "spec_precision",
                     "instruction_following", "total"]
    for k in expected_keys:
        if k not in parsed:
            parsed[k] = 0
    if "total" not in parsed or parsed["total"] == 0:
        parsed["total"] = sum(
            parsed.get(k, 0) for k in expected_keys if k != "total"
        )
    return parsed


def load_completed_ids(output_path: str) -> set:
    completed = set()
    if not os.path.exists(output_path):
        return completed
    with open(output_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                pid = obj.get("problem_id")
                if pid is not None:
                    completed.add(str(pid))
            except Exception:
                continue
    return completed


_file_lock = threading.Lock()


def score_one(
    index: int,
    item: dict,
    client: Ark,
    output_file: str,
    max_retries: int = 3,
) -> dict:
    instruction = extract_instruction_cid002(item)
    if not instruction:
        result = dict(item)
        result["gap_score"] = None
        result["gap_score_total"] = 0
        result["capability_gap_score"] = 0
        return result

    instruction_truncated = truncate_instruction(instruction)
    prompt = SCORING_PROMPT + "\n" + instruction_truncated

    score_obj = None
    for attempt in range(max_retries):
        try:
            response = client.chat.completions.create(
                model=MODEL_MAPPING["ds-v3.2"]["non_batch"],
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
                max_tokens=512,
            )
            text = response.choices[0].message.content
            score_obj = parse_score(text)
            if score_obj is not None:
                break
        except Exception as e:
            if attempt == max_retries - 1:
                print(f"[{index}] Error after {max_retries} attempts: {e}")

    result = dict(item)
    if score_obj is not None:
        result["gap_score"] = score_obj
        result["gap_score_total"] = score_obj.get("total", 0)
        result["capability_gap_score"] = score_obj.get("total", 0)
    else:
        result["gap_score"] = None
        result["gap_score_total"] = 0
        result["capability_gap_score"] = 0

    with _file_lock:
        with open(output_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(result, ensure_ascii=False) + "\n")

    return result


def main():
    parser = argparse.ArgumentParser(description="Score cid002 instructions for RL data filtering")
    parser.add_argument(
        "--input",
        default="/workspace/S/shiwenxuan/LLaMA-Factory/deduplicate/output/r1sft_cid002_3.5k.jsonl",
        help="Input JSONL file (cid002 format)",
    )
    parser.add_argument(
        "--output",
        default="/workspace/S/shiwenxuan/LLaMA-Factory/deduplicate/output/r1sft_cid002_3.5k_scored.jsonl",
        help="Output JSONL file with gap_score_total field",
    )
    parser.add_argument("--max_workers", type=int, default=16)
    parser.add_argument("--resume", action="store_true", help="Resume from existing output file")
    args = parser.parse_args()

    # Load input data
    items = []
    with open(args.input, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                items.append(json.loads(line))
    print(f"Loaded {len(items)} items from {args.input}")

    # Check for completed items (resume support)
    completed_ids = set()
    if args.resume:
        completed_ids = load_completed_ids(args.output)
        print(f"Resuming: {len(completed_ids)} already scored")
    elif os.path.exists(args.output):
        os.remove(args.output)

    # Filter to unscored items
    pending = [
        (i, item) for i, item in enumerate(items)
        if str(item.get("problem_id", i)) not in completed_ids
    ]
    print(f"Pending: {len(pending)} items to score")

    if not pending:
        print("All items already scored.")
        return

    client = build_client()

    with ThreadPoolExecutor(max_workers=args.max_workers) as executor:
        futures = {
            executor.submit(score_one, idx, item, client, args.output): (idx, item)
            for idx, item in pending
        }
        for future in tqdm(as_completed(futures), total=len(futures), desc="Scoring"):
            try:
                future.result()
            except Exception as e:
                idx, item = futures[future]
                print(f"Failed index {idx}: {e}")

    print(f"Done. Output written to {args.output}")

    # Print score distribution
    scored = []
    with open(args.output, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                obj = json.loads(line)
                scored.append(obj.get("gap_score_total", 0))
    if scored:
        import statistics
        print(f"Score stats: min={min(scored)}, max={max(scored)}, "
              f"mean={statistics.mean(scored):.2f}, median={statistics.median(scored):.1f}")


if __name__ == "__main__":
    main()
