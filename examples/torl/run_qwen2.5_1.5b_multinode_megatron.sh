#!/bin/bash

# Multi-node training script for ToRL with Qwen2.5-Math-1.5B
# This script runs training on multiple nodes with 8 GPUs each
# Supports both SLURM and manual multi-node setups
# Adapted from iverilog-r1 training script for Python code execution via SandboxFusion

# Use set -e to exit on error, but don't use -x to avoid excessive debug output
set -e

# Source bashrc to ensure conda/micromamba is available
. ~/.bashrc 2>/dev/null || true

# Initialize both conda and micromamba at the beginning of the script
# sandbox-runtime-swx is a conda environment, slime is a micromamba environment
# Adapted for lab cluster environment without root privileges
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook 2>/dev/null)" || true
    echo "✓ Initialized conda (for sandbox-runtime-swx environment)"
fi

    if [ -f "/workspace/S/shiwenxuan/bin/micromamba" ]; then
        export MAMBA_EXE='/workspace/S/shiwenxuan/bin/micromamba'
        export MAMBA_ROOT_PREFIX='/nfs_global/S/shiwenxuan/micromamba'
        eval "$($MAMBA_EXE shell hook --shell bash --root-prefix $MAMBA_ROOT_PREFIX 2>/dev/null)" || true
        
        # Try to activate workspace environment first to avoid NFS exec issues
        if [ -d "/workspace/S/shiwenxuan/envs/slime" ]; then
            micromamba activate /workspace/S/shiwenxuan/envs/slime
            echo "✓ Activated slime environment from /workspace (SSD)"
        else
            micromamba activate slime || true
            echo "✓ Initialized micromamba (slime)"
        fi
    fi

# Disable output buffering for immediate display
export PYTHONUNBUFFERED=1
if [ -t 1 ]; then
    export PYTHONIOENCODING=utf-8
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SLIME_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"

# === Disable HTTP proxy (may interfere with Ray dashboard connection) ===
# Unset proxy environment variables that might cause connection issues
unset http_proxy
unset HTTP_PROXY
unset https_proxy
unset HTTPS_PROXY
unset all_proxy
unset ALL_PROXY

# Explicitly set no_proxy to include local IPs and cluster IPs
# This prevents tools that respect no_proxy from trying to use a proxy if one is injected later
export no_proxy="127.0.0.1,localhost,0.0.0.0,::1,10.0.0.0/8,192.168.0.0/16,172.16.0.0/12,${no_proxy}"
export NO_PROXY="$no_proxy"

# === Path settings ===
# Use workspace directory but with host-specific subdirectory to avoid IP conflicts
# Ray uses TMPDIR to store node information. On NFS, multiple nodes writing to same dir causes "different IP" errors
# By including hostname in the path, each node gets a unique directory on the shared filesystem
# /workspace supports exec/mmap so it resolves the libarrow loading issue seen on /tmp
# IMPORTANT: Ray socket paths have a length limit (108 chars). We need a very short path.
# Using a hashed suffix to ensure uniqueness while keeping length short.
# Original long path: /workspace/S/shiwenxuan/tmp_local/${SLURM_JOB_ID:-manual}_${RANDOM}_$(hostname)
SHORT_HOST=$(hostname -s)
JOB_ID=${SLURM_JOB_ID:-manual}
# Use a short hash of jobid+hostname to keep path unique but short
UNIQUE_ID=$(echo "${JOB_ID}_${SHORT_HOST}" | md5sum | cut -c1-8)
# Use a shorter base path if possible to save characters for socket names
# Use local disk for Ray temp dir to avoid NFS conflicts
# Ray forces all workers to use the same path string as head node
# If this path is on NFS, all nodes write to the same directory -> CORRUPTION
# Use /tmp on local NVMe disk (3.5T available according to logs)
# Since we migrated the environment to /workspace (SSD), we don't need /dev/shm to bypass noexec.
# /tmp is more standard for Ray sockets and less likely to cause issues.
USER_TMP_DIR="/tmp/${USER}/tmp_r/${UNIQUE_ID}"
USER_DATA_DIR="/nfs_global/S/shiwenxuan/tmp"
mkdir -p $USER_TMP_DIR $USER_DATA_DIR

# Set TMPDIR for Python/OS to use /dev/shm
export TMPDIR=$USER_TMP_DIR
export TMP=$USER_TMP_DIR
export TEMP=$USER_TMP_DIR

# Ray internal temp dir (sockets, GCS)
export RAY_TMPDIR=$USER_TMP_DIR

# === Disable DeepGEMM ===
export SGLANG_DISABLE_DEEPGEMM=1
export SGLANG_DISABLE_FLASHINFER_SAMPLING=1

# === Compilation cache redirection ===
export TRITON_CACHE_DIR="$USER_TMP_DIR/triton_cache"
export TORCH_EXTENSIONS_DIR="$USER_TMP_DIR/torch_extensions"
export SGLANG_TMPDIR="$USER_TMP_DIR/sglang_tmp"
mkdir -p $TORCH_EXTENSIONS_DIR $TRITON_CACHE_DIR $SGLANG_TMPDIR

# === Ray object spilling configuration ===
# Use nfs_global for Ray spill (large data, needs more space)
RAY_SPILL_DIR="$USER_DATA_DIR/ray_spill"
mkdir -p $RAY_SPILL_DIR

# === Port Configuration (Copied from verl_tir/train-multigpu.sh) ===
# Calculate ports based on MASTER_PORT to avoid conflicts
# MASTER_PORT is usually assigned by SLURM or set manually
MASTER_PORT=${MASTER_PORT:-6379} 
# Ensure MASTER_PORT is not the default Redis port to avoid confusion if possible, 
# but Ray uses it as GCS port.
# If MASTER_PORT comes from SLURM (e.g. 5xxxx), we need to be careful.
# Let's use a base port for Ray that is distinct.
RAY_BASE_PORT=6379

DASHBOARD_PORT=8265
DAL_PORT=52365 # Dashboard Agent Listen Port
RCS_PORT=10001 # Ray Client Server Port
RS_PORT=55000  # Redis Shard Ports (start)
NM_PORT=45000  # Node Manager Port
OM_PORT=46000  # Object Manager Port

# Adjust ports based on job id to avoid conflicts on shared nodes if needed, 
# but usually inside a container or exclusive node it's fine.
# For simplicity and matching the successful script, we use fixed offsets if MASTER_PORT is high.
if [ "$MASTER_PORT" -gt 10000 ]; then
    RAY_GCS_PORT=$MASTER_PORT
    DASHBOARD_PORT=$(($MASTER_PORT-10000))
    DAL_PORT=$(($MASTER_PORT-20000))
    RCS_PORT=$(($MASTER_PORT-30000))
    RS_PORT=$(($MASTER_PORT-5000))
    NM_PORT=$(($MASTER_PORT-15000))
    OM_PORT=$(($MASTER_PORT-25000))
else
    RAY_GCS_PORT=6379
fi

RAY_DASHBOARD_PORT=$DASHBOARD_PORT

# === Temp Dir ===
export RAY_TEMP_DIR="/tmp/ray_${SLURM_JOB_ID:-manual}_${RANDOM}"
echo "RAY TEMP DIR is $RAY_TEMP_DIR"
mkdir -p $RAY_TEMP_DIR

# PID file to track processes started by this script
PID_FILE="${SCRIPT_DIR}/.run_qwen3_1.5b_torl_multinode.pid"

SANDBOX_PORT=${SANDBOX_PORT:-8185}  # SandboxFusion port (matching ToRL config)
SGLANG_ROUTER_PORT=${SGLANG_ROUTER_PORT:-3001}  # Port for SGLang router (different from iverilog-r1)

# Detect if running under SLURM
if [ ! -z "$SLURM_JOB_NODELIST" ]; then
    echo "=========================================="
    echo "Running under SLURM environment"
    echo "=========================================="
    # Get node list from SLURM
    NODE_LIST=($(scontrol show hostnames $SLURM_JOB_NODELIST))
    MASTER_ADDR=${NODE_LIST[0]}
    NUM_NODES=${#NODE_LIST[@]}
    GPUS_PER_NODE=${SLURM_GPUS_ON_NODE:-8}
    TOTAL_GPUS=$((NUM_NODES * GPUS_PER_NODE))
    
    # Get current node info
    CURRENT_NODE=$(hostname -s)
    NODE_RANK=$SLURM_NODEID
    
    echo "SLURM Node List: ${NODE_LIST[@]}"
    echo "Current Node: ${CURRENT_NODE}"
    echo "Node Rank: ${NODE_RANK}"
    echo "Master Node: ${MASTER_ADDR}"
    
    # Network interface - try to detect from InfiniBand
    if command -v ibdev2netdev >/dev/null 2>&1; then
        NETWORK_INTERFACE=$(ibdev2netdev | grep Up | grep ib | head -1 | awk '{print $5}' || echo "eth0")
    else
        NETWORK_INTERFACE=${NETWORK_INTERFACE:-"eth0"}
    fi
    
    # Use RDMA if available (SLURM clusters typically have IB)
    export NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-"0"}
else
    echo "=========================================="
    echo "Running in manual multi-node mode"
    echo "=========================================="
    # Manual multi-node configuration (fallback)
    MASTER_ADDR=${MASTER_ADDR:-"10.21.0.3"}
    WORKER_ADDR=${WORKER_ADDR:-"10.21.0.12"}
    NUM_NODES=2
    GPUS_PER_NODE=8
    TOTAL_GPUS=$((NUM_NODES * GPUS_PER_NODE))
    NODE_RANK=0  # Assume master in manual mode
    CURRENT_NODE=$(hostname -s)
    
    # Network interface configuration
    NETWORK_INTERFACE=${NETWORK_INTERFACE:-"eth0"}
    export NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-"1"}
fi

# Export NCCL and Gloo environment variables
export NCCL_SOCKET_IFNAME=${NCCL_SOCKET_IFNAME:-"${NETWORK_INTERFACE}"}
export GLOO_SOCKET_IFNAME=${GLOO_SOCKET_IFNAME:-"${NETWORK_INTERFACE}"}

echo "=========================================="
echo "ToRL Multi-node Training Configuration"
echo "=========================================="
echo "Master node: ${MASTER_ADDR}"
if [ ! -z "$SLURM_JOB_NODELIST" ]; then
    echo "All nodes: ${NODE_LIST[@]}"
else
    echo "Worker node: ${WORKER_ADDR}"
fi
echo "Current node: ${CURRENT_NODE}"
echo "Node rank: ${NODE_RANK}"
echo "Total nodes: ${NUM_NODES}"
echo "GPUs per node: ${GPUS_PER_NODE}"
echo "Total GPUs: ${TOTAL_GPUS}"
echo "Network interface: ${NETWORK_INTERFACE}"
echo "=========================================="
echo ""

# Function to cleanup worker nodes
cleanup_worker_nodes() {
    if [ ! -z "$SLURM_JOB_NODELIST" ]; then
        # In SLURM mode, cleanup is handled per-node
        echo "Cleaning up processes on current node..."
        ray stop --force 2>/dev/null || true
        pkill -f 'ray.*worker' 2>/dev/null || true
        pkill -f 'python.*train.py' 2>/dev/null || true
        pkill -f 'sglang.*scheduler' 2>/dev/null || true
        pkill -f 'sglang::scheduler' 2>/dev/null || true
        pkill -f 'sglang' 2>/dev/null || true
        # Clean up local temp dir
        # Be careful not to delete the parent directory if shared
        if [[ "$USER_TMP_DIR" == *"/tmp_r"* ]]; then
            rm -rf "$USER_TMP_DIR" 2>/dev/null || true
        fi
        if command -v nvidia-smi >/dev/null 2>&1; then
            nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null | grep -v '^$' | xargs kill -9 2>/dev/null || true
        fi
    else
        # Manual mode: cleanup worker node via SSH
        echo "Cleaning up worker node ${WORKER_ADDR}..."
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
            ${WORKER_ADDR} \
            "export MAMBA_EXE='/workspace/S/shiwenxuan/bin/micromamba'; \
             export MAMBA_ROOT_PREFIX='/nfs_global/S/shiwenxuan/micromamba'; \
             [ -f \"\$MAMBA_EXE\" ] && eval \"\$(\$MAMBA_EXE shell hook --shell bash --root-prefix \$MAMBA_ROOT_PREFIX 2>/dev/null)\" && (micromamba activate /workspace/S/shiwenxuan/envs/slime 2>/dev/null || micromamba activate slime 2>/dev/null) || true; \
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
    fi
}

# Function to cleanup processes started by this script
cleanup_own_processes() {
    echo "Cleaning up processes started by this script..."
    
    cleanup_worker_nodes
    
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
        # Use master node IP if available, otherwise use localhost
        RAY_DASHBOARD_ADDR="${MASTER_ADDR:-127.0.0.1}"
        ray stop --address="http://${RAY_DASHBOARD_ADDR}:${RAY_DASHBOARD_PORT}" --force 2>/dev/null || true
        sleep 2
        lsof -ti:${RAY_DASHBOARD_PORT} 2>/dev/null | xargs kill -9 2>/dev/null || true
    fi
    
    ray stop --force 2>/dev/null || true
    sleep 1
    
    ps aux | grep -E "ray.*${RAY_DASHBOARD_PORT}|ray.*dashboard.*${RAY_DASHBOARD_PORT}" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null || true
    pkill -f "ray.*dashboard.*${RAY_DASHBOARD_PORT}" 2>/dev/null || true
    pkill -f "ray.*head.*${RAY_DASHBOARD_PORT}" 2>/dev/null || true
    
    if ! pgrep -f "ray.*dashboard" >/dev/null 2>&1; then
        RAY_RUNTIME_DIR="$USER_TMP_DIR/ray"
        if [ -d "$RAY_RUNTIME_DIR" ]; then
            echo "Cleaning up Ray runtime directory to avoid session conflicts..."
            # Keep logs for debugging
            # find "$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
        fi
    fi
}

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    
    if [ ! -z "$RAY_JOB_ID" ]; then
        # Use master node IP for dashboard address
        RAY_DASHBOARD_ADDR="${MASTER_ADDR:-127.0.0.1}"
        RAY_DASHBOARD_URL="http://${RAY_DASHBOARD_ADDR}:${RAY_DASHBOARD_PORT}"
        JOB_STATUS_OUTPUT=$(ray job status --address="${RAY_DASHBOARD_URL}" "$RAY_JOB_ID" 2>/dev/null || echo "")
        JOB_STATUS=$(echo "$JOB_STATUS_OUTPUT" | grep -i "status" | head -1 || echo "")
        if echo "$JOB_STATUS" | grep -qi "running\|pending"; then
            echo "Warning: Ray job $RAY_JOB_ID is still running."
            echo "  The job will continue running in the background."
            echo "  To view logs: ray job logs --address=\"${RAY_DASHBOARD_URL}\" $RAY_JOB_ID"
            echo "  To check status: ray job status --address=\"${RAY_DASHBOARD_URL}\" $RAY_JOB_ID"
            echo "  To stop job: ray job stop --address=\"${RAY_DASHBOARD_URL}\" $RAY_JOB_ID"
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
        # Clean up local temp dir on master
        # Be careful not to delete the parent directory if shared
        if [[ "$USER_TMP_DIR" == *"/tmp_r"* ]]; then
            rm -rf "$USER_TMP_DIR" 2>/dev/null || true
        fi
    fi
}

# Register cleanup function to run on script exit
trap cleanup EXIT INT TERM

# Clean up any existing processes from previous runs
cleanup_own_processes
sleep 2

export PYTHONUNBUFFERED=1

# Host IP address that Ray workers will use to access services
HOST_IP=${HOST_IP:-"${MASTER_ADDR}"}

# SandboxFusion server configuration
SANDBOX_HOST=${SANDBOX_HOST:-"0.0.0.0"}
SANDBOX_URL="http://${HOST_IP}:${SANDBOX_PORT}/run_code"

echo "Host IP for service access: ${HOST_IP}"
echo "SANDBOX_URL for Ray workers: ${SANDBOX_URL}"

# Test SSH connection to worker nodes (only in manual mode)
if [ -z "$SLURM_JOB_NODELIST" ] && [ ! -z "$WORKER_ADDR" ]; then
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
fi

# Start SandboxFusion server in background (only on master node)
if [ "$NODE_RANK" -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Starting SandboxFusion server..."
    echo "=========================================="

    SANDBOX_DIR="/workspace/S/shiwenxuan/verl/SandboxFusion"
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
        conda activate sandbox-runtime-swx 2>/dev/null || {
            echo "ERROR: Could not activate sandbox-runtime-swx conda environment"
            echo "Please ensure sandbox-runtime-swx conda environment exists: conda env list"
            exit 1
        }
        echo "✓ Activated sandbox-runtime-swx conda environment"
    else
        echo "ERROR: conda not found. sandbox-runtime-swx is a conda environment."
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
    
    if [ -f "/workspace/S/shiwenxuan/bin/micromamba" ]; then
        micromamba deactivate 2>/dev/null || true
        
        # Try to activate workspace environment first
        if [ -d "/workspace/S/shiwenxuan/envs/slime" ]; then
            micromamba activate /workspace/S/shiwenxuan/envs/slime
        else
            micromamba activate slime
        fi
        
        if [ $? -ne 0 ]; then
            echo "ERROR: Could not activate slime micromamba environment"
            echo "Please ensure slime environment exists: micromamba env list"
            exit 1
        fi
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
else
    echo "Worker node ${NODE_RANK}: Waiting for SandboxFusion server on master node..."
    # Wait for SandboxFusion server to be ready
    MAX_RETRIES=60
    for i in $(seq 1 $MAX_RETRIES); do
        if curl -s http://${MASTER_ADDR}:${SANDBOX_PORT}/health > /dev/null 2>&1 || \
           curl -s http://${MASTER_ADDR}:${SANDBOX_PORT}/ > /dev/null 2>&1 || \
           curl -s http://${MASTER_ADDR}:${SANDBOX_PORT}/run_code > /dev/null 2>&1; then
            echo "✓ SandboxFusion server is ready on master node!"
            break
        fi
        if [ $i -eq $MAX_RETRIES ]; then
            echo "⚠ Warning: SandboxFusion server may not be ready after ${MAX_RETRIES} seconds"
        else
            sleep 2
        fi
    done
fi

# Model checkpoint paths (matching ToRL configuration)
# HF_MODEL_PATH: Original HuggingFace format model (for tokenizer and config)
HF_MODEL_PATH=/nfs_global/S/shiwenxuan/codev-t1/models/Qwen2.5-Math-1.5B
# MODEL_PATH: Megatron format model directory (for actual model weights)
MODEL_PATH=/nfs_global/S/shiwenxuan/codev-t1/models/Qwen2.5-Math-1.5B_torch_dist
DATA_PATH=/workspace/S/shiwenxuan/slime/examples/torl/data/torl_data

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
   ${WANDB_API_KEY:+--wandb-key "${WANDB_API_KEY}"}
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

# Setup Ray cluster
if [ "$NODE_RANK" -eq 0 ]; then
    # Master node: Start Ray head
    echo "=========================================="
    echo "Setting up Ray cluster..."
    echo "=========================================="
    
    # Get actual IP address of current node
    # Improved logic to ensure Master IP consistency with Worker perception
    
    # 1. Try to resolve MASTER_ADDR to IPv4
    RESOLVED_IP=$(getent hosts "$MASTER_ADDR" | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    
    # 2. Get all local IPv4 addresses
    LOCAL_IPS=$(hostname -I | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b')
    
    CURRENT_NODE_IP=""
    
    # 3. If resolved IP is bound to local interface, use it (Ideal case)
    if [ ! -z "$RESOLVED_IP" ] && echo "$LOCAL_IPS" | grep -q "$RESOLVED_IP"; then
        echo "Using resolved MASTER_ADDR IP: $RESOLVED_IP"
        CURRENT_NODE_IP=$RESOLVED_IP
    fi
    
    # 4. If not, try to find a local IP in the same subnet as the resolved IP (e.g. 10.200.80.x)
    if [ -z "$CURRENT_NODE_IP" ] && [ ! -z "$RESOLVED_IP" ]; then
        SUBNET=$(echo "$RESOLVED_IP" | cut -d. -f1-3)
        MATCHED_IP=$(echo "$LOCAL_IPS" | grep "^$SUBNET\." | head -1)
        if [ ! -z "$MATCHED_IP" ]; then
            echo "Using local IP in same subnet as MASTER_ADDR: $MATCHED_IP"
            CURRENT_NODE_IP=$MATCHED_IP
        fi
    fi
    
    # 5. Fallback: Prefer 10.200.80.x subnet (Cluster specific heuristic)
    if [ -z "$CURRENT_NODE_IP" ]; then
        MATCHED_IP=$(echo "$LOCAL_IPS" | grep "^10\.200\.80\." | head -1)
        if [ ! -z "$MATCHED_IP" ]; then
            echo "Using heuristic local IP (10.200.80.x): $MATCHED_IP"
            CURRENT_NODE_IP=$MATCHED_IP
        fi
    fi
    
    # 6. Fallback: Prefer any 10.200.x.x
    if [ -z "$CURRENT_NODE_IP" ]; then
        MATCHED_IP=$(echo "$LOCAL_IPS" | grep "^10\.200\." | head -1)
        if [ ! -z "$MATCHED_IP" ]; then
             CURRENT_NODE_IP=$MATCHED_IP
        fi
    fi

    # 7. Last resort
    if [ -z "$CURRENT_NODE_IP" ]; then
        echo "Warning: Could not determine optimal IP. Using first available."
        CURRENT_NODE_IP=$(echo "$LOCAL_IPS" | head -1)
    fi
    echo "Master Node IP: ${CURRENT_NODE_IP}"
    
    echo "Ensuring Ray is stopped before starting..."
    ray stop --force 2>/dev/null || true
    sleep 2

    cleanup_worker_nodes
    sleep 1

    if lsof -ti:${RAY_DASHBOARD_PORT} >/dev/null 2>&1; then
        echo "Port ${RAY_DASHBOARD_PORT} is still in use, force killing..."
        lsof -ti:${RAY_DASHBOARD_PORT} 2>/dev/null | xargs kill -9 2>/dev/null || true
        sleep 1
    fi

    RAY_RUNTIME_DIR="$USER_TMP_DIR/ray"
    mkdir -p "$RAY_RUNTIME_DIR"
    if [ -d "$RAY_RUNTIME_DIR" ]; then
        echo "Cleaning up Ray session directories..."
        find "$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Clean up old IP address records to avoid IP mismatch warnings
    if [ -f "$HOME/.ray/node_ip_address.json" ]; then
        rm -f "$HOME/.ray/node_ip_address.json" 2>/dev/null || true
    fi
    if [ -d "$RAY_RUNTIME_DIR" ]; then
        find "$RAY_RUNTIME_DIR" -name "node_ip_address.json" -delete 2>/dev/null || true
    fi

    # Start Ray head node on master
    echo "Starting Ray head node on ${MASTER_ADDR} (IP: ${CURRENT_NODE_IP})..."
    # Ray dashboard needs a temp dir to write logs, we must ensure it exists and is writable
    # Match the successful script's parameters
    
    # Try to start ray with --dashboard-host=0.0.0.0 to ensure accessibility
    # Also, we need to make sure we are not using 127.0.0.1 for submission if it binds to specific IP
    
    ray start --head \
        --node-ip-address ${CURRENT_NODE_IP} \
        --port=$RAY_GCS_PORT \
        --redis-shard-ports $RS_PORT \
        --node-manager-port $NM_PORT \
        --object-manager-port $OM_PORT \
        --dashboard-port $DASHBOARD_PORT \
        --dashboard-agent-listen-port $DAL_PORT \
        --ray-client-server-port $RCS_PORT \
        --num-gpus ${GPUS_PER_NODE} \
        --disable-usage-stats \
        --dashboard-host=0.0.0.0 \
        --temp-dir=$RAY_TEMP_DIR \
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
else
    # Worker node: Connect to Ray head
    echo "=========================================="
    echo "Worker node ${NODE_RANK}: Connecting to Ray cluster..."
    echo "=========================================="
    
    # Initialize micromamba on worker node
    if [ -f "/workspace/S/shiwenxuan/bin/micromamba" ]; then
        export MAMBA_EXE='/workspace/S/shiwenxuan/bin/micromamba'
        export MAMBA_ROOT_PREFIX='/nfs_global/S/shiwenxuan/micromamba'
        eval "$($MAMBA_EXE shell hook --shell bash --root-prefix $MAMBA_ROOT_PREFIX 2>/dev/null)" || true
        
        # Try to activate workspace environment first
        if [ -d "/workspace/S/shiwenxuan/envs/slime" ]; then
            micromamba activate /workspace/S/shiwenxuan/envs/slime
        else
            micromamba activate slime 2>/dev/null
        fi
        
        if [ $? -ne 0 ]; then
            echo "ERROR: Could not activate slime environment"
            exit 1
        fi
    fi
    
    export PYTHONPATH="/workspace/S/shiwenxuan/Megatron-LM/:${SCRIPT_DIR}:${SLIME_ROOT}:/workspace/S/shiwenxuan/slime:/workspace/S/shiwenxuan/sglang/python:/workspace/S/shiwenxuan/verl:/workspace/S/shiwenxuan/verl/eda_tools"
    export CUDA_DEVICE_MAX_CONNECTIONS=1
    
    # Resolve MASTER_ADDR to IP address to ensure consistency across all nodes
    # We want the IP that matches the 10.200 subnet if possible, or just the primary IP
    # FORCE IPv4
    MASTER_IP=$(getent hosts $MASTER_ADDR | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    if [ -z "$MASTER_IP" ]; then
        echo "Warning: Could not resolve MASTER_ADDR=$MASTER_ADDR to IP. Using hostname."
        MASTER_IP=$MASTER_ADDR
    fi
    echo "Resolved MASTER_ADDR $MASTER_ADDR to IP: $MASTER_IP"
    
    RAY_ADDRESS="${MASTER_IP}:${RAY_GCS_PORT}"
    
    ray stop --force 2>/dev/null || true
    sleep 2
    
    RAY_RUNTIME_DIR="$USER_TMP_DIR/ray"
    mkdir -p "$RAY_RUNTIME_DIR"
    if [ -d "$RAY_RUNTIME_DIR" ]; then
        find "$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
    fi
    
    # Clean up old IP address records to avoid IP mismatch warnings
    # Ray stores IP address in ~/.ray/node_ip_address.json or similar locations
    if [ -f "$HOME/.ray/node_ip_address.json" ]; then
        rm -f "$HOME/.ray/node_ip_address.json" 2>/dev/null || true
    fi
    # Also check in RAY_RUNTIME_DIR
    if [ -d "$RAY_RUNTIME_DIR" ]; then
        find "$RAY_RUNTIME_DIR" -name "node_ip_address.json" -delete 2>/dev/null || true
    fi
    
    echo "Waiting for master Ray node to be ready..."
    MAX_WAIT=120
    WAITED=0
    while [ $WAITED -lt $MAX_WAIT ]; do
        if ray status --address="$RAY_ADDRESS" 2>/dev/null | grep -qE '(Healthy|ALIVE|Active|node)'; then
            echo "Master Ray node is ready!"
            break
        fi
        sleep 2
        WAITED=$((WAITED + 2))
    done
    
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo "ERROR: Master Ray node at $RAY_ADDRESS is not ready after ${MAX_WAIT} seconds"
        exit 1
    fi
    
    echo "Connecting to Ray cluster at $RAY_ADDRESS..."
    # Get actual IP address of current node to avoid hostname/IP mismatch
    # Prefer 10.200.x.x IPs to match head node
    CURRENT_NODE_IP=$(hostname -I | grep -o '10\.200\.[0-9]*\.[0-9]*' | head -1)
    if [ -z "$CURRENT_NODE_IP" ]; then
        CURRENT_NODE_IP=$(hostname -I | awk '{print $1}' || echo "")
    fi
    if [ -z "$CURRENT_NODE_IP" ]; then
        CURRENT_NODE_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || echo "")
    fi
    
    # Start Ray worker
    # CRITICAL: Use the resolved MASTER_IP for connection
    ray start --address="${MASTER_IP}:${RAY_GCS_PORT}" \
        --node-ip-address="$CURRENT_NODE_IP" \
        --node-manager-port $NM_PORT \
        --object-manager-port $OM_PORT \
        --dashboard-agent-listen-port $DAL_PORT \
        --num-gpus ${GPUS_PER_NODE} \
        --disable-usage-stats \
        --temp-dir=$RAY_TEMP_DIR \
        2>&1
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to start Ray worker node"
        exit 1
    fi
    
    echo "✓ Ray worker node started successfully"
    
    # Wait for job agent to be ready - job agent needs time to initialize
    # Ray job agent starts automatically when a worker node connects, but it needs time
    echo "Waiting for Ray job agent to be ready..."
    # Check if job agent is accessible by trying to connect to the node's job agent port
    # Job agent typically runs on a port assigned by Ray (usually around 52365)
    # We'll wait longer to ensure job agent is fully initialized
    sleep 10
    
    # Additional check: verify Ray cluster connectivity
    echo "Verifying Ray cluster connectivity..."
    for i in $(seq 1 5); do
        if ray status --address="$RAY_ADDRESS" 2>/dev/null | grep -qE '(Healthy|ALIVE|Active)'; then
            echo "✓ Ray cluster connectivity verified"
            break
        fi
        sleep 2
    done
    
    # Worker nodes wait here for master to finish
    echo "Worker node ${NODE_RANK} is waiting for master node to complete training..."
    while true; do
        if ! ray status --address="$RAY_ADDRESS" 2>/dev/null | grep -qE '(Healthy|ALIVE|Active)'; then
            echo "Ray cluster is shutting down. Worker node exiting."
            break
        fi
        sleep 10
    done
    exit 0
fi

# Resolve MASTER_ADDR to IP for consistency (if not already resolved in SLURM mode)
if [ -z "$MASTER_IP" ]; then
    MASTER_IP=$(getent hosts $MASTER_ADDR | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    if [ -z "$MASTER_IP" ]; then
        MASTER_IP=$MASTER_ADDR
    fi
fi

RAY_ADDRESS="${MASTER_IP}:${RAY_GCS_PORT}"
echo "Ray address for worker nodes: ${RAY_ADDRESS}"

# In manual mode, start Ray worker on remote node via SSH
if [ -z "$SLURM_JOB_NODELIST" ] && [ ! -z "$WORKER_ADDR" ]; then
    echo ""
    echo "Starting Ray worker node on ${WORKER_ADDR}..."
    echo "Note: Worker node should have slime environment and access to /nfs_global"
    ssh -o StrictHostKeyChecking=no ${WORKER_ADDR} bash -s << EOF
set -e
export PYTHONUNBUFFERED=1

USER_TMP_DIR="/workspace/S/shiwenxuan/tmp"
USER_DATA_DIR="/nfs_global/S/shiwenxuan/tmp"
mkdir -p \$USER_TMP_DIR \$USER_DATA_DIR

export TMPDIR=\$USER_TMP_DIR
export TMP=\$USER_TMP_DIR
export TEMP=\$USER_TMP_DIR
export RAY_TMPDIR=\$USER_TMP_DIR

export SGLANG_DISABLE_DEEPGEMM=1
export SGLANG_DISABLE_FLASHINFER_SAMPLING=1

export TRITON_CACHE_DIR="\$USER_TMP_DIR/triton_cache"
export TORCH_EXTENSIONS_DIR="\$USER_TMP_DIR/torch_extensions"
export SGLANG_TMPDIR="\$USER_TMP_DIR/sglang_tmp"
mkdir -p \$TORCH_EXTENSIONS_DIR \$TRITON_CACHE_DIR \$SGLANG_TMPDIR

RAY_SPILL_DIR="\$USER_DATA_DIR/ray_spill"
mkdir -p \$RAY_SPILL_DIR

RAY_ADDRESS="${RAY_ADDRESS}"
GPUS_PER_NODE=${GPUS_PER_NODE}
SCRIPT_DIR="${SCRIPT_DIR}"
SLIME_ROOT="${SLIME_ROOT}"

export MAMBA_EXE='/workspace/S/shiwenxuan/bin/micromamba'
export MAMBA_ROOT_PREFIX='/nfs_global/S/shiwenxuan/micromamba'

if [ -f "\$MAMBA_EXE" ]; then
    eval "\$(\$MAMBA_EXE shell hook --shell bash --root-prefix \$MAMBA_ROOT_PREFIX 2>/dev/null)"
    if [ \$? -eq 0 ]; then
        if [ -d "/workspace/S/shiwenxuan/envs/slime" ]; then
            micromamba activate /workspace/S/shiwenxuan/envs/slime 2>/dev/null
        else
            micromamba activate slime 2>/dev/null
        fi

        if [ \$? -ne 0 ]; then
            echo "ERROR: Could not activate slime environment"
            if ! command -v ray >/dev/null 2>&1; then
                exit 1
            fi
        fi
    else
        echo "ERROR: Failed to initialize micromamba"
        exit 1
    fi
else
    echo "ERROR: micromamba not found at \$MAMBA_EXE"
    exit 1
fi

export PYTHONPATH="/workspace/S/shiwenxuan/Megatron-LM/:\${SCRIPT_DIR}:\${SLIME_ROOT}:/workspace/S/shiwenxuan/slime:/workspace/S/shiwenxuan/sglang/python:/workspace/S/shiwenxuan/verl:/workspace/S/shiwenxuan/verl/eda_tools"
export CUDA_DEVICE_MAX_CONNECTIONS=1

if ! command -v ray >/dev/null 2>&1; then
    echo "ERROR: ray command not found. Make sure slime environment is activated."
    exit 1
fi

ray stop --force 2>/dev/null || true
sleep 2

RAY_RUNTIME_DIR="\$USER_TMP_DIR/ray"
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
ray start --address="\$RAY_ADDRESS" \
    --num-gpus \$GPUS_PER_NODE \
    --disable-usage-stats \
    --object-spilling-directory=\$RAY_SPILL_DIR \
    --temp-dir=\$USER_TMP_DIR \
    2>&1

if [ \$? -ne 0 ]; then
    echo "ERROR: Failed to start Ray worker node"
    exit 1
fi

echo "Ray worker node started successfully"

# Keep worker node running
while true; do
    if ! ray status --address="\$RAY_ADDRESS" 2>/dev/null | grep -qE '(Healthy|ALIVE|Active)'; then
        echo "Ray cluster is shutting down. Worker node exiting."
        break
    fi
    sleep 10
done
EOF

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to start Ray worker node on ${WORKER_ADDR}"
        exit 1
    fi

    echo "✓ Ray worker node started successfully"
fi

sleep 5

echo ""
echo "Ray cluster status:"
ray status

NODE_COUNT=$(ray status 2>/dev/null | grep -c "node_" || echo "0")
if [ "$NODE_COUNT" -lt "$NUM_NODES" ]; then
    echo "Warning: Expected ${NUM_NODES} nodes, but found ${NODE_COUNT} nodes"
    echo "Waiting a bit longer for worker nodes to connect..."
    sleep 10
    ray status
fi

echo ""
echo "SANDBOX_URL for Ray workers: ${SANDBOX_URL}"
echo "  (SandboxFusion server is listening on ${SANDBOX_HOST}:${SANDBOX_PORT})"
echo ""

# Build runtime environment JSON matching train-multigpu.sh pattern
# Use jq if available for proper JSON escaping, otherwise construct manually
if command -v jq >/dev/null 2>&1; then
    RUNTIME_ENV_JSON=$(jq -n \
        --arg PYTHONPATH "/workspace/S/shiwenxuan/Megatron-LM/:${SCRIPT_DIR}:${SLIME_ROOT}:/workspace/S/shiwenxuan/slime:/workspace/S/shiwenxuan/sglang/python:/workspace/S/shiwenxuan/verl:/workspace/S/shiwenxuan/verl/eda_tools" \
        --arg CUDA_DEVICE_MAX_CONNECTIONS "1" \
        --arg SANDBOX_URL "${SANDBOX_URL}" \
        --arg NCCL_SOCKET_IFNAME "${NETWORK_INTERFACE}" \
        --arg GLOO_SOCKET_IFNAME "${NETWORK_INTERFACE}" \
        --arg NCCL_IB_DISABLE "${NCCL_IB_DISABLE}" \
        --arg TMPDIR "${USER_TMP_DIR}" \
        --arg TMP "${USER_TMP_DIR}" \
        --arg TEMP "${USER_TMP_DIR}" \
        '{
            "env_vars": {
                "PYTHONPATH": $PYTHONPATH,
                "CUDA_DEVICE_MAX_CONNECTIONS": $CUDA_DEVICE_MAX_CONNECTIONS,
                "SANDBOX_URL": $SANDBOX_URL,
                "NCCL_SOCKET_IFNAME": $NCCL_SOCKET_IFNAME,
                "GLOO_SOCKET_IFNAME": $GLOO_SOCKET_IFNAME,
                "NCCL_IB_DISABLE": $NCCL_IB_DISABLE,
                "TMPDIR": $TMPDIR,
                "TMP": $TMP,
                "TEMP": $TEMP
            }
        }')
else
    # Fallback: manual JSON construction (less safe but works if jq unavailable)
    RUNTIME_ENV_JSON="{
  \"env_vars\": {
    \"PYTHONPATH\": \"/workspace/S/shiwenxuan/Megatron-LM/:${SCRIPT_DIR}:${SLIME_ROOT}:/workspace/S/shiwenxuan/slime:/workspace/S/shiwenxuan/sglang/python:/workspace/S/shiwenxuan/verl:/workspace/S/shiwenxuan/verl/eda_tools\",
    \"CUDA_DEVICE_MAX_CONNECTIONS\": \"1\",
    \"SANDBOX_URL\": \"${SANDBOX_URL}\",
    \"NCCL_SOCKET_IFNAME\": \"${NETWORK_INTERFACE}\",
    \"GLOO_SOCKET_IFNAME\": \"${NETWORK_INTERFACE}\",
    \"NCCL_IB_DISABLE\": \"${NCCL_IB_DISABLE}\",
    \"TMPDIR\": \"${USER_TMP_DIR}\",
    \"TMP\": \"${USER_TMP_DIR}\",
    \"TEMP\": \"${USER_TMP_DIR}\"
  }
}"
fi

# Submit Ray job (only on master node)
if [ "$NODE_RANK" -ne 0 ]; then
    echo "Worker node ${NODE_RANK} should not reach here. Exiting."
    exit 1
fi

# Use master node IP for Ray dashboard address (not 127.0.0.1 in multi-node setup)
# FIX: Use actual Master IP instead of 127.0.0.1.
# In complex multi-NIC environments, 127.0.0.1 may not route correctly to the dashboard bound to a specific interface or 0.0.0.0.
# Using the resolved MASTER_IP ensures we are talking to the same interface Ray is bound to.
RAY_DASHBOARD_ADDRESS="http://${CURRENT_NODE_IP}:${RAY_DASHBOARD_PORT}"

echo "=========================================="
echo "Submitting Ray job..."
echo "=========================================="
echo "Ray dashboard address: ${RAY_DASHBOARD_ADDRESS}"

# Wait for job agents on all nodes to be ready before submitting job
# This is important because Ray job submission requires job agents to be running on all nodes
echo "Waiting for Ray job agents on all nodes to be ready..."
MAX_WAIT=120
WAITED=0
JOB_AGENTS_READY=0
while [ $WAITED -lt $MAX_WAIT ]; do
    # Check if dashboard is accessible
    if curl -s "${RAY_DASHBOARD_ADDRESS}/api/version" > /dev/null 2>&1; then
        # Check if all expected nodes are connected
        NODE_COUNT=$(ray status 2>/dev/null | grep -c "node_" || echo "0")
        if [ "$NODE_COUNT" -ge "$NUM_NODES" ]; then
            echo "✓ Ray cluster is ready with ${NODE_COUNT} nodes"
            
            # Additional wait to ensure job agents are fully initialized
            # Job agents need time to start and register with the dashboard
            echo "Waiting for job agents to initialize (this may take 20-30 seconds)..."
            sleep 20
            
            # Try to check job agent status via dashboard API
            # Job agents should be registered in the dashboard
            if curl -s "${RAY_DASHBOARD_ADDRESS}/api/nodes" > /dev/null 2>&1; then
                echo "✓ Dashboard API is accessible"
                
                # Try to verify job agent is actually ready by checking nodes endpoint
                # This gives us more confidence that job agents are running
                NODES_JSON=$(curl -s "${RAY_DASHBOARD_ADDRESS}/api/nodes" 2>/dev/null || echo "")
                if [ ! -z "$NODES_JSON" ]; then
                    # Check if we can see all nodes in the response
                    NODES_IN_RESPONSE=$(echo "$NODES_JSON" | grep -o '"node_id"' | wc -l || echo "0")
                    if [ "$NODES_IN_RESPONSE" -ge "$NUM_NODES" ]; then
                        echo "✓ All ${NUM_NODES} nodes are registered in dashboard"
                        # Additional wait to ensure job agents are fully ready
                        echo "Final wait for job agent initialization..."
                        sleep 10
                        JOB_AGENTS_READY=1
                        break
                    else
                        echo "⚠ Only ${NODES_IN_RESPONSE} nodes found in dashboard (expected ${NUM_NODES})."
                        # CRITICAL FIX: If ray status sees the nodes, but dashboard doesn't, we should TRUST RAY STATUS.
                        # Dashboard is often flaky in multi-interface HPC environments.
                        RAY_STATUS_NODES=$(ray status 2>/dev/null | grep -c "node_" || echo "0")
                        if [ "$RAY_STATUS_NODES" -ge "$NUM_NODES" ]; then
                             echo "✓ Ray status confirms ${RAY_STATUS_NODES} nodes are active. Ignoring Dashboard API mismatch."
                             echo "Proceeding with job submission..."
                             JOB_AGENTS_READY=1
                             break
                        else
                             echo "⚠ Ray status also shows insufficient nodes (${RAY_STATUS_NODES}/${NUM_NODES}), waiting more..."
                             sleep 5
                        fi
                    fi
                else
                    echo "⚠ Could not retrieve nodes info from dashboard, waiting more..."
                    sleep 5
                fi
            else
                echo "⚠ Dashboard API not fully ready, waiting more..."
                sleep 5
            fi
        else
            echo "⚠ Waiting for nodes to connect (${NODE_COUNT}/${NUM_NODES})..."
        fi
    else
        echo "⚠ Dashboard not accessible yet, waiting..."
    fi
    sleep 3
    WAITED=$((WAITED + 3))
done

if [ $JOB_AGENTS_READY -eq 0 ]; then
    echo "⚠ Warning: Ray job agents may not be fully ready after ${MAX_WAIT} seconds"
    echo "Current node count: $(ray status 2>/dev/null | grep -c "node_" || echo "0")"
    echo "Ray cluster status:"
    ray status 2>/dev/null | head -30 || true
    echo ""
    echo "Proceeding with job submission anyway (this may fail if job agents are not ready)..."
    # Give it one more chance with a longer wait
    sleep 15
fi

TEMP_JOB_OUTPUT=$(mktemp)
CLEANUP_TEMP_FILE="rm -f $TEMP_JOB_OUTPUT"
trap "$CLEANUP_TEMP_FILE; cleanup" EXIT INT TERM

if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL ray job submit --address="${RAY_DASHBOARD_ADDRESS}" \
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
    ray job submit --address="${RAY_DASHBOARD_ADDRESS}" \
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
    stdbuf -oL -eL ray job logs --address="${RAY_DASHBOARD_ADDRESS}" --follow "$RAY_JOB_ID" 2>&1
else
    ray job logs --address="${RAY_DASHBOARD_ADDRESS}" --follow "$RAY_JOB_ID" 2>&1
fi
LOGS_EXIT_CODE=$?

if [ $LOGS_EXIT_CODE -ne 0 ]; then
    echo "" >&2
    echo "Ray job logs command exited with code: $LOGS_EXIT_CODE" >&2
    JOB_STATUS_OUTPUT=$(ray job status --address="${RAY_DASHBOARD_ADDRESS}" "$RAY_JOB_ID" 2>/dev/null || echo "UNKNOWN")
    JOB_STATUS=$(echo "$JOB_STATUS_OUTPUT" | grep -i "status" | head -1 || echo "UNKNOWN")
    echo "Ray job status: $JOB_STATUS" >&2
    if echo "$JOB_STATUS" | grep -qi "running\|pending"; then
        echo "Job is still running. Logs following was interrupted but job continues." >&2
        echo "To view logs: ray job logs --address=\"${RAY_DASHBOARD_ADDRESS}\" $RAY_JOB_ID" >&2
        echo "To check status: ray job status --address=\"${RAY_DASHBOARD_ADDRESS}\" $RAY_JOB_ID" >&2
        echo "To stop job: ray job stop --address=\"${RAY_DASHBOARD_ADDRESS}\" $RAY_JOB_ID" >&2
    fi
fi

