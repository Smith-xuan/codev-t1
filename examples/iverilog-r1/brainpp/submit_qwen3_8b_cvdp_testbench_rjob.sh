#!/usr/bin/env bash

set -euo pipefail

RUN_NAME="${RUN_NAME:-qwen3-8b-cvdp-rjob-$(date +%d%H%M)}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/qwen3_8b_cvdp_testbench.conf"

if ! command -v "${RJOB_BIN}" >/dev/null 2>&1; then
  echo "ERROR: ${RJOB_BIN} not found in PATH" >&2
  echo "Hint: this script targets legacy 'rjob submit' environments. Use the jlaunch entry if your environment only provides brainctl/jlaunch." >&2
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

append_env_arg() {
  local key="$1"
  local value="${!key:-}"
  if [[ -n "${value}" ]]; then
    ENV_ARGS+=(-e "${key}=${value}")
  fi
}

append_repeated_flag_args() {
  local flag="$1"
  local values="$2"
  local item

  IFS=',' read -r -a _items <<< "${values}"
  for item in "${_items[@]}"; do
    if [[ -n "${item}" ]]; then
      COMMON_ARGS+=("${flag}=${item}")
    fi
  done
}

build_submit_args() {
  local job_name="$1"
  local cpu="$2"
  local memory="$3"
  local gpu="$4"
  local replicas="$5"
  local role="$6"
  local cmd="cd '${SYNC_REPO_ROOT}' && bash '${BOOTSTRAP_ENTRYPOINT}' ${role}"

  SUBMIT_ARGS=(
    "${RJOB_BIN}" submit
    "--name=${job_name}"
    "--image=${RJOB_IMAGE}"
    "--preemptible=${RJOB_PREEMPTIBLE}"
    "--gang-start=${RJOB_GANG_START}"
    "--auto-restart=${RJOB_AUTO_RESTART}"
    --cpu "${cpu}"
    --gpu "${gpu}"
    --memory "${memory}"
    "--replica=${replicas}"
  )

  if [[ -n "${RJOB_CHARGED_GROUP}" ]]; then
    SUBMIT_ARGS+=("--charged-group=${RJOB_CHARGED_GROUP}")
  fi

  if [[ -n "${RJOB_PRIVATE_MACHINE}" ]]; then
    SUBMIT_ARGS+=("--private-machine=${RJOB_PRIVATE_MACHINE}")
  fi

  SUBMIT_ARGS+=("${COMMON_ARGS[@]}")
  SUBMIT_ARGS+=("${ENV_ARGS[@]}")
  SUBMIT_ARGS+=(-- bash -lc "${cmd}")
}

sync_repo_to_mount
rm -f "${HEAD_IP_FILE}"

BOOTSTRAP_ENTRYPOINT="${SYNC_REPO_ROOT}/examples/iverilog-r1/brainpp/run_qwen3_8b_cvdp_testbench_brainpp.sh"

COMMON_ARGS=()

if [[ -n "${RJOB_SET_ENVS}" ]]; then
  IFS=',' read -r -a set_envs <<< "${RJOB_SET_ENVS}"
  for set_env in "${set_envs[@]}"; do
    if [[ -n "${set_env}" ]]; then
      COMMON_ARGS+=(--set-env "${set_env}")
    fi
  done
fi

append_repeated_flag_args "--positive-tags" "${RJOB_POSITIVE_TAGS}"
append_repeated_flag_args "--negative-tags" "${RJOB_NEGATIVE_TAGS}"
append_repeated_flag_args "--custom-resources" "${RJOB_CUSTOM_RESOURCES}"
append_repeated_flag_args "--mount" "${RJOB_MOUNT_SPECS}"
append_repeated_flag_args "--volume" "${RJOB_EXTRA_VOLUMES}"

ENV_ARGS=()
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

echo "Submitting rjob head: ${head_name}"
build_submit_args "${head_name}" "${RJOB_HEAD_CPU}" "${RJOB_HEAD_MEMORY_MIB}" "${RJOB_HEAD_GPU}" "1" "head"
"${SUBMIT_ARGS[@]}"

if (( WORKER_REPLICAS > 0 )); then
  echo "Submitting rjob worker: ${worker_name} x${WORKER_REPLICAS}"
  build_submit_args "${worker_name}" "${RJOB_WORKER_CPU}" "${RJOB_WORKER_MEMORY_MIB}" "${RJOB_WORKER_GPU}" "${WORKER_REPLICAS}" "worker"
  "${SUBMIT_ARGS[@]}"
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
