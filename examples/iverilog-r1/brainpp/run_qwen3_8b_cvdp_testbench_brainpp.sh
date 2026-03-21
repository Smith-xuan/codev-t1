#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/qwen3_8b_cvdp_testbench.conf"

ROLE="${1:-${ROLE:-}}"
if [[ "${ROLE}" != "head" && "${ROLE}" != "worker" ]]; then
  echo "Usage: $0 [head|worker]" >&2
  exit 1
fi

if [[ -n "${ENTRY_ACTIVATE_CMD}" ]]; then
  eval "${ENTRY_ACTIVATE_CMD}"
fi

sync_repo_to_workspace() {
  if [[ ! -d "${SYNC_REPO_ROOT}" ]]; then
    echo "ERROR: mounted repo not found: ${SYNC_REPO_ROOT}" >&2
    exit 1
  fi

  mkdir -p \
    "$(dirname -- "${CONTAINER_REPO_ROOT}")" \
    "${CONTAINER_REPO_ROOT}" \
    "${SHARED_STATE_DIR}" \
    "${LOG_ROOT}" \
    "${CKPT_BASE}" \
    "${WANDB_DIR}" \
    "${RAY_TMP_ROOT}" \
    "${IVERILOG_TMP_DIR}"

  if [[ "${SYNC_REPO_ROOT}" == "${CONTAINER_REPO_ROOT}" ]]; then
    echo "Mounted repo already serves as runtime repo: ${SYNC_REPO_ROOT}"
    return 0
  fi

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git/' \
      --exclude '.idea/' \
      --exclude '.venv/' \
      --exclude '.pytest_cache/' \
      --exclude '__pycache__/' \
      --exclude '.brainpp/' \
      --exclude 'logs/brainpp/' \
      --exclude 'wandb/' \
      --exclude 'outputs/' \
      --exclude 'local/' \
      --exclude 'examples/*/tmp/' \
      --exclude 'examples/iverilog-r1/codev_test/results/' \
      --exclude 'examples/iverilog-r1/codev_test/*/results/' \
      "${SYNC_REPO_ROOT}/" "${CONTAINER_REPO_ROOT}/"
  else
    echo "WARN: rsync not found, falling back to cp -a without delete" >&2
    rm -rf "${CONTAINER_REPO_ROOT}"
    mkdir -p "${CONTAINER_REPO_ROOT}"
    cp -a "${SYNC_REPO_ROOT}/." "${CONTAINER_REPO_ROOT}/"
  fi
}

sync_repo_to_workspace

for required_command in python3 ray; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${required_command}" >&2
    exit 1
  fi
done

mkdir -p "${SHARED_STATE_DIR}" "${LOG_ROOT}" "${RAY_TMP_ROOT}" "${IVERILOG_TMP_DIR}" "${CKPT_BASE}" "${WANDB_DIR}"

NODE_LOG_FILE="${LOG_ROOT}/${ROLE}_$(hostname).log"
exec > >(tee -a "${NODE_LOG_FILE}") 2>&1

echo "Bootstrap role=${ROLE} host=$(hostname) mounted_repo=${SYNC_REPO_ROOT} runtime_repo=${REPO_ROOT}"

NODE_TMP_DIR="${RAY_TMP_ROOT}/${ROLE}"
mkdir -p "${NODE_TMP_DIR}/triton_cache" "${NODE_TMP_DIR}/torch_extensions" "${NODE_TMP_DIR}/sglang_tmp"

export TMPDIR="${NODE_TMP_DIR}"
export TMP="${NODE_TMP_DIR}"
export TEMP="${NODE_TMP_DIR}"
export RAY_TMPDIR="${NODE_TMP_DIR}/ray"
export TRITON_CACHE_DIR="${NODE_TMP_DIR}/triton_cache"
export TORCH_EXTENSIONS_DIR="${NODE_TMP_DIR}/torch_extensions"
export SGLANG_TMPDIR="${NODE_TMP_DIR}/sglang_tmp"
mkdir -p "${RAY_TMPDIR}"
export IVERILOG_TMP_DIR
export PYTHONUNBUFFERED=1
export TOKENIZERS_PARALLELISM=false
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
export SGLANG_DISABLE_DEEPGEMM=1
export SGLANG_DISABLE_FLASHINFER_SAMPLING=1
export CUDA_DEVICE_MAX_CONNECTIONS=1
export IVERILOG_EXECUTION_METHOD=local_iverilog

unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY ftp_proxy FTP_PROXY
export no_proxy="${no_proxy:-127.0.0.1,localhost,::1}"
export NO_PROXY="${NO_PROXY:-${no_proxy}}"

if [[ -n "${CVDP_EXTRA_BIN_PATH}" ]]; then
  export PATH="${CVDP_EXTRA_BIN_PATH}:${PATH}"
fi

if [[ -n "${NETWORK_INTERFACE:-}" ]]; then
  export NCCL_SOCKET_IFNAME="${NETWORK_INTERFACE}"
  export GLOO_SOCKET_IFNAME="${NETWORK_INTERFACE}"
  export TP_SOCKET_IFNAME="${NETWORK_INTERFACE}"
fi

HOST_IP="${HOST_IP:-$(hostname -i | awk '{print $1}')}"
if [[ -z "${HOST_IP}" ]]; then
  echo "ERROR: failed to resolve current host IP" >&2
  exit 1
fi

MEGATRON_LM_PATH="${MEGATRON_LM_PATH:-/root/Megatron-LM}"

build_pythonpath() {
  local parts=("${REPO_ROOT}" "${EXAMPLE_DIR}" "${EXAMPLE_DIR}/eda_tools")
  local optional_parts=(
    "${MEGATRON_LM_PATH}"
    "${SGLANG_GATEWAY_PATH}"
    "${SGLANG_PYTHON_PATH}"
    "${VERL_PATH}"
    "${EXTRA_PYTHONPATH}"
  )
  local value
  for value in "${optional_parts[@]}"; do
    if [[ -n "${value}" ]]; then
      parts=("${value}" "${parts[@]}")
    fi
  done
  local joined=""
  local item
  for item in "${parts[@]}"; do
    if [[ -z "${joined}" ]]; then
      joined="${item}"
    else
      joined="${joined}:${item}"
    fi
  done
  printf '%s\n' "${joined}"
}

export PYTHONPATH="$(build_pythonpath)"

build_runtime_env_json() {
  python3 <<'PY'
import json
import os

keys = [
    "PYTHONPATH",
    "PATH",
    "LD_LIBRARY_PATH",
    "MEGATRON_LM_PATH",
    "REPO_ROOT",
    "EXAMPLE_DIR",
    "MOUNT_ROOT",
    "SYNC_REPO_ROOT",
    "RUN_NAME",
    "DATA_PATH",
    "TRAIN_FILE",
    "MODEL_PATH",
    "HF_MODEL_PATH",
    "CKPT_BASE",
    "CKPT_SAVE_NAME",
    "WANDB_DIR",
    "WANDB_PROJECT",
    "WANDB_GROUP",
    "WANDB_MODE",
    "USE_WANDB",
    "SHARED_STATE_DIR",
    "HEAD_IP_FILE",
    "LOG_ROOT",
    "CUDA_DEVICE_MAX_CONNECTIONS",
    "TOKENIZERS_PARALLELISM",
    "PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION",
    "SGLANG_DISABLE_DEEPGEMM",
    "SGLANG_DISABLE_FLASHINFER_SAMPLING",
    "IVERILOG_EXECUTION_METHOD",
    "IVERILOG_TMP_DIR",
    "CVDP_TESTENV_ROOT",
    "CODEV_TEST_ROOT",
    "CVDP_PYTEST_PATH",
    "CVDP_EXTRA_BIN_PATH",
    "IVERILOG_PATH",
    "VVP_PATH",
    "YOSYS_PATH",
    "WANDB_API_KEY",
    "HF_HOME",
    "TRANSFORMERS_CACHE",
    "HUGGINGFACE_HUB_CACHE",
    "HF_DATASETS_CACHE",
    "NCCL_SOCKET_IFNAME",
    "GLOO_SOCKET_IFNAME",
    "TP_SOCKET_IFNAME",
    "NCCL_IB_DISABLE",
    "no_proxy",
    "NO_PROXY",
]
env = {key: value for key in keys if (value := os.environ.get(key))}
print(json.dumps({"env_vars": env}, ensure_ascii=False))
PY
}

wait_for_dashboard() {
  local attempt
  for attempt in $(seq 1 60); do
    if python3 - "${RAY_DASHBOARD_PORT}" <<'PY'
import sys
import urllib.request

port = sys.argv[1]
try:
    urllib.request.urlopen(f"http://127.0.0.1:{port}/api/version", timeout=2)
except Exception:
    raise SystemExit(1)
raise SystemExit(0)
PY
    then
      return 0
    fi
    sleep 2
  done

  echo "ERROR: Ray dashboard did not become ready on port ${RAY_DASHBOARD_PORT}" >&2
  return 1
}

wait_for_cluster() {
  local attempt
  for attempt in $(seq 1 180); do
    local node_count
    node_count="$(ray status 2>/dev/null | grep -c 'node_' || true)"
    if (( node_count >= NUM_NODES )); then
      echo "Ray cluster ready: ${node_count}/${NUM_NODES} nodes"
      return 0
    fi
    sleep 5
  done

  echo "ERROR: timed out waiting for ${NUM_NODES} Ray nodes" >&2
  return 1
}

cleanup() {
  ray stop --force >/dev/null 2>&1 || true
  if [[ "${ROLE}" == "head" ]]; then
    rm -f "${HEAD_IP_FILE}"
  fi
}

trap cleanup EXIT INT TERM

ray stop --force >/dev/null 2>&1 || true

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
  --normalization RMSNorm
  --norm-epsilon 1e-6
  --rotary-base "${MODEL_ARGS_ROTARY_BASE:-1000000}"
  --vocab-size 151936
  --kv-channels 128
  --qk-layernorm
  --untie-embeddings-and-output-weights
)

CKPT_ARGS=(
  --hf-checkpoint "${HF_MODEL_PATH}"
  --ref-load "${MODEL_PATH}"
  --load "${CKPT_BASE}/${CKPT_SAVE_NAME}"
  --save "${CKPT_BASE}/${CKPT_SAVE_NAME}"
  --save-interval 10
)

ROLLOUT_ARGS=(
  --rollout-function-path iverilog_async_rollout.generate_rollout_fully_async
  --prompt-data "${DATA_PATH}/${TRAIN_FILE}"
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
  --partial-rollout
  --eval-interval 20
  --eval-prompt-data codev_test "${DATA_PATH}/${TRAIN_FILE}"
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

SGLANG_ARGS=(
  --rollout-num-gpus "${ROLLOUT_NUM_GPUS}"
  --rollout-num-gpus-per-engine "${ROLLOUT_NUM_GPUS_PER_ENGINE}"
  --sglang-mem-fraction-static 0.5
  --sglang-cuda-graph-bs 1 2 4 8 $(seq 16 8 256)
  --sglang-router-ip "${HOST_IP}"
  --sglang-router-port "${SGLANG_ROUTER_PORT}"
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

WANDB_ARGS=()
if [[ "${USE_WANDB}" != "0" ]]; then
  WANDB_ARGS=(
    --use-wandb
    --wandb-mode "${WANDB_MODE}"
    --wandb-project "${WANDB_PROJECT}"
    --wandb-group "${WANDB_GROUP}"
  )
  if [[ -n "${WANDB_API_KEY:-}" ]]; then
    WANDB_ARGS+=(--wandb-key "${WANDB_API_KEY}")
  fi
fi

if [[ "${ROLE}" == "head" ]]; then
  echo "Starting Ray head on ${HOST_IP}:${MASTER_PORT}"
  ray start \
    --head \
    --node-ip-address "${HOST_IP}" \
    --port "${MASTER_PORT}" \
    --dashboard-host 0.0.0.0 \
    --dashboard-port "${RAY_DASHBOARD_PORT}" \
    --num-gpus "${GPUS_PER_NODE}" \
    --disable-usage-stats \
    --temp-dir "${RAY_TMPDIR}"

  printf '%s\n' "${HOST_IP}" > "${HEAD_IP_FILE}"
  wait_for_dashboard
  wait_for_cluster

  RUNTIME_ENV_JSON="$(build_runtime_env_json)"

  cd "${REPO_ROOT}"
  ray job submit \
    --address "http://127.0.0.1:${RAY_DASHBOARD_PORT}" \
    --runtime-env-json "${RUNTIME_ENV_JSON}" \
    -- python3 "${REPO_ROOT}/train_async.py" \
    --actor-num-nodes "${ACTOR_NUM_NODES}" \
    --actor-num-gpus-per-node "${ACTOR_NUM_GPUS_PER_NODE}" \
    "${MODEL_ARGS[@]}" \
    "${CKPT_ARGS[@]}" \
    "${ROLLOUT_ARGS[@]}" \
    "${OPTIMIZER_ARGS[@]}" \
    "${GRPO_ARGS[@]}" \
    "${WANDB_ARGS[@]}" \
    "${PERF_ARGS[@]}" \
    "${SGLANG_ARGS[@]}" \
    "${MISC_ARGS[@]}" \
    "${CUSTOM_ARGS[@]}"
else
  echo "Waiting for head IP file: ${HEAD_IP_FILE}"
  for _ in $(seq 1 180); do
    if [[ -s "${HEAD_IP_FILE}" ]]; then
      break
    fi
    sleep 2
  done

  if [[ ! -s "${HEAD_IP_FILE}" ]]; then
    echo "ERROR: head IP file not found: ${HEAD_IP_FILE}" >&2
    exit 1
  fi

  MASTER_IP="$(<"${HEAD_IP_FILE}")"
  echo "Joining Ray head at ${MASTER_IP}:${MASTER_PORT}"

  joined=0
  for _ in $(seq 1 60); do
    if ray start \
      --address "${MASTER_IP}:${MASTER_PORT}" \
      --node-ip-address "${HOST_IP}" \
      --num-gpus "${GPUS_PER_NODE}" \
      --disable-usage-stats \
      --temp-dir "${RAY_TMPDIR}"
    then
      joined=1
      break
    fi
    ray stop --force >/dev/null 2>&1 || true
    sleep 5
  done

  if [[ "${joined}" != "1" ]]; then
    echo "ERROR: failed to join Ray head at ${MASTER_IP}:${MASTER_PORT}" >&2
    exit 1
  fi

  while ray status --address "${MASTER_IP}:${MASTER_PORT}" >/dev/null 2>&1; do
    sleep 30
  done
fi
