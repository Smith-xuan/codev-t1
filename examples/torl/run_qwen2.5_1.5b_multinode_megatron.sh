#!/bin/bash

# Multi-node training script for ToRL with Qwen2.5-Math-1.5B
# This script runs training on 2 nodes with 8 GPUs each (16 GPUs total)
# Worker node is accessed via SSH at 10.21.0.12
# Adapted from iverilog-r1 training script for Python code execution via SandboxFusion

# Use set -e to exit on error, but don't use -x to avoid excessive debug output
set -e

# Source bashrc to ensure conda/micromamba is available
. ~/.bashrc 2>/dev/null || true

# Initialize both conda and micromamba at the beginning of the script
# sandbox-runtime is a conda environment, slime is a micromamba environment
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook 2>/dev/null)" || true
    echo "✓ Initialized conda (for sandbox-runtime environment)"
fi

if [ -f "/root/.local/bin/micromamba" ]; then
    export MAMBA_EXE='/root/.local/bin/micromamba'
    export MAMBA_ROOT_PREFIX='/nfs_global/micromamba'
    eval "$($MAMBA_EXE shell hook --shell bash --root-prefix $MAMBA_ROOT_PREFIX 2>/dev/null)" || true
    echo "✓ Initialized micromamba (for slime environment)"
fi

# Disable output buffering for immediate display
export PYTHONUNBUFFERED=1
if [ -t 1 ]; then
    export PYTHONIOENCODING=utf-8
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SLIME_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"

# === Path settings ===
export TMPDIR=/tmp
export TMP=/tmp
export TEMP=/tmp
export RAY_TMPDIR=/tmp

# === Disable DeepGEMM ===
export SGLANG_DISABLE_DEEPGEMM=1
export SGLANG_DISABLE_FLASHINFER_SAMPLING=1

# === Compilation cache redirection ===
export TRITON_CACHE_DIR="/tmp/triton_cache"
export TORCH_EXTENSIONS_DIR="/tmp/torch_extensions"
export SGLANG_TMPDIR="/tmp/sglang_tmp"
mkdir -p $TORCH_EXTENSIONS_DIR $TRITON_CACHE_DIR $SGLANG_TMPDIR

# === Ray object spilling configuration ===
mkdir -p /nfs_global/tmp/ray_spill

# PID file to track processes started by this script
PID_FILE="${SCRIPT_DIR}/.run_qwen3_1.5b_torl_multinode.pid"
RAY_DASHBOARD_PORT=8266  # Use different port from iverilog-r1
SANDBOX_PORT=${SANDBOX_PORT:-8185}  # SandboxFusion port (matching ToRL config)
SGLANG_ROUTER_PORT=${SGLANG_ROUTER_PORT:-3001}  # Port for SGLang router (different from iverilog-r1)

# Multi-node configuration
MASTER_ADDR=${MASTER_ADDR:-"10.21.0.3"}
WORKER_ADDR=${WORKER_ADDR:-"10.21.0.12"}
NUM_NODES=2
GPUS_PER_NODE=8
TOTAL_GPUS=$((NUM_NODES * GPUS_PER_NODE))

# Network interface configuration
NETWORK_INTERFACE=${NETWORK_INTERFACE:-"eth0"}

# Export NCCL and Gloo environment variables
export NCCL_SOCKET_IFNAME=${NCCL_SOCKET_IFNAME:-"${NETWORK_INTERFACE}"}
export GLOO_SOCKET_IFNAME=${GLOO_SOCKET_IFNAME:-"${NETWORK_INTERFACE}"}
export NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-"1"}

echo "=========================================="
echo "ToRL Multi-node Training Configuration"
echo "=========================================="
echo "Master node: ${MASTER_ADDR}"
echo "Worker node: ${WORKER_ADDR}"
echo "Total nodes: ${NUM_NODES}"
echo "GPUs per node: ${GPUS_PER_NODE}"
echo "Total GPUs: ${TOTAL_GPUS}"
echo "=========================================="
echo ""

# Function to cleanup worker node via SSH
cleanup_worker_node() {
    echo "Cleaning up worker node ${WORKER_ADDR}..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        ${WORKER_ADDR} \
        "export MAMBA_EXE='/root/.local/bin/micromamba'; \
         export MAMBA_ROOT_PREFIX='/nfs_global/micromamba'; \
         [ -f \"\$MAMBA_EXE\" ] && eval \"\$(\$MAMBA_EXE shell hook --shell bash --root-prefix \$MAMBA_ROOT_PREFIX 2>/dev/null)\" && micromamba activate slime 2>/dev/null || true; \
         ray stop --force 2>/dev/null || true; \
         pkill -f 'ray.*worker' 2>/dev/null || true; \
         pkill -f 'python.*train.py' 2>/dev/null || true; \
         pkill -f 'sglang.*scheduler' 2>/dev/null || true; \
         pkill -f 'sglang::scheduler' 2>/dev/null || true; \
         pkill -f 'sglang' 2>/dev/null || true; \
         if command -v nvidia-smi >/dev/null 2>&1; then \
             nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | grep -v '^$' | xargs kill -9 2>/dev/null || true; \
         fi" \
        2>/dev/null || echo "Warning: Could not cleanup worker node (may already be cleaned up)"
}

# Function to cleanup processes started by this script
cleanup_own_processes() {
    echo "Cleaning up processes started by this script..."
    
    cleanup_worker_node
    
    # Kill processes from PID file if it exists
    if [ -f "$PID_FILE" ]; then
        while read pid; do
            if [ ! -z "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "Killing process PID: $pid"
                kill "$pid" 2>/dev/null || true
                sleep 1
                kill -9 "$pid" 2>/dev/null || true
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    # Kill SandboxFusion server processes
    pkill -f "sandbox.*server.*${SANDBOX_PORT}" 2>/dev/null || true
    pkill -f "uvicorn.*sandbox.*${SANDBOX_PORT}" 2>/dev/null || true
    
    # Kill SGLang processes
    pkill -f "sglang.*train.py" 2>/dev/null || true
    pkill -f "python.*train.py.*torl" 2>/dev/null || true
    pkill -f "sglang.*scheduler" 2>/dev/null || true
    pkill -f "sglang::scheduler" 2>/dev/null || true
    pkill -f "sglang" 2>/dev/null || true
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | grep -v '^$' | xargs kill -9 2>/dev/null || true
    fi
    
    # Stop Ray cluster
    if lsof -ti:${RAY_DASHBOARD_PORT} >/dev/null 2>&1; then
        echo "Stopping Ray cluster on port ${RAY_DASHBOARD_PORT}..."
        ray stop --address="http://127.0.0.1:${RAY_DASHBOARD_PORT}" --force 2>/dev/null || true
        sleep 2
        lsof -ti:${RAY_DASHBOARD_PORT} 2>/dev/null | xargs kill -9 2>/dev/null || true
    fi
    
    ray stop --force 2>/dev/null || true
    sleep 1
    
    ps aux | grep -E "ray.*${RAY_DASHBOARD_PORT}|ray.*dashboard.*${RAY_DASHBOARD_PORT}" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    pkill -f "ray.*dashboard.*${RAY_DASHBOARD_PORT}" 2>/dev/null || true
    pkill -f "ray.*head.*${RAY_DASHBOARD_PORT}" 2>/dev/null || true
    
    if ! pgrep -f "ray.*dashboard" >/dev/null 2>&1; then
        RAY_RUNTIME_DIR="/tmp/ray"
        if [ -d "$RAY_RUNTIME_DIR" ]; then
            echo "Cleaning up Ray runtime directory to avoid session conflicts..."
            find "$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
        fi
    fi
}

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    
    if [ ! -z "$RAY_JOB_ID" ]; then
        JOB_STATUS_OUTPUT=$(ray job status --address="http://127.0.0.1:${RAY_DASHBOARD_PORT}" "$RAY_JOB_ID" 2>/dev/null || echo "")
        JOB_STATUS=$(echo "$JOB_STATUS_OUTPUT" | grep -i "status" | head -1 || echo "")
        if echo "$JOB_STATUS" | grep -qi "running\|pending"; then
            echo "Warning: Ray job $RAY_JOB_ID is still running."
            echo "  The job will continue running in the background."
            echo "  To view logs: ray job logs $RAY_JOB_ID"
            echo "  To check status: ray job status $RAY_JOB_ID"
            echo "  To stop job: ray job stop $RAY_JOB_ID"
            echo ""
            echo "Skipping Ray cluster cleanup (job is still running)."
            SKIP_RAY_CLEANUP=true
        else
            SKIP_RAY_CLEANUP=false
        fi
    else
        SKIP_RAY_CLEANUP=false
    fi
    
    if [ ! -z "$SANDBOX_PID" ]; then
        echo "Stopping SandboxFusion server (PID: $SANDBOX_PID)..."
        kill $SANDBOX_PID 2>/dev/null || true
        sleep 1
        kill -9 $SANDBOX_PID 2>/dev/null || true
    fi
    
    if [ -f "$PID_FILE" ]; then
        while read pid; do
            if [ ! -z "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                if [ "$SKIP_RAY_CLEANUP" = "true" ]; then
                    PROC_INFO=$(ps -p "$pid" -o comm= 2>/dev/null || echo "")
                    if echo "$PROC_INFO" | grep -qi "ray"; then
                        echo "Skipping Ray process PID: $pid (job still running)"
                        continue
                    fi
                fi
                echo "Killing process PID: $pid"
                kill "$pid" 2>/dev/null || true
                sleep 1
                kill -9 "$pid" 2>/dev/null || true
            fi
        done < "$PID_FILE"
        if [ "$SKIP_RAY_CLEANUP" != "true" ]; then
            rm -f "$PID_FILE"
        fi
    fi
    
    if [ ! -z "$SANDBOX_PORT" ]; then
        pkill -f "sandbox.*server.*${SANDBOX_PORT}" 2>/dev/null || true
        pkill -f "uvicorn.*sandbox.*${SANDBOX_PORT}" 2>/dev/null || true
    fi
    
    if [ "$SKIP_RAY_CLEANUP" != "true" ]; then
        echo "Cleaning up Ray cluster..."
        cleanup_own_processes
    fi
}

# Register cleanup function to run on script exit
trap cleanup EXIT INT TERM

# Clean up any existing processes from previous runs
cleanup_own_processes
sleep 2

export PYTHONBUFFERED=16

# Host IP address that Ray workers will use to access services
HOST_IP=${HOST_IP:-"${MASTER_ADDR}"}

# SandboxFusion server configuration
SANDBOX_HOST=${SANDBOX_HOST:-"0.0.0.0"}
SANDBOX_URL="http://${HOST_IP}:${SANDBOX_PORT}/run_code"

echo "Host IP for service access: ${HOST_IP}"
echo "SANDBOX_URL for Ray workers: ${SANDBOX_URL}"

# Test SSH connection to worker node
echo ""
echo "=========================================="
echo "Testing SSH connection to worker node..."
echo "=========================================="
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    ${WORKER_ADDR} "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✓ SSH connection to ${WORKER_ADDR} successful"
else
    echo "✗ ERROR: Cannot connect to worker node ${WORKER_ADDR} via SSH"
    echo "Please ensure:"
    echo "  1. SSH key-based authentication is set up"
    echo "  2. Worker node is accessible at ${WORKER_ADDR}"
    echo "  3. You can connect via: ssh ${WORKER_ADDR}"
    exit 1
fi

# Verify network interface on worker node
echo "Verifying network interface on worker node..."
WORKER_INTERFACE=$(ssh -o StrictHostKeyChecking=no ${WORKER_ADDR} \
    "ip route | grep default | awk '{print \$5}' | head -1" 2>/dev/null || echo "")
if [ -z "$WORKER_INTERFACE" ]; then
    WORKER_INTERFACE=$(ssh -o StrictHostKeyChecking=no ${WORKER_ADDR} \
        "ip addr | grep -E '^[0-9]+:.*state UP' | grep -v lo | head -1 | awk '{print \$2}' | sed 's/://'" 2>/dev/null || echo "eth0")
fi
if [ "$WORKER_INTERFACE" != "$NETWORK_INTERFACE" ]; then
    echo "⚠ Warning: Worker node network interface ($WORKER_INTERFACE) differs from master ($NETWORK_INTERFACE)"
else
    echo "✓ Network interface matches on both nodes: ${NETWORK_INTERFACE}"
fi

# Start SandboxFusion server in background
echo ""
echo "=========================================="
echo "Starting SandboxFusion server..."
echo "=========================================="

SANDBOX_DIR="/nfs_global/projects/verl/SandboxFusion"
if [ ! -d "$SANDBOX_DIR" ]; then
    echo "ERROR: SandboxFusion directory not found at $SANDBOX_DIR"
    echo "Please ensure verl is installed and SandboxFusion is available"
    exit 1
fi

# Check if server is already running
if curl -s http://127.0.0.1:${SANDBOX_PORT}/health > /dev/null 2>&1 || \
   curl -s http://127.0.0.1:${SANDBOX_PORT}/ > /dev/null 2>&1 || \
   curl -s http://127.0.0.1:${SANDBOX_PORT}/run_code > /dev/null 2>&1; then
    echo "SandboxFusion server is already running on port ${SANDBOX_PORT}"
else
    # Kill any existing SandboxFusion server processes
    pkill -f "sandbox.*server" 2>/dev/null || true
    pkill -f "uvicorn.*sandbox" 2>/dev/null || true
    sleep 2
    
    ORIGINAL_DIR=$(pwd)
    
    echo "Starting SandboxFusion server on ${SANDBOX_HOST}:${SANDBOX_PORT}..."
    cd "$SANDBOX_DIR"
    
    if command -v conda >/dev/null 2>&1; then
        conda activate sandbox-runtime 2>/dev/null || {
            echo "ERROR: Could not activate sandbox-runtime conda environment"
            echo "Please ensure sandbox-runtime conda environment exists: conda env list"
            exit 1
        }
        echo "✓ Activated sandbox-runtime conda environment"
    else
        echo "ERROR: conda not found. sandbox-runtime is a conda environment."
        exit 1
    fi
    
    # Start SandboxFusion server
    uvicorn sandbox.server.server:app --host ${SANDBOX_HOST} --port ${SANDBOX_PORT} --log-level info > ${SCRIPT_DIR}/sandbox_fusion.log 2>&1 &
    SANDBOX_PID=$!
    echo "SandboxFusion server started with PID: ${SANDBOX_PID}"
    echo "Log file: ${SCRIPT_DIR}/sandbox_fusion.log"
    echo "${SANDBOX_PID}" >> "$PID_FILE"
    
    cd "$ORIGINAL_DIR"
    
    echo "Switching back to slime environment..."
    
    if command -v conda >/dev/null 2>&1; then
        conda deactivate 2>/dev/null || true
    fi
    
    if [ -f "/root/.local/bin/micromamba" ]; then
        micromamba deactivate 2>/dev/null || true
        micromamba activate slime || {
            echo "ERROR: Could not activate slime micromamba environment"
            echo "Please ensure slime environment exists: micromamba env list"
            exit 1
        }
        echo "✓ Activated slime micromamba environment"
    else
        echo "ERROR: micromamba not found. slime is a micromamba environment."
        exit 1
    fi
    
    # Wait for server to be ready
    echo "Waiting for SandboxFusion server to be ready..."
    MAX_RETRIES=30
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s http://127.0.0.1:${SANDBOX_PORT}/health > /dev/null 2>&1 || \
           curl -s http://127.0.0.1:${SANDBOX_PORT}/ > /dev/null 2>&1 || \
           curl -s http://127.0.0.1:${SANDBOX_PORT}/run_code > /dev/null 2>&1; then
            echo "✓ SandboxFusion server is ready!"
            break
        fi
        if [ $i -eq $MAX_RETRIES ]; then
            echo "⚠ Warning: SandboxFusion server may not be ready after ${MAX_RETRIES} seconds"
            echo "Check the log file: ${SCRIPT_DIR}/sandbox_fusion.log"
        else
            sleep 2
        fi
    done
fi

echo "SandboxFusion server URL: ${SANDBOX_URL}"
echo "=========================================="
echo ""

# Model checkpoint paths (matching ToRL configuration)
# HF_MODEL_PATH: Original HuggingFace format model (for tokenizer and config)
HF_MODEL_PATH=/nfs_global/codev-t1/models/Qwen2.5-Math-1.5B
# MODEL_PATH: Megatron format model directory (for actual model weights)
MODEL_PATH=/nfs_global/codev-t1/models/Qwen2.5-Math-1.5B_torch_dist
DATA_PATH=/nfs_global/ToRL/data/torl_data

# 解决多线程死锁
export TOKENIZERS_PARALLELISM=false

# 解决 Protobuf C++ 冲突
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

export USE_DIRECT_SANDBOX_API=true
export SANDBOX_FUSION_CONCURRENCY=32

# Note: Megatron backend requires MODEL_ARGS to specify model architecture
# Qwen2.5-Math-1.5B model architecture parameters
MODEL_ARGS=(
   --swiglu
   --num-layers 28
   --hidden-size 1536
   --ffn-hidden-size 8960
   --num-attention-heads 12
   --use-rotary-position-embeddings
   --disable-bias-linear
   --add-qkv-bias
   --normalization "RMSNorm"
   --norm-epsilon 1e-6
   --rotary-base 10000
   --group-query-attention
   --num-query-groups 2
   --vocab-size 151936
)

CKPT_ARGS=(
   --hf-checkpoint ${HF_MODEL_PATH}
   --ref-load ${MODEL_PATH}
   --load ${MODEL_PATH}/megatron_slime_save
   --save ${MODEL_PATH}/megatron_slime_save
   --save-interval 50
)

ROLLOUT_ARGS=(
   --prompt-data ${DATA_PATH}/train.parquet
   --input-key prompt
   --label-key reward_model
   --tool-key tools
   --apply-chat-template
   --rollout-shuffle
   --num-rollout 1000
   --rollout-batch-size 128
   --n-samples-per-prompt 16
   --rollout-max-response-len 3072
   --rollout-max-context-len 4096
   --over-sampling-batch-size 160
   --dynamic-sampling-filter-path slime.rollout.filter_hub.dynamic_sampling_filters.check_reward_nonzero_std
   --rollout-temperature 1.0

   # eval args (optional)
   --eval-interval 10
   --eval-prompt-data torl_test ${DATA_PATH}/test.parquet
   --eval-input-key prompt
   --eval-label-key reward_model
   --eval-tool-key tools
   --n-samples-per-eval-prompt 1
   --eval-max-response-len 3072
   --eval-max-context-len 4096

   --global-batch-size 2048
   --balance-data
)

PERF_ARGS=(
   --tensor-model-parallel-size 2
   --sequence-parallel
   --pipeline-model-parallel-size 1
   --context-parallel-size 1
   --expert-model-parallel-size 1
   --expert-tensor-parallel-size 1
   --recompute-granularity full
   --recompute-method uniform
   --recompute-num-layers 1

   --use-dynamic-batch-size
   --max-tokens-per-gpu 30000
)

GRPO_ARGS=(
   --advantage-estimator grpo
   --kl-loss-coef 0.00
   --kl-loss-type low_var_kl
   --entropy-coef 0.00
   --eps-clip 0.2
   --eps-clip-high 0.28

   # TIS-related args (optional)
   --use-tis
)

OPTIMIZER_ARGS=(
   --optimizer adam
   --lr 1e-6
   --lr-decay-style constant
   --weight-decay 0.01
   --adam-beta1 0.9
   --adam-beta2 0.98
)

WANDB_ARGS=(
   --use-wandb
   --wandb-mode offline
   --wandb-project torl
   --wandb-group torl_qwen_math_1.5b
   --wandb-key 'e8f26cb646aea4a12ef982270212804afa4fa31e'
)

SGLANG_ARGS=(
   --rollout-num-gpus-per-engine 2
   --sglang-mem-fraction-static 0.7
   --sglang-cuda-graph-bs 1 2 4 8 $(seq 16 8 256)
   --sglang-router-ip ${MASTER_ADDR}
   --sglang-router-port ${SGLANG_ROUTER_PORT}
)

MISC_ARGS=(
   --attention-dropout 0.0
   --hidden-dropout 0.0
   --accumulate-allreduce-grads-in-fp32
   --attention-softmax-in-fp32
   --attention-backend flash
)

CUSTOM_ARGS=(
   --custom-generate-function-path generate_with_torl.generate
   --custom-rm-path generate_with_torl.reward_func
)

# Ensure Ray is completely stopped and cleaned up before starting
echo "=========================================="
echo "Setting up Ray cluster..."
echo "=========================================="
echo "Ensuring Ray is stopped before starting..."
ray stop --force 2>/dev/null || true
sleep 2

cleanup_worker_node
sleep 1

if lsof -ti:${RAY_DASHBOARD_PORT} >/dev/null 2>&1; then
    echo "Port ${RAY_DASHBOARD_PORT} is still in use, force killing..."
    lsof -ti:${RAY_DASHBOARD_PORT} 2>/dev/null | xargs kill -9 2>/dev/null || true
    sleep 1
fi

RAY_RUNTIME_DIR="/tmp/ray"
mkdir -p "$RAY_RUNTIME_DIR"
if [ -d "$RAY_RUNTIME_DIR" ]; then
    echo "Cleaning up Ray session directories..."
    find "$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
fi

# Start Ray head node on master
echo "Starting Ray head node on ${MASTER_ADDR}..."
mkdir -p /nfs_global/tmp/ray_spill
ray start --head \
    --node-ip-address ${MASTER_ADDR} \
    --num-gpus ${GPUS_PER_NODE} \
    --disable-usage-stats \
    --dashboard-host=0.0.0.0 \
    --dashboard-port=${RAY_DASHBOARD_PORT} \
    --object-spilling-directory=/nfs_global/tmp/ray_spill \
    2>&1

RAY_HEAD_PID=$(lsof -ti:${RAY_DASHBOARD_PORT} 2>/dev/null | head -1)
if [ ! -z "$RAY_HEAD_PID" ]; then
    echo "${RAY_HEAD_PID}" >> "$PID_FILE"
    echo "Ray head node started with PID: ${RAY_HEAD_PID}"
fi

# Wait for Ray head to be ready
echo "Waiting for Ray head node to be ready..."
RAY_READY=0
for i in $(seq 1 30); do
    if ray status 2>/dev/null | grep -qE '(Healthy|ALIVE|Active)'; then
        RAY_READY=1
        break
    fi
    sleep 2
done

if [ $RAY_READY -eq 0 ]; then
    echo "ERROR: Ray head node failed to start properly!"
    ray status 2>&1 | head -20 || echo "ray status command failed"
    exit 1
fi

echo "✓ Ray head node is ready!"

RAY_ADDRESS="${MASTER_ADDR}:6379"
echo "Ray address for worker nodes: ${RAY_ADDRESS}"

# Start Ray worker node on remote machine
echo ""
echo "Starting Ray worker node on ${WORKER_ADDR}..."
echo "Note: Worker node should have slime environment and access to /nfs_global"
ssh -o StrictHostKeyChecking=no ${WORKER_ADDR} bash -s << EOF
set -e
export PYTHONUNBUFFERED=1

export TMPDIR=/tmp
export TMP=/tmp
export TEMP=/tmp
export RAY_TMPDIR=/tmp

export SGLANG_DISABLE_DEEPGEMM=1
export SGLANG_DISABLE_FLASHINFER_SAMPLING=1

export TRITON_CACHE_DIR="/tmp/triton_cache"
export TORCH_EXTENSIONS_DIR="/tmp/torch_extensions"
export SGLANG_TMPDIR="/tmp/sglang_tmp"
mkdir -p \$TORCH_EXTENSIONS_DIR \$TRITON_CACHE_DIR \$SGLANG_TMPDIR

RAY_ADDRESS="${RAY_ADDRESS}"
GPUS_PER_NODE=${GPUS_PER_NODE}
SCRIPT_DIR="${SCRIPT_DIR}"
SLIME_ROOT="${SLIME_ROOT}"

export MAMBA_EXE='/root/.local/bin/micromamba'
export MAMBA_ROOT_PREFIX='/nfs_global/micromamba'

if [ -f "\$MAMBA_EXE" ]; then
    eval "\$(\$MAMBA_EXE shell hook --shell bash --root-prefix \$MAMBA_ROOT_PREFIX 2>/dev/null)"
    if [ \$? -eq 0 ]; then
        micromamba activate slime 2>/dev/null || {
            echo "ERROR: Could not activate slime environment"
            if ! command -v ray >/dev/null 2>&1; then
                exit 1
            fi
        }
    else
        echo "ERROR: Failed to initialize micromamba"
        exit 1
    fi
else
    echo "ERROR: micromamba not found at \$MAMBA_EXE"
    exit 1
fi

# Set up symlinks for editable packages
echo "Setting up editable package paths..."

if [ ! -d "/root/slime" ]; then
    if [ -d "/nfs_global/slime" ]; then
        ln -sf /nfs_global/slime /root/slime 2>/dev/null && echo "  ✓ Created /root/slime -> /nfs_global/slime" || echo "  ⚠ Could not create /root/slime symlink"
    fi
fi

if [ ! -d "/root/sglang" ]; then
    if [ -d "/nfs_global/sglang" ]; then
        ln -sf /nfs_global/sglang /root/sglang 2>/dev/null && echo "  ✓ Created /root/sglang -> /nfs_global/sglang" || echo "  ⚠ Could not create /root/sglang symlink"
    fi
fi

if [ ! -d "/root/Megatron-LM-core" ]; then
    if [ -d "/nfs_global/Megatron-LM-core" ]; then
        ln -sf /nfs_global/Megatron-LM-core /root/Megatron-LM-core 2>/dev/null && echo "  ✓ Created /root/Megatron-LM-core -> /nfs_global/Megatron-LM-core" || echo "  ⚠ Could not create /root/Megatron-LM-core symlink"
    fi
fi

if [ ! -d "/root/Megatron-LM" ]; then
    if [ -d "/nfs_global/Megatron-LM" ]; then
        ln -sf /nfs_global/Megatron-LM /root/Megatron-LM 2>/dev/null && echo "  ✓ Created /root/Megatron-LM -> /nfs_global/Megatron-LM" || echo "  ⚠ Could not create /root/Megatron-LM symlink"
    fi
fi

export PYTHONPATH="/root/Megatron-LM/:/root/Megatron-LM-core:\${SCRIPT_DIR}:\${SLIME_ROOT}:/root/slime:/root/sglang/python:/nfs_global/projects/verl:/nfs_global/projects/verl/eda_tools"
export CUDA_DEVICE_MAX_CONNECTIONS=1

if ! command -v ray >/dev/null 2>&1; then
    echo "ERROR: ray command not found. Make sure slime environment is activated."
    exit 1
fi

ray stop --force 2>/dev/null || true
sleep 2

RAY_RUNTIME_DIR="/tmp/ray"
mkdir -p "\$RAY_RUNTIME_DIR"
if [ -d "\$RAY_RUNTIME_DIR" ]; then
    find "\$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
fi

echo "Waiting for master Ray node to be ready..."
MAX_WAIT=60
WAITED=0
while [ \$WAITED -lt \$MAX_WAIT ]; do
    if ray status --address="\$RAY_ADDRESS" 2>/dev/null | grep -qE '(Healthy|ALIVE|Active|node)'; then
        echo "Master Ray node is ready!"
        break
    fi
    sleep 2
    WAITED=\$((WAITED + 2))
done

if [ \$WAITED -ge \$MAX_WAIT ]; then
    echo "ERROR: Master Ray node at \$RAY_ADDRESS is not ready after \${MAX_WAIT} seconds"
    exit 1
fi

echo "Connecting to Ray cluster at \$RAY_ADDRESS..."
mkdir -p /nfs_global/tmp/ray_spill
ray start --address="\$RAY_ADDRESS" \
    --num-gpus \$GPUS_PER_NODE \
    --disable-usage-stats \
    --object-spilling-directory=/nfs_global/tmp/ray_spill \
    2>&1

if [ \$? -ne 0 ]; then
    echo "ERROR: Failed to start Ray worker node"
    exit 1
fi

echo "Ray worker node started successfully"
EOF

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start Ray worker node on ${WORKER_ADDR}"
    exit 1
fi

echo "✓ Ray worker node started successfully"

sleep 5

echo ""
echo "Ray cluster status:"
ray status

NODE_COUNT=$(ray status 2>/dev/null | grep -c "node_" || echo "0")
if [ "$NODE_COUNT" -lt "$NUM_NODES" ]; then
    echo "Warning: Expected ${NUM_NODES} nodes, but found ${NODE_COUNT} nodes"
    echo "Waiting a bit longer for worker node to connect..."
    sleep 10
    ray status
fi

echo ""
echo "SANDBOX_URL for Ray workers: ${SANDBOX_URL}"
echo "  (SandboxFusion server is listening on ${SANDBOX_HOST}:${SANDBOX_PORT})"
echo ""

RUNTIME_ENV_JSON="{
  \"env_vars\": {
    \"PYTHONPATH\": \"/root/Megatron-LM/:/root/Megatron-LM-core:${SCRIPT_DIR}:${SLIME_ROOT}:/root/slime:/root/sglang/python:/nfs_global/projects/verl:/nfs_global/projects/verl/eda_tools\",
    \"CUDA_DEVICE_MAX_CONNECTIONS\": \"1\",
    \"SANDBOX_URL\": \"${SANDBOX_URL}\",
    \"NCCL_SOCKET_IFNAME\": \"${NETWORK_INTERFACE}\",
    \"GLOO_SOCKET_IFNAME\": \"${NETWORK_INTERFACE}\",
    \"NCCL_IB_DISABLE\": \"${NCCL_IB_DISABLE}\"
  }
}"

# Submit Ray job
echo "=========================================="
echo "Submitting Ray job..."
echo "=========================================="
TEMP_JOB_OUTPUT=$(mktemp)
CLEANUP_TEMP_FILE="rm -f $TEMP_JOB_OUTPUT"
trap "$CLEANUP_TEMP_FILE; cleanup" EXIT INT TERM

if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL ray job submit --address="http://127.0.0.1:${RAY_DASHBOARD_PORT}" \
       --runtime-env-json="${RUNTIME_ENV_JSON}" \
       -- python3 ${SLIME_ROOT}/train.py \
       --actor-num-nodes ${NUM_NODES} \
       --actor-num-gpus-per-node ${GPUS_PER_NODE} \
       --colocate \
       ${MODEL_ARGS[@]} \
       ${CKPT_ARGS[@]} \
       ${ROLLOUT_ARGS[@]} \
       ${OPTIMIZER_ARGS[@]} \
       ${GRPO_ARGS[@]} \
       ${WANDB_ARGS[@]} \
       ${PERF_ARGS[@]} \
       ${SGLANG_ARGS[@]} \
       ${MISC_ARGS[@]} \
       ${CUSTOM_ARGS[@]} 2>&1 | stdbuf -oL -eL tee "$TEMP_JOB_OUTPUT"
else
    ray job submit --address="http://127.0.0.1:${RAY_DASHBOARD_PORT}" \
       --runtime-env-json="${RUNTIME_ENV_JSON}" \
       -- python3 ${SLIME_ROOT}/train.py \
       --actor-num-nodes ${NUM_NODES} \
       --actor-num-gpus-per-node ${GPUS_PER_NODE} \
       --colocate \
       ${MODEL_ARGS[@]} \
       ${CKPT_ARGS[@]} \
       ${ROLLOUT_ARGS[@]} \
       ${OPTIMIZER_ARGS[@]} \
       ${GRPO_ARGS[@]} \
       ${WANDB_ARGS[@]} \
       ${PERF_ARGS[@]} \
       ${SGLANG_ARGS[@]} \
       ${MISC_ARGS[@]} \
       ${CUSTOM_ARGS[@]} 2>&1 | tee "$TEMP_JOB_OUTPUT"
fi
JOB_SUBMIT_EXIT_CODE=${PIPESTATUS[0]}

RAY_JOB_ID=$(grep -oP "raysubmit_\w+" "$TEMP_JOB_OUTPUT" | head -1)

if [ $JOB_SUBMIT_EXIT_CODE -ne 0 ] || [ -z "$RAY_JOB_ID" ]; then
    echo "" >&2
    echo "ERROR: Failed to submit Ray job or extract job ID" >&2
    echo "Exit code: $JOB_SUBMIT_EXIT_CODE" >&2
    echo "Job output:" >&2
    cat "$TEMP_JOB_OUTPUT" >&2
    rm -f "$TEMP_JOB_OUTPUT"
    exit 1
fi

rm -f "$TEMP_JOB_OUTPUT"
trap cleanup EXIT INT TERM

echo ""
echo "=========================================="
echo "✓ Ray job submitted successfully!"
echo "Job ID: $RAY_JOB_ID"
echo "=========================================="
echo "Following job logs (press Ctrl+C to stop following, job will continue running)..."
echo "To view logs later, use: ray job logs $RAY_JOB_ID"
echo "To check job status, use: ray job status $RAY_JOB_ID"
echo "To stop job, use: ray job stop $RAY_JOB_ID"
echo "=========================================="
echo ""

export PYTHONUNBUFFERED=1

if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL ray job logs --address="http://127.0.0.1:${RAY_DASHBOARD_PORT}" --follow "$RAY_JOB_ID" 2>&1
else
    ray job logs --address="http://127.0.0.1:${RAY_DASHBOARD_PORT}" --follow "$RAY_JOB_ID" 2>&1
fi
LOGS_EXIT_CODE=$?

if [ $LOGS_EXIT_CODE -ne 0 ]; then
    echo "" >&2
    echo "Ray job logs command exited with code: $LOGS_EXIT_CODE" >&2
    JOB_STATUS_OUTPUT=$(ray job status --address="http://127.0.0.1:${RAY_DASHBOARD_PORT}" "$RAY_JOB_ID" 2>/dev/null || echo "UNKNOWN")
    JOB_STATUS=$(echo "$JOB_STATUS_OUTPUT" | grep -i "status" | head -1 || echo "UNKNOWN")
    echo "Ray job status: $JOB_STATUS" >&2
    if echo "$JOB_STATUS" | grep -qi "running\|pending"; then
        echo "Job is still running. Logs following was interrupted but job continues." >&2
        echo "To view logs: ray job logs $RAY_JOB_ID" >&2
        echo "To check status: ray job status $RAY_JOB_ID" >&2
        echo "To stop job: ray job stop $RAY_JOB_ID" >&2
    fi
fi

