#!/bin/bash
# =============================================================================
# Fully-Async Multi-Node Training Script for CVDP Testbench Reward with Qwen3-8B
# =============================================================================
# All site-specific paths and settings are in the USER CONFIGURATION section
# below.  Override any variable by exporting it before running this script,
# or by editing the defaults in that section.
# =============================================================================

set -e

# Source bashrc
. ~/.bashrc 2>/dev/null || true

# ---------------------------------------------------------------------------
# Resolve script/repo directories first — needed for relative path defaults.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SLIME_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"
IVERILOG_R1_DIR="${SCRIPT_DIR}"

# Compute JOB_ID early — used in tmp-dir defaults below.
JOB_ID=${SLURM_JOB_ID:-manual}
JOB_ID_SHORT=$(echo "${JOB_ID}" | cut -c1-6)
HOST_HASH=$(hostname | md5sum | cut -c1-6)

# =============================================================================
# USER CONFIGURATION — edit defaults here or export variables before running
# =============================================================================

# ---------------------------------------------------------------------------
# 1. Conda / Python environment
#    CONDA_ENV_PATH : path to the activated conda/micromamba env
#    MAMBA_EXE      : micromamba binary (leave unset to skip micromamba init)
#    MAMBA_ROOT_PREFIX : micromamba root prefix
# ---------------------------------------------------------------------------
MAMBA_EXE="${MAMBA_EXE:-/workspace/S/shiwenxuan/bin/micromamba}"
MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-/nfs_global/S/shiwenxuan/micromamba}"
CONDA_ENV_PATH="${CONDA_ENV_PATH:-/workspace/S/shiwenxuan/envs/slime}"

# ---------------------------------------------------------------------------
# 2. Tmp / spill directories
#    EXEC_TMP_BASE  : base for per-node Python/Triton/SGLang tmp dirs
#                     must be a fast local (non-NFS) path visible on every node
#    RAY_SPILL_BASE : base for Ray object-spill dir
#                     should be on a shared filesystem so all nodes can access it
# ---------------------------------------------------------------------------
EXEC_TMP_BASE="${EXEC_TMP_BASE:-/workspace/S/shiwenxuan/tmp}"
RAY_SPILL_BASE="${RAY_SPILL_BASE:-/nfs_global/S/shiwenxuan/tmp}"

# ---------------------------------------------------------------------------
# 3. Multi-node cluster settings
#    NODE_RANK  : 0 = master/head node, 1+ = worker nodes
#    MASTER_ADDR: IP or hostname of the master node
#    NUM_NODES  : total number of nodes
#    GPUS_PER_NODE : GPUs available on each node
# ---------------------------------------------------------------------------
NODE_RANK="${NODE_RANK:-0}"
MASTER_ADDR="${MASTER_ADDR:-10.21.0.3}"
NUM_NODES="${NUM_NODES:-2}"
GPUS_PER_NODE="${GPUS_PER_NODE:-8}"

# ---------------------------------------------------------------------------
# 4. Ports
# ---------------------------------------------------------------------------
MASTER_PORT="${MASTER_PORT:-59553}"
SANDBOX_PORT="${SANDBOX_PORT:-8181}"
SGLANG_ROUTER_PORT="${SGLANG_ROUTER_PORT:-3001}"

# ---------------------------------------------------------------------------
# 5. EDA tool binaries
#    Set to absolute paths if the tools are not on PATH in the worker env.
#    CVDP_EXTRA_BIN_PATH : extra directory appended to PATH in Ray workers
#                          (useful when tools live in a conda env bin dir)
# ---------------------------------------------------------------------------
IVERILOG_PATH="${IVERILOG_PATH:-/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/iverilog}"
VVP_PATH="${VVP_PATH:-/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/vvp}"
YOSYS_PATH="${YOSYS_PATH:-/workspace/S/zhuyaoyu/softwares/miniconda3/envs/verl/bin/yosys}"
CVDP_EXTRA_BIN_PATH="${CVDP_EXTRA_BIN_PATH:-}"

# ---------------------------------------------------------------------------
# 6. SandboxFusion server (used as fallback when IVERILOG_EXECUTION_METHOD
#    is not "local_iverilog"; safe to leave pointing to a non-existent path
#    when running in local_iverilog mode)
# ---------------------------------------------------------------------------
SANDBOX_DIR="${SANDBOX_DIR:-/workspace/S/shiwenxuan/verl/SandboxFusion}"
SANDBOX_HOST="${SANDBOX_HOST:-0.0.0.0}"

# ---------------------------------------------------------------------------
# 7. Data paths
#    DATA_PATH        : training data directory (must contain train.parquet)
#    CODEV_TEST_ROOT  : codev_test root (benchmark JSONL, test scripts)
#    CVDP_TESTENV_ROOT: pre-generated testbench environments
#    IVERILOG_TMP_DIR : iverilog simulation tmp dir — MUST be local disk, not NFS
# ---------------------------------------------------------------------------
DATA_PATH="${DATA_PATH:-${IVERILOG_R1_DIR}/data/cvdp_testbench_172}"
CODEV_TEST_ROOT="${CODEV_TEST_ROOT:-${IVERILOG_R1_DIR}/codev_test}"
CVDP_TESTENV_ROOT="${CVDP_TESTENV_ROOT:-${IVERILOG_R1_DIR}/codev_test/train_testenv}"
IVERILOG_TMP_DIR="${IVERILOG_TMP_DIR:-/tmp/iverilog_tmp}"

# ---------------------------------------------------------------------------
# 8. Model checkpoints
#    MODEL_PATH   : HuggingFace format checkpoint (for --hf-checkpoint)
#    CKPT_BASE    : Megatron format checkpoint directory (for --ref-load)
#    CKPT_SAVE_NAME: subdirectory under CKPT_BASE used for --load and --save
# ---------------------------------------------------------------------------
MODEL_PATH="${MODEL_PATH:-/nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/87k_sft_8.1k_ds32_10epochs/checkpoint-1270}"
CKPT_BASE="${CKPT_BASE:-/nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/87k_sft_8.1k_ds32_10epochs/checkpoint-1270_torch_dist}"
CKPT_SAVE_NAME="${CKPT_SAVE_NAME:-dynamic_curriculum_kl0.0_update2_eval3_lr2e-6}"

# ---------------------------------------------------------------------------
# 9. Python dependency paths injected into Ray workers via PYTHONPATH
#    These must be visible on all nodes (typically NFS-mounted).
# ---------------------------------------------------------------------------
MEGATRON_LM_PATH="${MEGATRON_LM_PATH:-/workspace/S/shiwenxuan/Megatron-LM}"
SGLANG_GATEWAY_PATH="${SGLANG_GATEWAY_PATH:-/workspace/S/shiwenxuan/sglang/sgl-model-gateway/bindings/python}"
SGLANG_PYTHON_PATH="${SGLANG_PYTHON_PATH:-/workspace/S/shiwenxuan/sglang/python}"
VERL_PATH="${VERL_PATH:-/workspace/S/shiwenxuan/verl}"

# ---------------------------------------------------------------------------
# 10. pytest for CVDP testbench evaluation
#     Leave empty to use sys.executable -m pytest (the current Python env).
#     Set to an absolute path only when pytest/cocotb live in a *different*
#     Python environment from the one running the reward function.
# ---------------------------------------------------------------------------
CVDP_PYTEST_PATH="${CVDP_PYTEST_PATH:-}"

# ---------------------------------------------------------------------------
# 11. W&B — set WANDB_API_KEY in env to enable online logging
# ---------------------------------------------------------------------------
WANDB_PROJECT="${WANDB_PROJECT:-slime-async-cvdp-train}"
WANDB_GROUP="${WANDB_GROUP:-cvdp_testbench_reward_qwen3_8b}"
WANDB_MODE="${WANDB_MODE:-offline}"

# =============================================================================
# END OF USER CONFIGURATION
# =============================================================================

# ---------------------------------------------------------------------------
# Derived paths (computed from configurable bases above)
# ---------------------------------------------------------------------------
EXEC_ROOT_DIR="${EXEC_ROOT_DIR:-${EXEC_TMP_BASE}/job_${JOB_ID_SHORT}}"
NODE_EXEC_TMP_DIR="${EXEC_ROOT_DIR}/${HOST_HASH}"
RAY_SPILL_DIR="${RAY_SPILL_DIR:-${RAY_SPILL_BASE}/ray_spill_${JOB_ID_SHORT}}"
TRAIN_FILE="train.parquet"
RAY_WORKER_PYTHONPATH="${SGLANG_GATEWAY_PATH}:${MEGATRON_LM_PATH}:${SCRIPT_DIR}:${SLIME_ROOT}:${SGLANG_PYTHON_PATH}:${VERL_PATH}:${IVERILOG_R1_DIR}/eda_tools"

# ---------------------------------------------------------------------------
# System limits
# ---------------------------------------------------------------------------
ulimit -n 65536 2>/dev/null || true
echo "Current ulimit -n: $(ulimit -n)"
ulimit -l unlimited
ulimit -v unlimited
ulimit -n 65535
ulimit -u 4125556

# ---------------------------------------------------------------------------
# Conda / micromamba activation
# ---------------------------------------------------------------------------
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook 2>/dev/null)" || true
fi

if [ -f "${MAMBA_EXE}" ]; then
    export MAMBA_EXE
    export MAMBA_ROOT_PREFIX
    eval "$($MAMBA_EXE shell hook --shell bash --root-prefix $MAMBA_ROOT_PREFIX 2>/dev/null)" || true

    if [ -d "${CONDA_ENV_PATH}" ]; then
        micromamba activate "${CONDA_ENV_PATH}"
    else
        micromamba activate slime || true
    fi
fi

# Fix GLIBCXX version mismatch
export LD_LIBRARY_PATH="${CONDA_PREFIX:-${CONDA_ENV_PATH}}/lib:${LD_LIBRARY_PATH}"
echo "Updated LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}"

export PYTHONUNBUFFERED=1
if [ -t 1 ]; then
    export PYTHONIOENCODING=utf-8
fi

# ---------------------------------------------------------------------------
# Disable HTTP proxy (Ray is sensitive to proxy settings)
# ---------------------------------------------------------------------------
unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY ftp_proxy FTP_PROXY
export no_proxy="127.0.0.1,localhost,0.0.0.0,::1,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,*.local,*.future.cn"
export NO_PROXY="$no_proxy"
export RAY_AGENT_DISABLE_HTTP_PROXY=1

echo "=== Environment Network Settings ==="
env | grep -iE "proxy|addr|port|ray" | sort
echo "=================================="

echo "=== Checking Shared Memory ==="
df -h /dev/shm
echo "=============================="

# ---------------------------------------------------------------------------
# Tmp directories
# ---------------------------------------------------------------------------
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

# Ray tmp (local disk — avoid NFS)
RAY_TMP_DIR="/tmp/r_${JOB_ID_SHORT}"
rm -rf $RAY_TMP_DIR
mkdir -p $RAY_TMP_DIR
export RAY_TMPDIR=$RAY_TMP_DIR

echo "Node Hostname: $(hostname)"
echo "Python TMP: $NODE_EXEC_TMP_DIR"
echo "Ray TMP:    $RAY_TMP_DIR"
echo "=== Training dataset: ${DATA_PATH}/${TRAIN_FILE} (dynamic curriculum) ==="
echo "=== CVDP_TESTENV_ROOT: ${CVDP_TESTENV_ROOT} ==="
echo "=== Model: ${MODEL_PATH} ==="
echo "=== Checkpoint save: ${CKPT_BASE}/${CKPT_SAVE_NAME} ==="

# ---------------------------------------------------------------------------
# SGLang / DeepGEMM
# ---------------------------------------------------------------------------
export SGLANG_DISABLE_DEEPGEMM=1
export SGLANG_DISABLE_FLASHINFER_SAMPLING=1

# ---------------------------------------------------------------------------
# Port derivation from MASTER_PORT
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Network interface detection
# ---------------------------------------------------------------------------
get_valid_iface() {
    if command -v ibdev2netdev >/dev/null 2>&1; then
        IB_IF=$(ibdev2netdev | grep Up | grep ib | head -1 | awk '{print $5}')
        if [ ! -z "$IB_IF" ]; then
            if ip addr show "$IB_IF" | grep -q "inet"; then
                echo "$IB_IF"
                return
            fi
        fi
    fi

    for iface in bond0 eth0 ib0 eno1 enp0s3; do
        if ip link show "$iface" >/dev/null 2>&1; then
             if ip addr show "$iface" | grep -q "inet"; then
                 echo "$iface"
                 return
             fi
        fi
    done

    ip route | grep default | awk '{print $5}' | head -1
}

if [ -z "$NETWORK_INTERFACE" ]; then
    NETWORK_INTERFACE=$(get_valid_iface)
fi
NETWORK_INTERFACE=${NETWORK_INTERFACE:-"eth0"}

echo "Using Network Interface: $NETWORK_INTERFACE"

export NCCL_SOCKET_IFNAME=$NETWORK_INTERFACE
export GLOO_SOCKET_IFNAME=$NETWORK_INTERFACE
export TP_SOCKET_IFNAME=$NETWORK_INTERFACE

# ---------------------------------------------------------------------------
# Node configuration (override by SLURM if available)
# ---------------------------------------------------------------------------
if [ ! -z "$SLURM_JOB_NODELIST" ]; then
    echo "Running under SLURM environment"
    NODE_LIST=($(scontrol show hostnames $SLURM_JOB_NODELIST))
    MASTER_ADDR=${MASTER_ADDR:-${NODE_LIST[0]}}
    NUM_NODES=${#NODE_LIST[@]}
    GPUS_PER_NODE=${SLURM_GPUS_ON_NODE:-${GPUS_PER_NODE}}
    NODE_RANK=${NODE_RANK:-${SLURM_NODEID:-0}}
    export NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-"0"}
else
    echo "Running in manual multi-node mode"
    export NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-"1"}
fi

# GPU split: actor training vs SGLang rollout
ACTOR_NODES=1
ACTOR_GPUS_PER_NODE=8
ROLLOUT_GPUS=8              # total SGLang GPUs across all engines
ROLLOUT_GPUS_PER_ENGINE=8   # one engine uses all 8 rollout GPUs

# ---------------------------------------------------------------------------
# Cleanup function
# ---------------------------------------------------------------------------
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
    rm -rf "$NODE_EXEC_TMP_DIR" 2>/dev/null || true
    rm -rf "$RAY_SPILL_DIR" 2>/dev/null || true
}

trap cleanup_worker_nodes EXIT INT TERM
cleanup_worker_nodes
sleep 2

# Recreate spill dir after initial cleanup
mkdir -p $RAY_SPILL_DIR

# ---------------------------------------------------------------------------
# IP address
# ---------------------------------------------------------------------------
HOST_IP=$(ip -4 addr show "$NETWORK_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [ -z "$HOST_IP" ]; then
    echo "WARNING: Could not find IP for interface $NETWORK_INTERFACE, falling back to hostname -I"
    HOST_IP=$(hostname -I | awk '{print $1}')
fi
echo "Node IP: $HOST_IP"

if [ "$NODE_RANK" -eq 0 ]; then
    MASTER_IP=$HOST_IP
else
    RESOLVED=$(getent hosts $MASTER_ADDR | awk '{print $1}' | head -1)
    if [ ! -z "$RESOLVED" ]; then
        MASTER_IP=$RESOLVED
    else
        MASTER_IP=$MASTER_ADDR
    fi
fi
SANDBOX_URL="http://${MASTER_IP}:${SANDBOX_PORT}/run_code"

# ---------------------------------------------------------------------------
# Start SandboxFusion (master only)
# ---------------------------------------------------------------------------
if [ "$NODE_RANK" -eq 0 ]; then
    echo "Starting SandboxFusion server..."

    if [ ! -d "$SANDBOX_DIR" ]; then
        echo "WARNING: SandboxFusion directory not found at $SANDBOX_DIR"
        echo "WARNING: Continuing without SandboxFusion (local_iverilog mode will still work)"
    else
        (
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
    fi
else
    sleep 5
fi

# ---------------------------------------------------------------------------
# Export tool / runtime env vars (used locally and forwarded to Ray workers)
# ---------------------------------------------------------------------------
export IVERILOG_PATH
export VVP_PATH
export YOSYS_PATH
export CVDP_EXTRA_BIN_PATH
export CODEV_TEST_ROOT
export CVDP_TESTENV_ROOT
export TOKENIZERS_PARALLELISM=false
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
export IVERILOG_EXECUTION_METHOD=local_iverilog
export SANDBOX_FUSION_CONCURRENCY=32
export IVERILOG_URL="${SANDBOX_URL}"
export IVERILOG_TMP_DIR

# ---------------------------------------------------------------------------
# Training argument arrays
# ---------------------------------------------------------------------------
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
   --ref-load ${CKPT_BASE}
   --load ${CKPT_BASE}/${CKPT_SAVE_NAME}
   --save ${CKPT_BASE}/${CKPT_SAVE_NAME}
   --save-interval 10
)

ROLLOUT_ARGS=(
   # ---- fully-async rollout driver ----
   --rollout-function-path iverilog_async_rollout.generate_rollout_fully_async

   --prompt-data ${DATA_PATH}/${TRAIN_FILE}
   --input-key prompt
   --label-key reward_model
   --tool-key tools
   --metadata-key extra_info
   --apply-chat-template
   --rollout-shuffle
   --num-rollout 1000
   --rollout-batch-size 16
   --n-samples-per-prompt 8
   --rollout-max-response-len 30000
   --rollout-max-context-len 36000
   --over-sampling-batch-size 22
   --dynamic-sampling-filter-path slime.rollout.filter_hub.dynamic_sampling_filters.check_reward_nonzero_std
   --rollout-temperature 1.0
   --start-rollout-id 0

   # ---- partial rollout: aborted samples are recycled; off-policy tokens masked ----
   --partial-rollout
#    --mask-offpolicy-in-partial-rollout

   --eval-interval 20
   --eval-prompt-data codev_test ${DATA_PATH}/train.parquet
   --eval-input-key prompt
   --eval-label-key reward_model
   --eval-tool-key tools
   --n-samples-per-eval-prompt 3
   --eval-max-response-len 30000
   --eval-max-context-len 36000

   --global-batch-size 128
   --balance-data
)

PERF_ARGS=(
   --tensor-model-parallel-size 8
   --sequence-parallel
   --pipeline-model-parallel-size 1
   --context-parallel-size 1
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
   --kl-loss-coef 0.0
   --kl-loss-type low_var_kl
   --entropy-coef 0.00
   --eps-clip 0.2
   --eps-clip-high 0.28
   --use-tis
   --update-weights-interval 2
)

OPTIMIZER_ARGS=(
   --optimizer adam
   --lr 2e-6
   --lr-decay-style constant
   --weight-decay 0.01
   --adam-beta1 0.9
   --adam-beta2 0.98
)

WANDB_ARGS=(
   --use-wandb
   --wandb-mode ${WANDB_MODE}
   --wandb-project ${WANDB_PROJECT}
   --wandb-group ${WANDB_GROUP}
   ${WANDB_API_KEY:+--wandb-key "${WANDB_API_KEY}"}
)

SGLANG_ARGS=(
   --rollout-num-gpus ${ROLLOUT_GPUS}
   --rollout-num-gpus-per-engine ${ROLLOUT_GPUS_PER_ENGINE}
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
   --custom-rm-path cvdp_testbench_reward.reward_func
   --eval-function-path custom_eval_cvdp.custom_eval_cvdp
)

# ---------------------------------------------------------------------------
# Start Ray
# ---------------------------------------------------------------------------
# 60 GB object store: reduces spilling from the default 20 GB.
OBJECT_STORE_MEMORY=$((60 * 1024 * 1024 * 1024))

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
    touch "${EXEC_ROOT_DIR}/ray_head_ready"
else
    echo "Starting Ray Worker..."
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

# ---------------------------------------------------------------------------
# Submit job (master only)
# ---------------------------------------------------------------------------
if [ "$NODE_RANK" -eq 0 ]; then
    echo "Waiting for $NUM_NODES nodes..."
    while true; do
        NODE_COUNT=$(ray status 2>/dev/null | grep -c "node_" || echo "0")
        if [ "$NODE_COUNT" -ge "$NUM_NODES" ]; then break; fi
        sleep 2
    done

    LOCAL_DASHBOARD_URL="http://127.0.0.1:${DASHBOARD_PORT}"

    echo "Checking Dashboard API (via localhost)..."
    for i in {1..30}; do
        if curl -s "${LOCAL_DASHBOARD_URL}/api/version" >/dev/null 2>&1; then
            echo "✓ Dashboard API is ready on localhost!"
            break
        fi
        sleep 2
    done

    echo "Waiting for Dashboard Agent to listen on port ${DAL_PORT}..."
    for i in {1..30}; do
        if lsof -i :${DAL_PORT} >/dev/null 2>&1; then
             echo "✓ Dashboard Agent is listening on port ${DAL_PORT}!"
             break
        fi
        sleep 1
    done

    sleep 5

    RUNTIME_ENV_JSON=$(jq -n \
        --arg PYTHONPATH "${RAY_WORKER_PYTHONPATH}" \
        --arg CUDA_DEVICE_MAX_CONNECTIONS "1" \
        --arg SANDBOX_URL "${SANDBOX_URL}" \
        --arg IVERILOG_URL "${IVERILOG_URL}" \
        --arg IVERILOG_EXECUTION_METHOD "${IVERILOG_EXECUTION_METHOD}" \
        --arg IVERILOG_PATH "${IVERILOG_PATH}" \
        --arg VVP_PATH "${VVP_PATH}" \
        --arg YOSYS_PATH "${YOSYS_PATH}" \
        --arg IVERILOG_TMP_DIR "${IVERILOG_TMP_DIR}" \
        --arg SANDBOX_FUSION_CONCURRENCY "${SANDBOX_FUSION_CONCURRENCY}" \
        --arg NCCL_SOCKET_IFNAME "${NETWORK_INTERFACE}" \
        --arg GLOO_SOCKET_IFNAME "${NETWORK_INTERFACE}" \
        --arg TP_SOCKET_IFNAME "${NETWORK_INTERFACE}" \
        --arg NCCL_IB_DISABLE "${NCCL_IB_DISABLE}" \
        --arg NO_PROXY "${NO_PROXY}" \
        --arg no_proxy "${no_proxy}" \
        --arg CVDP_TESTENV_ROOT "${CVDP_TESTENV_ROOT}" \
        --arg CVDP_PYTEST_PATH "${CVDP_PYTEST_PATH}" \
        --arg CVDP_EXTRA_BIN_PATH "${CVDP_EXTRA_BIN_PATH}" \
        --arg CODEV_TEST_ROOT "${CODEV_TEST_ROOT}" \
        --arg VERL_PATH "${VERL_PATH}" \
        '{
            "env_vars": {
                "PYTHONPATH": $PYTHONPATH,
                "CUDA_DEVICE_MAX_CONNECTIONS": $CUDA_DEVICE_MAX_CONNECTIONS,
                "SANDBOX_URL": $SANDBOX_URL,
                "IVERILOG_URL": $IVERILOG_URL,
                "IVERILOG_EXECUTION_METHOD": $IVERILOG_EXECUTION_METHOD,
                "IVERILOG_PATH": $IVERILOG_PATH,
                "VVP_PATH": $VVP_PATH,
                "YOSYS_PATH": $YOSYS_PATH,
                "IVERILOG_TMP_DIR": $IVERILOG_TMP_DIR,
                "SANDBOX_FUSION_CONCURRENCY": $SANDBOX_FUSION_CONCURRENCY,
                "NCCL_SOCKET_IFNAME": $NCCL_SOCKET_IFNAME,
                "GLOO_SOCKET_IFNAME": $GLOO_SOCKET_IFNAME,
                "TP_SOCKET_IFNAME": $TP_SOCKET_IFNAME,
                "NCCL_IB_DISABLE": $NCCL_IB_DISABLE,
                "NO_PROXY": $NO_PROXY,
                "no_proxy": $no_proxy,
                "CVDP_TESTENV_ROOT": $CVDP_TESTENV_ROOT,
                "CVDP_PYTEST_PATH": $CVDP_PYTEST_PATH,
                "CVDP_EXTRA_BIN_PATH": $CVDP_EXTRA_BIN_PATH,
                "CODEV_TEST_ROOT": $CODEV_TEST_ROOT,
                "VERL_PATH": $VERL_PATH
            }
        }')

    echo "Submitting Ray Job (with retry) via ${LOCAL_DASHBOARD_URL}..."

    MAX_RETRIES=1
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if ray job submit --address="${LOCAL_DASHBOARD_URL}" \
           --runtime-env-json="${RUNTIME_ENV_JSON}" \
           -- python3 ${SLIME_ROOT}/train_async.py \
           --actor-num-nodes ${ACTOR_NODES} \
           --actor-num-gpus-per-node ${ACTOR_GPUS_PER_NODE} \
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

    sleep 10
    RAY_JOB_ID=$(ray job list --address="${LOCAL_DASHBOARD_URL}" | grep "RUNNING" | awk '{print $1}' | head -1)
    if [ ! -z "$RAY_JOB_ID" ]; then
        ray job logs --address="${LOCAL_DASHBOARD_URL}" --follow "$RAY_JOB_ID"
    fi
fi
