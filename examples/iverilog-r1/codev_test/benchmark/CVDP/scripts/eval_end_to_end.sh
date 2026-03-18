#!/bin/bash

RAW_OUTPUT_PATH=/nfs_global/projects/verl/results/test/cvdp/raw/Qwen3_8b_32k-codegeneration-shot_0-temp_1.0-test.parquet
RAW_DATA_PATH=/nfs_global/projects/cvdp_benchmark/data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl
RAW_JSONL_PATH=/nfs_global/projects/verl/results/test/cvdp/raw/Qwen3_8b_32k-codegeneration-shot_0-temp_1.0-test.jsonl

python /nfs_global/projects/verl/results/test/cvdp/raw/convert_parquet_to_jsonl.py -i $RAW_OUTPUT_PATH -o $RAW_JSONL_PATH
echo "Convert parquet to jsonl done"

FILENAME=$(basename "$RAW_OUTPUT_PATH")
PREFIX=${FILENAME%%-codegeneration*}
OUTPUT_DIR=/nfs_global/projects/cvdp_benchmark/results/$PREFIX
COT_DIR=$OUTPUT_DIR/cot
mkdir -p $OUTPUT_DIR
echo "Create output directory done"

python /nfs_global/projects/cvdp_benchmark/scripts/extract_responses.py --jsonl_path $RAW_JSONL_PATH --output_dir $COT_DIR
echo "Extract responses done"

PROMPTS_RESPONSES_FILE=$OUTPUT_DIR/answer_to_import.jsonl
python /nfs_global/projects/cvdp_benchmark/scripts/extract_verilog_from_jsonl.py --in_path $RAW_JSONL_PATH --out_path $PROMPTS_RESPONSES_FILE
echo "Extract verilog from jsonl done"

echo "Run samples start"

python run_samples.py \
  -f $RAW_DATA_PATH \
  --llm \
  --model local_import \
  --threads 64 \
  --prompts-responses-file $PROMPTS_RESPONSES_FILE \
  --prefix $OUTPUT_DIR/result \
  -n 1 \
  -k 1
echo "Run samples done"

python run_samples.py \
  -f /nfs_global/projects/cvdp_benchmark/data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial_left.jsonl \
  --llm \
  --model local_import \
  --threads 64 \
  --prompts-responses-file /nfs_global/projects/cvdp_benchmark/results/claude_tool_left/answer_to_import_left.jsonl \
  --prefix /nfs_global/projects/cvdp_benchmark/results/claude_tool_left/result_left \
  -n 1 \
  -k 1

  python run_samples.py \
  -f /nfs_global/projects/cvdp_benchmark/data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl \
  --llm \
  --model local_import \
  --threads 32 \
  --prompts-responses-file /nfs_global/projects/cvdp_benchmark/results/qwen3_32b_tool_10epochs_vllm/answer_to_import_veri.jsonl \
  --prefix /nfs_global/projects/cvdp_benchmark/results/qwen3_32b_tool_10epochs_vllm/result_veri\
  -n 1 \
  -k 1

  python run_samples.py \
  -f /nfs_global/projects/cvdp_benchmark/data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl \
  --llm \
  --model local_import \
  --threads 32 \
  --prompts-responses-file /nfs_global/projects/cvdp_benchmark/results/qwen3_32b_sft_87k_r1_then_8.2k/answer_to_import.jsonl \
  --prefix /nfs_global/projects/cvdp_benchmark/results/qwen3_32b_sft_87k_r1_then_8.2k/result\
  -n 1 \
  -k 1


  python run_benchmark.py -f /nfs_global/projects/cvdp_benchmark/data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl \
  --model local_import \
  --prompts-responses-file /nfs_global/projects/cvdp_benchmark/results/qwen3_32b_sft_87k_r1_then_8.2k/answer_to_import.jsonl \
  --prefix /nfs_global/projects/cvdp_benchmark/results/qwen3_32b_sft_87k_r1_then_8.2k/result \
  --threads 32 \
  --llm 