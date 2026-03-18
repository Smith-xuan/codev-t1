#!/bin/bash

# Training script for Iverilog-R1 with Qwen3-1.7B
# Adapted from verl's run_tir_codev_1.7b.sh

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

# PID file to track processes started by this script
PID_FILE="${SCRIPT_DIR}/.run_qwen3_1.7b.pid"
RAY_DASHBOARD_PORT=8265
IVERILOG_PORT=${IVERILOG_PORT:-8000}

# Function to cleanup processes started by this script
cleanup_own_processes() {
    echo "Cleaning up processes started by this script..."
    
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
    # Match processes that contain train.py or specific SGLang patterns for this job
    pkill -f "sglang.*train.py" 2>/dev/null || true
    pkill -f "python.*train.py.*iverilog" 2>/dev/null || true
    
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
    # This is safer - we kill Ray processes that might be using our dashboard port
    pkill -f "ray.*dashboard.*${RAY_DASHBOARD_PORT}" 2>/dev/null || true
    pkill -f "ray.*head.*${RAY_DASHBOARD_PORT}" 2>/dev/null || true
    
    # Clean up Ray runtime directory to avoid session conflicts
    # Only clean if we're sure no other Ray instance is running
    if ! pgrep -f "ray.*dashboard" >/dev/null 2>&1; then
        RAY_RUNTIME_DIR="/tmp/ray"
        if [ -d "$RAY_RUNTIME_DIR" ]; then
            echo "Cleaning up Ray runtime directory to avoid session conflicts..."
            # Only remove session directories, not the entire /tmp/ray
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

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SLIME_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"

# Host IP address that Ray workers will use to access services
# This is the actual network IP of the host machine
HOST_IP=${HOST_IP:-"10.21.0.3"}

# Iverilog server configuration
IVERILOG_HOST=${IVERILOG_HOST:-"0.0.0.0"}
# IVERILOG_PORT is already defined above
# Use the host IP for IVERILOG_URL (Ray workers will use this to access the server)
IVERILOG_URL="http://${HOST_IP}:${IVERILOG_PORT}/run_code"

echo "Host IP for service access: ${HOST_IP}"
echo "IVERILOG_URL for Ray workers: ${IVERILOG_URL}"

# Start iverilog server in background
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
    for i in {1..30}; do
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
MODEL_PATH=/nfs_global/LLaMA-Factory/saves/qwen3-1.7b/full/tool_8.1k_ds32_resummrized_10epochs/checkpoint-1270
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
   --rollout-batch-size 32
   --n-samples-per-prompt 8
   --rollout-max-response-len 20000  # Reduced to ensure input + output <= 40960 (model max context length)
   --rollout-max-context-len 40960    # Set to model's maximum context length
   --rollout-temperature 1.0

   # eval args (optional)
   --eval-interval 10
   --eval-prompt-data codev_test ${DATA_PATH}/test.parquet
   --eval-input-key prompt
   --eval-label-key reward_model
   --eval-tool-key tools
   --n-samples-per-eval-prompt 1
   --eval-max-response-len 20000  # Reduced for validation to ensure input + output <= 40960
   --eval-max-context-len 40960    # Set to model's maximum context length

   --global-batch-size 256
   --balance-data
)

PERF_ARGS=(
   # FSDP2 backend configuration (matching verl's fsdp_config)
   --train-backend fsdp
   --gradient-checkpointing  # Matching verl's enable_gradient_checkpointing
   
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
   --max-tokens-per-gpu 36000  # Matching verl's ppo_max_token_len_per_gpu
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
   # --use-tis
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
   --wandb-project verl_onpolicy_modified_format_reward_slime  # Matching verl's project_name
   --wandb-group codev_onpolicy_modified_format_reward_slime   # Matching verl's experiment_name
   ${WANDB_API_KEY:+--wandb-key "${WANDB_API_KEY}"}
)

SGLANG_ARGS=(
   --rollout-num-gpus-per-engine 8  # Each engine uses 2 GPUs (with 4 total GPUs, this creates 2 engines)
   --sglang-mem-fraction-static 0.6  # Reduced to 0.4 to leave more memory for FSDP in colocate mode
   --sglang-rl-on-policy-target fsdp  # Required when using FSDP backend for on-policy RL
   --sglang-mamba-ssm-dtype bfloat16
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

# launch the master node of ray in container
export MASTER_ADDR=${MASTER_ADDR:-"127.0.0.1"}
# Note: Ray should declare the actual number of GPUs used (4 for FSDP + 4 for SGLang = 8 total)
# But since we're using colocate mode, we need to ensure proper resource allocation

# Ensure Ray is completely stopped and cleaned up before starting
echo "Ensuring Ray is stopped before starting..."
ray stop --force 2>/dev/null || true
sleep 2

# If port is still in use, force kill processes using it
if lsof -ti:${RAY_DASHBOARD_PORT} >/dev/null 2>&1; then
    echo "Port ${RAY_DASHBOARD_PORT} is still in use, force killing..."
    lsof -ti:${RAY_DASHBOARD_PORT} 2>/dev/null | xargs kill -9 2>/dev/null || true
    sleep 1
fi

# Clean up Ray session directories to avoid session conflicts
RAY_RUNTIME_DIR="/tmp/ray"
if [ -d "$RAY_RUNTIME_DIR" ]; then
    echo "Cleaning up Ray session directories..."
    find "$RAY_RUNTIME_DIR" -maxdepth 1 -type d -name "session_*" -exec rm -rf {} + 2>/dev/null || true
fi

# Start Ray head node
echo "Starting Ray head node on port ${RAY_DASHBOARD_PORT}..."
ray start --head --node-ip-address ${MASTER_ADDR} --num-gpus 8 --disable-usage-stats --dashboard-host=0.0.0.0 --dashboard-port=${RAY_DASHBOARD_PORT} 2>&1

# Record Ray head process PID if possible
RAY_HEAD_PID=$(lsof -ti:${RAY_DASHBOARD_PORT} 2>/dev/null | head -1)
if [ ! -z "$RAY_HEAD_PID" ]; then
    echo "${RAY_HEAD_PID}" >> "$PID_FILE"
    echo "Ray head node started with PID: ${RAY_HEAD_PID}"
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
    \"IVERILOG_URL\": \"${IVERILOG_URL}\"
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
       --actor-num-nodes 1 \
       --actor-num-gpus-per-node 8 \
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
       --actor-num-nodes 1 \
       --actor-num-gpus-per-node 8 \
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

