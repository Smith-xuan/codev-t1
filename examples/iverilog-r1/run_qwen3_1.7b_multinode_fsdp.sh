#!/bin/bash

# Multi-node training script for Iverilog-R1 with Qwen3-1.7B
# This script runs training on 2 nodes with 8 GPUs each (16 GPUs total)
# Worker node is accessed via SSH at 10.21.0.12

# Use set -e to exit on error, but don't use -x to avoid excessive debug output
# We'll use explicit echo statements for important messages
set -e

# Disable output buffering for immediate display
export PYTHONUNBUFFERED=1
if [ -t 1 ]; then
    # If stdout is a terminal, disable line buffering
    export PYTHONIOENCODING=utf-8
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SLIME_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"

# === 修改 1: 路径设置 ===
# 必须改回使用本地路径，因为 Ray 需要本地 Socket
# 15GB 空间对于不带 DeepGEMM 编译的 Ray 运行来说通常是够用的
export TMPDIR=/tmp
export TMP=/tmp
export TEMP=/tmp
export RAY_TMPDIR=/tmp

# === 修改 2: 禁用 DeepGEMM ===
# 禁用 DeepGEMM 以避免 JIT 编译产生大量临时文件填满 /tmp
export SGLANG_DISABLE_DEEPGEMM=1
# 同时也禁用 FlashInfer 的 JIT (如果开启的话)，防止类似问题
export SGLANG_DISABLE_FLASHINFER_SAMPLING=1

# === 修改 3: 将编译缓存重定向到 NFS (双重保险) ===
# 如果还有其他的 JIT 编译（如 Triton），让它们去 NFS 上生成文件
# 编译后的文件是静态的，放在 NFS 上没有问题，不像 Socket
export TRITON_CACHE_DIR="/tmp/triton_cache"
export TORCH_EXTENSIONS_DIR="/tmp/torch_extensions"

# SGLang 的临时目录也建议放回本地，除非它产生大文件
export SGLANG_TMPDIR="/tmp/sglang_tmp"
mkdir -p $TORCH_EXTENSIONS_DIR $TRITON_CACHE_DIR $SGLANG_TMPDIR

# === 修改 4: Ray 对象溢出配置 ===
# 防止 Ray 对象溢出（Object Spilling）填满磁盘
# Socket 放在本地 /tmp，但如果数据太多要溢出，请写到 NFS 上
mkdir -p /nfs_global/tmp/ray_spill

# PID file to track processes started by this script
PID_FILE="${SCRIPT_DIR}/.run_qwen3_1.7b_multinode.pid"
RAY_DASHBOARD_PORT=8265
IVERILOG_PORT=${IVERILOG_PORT:-8000}
SGLANG_ROUTER_PORT=${SGLANG_ROUTER_PORT:-3000}  # Port for SGLang router

# Multi-node configuration
MASTER_ADDR=${MASTER_ADDR:-"10.21.0.3"}
WORKER_ADDR=${WORKER_ADDR:-"10.21.0.12"}
NUM_NODES=2
GPUS_PER_NODE=8
TOTAL_GPUS=$((NUM_NODES * GPUS_PER_NODE))

# Network interface configuration for distributed training
# Auto-detect network interface (eth0, ens3, etc.) that has the actual IP
# This ensures NCCL and Gloo use the correct network interface instead of loopback
NETWORK_INTERFACE=${NETWORK_INTERFACE:-"eth0"}
# If auto-detection is needed, uncomment the following lines:
# NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
# if [ -z "$NETWORK_INTERFACE" ]; then
#     NETWORK_INTERFACE="eth0"  # fallback
# fi

# Export NCCL and Gloo environment variables to use correct network interface
export NCCL_SOCKET_IFNAME=${NCCL_SOCKET_IFNAME:-"${NETWORK_INTERFACE}"}
export GLOO_SOCKET_IFNAME=${GLOO_SOCKET_IFNAME:-"${NETWORK_INTERFACE}"}
export NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-"1"}  # Disable InfiniBand if not available

# Note: Worker node requirements:
# 1. SSH access without username (ssh 10.21.0.12 should work)
# 2. Same Python environment with slime dependencies installed
# 3. Access to shared filesystem (/nfs_global)
# 4. Ray installed and available in PATH
# 5. Same CUDA/GPU drivers and libraries

# Ray will auto-assign ports, we'll get the address from ray status after starting
# Note: We don't specify --port to avoid port conflicts

echo "=========================================="
echo "Multi-node Training Configuration"
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
         # Also kill any processes using GPU that might be leftover SGLang processes
         if command -v nvidia-smi >/dev/null 2>&1; then \
             nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | grep -v '^$' | xargs kill -9 2>/dev/null || true; \
         fi" \
        2>/dev/null || echo "Warning: Could not cleanup worker node (may already be cleaned up)"
}

# Function to cleanup processes started by this script
cleanup_own_processes() {
    echo "Cleaning up processes started by this script..."
    
    # Cleanup worker node
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
    
    # Kill iverilog server processes related to this script (on our specific port)
    pkill -f "iverilog_server.py.*--port.*${IVERILOG_PORT}" 2>/dev/null || true
    pkill -f "uvicorn.*iverilog.*${IVERILOG_PORT}" 2>/dev/null || true
    
    # Kill SGLang processes that are part of this training job
    pkill -f "sglang.*train.py" 2>/dev/null || true
    pkill -f "python.*train.py.*iverilog" 2>/dev/null || true
    pkill -f "sglang.*scheduler" 2>/dev/null || true
    pkill -f "sglang::scheduler" 2>/dev/null || true
    pkill -f "sglang" 2>/dev/null || true
    # Also kill any processes using GPU that might be leftover SGLang processes
    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | grep -v '^$' | xargs kill -9 2>/dev/null || true
    fi
    
    # Stop Ray cluster on the specific dashboard port (if started by this script)
    if lsof -ti:${RAY_DASHBOARD_PORT} >/dev/null 2>&1; then
        echo "Stopping Ray cluster on port ${RAY_DASHBOARD_PORT}..."
        ray stop --address="http://127.0.0.1:${RAY_DASHBOARD_PORT}" --force 2>/dev/null || true
        sleep 2
        # Force kill Ray processes using this port
        lsof -ti:${RAY_DASHBOARD_PORT} 2>/dev/null | xargs kill -9 2>/dev/null || true
    fi
    
    # Also try to stop Ray without address (in case it's a head node)
    ray stop --force 2>/dev/null || true
    sleep 1
    
    # Kill Ray worker processes that are part of this job (identified by dashboard port)
    ps aux | grep -E "ray.*${RAY_DASHBOARD_PORT}|ray.*dashboard.*${RAY_DASHBOARD_PORT}" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    
    # Kill all Ray processes (but only if they're related to our port or if no other Ray is running)
    pkill -f "ray.*dashboard.*${RAY_DASHBOARD_PORT}" 2>/dev/null || true
    pkill -f "ray.*head.*${RAY_DASHBOARD_PORT}" 2>/dev/null || true
    
    # Clean up Ray runtime directory to avoid session conflicts
    # Only clean if we're sure no other Ray instance is running
    if ! pgrep -f "ray.*dashboard" >/dev/null 2>&1; then
        RAY_RUNTIME_DIR="/tmp/ray"
        if [ -d "$RAY_RUNTIME_DIR" ]; then
            echo "Cleaning up Ray runtime directory to avoid session conflicts..."
            # Only remove session directories, not the entire ray directory
            find "$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
        fi
    fi
}

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    
    # Check if Ray job is still running (if we have a job ID)
    if [ ! -z "$RAY_JOB_ID" ]; then
        JOB_STATUS_OUTPUT=$(ray job status --address="http://127.0.0.1:8265" "$RAY_JOB_ID" 2>/dev/null || echo "")
        JOB_STATUS=$(echo "$JOB_STATUS_OUTPUT" | grep -i "status" | head -1 || echo "")
        if echo "$JOB_STATUS" | grep -qi "running\|pending"; then
            echo "Warning: Ray job $RAY_JOB_ID is still running."
            echo "  The job will continue running in the background."
            echo "  To view logs: ray job logs $RAY_JOB_ID"
            echo "  To check status: ray job status $RAY_JOB_ID"
            echo "  To stop job: ray job stop $RAY_JOB_ID"
            echo ""
            echo "Skipping Ray cluster cleanup (job is still running)."
            echo "Only cleaning up iverilog server and local processes."
            SKIP_RAY_CLEANUP=true
        else
            SKIP_RAY_CLEANUP=false
        fi
    else
        SKIP_RAY_CLEANUP=false
    fi
    
    # Kill iverilog server if it was started by this script
    if [ ! -z "$IVERILOG_PID" ]; then
        echo "Stopping iverilog server (PID: $IVERILOG_PID)..."
        kill $IVERILOG_PID 2>/dev/null || true
        sleep 1
        kill -9 $IVERILOG_PID 2>/dev/null || true
    fi
    
    # Kill processes from PID file (but skip Ray processes if job is still running)
    if [ -f "$PID_FILE" ]; then
        while read pid; do
            if [ ! -z "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                # Check if this is a Ray process
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
        # Don't remove PID file if Ray job is still running (we might need it)
        if [ "$SKIP_RAY_CLEANUP" != "true" ]; then
            rm -f "$PID_FILE"
        fi
    fi
    
    # Also kill any iverilog server processes on our port
    if [ ! -z "$IVERILOG_PORT" ]; then
        pkill -f "iverilog_server.py.*--port.*${IVERILOG_PORT}" 2>/dev/null || true
        pkill -f "uvicorn.*iverilog.*${IVERILOG_PORT}" 2>/dev/null || true
    fi
    
    # Only cleanup Ray if job is not running
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

# will prevent ray from buffering stdout/stderr
export PYTHONBUFFERED=16

# Host IP address that Ray workers will use to access services
# This is the actual network IP of the host machine
HOST_IP=${HOST_IP:-"${MASTER_ADDR}"}

# Iverilog server configuration
IVERILOG_HOST=${IVERILOG_HOST:-"0.0.0.0"}
# IVERILOG_PORT is already defined above
# Use the host IP for IVERILOG_URL (Ray workers will use this to access the server)
IVERILOG_URL="http://${HOST_IP}:${IVERILOG_PORT}/run_code"

echo "Host IP for service access: ${HOST_IP}"
echo "IVERILOG_URL for Ray workers: ${IVERILOG_URL}"

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

# Verify network interface on worker node (should match master node)
echo "Verifying network interface on worker node..."
WORKER_INTERFACE=$(ssh -o StrictHostKeyChecking=no ${WORKER_ADDR} \
    "ip route | grep default | awk '{print \$5}' | head -1" 2>/dev/null || echo "")
if [ -z "$WORKER_INTERFACE" ]; then
    WORKER_INTERFACE=$(ssh -o StrictHostKeyChecking=no ${WORKER_ADDR} \
        "ip addr | grep -E '^[0-9]+:.*state UP' | grep -v lo | head -1 | awk '{print \$2}' | sed 's/://'" 2>/dev/null || echo "eth0")
fi
if [ "$WORKER_INTERFACE" != "$NETWORK_INTERFACE" ]; then
    echo "⚠ Warning: Worker node network interface ($WORKER_INTERFACE) differs from master ($NETWORK_INTERFACE)"
    echo "  This may cause issues. Consider setting NETWORK_INTERFACE environment variable."
    echo "  Master node: ${NETWORK_INTERFACE}, Worker node: ${WORKER_INTERFACE}"
else
    echo "✓ Network interface matches on both nodes: ${NETWORK_INTERFACE}"
fi

# Start iverilog server in background
echo ""
echo "=========================================="
echo "Starting iverilog server..."
echo "=========================================="
cd ${SCRIPT_DIR}

# Check if server is already running
if curl -s http://127.0.0.1:${IVERILOG_PORT}/docs > /dev/null 2>&1; then
    echo "Iverilog server is already running on port ${IVERILOG_PORT}"
else
    # Kill any existing iverilog server processes
    pkill -f "iverilog_server.py" 2>/dev/null || true
    pkill -f "uvicorn.*iverilog" 2>/dev/null || true
    sleep 2
    
    # Start iverilog server in background
    echo "Starting iverilog server on ${IVERILOG_HOST}:${IVERILOG_PORT}..."
    python3 ${SCRIPT_DIR}/iverilog_server.py --host ${IVERILOG_HOST} --port ${IVERILOG_PORT} > ${SCRIPT_DIR}/iverilog_server.log 2>&1 &
    IVERILOG_PID=$!
    echo "Iverilog server started with PID: ${IVERILOG_PID}"
    echo "Log file: ${SCRIPT_DIR}/iverilog_server.log"
    # Save PID to file for cleanup
    echo "${IVERILOG_PID}" >> "$PID_FILE"
    
    # Wait for server to be ready (max 30 seconds)
    echo "Waiting for iverilog server to be ready..."
    for i in $(seq 1 30); do
        if curl -s http://127.0.0.1:${IVERILOG_PORT}/docs > /dev/null 2>&1; then
            echo "✓ Iverilog server is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "⚠ Warning: Iverilog server may not be ready after 30 seconds"
            echo "Check the log file: ${SCRIPT_DIR}/iverilog_server.log"
        else
            sleep 1
        fi
    done
fi

echo "Iverilog server URL: ${IVERILOG_URL}"
echo "=========================================="
echo ""

# Model checkpoint paths (matching verl configuration)
# MODEL_PATH=/nfs_global/LLaMA-Factory/saves/qwen3-1.7b/full/tool_8.1k_ds32_resummrized_10epochs/checkpoint-1270
MODEL_PATH=/nfs_global/LLaMA-Factory/saves/qwen3-8b/full/tool_8.1k_ds32_10epochs/checkpoint-1270
DATA_PATH=/nfs_global/projects/verl/data/codev/v1/3.1k_r1_tool_with_tools

# Note: FSDP backend loads model from HuggingFace checkpoint directly,
# so we don't need MODEL_ARGS (Megatron-specific parameters like --swiglu, --num-layers, etc.)
CKPT_ARGS=(
   --hf-checkpoint ${MODEL_PATH}
   # --ref-load is not needed for FSDP backend, it loads from HF checkpoint directly
   # --load /path/to/saved/checkpoint
   # --save /path/to/save/checkpoint
   # --save-interval 50
)

ROLLOUT_ARGS=(
   --prompt-data ${DATA_PATH}/train.parquet
   --input-key prompt
   --label-key reward_model
   --tool-key tools
   --apply-chat-template
   --rollout-shuffle
   --num-rollout 3000  # Adjust based on your dataset size and epochs
   --rollout-batch-size 4
   --n-samples-per-prompt 8
   --rollout-max-response-len 30000  # Reduced to ensure input + output <= 40960 (model max context length)
   --rollout-max-context-len 36000    # Set to model's maximum context length
   --over-sampling-batch-size 16
   --dynamic-sampling-filter-path slime.rollout.filter_hub.dynamic_sampling_filters.check_reward_nonzero_std
   --rollout-temperature 1.0

   # eval args (optional)
#    --eval-interval 10
#    --eval-prompt-data codev_test ${DATA_PATH}/test.parquet
#    --eval-input-key prompt
#    --eval-label-key reward_model
#    --eval-tool-key tools
#    --n-samples-per-eval-prompt 1
#    --eval-max-response-len 25000  # Reduced for validation to ensure input + output <= 40960
#    --eval-max-context-len 36000    # Set to model's maximum context length

   --global-batch-size 32
   --balance-data
)

PERF_ARGS=(
   # FSDP2 backend configuration (matching verl's fsdp_config)
   --train-backend fsdp
   --gradient-checkpointing  # Matching verl's enable_gradient_checkpointing
   --context-parallel-size 2
   
   #--bf16  # Use bfloat16 precision (uncommented to reduce memory usage)
   # Note: FSDP2 doesn't use tensor/pipeline parallelism in the same way as Megatron
   # These args are ignored when using FSDP backend
   # --tensor-model-parallel-size 8
   # --sequence-parallel
   # --pipeline-model-parallel-size 1
   # --context-parallel-size 1
   # --expert-model-parallel-size 1
   # --expert-tensor-parallel-size 1
   # --recompute-granularity full
   # --recompute-method uniform
   # --recompute-num-layers 1

   --use-dynamic-batch-size
   --max-tokens-per-gpu 18000  # Matching verl's ppo_max_token_len_per_gpu
)

GRPO_ARGS=(
   --advantage-estimator grpo
   # --use-kl-loss  # Disabled to match verl's use_kl_loss=False, and to avoid requiring --ref-load
   --kl-loss-coef 0.00  # Set to 0.00 to match verl's configuration
   --kl-loss-type low_var_kl
   --entropy-coef 0.00
   --eps-clip 0.2
   --eps-clip-high 0.28

   # TIS-related args (optional)
   --use-tis
   # --custom-config-path examples/train_infer_mismatch_helper/mis.yaml
   # --custom-tis-function-path examples.train_infer_mismatch_helper.mis.compute_mis_weights_with_cp
)

OPTIMIZER_ARGS=(
   --optimizer adam
   --lr 1e-6  # Matching verl's actor.optim.lr
   --lr-decay-style constant
   --weight-decay 0.01
   --adam-beta1 0.9
   --adam-beta2 0.98
)

WANDB_ARGS=(
   --use-wandb
   --wandb-mode offline # 离线模式，不上传数据到wandb
   --wandb-project verl_onpolicy_modified_format_reward_slime  # Matching verl's project_name
   --wandb-group codev_onpolicy_modified_format_reward_slime   # Matching verl's experiment_name
   --wandb-key 'e8f26cb646aea4a12ef982270212804afa4fa31e'
)

SGLANG_ARGS=(
   --rollout-num-gpus-per-engine 8  # Each engine uses 8 GPUs per node
   --sglang-mem-fraction-static 0.5  # Reduced to 0.6 to leave more memory for FSDP in colocate mode
   --sglang-rl-on-policy-target fsdp  # Required when using FSDP backend for on-policy RL
   --sglang-mamba-ssm-dtype bfloat16
   --sglang-router-ip ${MASTER_ADDR}  # Router runs on master node, all nodes should use master IP
   --sglang-router-port ${SGLANG_ROUTER_PORT}  # Port for SGLang router (default: 3000)
)

MISC_ARGS=(
   # FSDP2 specific settings
   --fsdp-cpu-offload  # Matching verl's fsdp_config.param_offload=True and optimizer_offload=True
   # Note: FSDP2 CPU offload handles both param and optimizer offload together
   
   # Attention implementation: use "eager" to avoid flash_attn version compatibility issues
   --attn-implementation flash_attention_2
   
   # Note: The following args are for Megatron backend only, ignored when using FSDP
   # --attention-dropout 0.0
   # --hidden-dropout 0.0
   # --accumulate-allreduce-grads-in-fp32
   # --attention-softmax-in-fp32
   # --attention-backend flash
)

CUSTOM_ARGS=(
   --custom-generate-function-path generate_with_iverilog.generate
   --custom-rm-path generate_with_iverilog.reward_func
)

# Ensure Ray is completely stopped and cleaned up before starting
echo "=========================================="
echo "Setting up Ray cluster..."
echo "=========================================="
echo "Ensuring Ray is stopped before starting..."
ray stop --force 2>/dev/null || true
sleep 2

# Cleanup worker node Ray
cleanup_worker_node
sleep 1

# If port is still in use, force kill processes using it
if lsof -ti:${RAY_DASHBOARD_PORT} >/dev/null 2>&1; then
    echo "Port ${RAY_DASHBOARD_PORT} is still in use, force killing..."
    lsof -ti:${RAY_DASHBOARD_PORT} 2>/dev/null | xargs kill -9 2>/dev/null || true
    sleep 1
fi

# Clean up Ray session directories to avoid session conflicts
RAY_RUNTIME_DIR="/tmp/ray"
mkdir -p "$RAY_RUNTIME_DIR"
if [ -d "$RAY_RUNTIME_DIR" ]; then
    echo "Cleaning up Ray session directories..."
    find "$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
fi

# Start Ray head node on master
echo "Starting Ray head node on ${MASTER_ADDR}..."
# 使用稳定的 API --object-spilling-directory 指定对象溢出目录
# 当需要溢出数据时，写到 /nfs_global/tmp/ray_spill
mkdir -p /nfs_global/tmp/ray_spill
ray start --head \
    --node-ip-address ${MASTER_ADDR} \
    --num-gpus ${GPUS_PER_NODE} \
    --disable-usage-stats \
    --dashboard-host=0.0.0.0 \
    --dashboard-port=${RAY_DASHBOARD_PORT} \
    --object-spilling-directory=/nfs_global/tmp/ray_spill \
    2>&1

# Record Ray head process PID if possible
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

# Get Ray head address for worker to connect
# Ray uses port 6379 by default for GCS server (as shown in ray start output)
RAY_ADDRESS="${MASTER_ADDR}:6379"
echo "Ray address for worker nodes: ${RAY_ADDRESS}"

# Start Ray worker node on remote machine
echo ""
echo "Starting Ray worker node on ${WORKER_ADDR}..."
echo "Note: Worker node should have slime environment and access to /nfs_global"
ssh -o StrictHostKeyChecking=no ${WORKER_ADDR} bash -s << EOF
set -e
export PYTHONUNBUFFERED=1

# === Worker 修改 ===
# 使用本地 /tmp (Worker 上应该也有 10G+ 空间)
export TMPDIR=/tmp
export TMP=/tmp
export TEMP=/tmp
export RAY_TMPDIR=/tmp

# 禁用 DeepGEMM
export SGLANG_DISABLE_DEEPGEMM=1
export SGLANG_DISABLE_FLASHINFER_SAMPLING=1

export TRITON_CACHE_DIR="/tmp/triton_cache"
export TORCH_EXTENSIONS_DIR="/tmp/torch_extensions"

# SGLang 的临时目录也建议放回本地，除非它产生大文件
export SGLANG_TMPDIR="/tmp/sglang_tmp"
mkdir -p \$TORCH_EXTENSIONS_DIR \$TRITON_CACHE_DIR \$SGLANG_TMPDIR

# Variables passed from master (will be substituted before SSH)
RAY_ADDRESS="${RAY_ADDRESS}"
GPUS_PER_NODE=${GPUS_PER_NODE}
SCRIPT_DIR="${SCRIPT_DIR}"
SLIME_ROOT="${SLIME_ROOT}"

# Activate slime environment (required for ray and other dependencies)
export MAMBA_EXE='/root/.local/bin/micromamba'
export MAMBA_ROOT_PREFIX='/nfs_global/micromamba'

# Initialize micromamba and activate slime environment
if [ -f "\$MAMBA_EXE" ]; then
    # Use --root-prefix instead of --prefix for micromamba shell hook
    eval "\$(\$MAMBA_EXE shell hook --shell bash --root-prefix \$MAMBA_ROOT_PREFIX 2>/dev/null)"
    if [ \$? -eq 0 ]; then
        micromamba activate slime 2>/dev/null || {
            echo "ERROR: Could not activate slime environment"
            echo "Trying to use ray from PATH..."
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

# Set up symlinks for editable packages (if they don't exist)
# These packages are installed as editable and point to /root/ paths
# We need to create symlinks on worker node to match master node structure
echo "Setting up editable package paths..."

# slime: link to shared filesystem if available
if [ ! -d "/root/slime" ]; then
    if [ -d "/nfs_global/slime" ]; then
        ln -sf /nfs_global/slime /root/slime 2>/dev/null && echo "  ✓ Created /root/slime -> /nfs_global/slime" || echo "  ⚠ Could not create /root/slime symlink"
    else
        echo "  ⚠ /nfs_global/slime not found, /root/slime will not be available"
    fi
else
    echo "  ✓ /root/slime already exists"
fi

# sglang: check if it exists, if not try to find in shared location or create symlink
if [ ! -d "/root/sglang" ]; then
    # Try to find sglang in common locations
    if [ -d "/nfs_global/sglang" ]; then
        ln -sf /nfs_global/sglang /root/sglang 2>/dev/null && echo "  ✓ Created /root/sglang -> /nfs_global/sglang" || echo "  ⚠ Could not create /root/sglang symlink"
    else
        echo "  ⚠ /root/sglang not found - sglang may not work correctly"
        echo "  Consider syncing /root/sglang from master node or installing sglang in shared location"
    fi
else
    echo "  ✓ /root/sglang already exists"
fi

# Megatron-LM-core: check if it exists
if [ ! -d "/root/Megatron-LM-core" ]; then
    if [ -d "/nfs_global/Megatron-LM-core" ]; then
        ln -sf /nfs_global/Megatron-LM-core /root/Megatron-LM-core 2>/dev/null && echo "  ✓ Created /root/Megatron-LM-core -> /nfs_global/Megatron-LM-core" || echo "  ⚠ Could not create /root/Megatron-LM-core symlink"
    else
        echo "  ⚠ /root/Megatron-LM-core not found - may cause import errors"
    fi
else
    echo "  ✓ /root/Megatron-LM-core already exists"
fi

# Megatron-LM: check if it exists
if [ ! -d "/root/Megatron-LM" ]; then
    if [ -d "/nfs_global/Megatron-LM" ]; then
        ln -sf /nfs_global/Megatron-LM /root/Megatron-LM 2>/dev/null && echo "  ✓ Created /root/Megatron-LM -> /nfs_global/Megatron-LM" || echo "  ⚠ Could not create /root/Megatron-LM symlink"
    fi
fi

# Set up environment variables (same as master node)
# Include both /root paths (for editable installs) and /nfs_global paths (for shared)
# Order matters: /root paths first (for editable installs), then shared paths
export PYTHONPATH="/root/Megatron-LM/:/root/Megatron-LM-core:\${SCRIPT_DIR}:\${SLIME_ROOT}:/root/slime:/root/sglang/python:/nfs_global/projects/verl:/nfs_global/projects/verl/eda_tools"
export CUDA_DEVICE_MAX_CONNECTIONS=1

# Verify critical imports (only if packages exist)
echo "Verifying Python imports..."
if [ -d "/root/slime" ] || [ -d "/nfs_global/slime" ]; then
    python3 -c "import slime; print('  ✓ slime imported from:', slime.__file__)" 2>/dev/null || echo "  ✗ Failed to import slime"
else
    echo "  ⚠ Skipping slime import check (package not found)"
fi

if [ -d "/root/sglang" ] || [ -d "/nfs_global/sglang" ]; then
    python3 -c "import sglang; print('  ✓ sglang imported from:', sglang.__file__)" 2>/dev/null || echo "  ✗ Failed to import sglang - this will cause errors!"
else
    echo "  ⚠ Skipping sglang import check (package not found)"
    echo "  If you see import errors later, ensure /root/sglang exists on worker node"
fi

# Verify ray is available
if ! command -v ray >/dev/null 2>&1; then
    echo "ERROR: ray command not found. Make sure slime environment is activated."
    exit 1
fi

# Stop any existing Ray instance
ray stop --force 2>/dev/null || true
sleep 2

# Clean up Ray session directories
RAY_RUNTIME_DIR="/tmp/ray"
mkdir -p "\$RAY_RUNTIME_DIR"
if [ -d "\$RAY_RUNTIME_DIR" ]; then
    find "\$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
fi

# Wait for master node to be ready (check if port is accessible)
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

# Start Ray worker node
echo "Connecting to Ray cluster at \$RAY_ADDRESS..."
# Worker 也同样配置溢出路径，使用稳定的 API --object-spilling-directory
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

# Wait a bit for worker to fully connect
sleep 5

# Verify cluster status
echo ""
echo "Ray cluster status:"
ray status

# Verify we have the expected number of nodes
NODE_COUNT=$(ray status 2>/dev/null | grep -c "node_" || echo "0")
if [ "$NODE_COUNT" -lt "$NUM_NODES" ]; then
    echo "Warning: Expected ${NUM_NODES} nodes, but found ${NODE_COUNT} nodes"
    echo "Waiting a bit longer for worker node to connect..."
    sleep 10
    ray status
fi

# IVERILOG_URL was already set before starting Ray using the host IP we determined
# No need to update it here - we already have the correct IP
echo ""
echo "IVERILOG_URL for Ray workers: ${IVERILOG_URL}"
echo "  (Iverilog server is listening on ${IVERILOG_HOST}:${IVERILOG_PORT})"
echo ""

RUNTIME_ENV_JSON="{
  \"env_vars\": {
    \"PYTHONPATH\": \"/root/Megatron-LM/:${SCRIPT_DIR}:${SLIME_ROOT}:/nfs_global/projects/verl:/nfs_global/projects/verl/eda_tools\",
    \"CUDA_DEVICE_MAX_CONNECTIONS\": \"1\",
    \"IVERILOG_URL\": \"${IVERILOG_URL}\",
    \"NCCL_SOCKET_IFNAME\": \"${NETWORK_INTERFACE}\",
    \"GLOO_SOCKET_IFNAME\": \"${NETWORK_INTERFACE}\",
    \"NCCL_IB_DISABLE\": \"${NCCL_IB_DISABLE}\"
  }
}"

# Submit Ray job and capture job ID
# Use a temporary file to capture output while also displaying it in real-time
echo "=========================================="
echo "Submitting Ray job..."
echo "=========================================="
TEMP_JOB_OUTPUT=$(mktemp)
# Add cleanup for temp file to existing trap
CLEANUP_TEMP_FILE="rm -f $TEMP_JOB_OUTPUT"
trap "$CLEANUP_TEMP_FILE; cleanup" EXIT INT TERM

# Submit job and tee output to both terminal and temp file
# This ensures output is displayed immediately while also being captured
# Use unbuffered output to ensure immediate display
if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL ray job submit --address="http://127.0.0.1:8265" \
       --runtime-env-json="${RUNTIME_ENV_JSON}" \
       -- python3 ${SLIME_ROOT}/train.py \
       --actor-num-nodes ${NUM_NODES} \
       --actor-num-gpus-per-node ${GPUS_PER_NODE} \
       --colocate \
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
    ray job submit --address="http://127.0.0.1:8265" \
       --runtime-env-json="${RUNTIME_ENV_JSON}" \
       -- python3 ${SLIME_ROOT}/train.py \
       --actor-num-nodes ${NUM_NODES} \
       --actor-num-gpus-per-node ${GPUS_PER_NODE} \
       --colocate \
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

# Extract job ID from captured output
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

# Clean up temp file (no longer needed)
rm -f "$TEMP_JOB_OUTPUT"
# Update trap to remove temp file cleanup
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

# Follow job logs
# Output directly to stdout - parent script's tee will capture and write to file
# Use unbuffered output to ensure logs are written immediately
export PYTHONUNBUFFERED=1

if command -v stdbuf >/dev/null 2>&1; then
    # Use stdbuf to disable buffering for immediate output
    stdbuf -oL -eL ray job logs --address="http://127.0.0.1:8265" --follow "$RAY_JOB_ID" 2>&1
else
    # Fallback if stdbuf is not available
    ray job logs --address="http://127.0.0.1:8265" --follow "$RAY_JOB_ID" 2>&1
fi
LOGS_EXIT_CODE=$?

# Check exit code and job status
if [ $LOGS_EXIT_CODE -ne 0 ]; then
    echo "" >&2
    echo "Ray job logs command exited with code: $LOGS_EXIT_CODE" >&2
    # Check if job is still running
    JOB_STATUS_OUTPUT=$(ray job status --address="http://127.0.0.1:8265" "$RAY_JOB_ID" 2>/dev/null || echo "UNKNOWN")
    JOB_STATUS=$(echo "$JOB_STATUS_OUTPUT" | grep -i "status" | head -1 || echo "UNKNOWN")
    echo "Ray job status: $JOB_STATUS" >&2
    if echo "$JOB_STATUS" | grep -qi "running\|pending"; then
        echo "Job is still running. Logs following was interrupted but job continues." >&2
        echo "To view logs: ray job logs $RAY_JOB_ID" >&2
        echo "To check status: ray job status $RAY_JOB_ID" >&2
        echo "To stop job: ray job stop $RAY_JOB_ID" >&2
    fi
fi