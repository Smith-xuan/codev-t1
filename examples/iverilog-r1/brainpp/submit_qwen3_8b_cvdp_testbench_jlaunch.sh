#!/usr/bin/env bash

set -euo pipefail

RUN_NAME="${RUN_NAME:-qwen3-8b-cvdp-$(date +%d%H%M)}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/qwen3_8b_cvdp_testbench.conf"

if ! command -v jlaunch >/dev/null 2>&1; then
  echo "ERROR: jlaunch not found in PATH" >&2
  exit 1
fi

sync_repo_to_mount() {
  if [[ ! -d "${LOCAL_REPO_ROOT}" ]]; then
    echo "ERROR: local repo root not found: ${LOCAL_REPO_ROOT}" >&2
    exit 1
  fi

  mkdir -p "${SYNC_REPO_ROOT}" "${SHARED_STATE_DIR}" "${LOG_ROOT}" "${CKPT_BASE}" "${WANDB_DIR}"

  if [[ "${LOCAL_REPO_ROOT}" == "${SYNC_REPO_ROOT}" ]]; then
    echo "Local repo already points at mounted repo: ${SYNC_REPO_ROOT}"
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
      "${LOCAL_REPO_ROOT}/" "${SYNC_REPO_ROOT}/"
  else
    echo "WARN: rsync not found, falling back to cp -a without delete" >&2
    mkdir -p "${SYNC_REPO_ROOT}"
    cp -a "${LOCAL_REPO_ROOT}/." "${SYNC_REPO_ROOT}/"
  fi
}

sync_repo_to_mount
rm -f "${HEAD_IP_FILE}"

BOOTSTRAP_ENTRYPOINT="${SYNC_REPO_ROOT}/examples/iverilog-r1/brainpp/run_qwen3_8b_cvdp_testbench_brainpp.sh"

common_args=(
  --image "${JLAUNCH_IMAGE}"
  --cpu "${JLAUNCH_CPU}"
  --memory "${JLAUNCH_MEMORY_MIB}"
  --gpu "${JLAUNCH_GPU}"
  --gpu-qos "${JLAUNCH_GPU_QOS}"
  --backoff-limit "${JLAUNCH_BACKOFF_LIMIT}"
  --max-wait-duration "${JLAUNCH_MAX_WAIT_DURATION}"
  --replica-restart never
  --workdir "${JLAUNCH_WORKDIR}"
  -d
)

if [[ -n "${JLAUNCH_CHARGED_GROUP}" ]]; then
  common_args+=(--charged-group "${JLAUNCH_CHARGED_GROUP}")
fi

if [[ -n "${JLAUNCH_PRIVATE_MACHINE}" ]]; then
  common_args+=(--private-machine "${JLAUNCH_PRIVATE_MACHINE}")
fi

if [[ -n "${JLAUNCH_POSITIVE_TAGS}" ]]; then
  IFS=',' read -r -a positive_tags <<< "${JLAUNCH_POSITIVE_TAGS}"
  for tag in "${positive_tags[@]}"; do
    if [[ -n "${tag}" ]]; then
      common_args+=(--positive-tags "${tag}")
    fi
  done
fi

if [[ -n "${JLAUNCH_NEGATIVE_TAGS}" ]]; then
  IFS=',' read -r -a negative_tags <<< "${JLAUNCH_NEGATIVE_TAGS}"
  for tag in "${negative_tags[@]}"; do
    if [[ -n "${tag}" ]]; then
      common_args+=(--negative-tags "${tag}")
    fi
  done
fi

if [[ -n "${JLAUNCH_CUSTOM_RESOURCES}" ]]; then
  IFS=',' read -r -a custom_resources <<< "${JLAUNCH_CUSTOM_RESOURCES}"
  for resource in "${custom_resources[@]}"; do
    if [[ -n "${resource}" ]]; then
      common_args+=(--custom-resources "${resource}")
    fi
  done
fi

volume_args=()
IFS=',' read -r -a extra_volumes <<< "${JLAUNCH_EXTRA_VOLUMES}"
for volume_spec in "${extra_volumes[@]}"; do
  if [[ -n "${volume_spec}" ]]; then
    volume_args+=(--volume "${volume_spec}")
  fi
done

mount_args=()
IFS=',' read -r -a mount_specs <<< "${JLAUNCH_MOUNT_SPECS}"
for mount_spec in "${mount_specs[@]}"; do
  if [[ -n "${mount_spec}" ]]; then
    mount_args+=(--mount "${mount_spec}")
  fi
done

env_args=()
append_env_arg() {
  local key="$1"
  local value="${!key:-}"
  if [[ -n "${value}" ]]; then
    env_args+=(-e "${key}=${value}")
  fi
}

required_envs=(
  REPO_NAME
  MOUNT_ROOT
  SYNC_REPO_ROOT
  REPO_ROOT
  EXAMPLE_DIR
  RUN_NAME
  NUM_NODES
  GPUS_PER_NODE
  ACTOR_NUM_NODES
  ACTOR_NUM_GPUS_PER_NODE
  ROLLOUT_NUM_GPUS
  ROLLOUT_NUM_GPUS_PER_ENGINE
  MASTER_PORT
  RAY_DASHBOARD_PORT
  SGLANG_ROUTER_PORT
  MODEL_PATH
  HF_MODEL_PATH
  CKPT_BASE
  CKPT_SAVE_NAME
  DATA_PATH
  CODEV_TEST_ROOT
  CVDP_TESTENV_ROOT
  TRAIN_FILE
  SHARED_STATE_DIR
  HEAD_IP_FILE
  LOG_ROOT
  RAY_TMP_ROOT
  IVERILOG_TMP_DIR
  WANDB_PROJECT
  WANDB_GROUP
  WANDB_MODE
  USE_WANDB
  WANDB_DIR
  CONTAINER_REPO_ROOT
)

optional_envs=(
  CVDP_PYTEST_PATH
  CVDP_EXTRA_BIN_PATH
  IVERILOG_PATH
  VVP_PATH
  YOSYS_PATH
  MEGATRON_LM_PATH
  SGLANG_GATEWAY_PATH
  SGLANG_PYTHON_PATH
  VERL_PATH
  EXTRA_PYTHONPATH
  ENTRY_ACTIVATE_CMD
  NETWORK_INTERFACE
  NCCL_IB_DISABLE
  WANDB_API_KEY
  HF_HOME
  TRANSFORMERS_CACHE
  HUGGINGFACE_HUB_CACHE
  HF_DATASETS_CACHE
)

for env_key in "${required_envs[@]}"; do
  append_env_arg "${env_key}"
done

for env_key in "${optional_envs[@]}"; do
  append_env_arg "${env_key}"
done

head_name="${RUN_NAME}-head"
worker_name="${RUN_NAME}-worker"

head_cmd=(bash -lc "cd '${SYNC_REPO_ROOT}' && bash '${BOOTSTRAP_ENTRYPOINT}' head")
worker_cmd=(bash -lc "cd '${SYNC_REPO_ROOT}' && bash '${BOOTSTRAP_ENTRYPOINT}' worker")

echo "Submitting head job: ${head_name}"
jlaunch \
  "${common_args[@]}" \
  "${volume_args[@]}" \
  "${mount_args[@]}" \
  "${env_args[@]}" \
  --name "${head_name}" \
  --comment "${head_name}" \
  -- \
  "${head_cmd[@]}"

if (( WORKER_REPLICAS > 0 )); then
  echo "Submitting worker job: ${worker_name} x${WORKER_REPLICAS}"
  jlaunch \
    "${common_args[@]}" \
    "${volume_args[@]}" \
    "${mount_args[@]}" \
    "${env_args[@]}" \
    -P "${WORKER_REPLICAS}" \
    --replica-prefix \
    --name "${worker_name}" \
    --comment "${worker_name}" \
    -- \
    "${worker_cmd[@]}"
fi

cat <<EOF
Submitted run: ${RUN_NAME}
- Head job:   ${head_name}
- Worker job: ${worker_name}
- Mounted repo: ${SYNC_REPO_ROOT}
- Runtime repo in container: ${CONTAINER_REPO_ROOT}
- Checkpoints: ${CKPT_BASE}/${CKPT_SAVE_NAME}
- W&B/offline dir: ${WANDB_DIR}
- Shared head IP file: ${HEAD_IP_FILE}
EOF
