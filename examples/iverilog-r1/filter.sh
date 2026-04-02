#!/bin/bash

set -e

. ~/.bashrc 2>/dev/null || true

ulimit -n 65536 2>/dev/null || true
ulimit -l unlimited
ulimit -v unlimited
ulimit -n 65535
# ulimit -u 4125556

micromamba activate slime

export IVERILOG_PATH="/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/iverilog"
export VVP_PATH="/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/vvp"
export YOSYS_PATH="/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/yosys"

: "${MODEL_PATH:?Set MODEL_PATH to your HuggingFace model directory}"
: "${DATA_TYPE:?Set DATA_TYPE to cid002 or cid003}"
TP_SIZE="${TP_SIZE:-${SLURM_GPUS_ON_NODE:-8}}"

case "$DATA_TYPE" in
  cid002)
    INPUT="/workspace/S/shiwenxuan/LLaMA-Factory/deduplicate/output/r1sft_cid002_3.5k_scored.jsonl"
    OUTPUT="./cid002_filtered_200.jsonl"
    ;;
  cid003)
    INPUT="/workspace/S/shiwenxuan/LLaMA-Factory/deduplicate/output/r1_sft_87k_top8107.jsonl"
    OUTPUT="./cid003_filtered_200.jsonl"
    ;;
  *)
    echo "ERROR: DATA_TYPE must be cid002 or cid003, got: $DATA_TYPE"
    exit 1
    ;;
esac

echo "=== Filtering $DATA_TYPE ==="
echo "  Input:  $INPUT"
echo "  Output: $OUTPUT"

python filter_by_sampling.py \
  --input "$INPUT" \
  --output "$OUTPUT" \
  --data-type "$DATA_TYPE" \
  --api-url http://localhost:30000 \
  --model-name default \
  --auto-start-model "$MODEL_PATH" \
  --tp-size "$TP_SIZE" \
  --target-count 200 \
  --n-samples 5 \
  --max-concurrent 8 \
  --max-turns 8 \
  --resume \