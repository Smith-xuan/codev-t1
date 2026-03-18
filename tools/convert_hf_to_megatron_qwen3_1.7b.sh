#!/bin/bash

# 将 HuggingFace 格式的 Qwen3-1.7B 模型转换为 Megatron 格式
# 使用方法: bash convert_hf_to_megatron_qwen3_1.7b.sh

set -e

# 源模型路径 (HuggingFace 格式)
HF_CHECKPOINT="/nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/87k_sft_8.1k_ds32_10epochs/checkpoint-1270"

# 输出路径 (Megatron 格式)
OUTPUT_DIR="${HF_CHECKPOINT}_torch_dist"

# 获取脚本所在目录
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SLIME_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

# 检查并设置 Megatron-LM 路径
# 适配实验室集群环境，使用 /workspace/S/shiwenxuan 路径
MEGATRON_LM_PATH="/workspace/S/shiwenxuan/Megatron-LM"

# 检查 Megatron-LM 是否存在
if [ ! -d "$MEGATRON_LM_PATH" ]; then
    echo "  ✗ ERROR: Megatron-LM not found at ${MEGATRON_LM_PATH}"
    echo "  请确保 Megatron-LM 已安装在 /workspace/S/shiwenxuan/Megatron-LM"
    exit 1
else
    echo "  ✓ Found Megatron-LM at ${MEGATRON_LM_PATH}"
fi

# 设置环境变量
export PYTHONPATH="${MEGATRON_LM_PATH}:${SLIME_ROOT}:${PYTHONPATH}"
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-"0,1,2,3,4,5,6,7"}

echo "PYTHONPATH: ${PYTHONPATH}"

# 验证 Megatron-LM 安装（检查是否可以导入 megatron.training）
echo "验证 Megatron-LM 安装..."
if [ -d "$MEGATRON_LM_PATH" ]; then
    python3 -c "import sys; sys.path.insert(0, '${MEGATRON_LM_PATH}'); from megatron.training.arguments import parse_args; print('  ✓ megatron.training imported successfully')" 2>/dev/null || {
        echo "  ⚠ Warning: megatron.training import failed"
        echo "  尝试安装 Megatron-LM..."
        if [ -d "$MEGATRON_LM_PATH" ]; then
            cd "$MEGATRON_LM_PATH" && pip install -e . 2>/dev/null && echo "  ✓ Installed Megatron-LM" || echo "  ✗ Failed to install Megatron-LM"
        fi
    }
else
    echo "  ✗ ERROR: Megatron-LM not found at ${MEGATRON_LM_PATH}"
    echo "  请确保 Megatron-LM 已安装或路径正确"
    exit 1
fi

# 检查源模型路径是否存在
if [ ! -d "${HF_CHECKPOINT}" ]; then
    echo "错误: 源模型路径不存在: ${HF_CHECKPOINT}"
    exit 1
fi

# 创建输出目录
mkdir -p "${OUTPUT_DIR}"

# 设置分布式训练环境变量
# 根据可用的 GPU 数量设置
NUM_GPUS=$(echo "${CUDA_VISIBLE_DEVICES}" | tr ',' '\n' | wc -l)
export WORLD_SIZE=${NUM_GPUS}
export MASTER_ADDR=${MASTER_ADDR:-"localhost"}
export MASTER_PORT=${MASTER_PORT:-"29500"}

echo "=========================================="
echo "HuggingFace 到 Megatron 模型转换"
echo "=========================================="
echo "源模型路径: ${HF_CHECKPOINT}"
echo "输出路径: ${OUTPUT_DIR}"
echo "使用 GPU 数量: ${NUM_GPUS}"
echo "=========================================="

# 运行转换脚本
# 使用 torchrun 启动分布式转换
# torchrun \
#     --nproc_per_node=${NUM_GPUS} \
#     --master_addr=${MASTER_ADDR} \
#     --master_port=${MASTER_PORT} \
#     "${SLIME_ROOT}/tools/convert_hf_to_torch_dist.py" \
#     --hf-checkpoint "${HF_CHECKPOINT}" \
#     --save "${OUTPUT_DIR}" \
#     --swiglu \
#     --num-layers 28 \
#     --hidden-size 2048 \
#     --ffn-hidden-size 6144 \
#     --num-attention-heads 16 \
#     --group-query-attention \
#     --num-query-groups 8 \
#     --use-rotary-position-embeddings \
#     --disable-bias-linear \
#     --normalization "RMSNorm" \
#     --norm-epsilon 1e-6 \
#     --rotary-base 1000000 \
#     --vocab-size 151936 \
#     --kv-channels 128 \
#     --qk-layernorm \
#     --tensor-model-parallel-size 1 \
#     --pipeline-model-parallel-size 1 \
#     --sequence-parallel \
#     --use-distributed-optimizer

# torchrun \
#     --nproc_per_node=${NUM_GPUS} \
#     --master_addr=${MASTER_ADDR} \
#     --master_port=${MASTER_PORT} \
#     "${SLIME_ROOT}/tools/convert_hf_to_torch_dist.py" \
#     --hf-checkpoint "${HF_CHECKPOINT}" \
#     --save "${OUTPUT_DIR}" \
#     --swiglu \
#     --num-layers 28 \
#     --hidden-size 1536 \
#     --ffn-hidden-size 8960 \
#     --num-attention-heads 12 \
#     --use-rotary-position-embeddings \
#     --disable-bias-linear \
#     --add-qkv-bias \
#     --normalization "RMSNorm" \
#     --norm-epsilon 1e-6 \
#     --rotary-base 10000 \
#     --group-query-attention \
#     --num-query-groups 2 \
#     --vocab-size 151936 \
#     --tensor-model-parallel-size 1 \
#     --pipeline-model-parallel-size 1 \
#     --sequence-parallel \

torchrun \
    --nproc_per_node=${NUM_GPUS} \
    --master_addr=${MASTER_ADDR} \
    --master_port=${MASTER_PORT} \
    "${SLIME_ROOT}/tools/convert_hf_to_torch_dist.py" \
    --hf-checkpoint "${HF_CHECKPOINT}" \
    --save "${OUTPUT_DIR}" \
    --swiglu \
    --num-layers 36 \
    --hidden-size 4096 \
    --ffn-hidden-size 12288 \
    --num-attention-heads 32 \
    --use-rotary-position-embeddings \
    --disable-bias-linear \
    --normalization "RMSNorm" \
    --norm-epsilon 1e-6 \
    --rotary-base 1000000 \
    --group-query-attention \
    --num-query-groups 8 \
    --vocab-size 151936 \
    --kv-channels 128 \
    --qk-layernorm \
    --untie-embeddings-and-output-weights \
    --tensor-model-parallel-size 1 \
    --pipeline-model-parallel-size 1 \
    --sequence-parallel \
    --use-distributed-optimizer

echo "=========================================="
echo "转换完成！"
echo "Megatron 模型已保存到: ${OUTPUT_DIR}"
echo "=========================================="


# megatron 转换为 HF 格式例子
# PYTHONPATH=/workspace/S/shiwenxuan/Megatron-LM python tools/convert_torch_dist_to_hf.py \
#   --input-dir /nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/tool_8.1k_ds32_10epochs/megatron_slime_save/iter_0000049/ \
#   --output-dir /nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/tool_8.1k_ds32_10epochs/megatron_slime_save/50steps \
#   --origin-hf-dir /nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/tool_8.1k_ds32_10epochs