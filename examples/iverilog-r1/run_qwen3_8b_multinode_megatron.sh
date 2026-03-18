#!/bin/bash

# Multi-node training script for Iverilog-R1 with Qwen3-1.7B (Slurm Mode)
set -e

# Source bashrc
. ~/.bashrc 2>/dev/null || true

# Increase file descriptor limit
ulimit -n 65536 2>/dev/null || true
echo "Current ulimit -n: $(ulimit -n)"

ulimit -l unlimited
##  otherwise it will result in an insufficient virtual memory size error, especially when loading LLM:
ulimit -v unlimited
ulimit -n 65535
ulimit -u 4125556

# Initialize conda/micromamba
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook 2>/dev/null)" || true
fi

if [ -f "/workspace/S/shiwenxuan/bin/micromamba" ]; then
    export MAMBA_EXE='/workspace/S/shiwenxuan/bin/micromamba'
    export MAMBA_ROOT_PREFIX='/nfs_global/S/shiwenxuan/micromamba'
    eval "$($MAMBA_EXE shell hook --shell bash --root-prefix $MAMBA_ROOT_PREFIX 2>/dev/null)" || true
    
    if [ -d "/workspace/S/shiwenxuan/envs/slime" ]; then
        micromamba activate /workspace/S/shiwenxuan/envs/slime
    else
        micromamba activate slime || true
    fi
fi

# === Fix GLIBCXX Version Mismatch ===
# Force use of Conda's newer libstdc++.so.6 instead of system's old GCC 9.3.0
export LD_LIBRARY_PATH="${CONDA_PREFIX:-/workspace/S/shiwenxuan/envs/slime}/lib:${LD_LIBRARY_PATH}"
echo "Updated LD_LIBRARY_PATH to include Conda lib: ${LD_LIBRARY_PATH}"

# Disable output buffering
export PYTHONUNBUFFERED=1
if [ -t 1 ]; then
    export PYTHONIOENCODING=utf-8
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SLIME_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"

# === Disable HTTP proxy ===
unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY ftp_proxy FTP_PROXY
export no_proxy="127.0.0.1,localhost,0.0.0.0,::1,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,*.local,*.future.cn"
export NO_PROXY="$no_proxy"
# Force Ray to ignore proxy settings
export RAY_AGENT_DISABLE_HTTP_PROXY=1

echo "=== Environment Network Settings ==="
env | grep -iE "proxy|addr|port|ray" | sort
echo "=================================="

# === Path settings ===
echo "=== Checking Shared Memory ==="
df -h /dev/shm
echo "=============================="

JOB_ID=${SLURM_JOB_ID:-manual}
JOB_ID_SHORT=$(echo "${JOB_ID}" | cut -c1-6)
HOST_HASH=$(hostname | md5sum | cut -c1-6)

# 1. Python/Exec Tmp Dir
EXEC_ROOT_DIR="/workspace/S/shiwenxuan/tmp/job_${JOB_ID_SHORT}"
NODE_EXEC_TMP_DIR="${EXEC_ROOT_DIR}/${HOST_HASH}"

mkdir -p "$EXEC_ROOT_DIR"
mkdir -p "$NODE_EXEC_TMP_DIR"

if [ ! -d "$NODE_EXEC_TMP_DIR" ]; then
    echo "ERROR: Failed to create $NODE_EXEC_TMP_DIR"
    NODE_EXEC_TMP_DIR="/tmp/exec_${JOB_ID_SHORT}_${HOST_HASH}"
    mkdir -p "$NODE_EXEC_TMP_DIR"
fi

export TMPDIR=$NODE_EXEC_TMP_DIR
export TMP=$NODE_EXEC_TMP_DIR
export TEMP=$NODE_EXEC_TMP_DIR

export TRITON_CACHE_DIR="$NODE_EXEC_TMP_DIR/triton_cache"
export TORCH_EXTENSIONS_DIR="$NODE_EXEC_TMP_DIR/torch_extensions"
export SGLANG_TMPDIR="$NODE_EXEC_TMP_DIR/sglang_tmp"
mkdir -p $TORCH_EXTENSIONS_DIR $TRITON_CACHE_DIR $SGLANG_TMPDIR

# 2. Ray Tmp Dir (Local)
RAY_TMP_DIR="/tmp/r_${JOB_ID_SHORT}"
rm -rf $RAY_TMP_DIR
mkdir -p $RAY_TMP_DIR
export RAY_TMPDIR=$RAY_TMP_DIR

# 3. Ray Spill Dir
USER_DATA_DIR="/workspace/S/shiwenxuan/tmp"
RAY_SPILL_DIR="$USER_DATA_DIR/ray_spill"
mkdir -p $RAY_SPILL_DIR

echo "Node Hostname: $(hostname)"
echo "Python TMP: $NODE_EXEC_TMP_DIR"
echo "Ray TMP:    $RAY_TMP_DIR"

# === Disable DeepGEMM ===
export SGLANG_DISABLE_DEEPGEMM=1
export SGLANG_DISABLE_FLASHINFER_SAMPLING=1

# === Port Configuration ===
MASTER_PORT=${MASTER_PORT:-59553}
RAY_GCS_PORT=$MASTER_PORT

if [ "$MASTER_PORT" -gt 10000 ]; then
    DASHBOARD_PORT=$(($MASTER_PORT-10000))
    DAL_PORT=$(($MASTER_PORT-20000))
    RCS_PORT=$(($MASTER_PORT-30000))
    RS_PORT=$(($MASTER_PORT-5000))
    NM_PORT=$(($MASTER_PORT-15000))
    OM_PORT=$(($MASTER_PORT-25000))
else
    RAY_GCS_PORT=6379
    DASHBOARD_PORT=8265
    DAL_PORT=52365
    RCS_PORT=10001
    RS_PORT=55000
    NM_PORT=45000
    OM_PORT=46000
fi
RAY_DASHBOARD_PORT=$DASHBOARD_PORT

SANDBOX_PORT=${SANDBOX_PORT:-8181}
SGLANG_ROUTER_PORT=${SGLANG_ROUTER_PORT:-3001}

# === Network Interface Detection (Robust) ===
get_valid_iface() {
    # Check for InfiniBand (IPoIB)
    if command -v ibdev2netdev >/dev/null 2>&1; then
        IB_IF=$(ibdev2netdev | grep Up | grep ib | head -1 | awk '{print $5}')
        if [ ! -z "$IB_IF" ]; then
            # Verify it has an IP
            if ip addr show "$IB_IF" | grep -q "inet"; then
                echo "$IB_IF"
                return
            fi
        fi
    fi
    
    # Check common interfaces in order of preference
    for iface in bond0 eth0 ib0 eno1 enp0s3; do
        if ip link show "$iface" >/dev/null 2>&1; then
             # Verify it has an IP (important!)
             if ip addr show "$iface" | grep -q "inet"; then
                 echo "$iface"
                 return
             fi
        fi
    done
    
    # Fallback: Default route interface
    ip route | grep default | awk '{print $5}' | head -1
}

if [ -z "$NETWORK_INTERFACE" ]; then
    NETWORK_INTERFACE=$(get_valid_iface)
fi
# Fallback to eth0 if detection completely fails
NETWORK_INTERFACE=${NETWORK_INTERFACE:-"eth0"}

echo "Using Network Interface: $NETWORK_INTERFACE"

# Export for Ray/NCCL/Gloo
export NCCL_SOCKET_IFNAME=$NETWORK_INTERFACE
export GLOO_SOCKET_IFNAME=$NETWORK_INTERFACE
export TP_SOCKET_IFNAME=$NETWORK_INTERFACE # SGLang specific

# === Node Configuration ===
if [ ! -z "$SLURM_JOB_NODELIST" ]; then
    echo "Running under SLURM environment"
    NODE_LIST=($(scontrol show hostnames $SLURM_JOB_NODELIST))
    MASTER_ADDR=${MASTER_ADDR:-${NODE_LIST[0]}}
    NUM_NODES=${#NODE_LIST[@]}
    GPUS_PER_NODE=${SLURM_GPUS_ON_NODE:-8}
    NODE_RANK=${NODE_RANK:-${SLURM_NODEID:-0}}
    export NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-"0"}
else
    echo "Running in manual multi-node mode"
    MASTER_ADDR=${MASTER_ADDR:-"10.21.0.3"}
    NUM_NODES=${NUM_NODES:-2}
    GPUS_PER_NODE=${GPUS_PER_NODE:-8}
    NODE_RANK=${NODE_RANK:-0}
    export NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-"1"}
fi

# Cleanup Function
cleanup_worker_nodes() {
    echo "Cleaning up Ray processes..."
    ray stop --force 2>/dev/null || true
    pkill -f 'ray' 2>/dev/null || true
    pkill -f 'sglang' 2>/dev/null || true
    pkill -f 'sandbox' 2>/dev/null || true
    
    for port in $RAY_GCS_PORT $DASHBOARD_PORT $SANDBOX_PORT $SGLANG_ROUTER_PORT; do
        if [ ! -z "$port" ]; then
            lsof -ti:$port | xargs kill -9 2>/dev/null || true
        fi
    done
    # rm -rf "$RAY_TMP_DIR" 2>/dev/null || true
    rm -rf "$NODE_EXEC_TMP_DIR" 2>/dev/null || true
}

trap cleanup_worker_nodes EXIT INT TERM

# Initial cleanup
cleanup_worker_nodes
sleep 2

# === IP Address ===
# HOST_IP=$(hostname -I | awk '{print $1}')
HOST_IP=$(ip -4 addr show "$NETWORK_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [ -z "$HOST_IP" ]; then
    echo "WARNING: Could not find IP for interface $NETWORK_INTERFACE, falling back to hostname -I"
    HOST_IP=$(hostname -I | awk '{print $1}')
fi
echo "Node IP: $HOST_IP"

SANDBOX_HOST=${SANDBOX_HOST:-"0.0.0.0"}
if [ "$NODE_RANK" -eq 0 ]; then
    MASTER_IP=$HOST_IP
else
    # Try to resolve MASTER_ADDR to IP
    RESOLVED=$(getent hosts $MASTER_ADDR | awk '{print $1}' | head -1)
    if [ ! -z "$RESOLVED" ]; then
        MASTER_IP=$RESOLVED
    else
        MASTER_IP=$MASTER_ADDR
    fi
fi
SANDBOX_URL="http://${MASTER_IP}:${SANDBOX_PORT}/run_code"

# === Start SandboxFusion (Master Only) ===
if [ "$NODE_RANK" -eq 0 ]; then
    echo "Starting SandboxFusion server..."
    # Using path from original script
    SANDBOX_DIR="/workspace/S/shiwenxuan/verl/SandboxFusion"
    
    if [ ! -d "$SANDBOX_DIR" ]; then
        echo "ERROR: SandboxFusion directory not found at $SANDBOX_DIR"
        exit 1
    fi

    (
        # Use conda to activate sandbox-runtime (conda hook already initialized)
        if command -v conda >/dev/null 2>&1; then
             conda activate sandbox-runtime 2>/dev/null || echo "WARNING: Could not activate sandbox-runtime env"
        fi
        
        cd "$SANDBOX_DIR"
        mkdir -p "$NODE_EXEC_TMP_DIR"
        nohup uvicorn sandbox.server.server:app --host ${SANDBOX_HOST} --port ${SANDBOX_PORT} > "${NODE_EXEC_TMP_DIR}/sandbox_fusion.log" 2>&1 &
    )
    
    for i in {1..30}; do
        if curl -s http://127.0.0.1:${SANDBOX_PORT}/health >/dev/null 2>&1 || \
           curl -s http://127.0.0.1:${SANDBOX_PORT}/ > /dev/null 2>&1 || \
           curl -s http://127.0.0.1:${SANDBOX_PORT}/run_code > /dev/null 2>&1; then
            echo "✓ SandboxFusion server is ready!"
            break
        fi
        sleep 1
    done
else
    sleep 5
fi

# === Model Config ===
# Specific to Qwen3-1.7B (using paths from original script)
MODEL_PATH=/nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/87k_sft_8.1k_ds32_10epochs/checkpoint-1270
DATA_PATH=/nfs_global/S/shiwenxuan/verl/data/codev/v1/cvdp_claude_256

export TOKENIZERS_PARALLELISM=false
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
# export USE_DIRECT_SANDBOX_API=true
export IVERILOG_EXECUTION_METHOD=local_iverilog
export SANDBOX_FUSION_CONCURRENCY=32
# Also set IVERILOG_URL for backward compatibility
export IVERILOG_URL="${SANDBOX_URL}"
# Set iverilog executable path
export IVERILOG_PATH="${IVERILOG_PATH:-/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/iverilog}"
# Set vvp executable path (optional, defaults to same directory as iverilog)
export VVP_PATH="${VVP_PATH:-/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/vvp}"
# Set iverilog temporary directory (optional, defaults to /nfs_global/S/shiwenxuan/tmp/iverilog_tmp)
export IVERILOG_TMP_DIR="${IVERILOG_TMP_DIR:-/workspace/S/shiwenxuan/tmp/iverilog_tmp}"

MODEL_ARGS=(
   --swiglu
   --num-layers 36
   --hidden-size 4096
   --ffn-hidden-size 12288
   --num-attention-heads 32
   --group-query-attention
   --num-query-groups 8
   --use-rotary-position-embeddings
   --disable-bias-linear
   --normalization "RMSNorm"
   --norm-epsilon 1e-6
   --rotary-base "${MODEL_ARGS_ROTARY_BASE:-1000000}"
   --vocab-size 151936
   --kv-channels 128
   --qk-layernorm
   --untie-embeddings-and-output-weights
)

CKPT_ARGS=(
   --hf-checkpoint ${MODEL_PATH}
   --ref-load /nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/87k_sft_8.1k_ds32_10epochs/checkpoint-1270_torch_dist
   --load /nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/87k_sft_8.1k_ds32_10epochs/checkpoint-1270_torch_dist
   --save /nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/87k_sft_8.1k_ds32_10epochs/checkpoint-1270_torch_dist
   --save-interval 10
)

ROLLOUT_ARGS=(
   --prompt-data ${DATA_PATH}/train.parquet
   --input-key prompt
   --label-key reward_model
   --tool-key tools
   --apply-chat-template
   --rollout-shuffle
   --num-rollout 1000  
   --rollout-batch-size 16
   --n-samples-per-prompt 8
   --rollout-max-response-len 30000
   --rollout-max-context-len 36000
   --over-sampling-batch-size 16
   --dynamic-sampling-filter-path slime.rollout.filter_hub.dynamic_sampling_filters.check_reward_nonzero_std
   --rollout-temperature 1.0
   --start-rollout-id 0

   --eval-interval 10
   --eval-prompt-data codev_test ${DATA_PATH}/test.parquet
   --eval-input-key prompt
   --eval-label-key reward_model
   --eval-tool-key tools
   --n-samples-per-eval-prompt 1
   --eval-max-response-len 30000
   --eval-max-context-len 36000

   --global-batch-size 128
   --balance-data
)

PERF_ARGS=(
   --tensor-model-parallel-size 8
   --sequence-parallel
   --pipeline-model-parallel-size 1
   --context-parallel-size 2
   --expert-model-parallel-size 1
   --expert-tensor-parallel-size 1
   --recompute-granularity full
   --recompute-method uniform
   --recompute-num-layers 1

   --use-dynamic-batch-size
   --max-tokens-per-gpu 36000
)

GRPO_ARGS=(
   --advantage-estimator grpo
   --kl-loss-coef 0.00
   --kl-loss-type low_var_kl
   --entropy-coef 0.00
   --eps-clip 0.2
   --eps-clip-high 0.28
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
   --wandb-project verl_onpolicy_modified_format_reward_slime_test
   --wandb-group codev_onpolicy_modified_format_reward_slime_test
   ${WANDB_API_KEY:+--wandb-key "${WANDB_API_KEY}"}
)

SGLANG_ARGS=(
   --rollout-num-gpus-per-engine 8
   --sglang-mem-fraction-static 0.5
   --sglang-cuda-graph-bs 1 2 4 8 $(seq 16 8 256)
   --sglang-router-ip ${MASTER_IP}
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
   --custom-generate-function-path generate_with_iverilog.generate
   --custom-rm-path generate_with_iverilog.reward_func
   --eval-function-path custom_eval_cvdp.custom_eval_cvdp
)

# === Start Ray ===
# Limit object store memory to avoid mmap errors in restricted Slurm environments
# 50GB should be sufficient
OBJECT_STORE_MEMORY=$((20 * 1024 * 1024 * 1024))

if [ "$NODE_RANK" -eq 0 ]; then
    echo "Starting Ray Head on ${HOST_IP}..."
    ray start --head \
        --node-ip-address ${HOST_IP} \
        --port=$RAY_GCS_PORT \
        --redis-shard-ports $RS_PORT \
        --node-manager-port $NM_PORT \
        --object-manager-port $OM_PORT \
        --dashboard-port $DASHBOARD_PORT \
        --dashboard-agent-listen-port $DAL_PORT \
        --ray-client-server-port $RCS_PORT \
        --num-gpus ${GPUS_PER_NODE} \
        --object-store-memory ${OBJECT_STORE_MEMORY} \
        --disable-usage-stats \
        --dashboard-host=0.0.0.0 \
        --temp-dir=$RAY_TMP_DIR \
        --object-spilling-directory=$RAY_SPILL_DIR
        
    echo "Waiting for Ray Head..."
    sleep 5
    if ! ray status >/dev/null 2>&1; then
        echo "ERROR: Ray Head failed to start!"
        exit 1
    fi
    echo "✓ Ray Head started."
    # Create a ready flag file for Slurm synchronization (in shared dir)
    touch "${EXEC_ROOT_DIR}/ray_head_ready"
    RAY_DASHBOARD_URL="http://${HOST_IP}:${DASHBOARD_PORT}"
else
    echo "Starting Ray Worker..."
    # Wait loop
    for i in {1..30}; do sleep 2; done
    
    ray start --address="${MASTER_IP}:${RAY_GCS_PORT}" \
        --node-ip-address="${HOST_IP}" \
        --node-manager-port $NM_PORT \
        --object-manager-port $OM_PORT \
        --dashboard-agent-listen-port $DAL_PORT \
        --num-gpus ${GPUS_PER_NODE} \
        --object-store-memory ${OBJECT_STORE_MEMORY} \
        --disable-usage-stats \
        --temp-dir=$RAY_TMP_DIR \
        --object-spilling-directory=$RAY_SPILL_DIR
        
    if [ $? -ne 0 ]; then exit 1; fi
    echo "✓ Ray Worker started."
    while true; do
        sleep 10
        if ! ray status --address="${MASTER_IP}:${RAY_GCS_PORT}" >/dev/null 2>&1; then break; fi
    done
    exit 0
fi

# === Submit Job (Master Only) ===
if [ "$NODE_RANK" -eq 0 ]; then
    echo "Waiting for $NUM_NODES nodes..."
    while true; do
        NODE_COUNT=$(ray status 2>/dev/null | grep -c "node_" || echo "0")
        if [ "$NODE_COUNT" -ge "$NUM_NODES" ]; then break; fi
        sleep 2
    done
    
    # Use 127.0.0.1 for local job submission to avoid networking/proxy issues
    LOCAL_DASHBOARD_URL="http://127.0.0.1:${DASHBOARD_PORT}"

    echo "Checking Dashboard API (via localhost)..."
    for i in {1..30}; do
        if curl -s "${LOCAL_DASHBOARD_URL}/api/version" >/dev/null 2>&1; then 
            echo "✓ Dashboard API is ready on localhost!"
            break
        fi
        sleep 2
    done
    
    # Wait for Dashboard Agent Port explicitly
    echo "Waiting for Dashboard Agent to listen on port ${DAL_PORT}..."
    for i in {1..30}; do
        if lsof -i :${DAL_PORT} >/dev/null 2>&1; then
             echo "✓ Dashboard Agent is listening on port ${DAL_PORT}!"
             break
        fi
        sleep 1
    done
    
    # Extra safety sleep for internal connectivity
    sleep 5

    # IMPORTANT: Explicitly pass NCCL/Gloo environment variables
    # Including IVERILOG_URL and specific env vars
    RUNTIME_ENV_JSON=$(jq -n \
        --arg PYTHONPATH "/workspace/S/shiwenxuan/sglang/sgl-model-gateway/bindings/python:/workspace/S/shiwenxuan/Megatron-LM/:${SCRIPT_DIR}:${SLIME_ROOT}:/workspace/S/shiwenxuan/slime:/workspace/S/shiwenxuan/sglang/python:/workspace/S/shiwenxuan/verl:/workspace/S/shiwenxuan/verl/eda_tools" \
        --arg CUDA_DEVICE_MAX_CONNECTIONS "1" \
        --arg SANDBOX_URL "${SANDBOX_URL}" \
        --arg IVERILOG_URL "${IVERILOG_URL}" \
        --arg IVERILOG_EXECUTION_METHOD "${IVERILOG_EXECUTION_METHOD}" \
        --arg IVERILOG_PATH "${IVERILOG_PATH}" \
        --arg VVP_PATH "${VVP_PATH}" \
        --arg IVERILOG_TMP_DIR "${IVERILOG_TMP_DIR}" \
        --arg SANDBOX_FUSION_CONCURRENCY "${SANDBOX_FUSION_CONCURRENCY}" \
        --arg NCCL_SOCKET_IFNAME "${NETWORK_INTERFACE}" \
        --arg GLOO_SOCKET_IFNAME "${NETWORK_INTERFACE}" \
        --arg TP_SOCKET_IFNAME "${NETWORK_INTERFACE}" \
        --arg NCCL_IB_DISABLE "${NCCL_IB_DISABLE}" \
        --arg NO_PROXY "${NO_PROXY}" \
        --arg no_proxy "${no_proxy}" \
        --arg YOSYS_PATH "/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/yosys" \
        '{
            "env_vars": {
                "PYTHONPATH": $PYTHONPATH,
                "CUDA_DEVICE_MAX_CONNECTIONS": $CUDA_DEVICE_MAX_CONNECTIONS,
                "SANDBOX_URL": $SANDBOX_URL,
                "IVERILOG_URL": $IVERILOG_URL,
                "IVERILOG_EXECUTION_METHOD": $IVERILOG_EXECUTION_METHOD,
                "IVERILOG_PATH": $IVERILOG_PATH,
                "VVP_PATH": $VVP_PATH,
                "IVERILOG_TMP_DIR": $IVERILOG_TMP_DIR,
                "SANDBOX_FUSION_CONCURRENCY": $SANDBOX_FUSION_CONCURRENCY,
                "NCCL_SOCKET_IFNAME": $NCCL_SOCKET_IFNAME,
                "GLOO_SOCKET_IFNAME": $GLOO_SOCKET_IFNAME,
                "TP_SOCKET_IFNAME": $TP_SOCKET_IFNAME,
                "NCCL_IB_DISABLE": $NCCL_IB_DISABLE,
                "NO_PROXY": $NO_PROXY,
                "no_proxy": $no_proxy,
                "YOSYS_PATH": $YOSYS_PATH
            }
        }')

    echo "Submitting Ray Job (with retry) via ${LOCAL_DASHBOARD_URL}..."
    
    # Retry loop for job submission
    MAX_RETRIES=1
    RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if ray job submit --address="${LOCAL_DASHBOARD_URL}" \
           --runtime-env-json="${RUNTIME_ENV_JSON}" \
           -- python3 ${SLIME_ROOT}/train.py \
           --actor-num-nodes ${NUM_NODES} \
           --actor-num-gpus-per-node ${GPUS_PER_NODE} \
           --colocate \
           ${MODEL_ARGS[@]} ${CKPT_ARGS[@]} ${ROLLOUT_ARGS[@]} \
           ${OPTIMIZER_ARGS[@]} ${GRPO_ARGS[@]} ${WANDB_ARGS[@]} \
           ${PERF_ARGS[@]} ${SGLANG_ARGS[@]} ${MISC_ARGS[@]} ${CUSTOM_ARGS[@]}; then
           
           echo "✓ Job submitted successfully."
           break
        else
           echo "WARNING: Job submission failed (Attempt $(($RETRY_COUNT + 1))/$MAX_RETRIES). Retrying in 5 seconds..."
           RETRY_COUNT=$(($RETRY_COUNT + 1))
           sleep 5
        fi
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "ERROR: Failed to submit job after $MAX_RETRIES attempts."
        exit 1
    fi
       
    # Log tailing
    sleep 10
    RAY_JOB_ID=$(ray job list --address="${LOCAL_DASHBOARD_URL}" | grep "RUNNING" | awk '{print $1}' | head -1)
    if [ ! -z "$RAY_JOB_ID" ]; then
        ray job logs --address="${LOCAL_DASHBOARD_URL}" --follow "$RAY_JOB_ID"
    fi
fi
