#!/bin/bash

. ~/.bashrc
conda activate cvdp

# 设置基本参数（对齐tir-claude-api-ppa.yaml）
RESULT_DIR=/nfs_global/projects/cvdp_benchmark/results/glm4_6_tool
CODE_FINAL_TOOL=$RESULT_DIR/answer_to_import.jsonl
COT_FINAL_TOOL=$RESULT_DIR/cot

rm -rf "$CODE_FINAL_TOOL" "$COT_FINAL_TOOL"
mkdir -p "$COT_FINAL_TOOL"

for i in {1..3}; do
    INPUT_FILE_TOOL="/nfs_global/NeMo-Skills/openmathreasoning-verilog/solution-sdg-cvdp/cvdp_problems_glm/output-rs$((i - 1)).jsonl"
    CODE_JSONL_TOOL="$RESULT_DIR/extracted_answers_improved_t$i.jsonl"
    
    python scripts/extract_verilog_answers_improved.py --input "$INPUT_FILE_TOOL" --output "$CODE_JSONL_TOOL"
    python scripts/process_cvdp_result.py --input "$CODE_JSONL_TOOL" --output "$CODE_FINAL_TOOL" --input_cot "$INPUT_FILE_TOOL" --output_cot "$COT_FINAL_TOOL"
done

# python run_benchmark.py -f data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl \
python run_samples.py -f data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl -n 5\
  --llm \
  --model local_import \
  --prompts-responses-file $CODE_FINAL_TOOL \
  --prefix $RESULT_DIR/results &> tmp/experiment_tool.log