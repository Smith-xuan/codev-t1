#!/bin/bash

set -ex

# Set installation directories to /nfs_global to avoid disk space issues
# /dev/vda2 (root) has only 3.2G free, while /nfs_global has 3.1T free
export MAMBA_ROOT_PREFIX=/nfs_global/micromamba
export PIP_CACHE_DIR=/nfs_global/.cache/pip
export XDG_CACHE_HOME=/nfs_global/.cache
mkdir -p $MAMBA_ROOT_PREFIX $PIP_CACHE_DIR $XDG_CACHE_HOME

# create conda
yes '' | "${SHELL}" <(curl -L micro.mamba.pm/install.sh)
export PS1=tmp
mkdir -p /root/.cargo/
touch /root/.cargo/env
# source ~/.bashrc with error handling to prevent script exit
# The issue is that .bashrc has conda init code with incorrect quotes
# which causes command failure, but we want to continue anyway
set +e
source ~/.bashrc 2>/dev/null || true
set -e

# Ensure MAMBA_ROOT_PREFIX is set for micromamba commands
export MAMBA_ROOT_PREFIX=/nfs_global/micromamba

# Check if slime environment already exists
if /root/.local/bin/micromamba env list | grep -q "slime"; then
    echo "slime environment already exists, skipping creation"
else
    echo "Creating slime environment..."
    micromamba create -n slime python=3.12 pip -c conda-forge -y
fi

micromamba activate slime
export CUDA_HOME="$CONDA_PREFIX"

export BASE_DIR=${BASE_DIR:-"/root"}
cd $BASE_DIR

# install cuda 12.9 as it's the default cuda version for torch
# Check if CUDA packages are already installed
if python -c "import sys; sys.path.insert(0, '/nfs_global/micromamba/envs/slime/lib/python3.12/site-packages'); import cuda" 2>/dev/null; then
    echo "CUDA packages appear to be installed, skipping..."
else
    echo "Installing CUDA packages..."
    # Clean any corrupted package cache first
    micromamba clean -a -y || true
    # Retry installation with multiple attempts for network issues
    for i in {1..3}; do
        echo "Attempt $i/3: Installing CUDA packages..."
        if micromamba install -n slime cuda cuda-nvtx cuda-nvtx-dev nccl -c nvidia/label/cuda-12.9.1 -y; then
            break
        fi
        if [ $i -lt 3 ]; then
            echo "Installation failed, cleaning cache and retrying..."
            micromamba clean -a -y || true
            sleep 5
        else
            echo "All installation attempts failed"
            exit 1
        fi
    done
fi

# Check if cudnn is installed
if python -c "import sys; sys.path.insert(0, '/nfs_global/micromamba/envs/slime/lib/python3.12/site-packages'); import cudnn" 2>/dev/null; then
    echo "cudnn appears to be installed, skipping..."
else
    micromamba install -n slime -c conda-forge cudnn -y
fi

# prevent installing cuda 13.0 for sglang
# Use pip cache directory on /nfs_global to avoid disk space issues
# Check if packages are already installed before installing
if ! python -c "import cuda_python" 2>/dev/null; then
    pip install --cache-dir=$PIP_CACHE_DIR cuda-python==13.1.0
else
    echo "cuda-python already installed, skipping..."
fi

if ! python -c "import torch; assert torch.__version__.startswith('2.9.1')" 2>/dev/null; then
    pip install --cache-dir=$PIP_CACHE_DIR torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 --index-url https://download.pytorch.org/whl/cu129
else
    echo "torch 2.9.1 already installed, skipping..."
fi

# install sglang
if [ ! -d "$BASE_DIR/sglang" ]; then
    echo "Cloning sglang repository..."
    git clone https://github.com/sgl-project/sglang.git
    cd sglang
    git checkout 5e2cda6158e670e64b926a9985d65826c537ac82
else
    echo "sglang directory already exists, skipping clone..."
    cd sglang
    # Ensure we're on the correct commit
    git fetch origin
    git checkout 5e2cda6158e670e64b926a9985d65826c537ac82 || true
fi

# Install the python packages (pip will skip if already installed in editable mode)
if ! python -c "import sglang" 2>/dev/null; then
    pip install --cache-dir=$PIP_CACHE_DIR -e "python[all]"
else
    echo "sglang already installed, skipping..."
fi


# Install cmake and ninja if not already installed
if ! command -v cmake &> /dev/null; then
    pip install --cache-dir=$PIP_CACHE_DIR cmake
else
    echo "cmake already installed, skipping..."
fi

if ! python -c "import ninja" 2>/dev/null; then
    pip install --cache-dir=$PIP_CACHE_DIR ninja
else
    echo "ninja already installed, skipping..."
fi

# flash attn
# the newest version megatron supports is v2.7.4.post1
# Install from local pre-built wheel file to avoid long compilation time
if ! python -c "import flash_attn" 2>/dev/null; then
    FLASH_ATTN_WHL="/nfs_global/slime/flash_attn-2.7.4.post1+cu12torch2.7cxx11abiFALSE-cp312-cp312-linux_x86_64.whl"
    
    if [ -f "$FLASH_ATTN_WHL" ]; then
        echo "Found flash-attn wheel file, installing directly from: $FLASH_ATTN_WHL"
        pip install --cache-dir=$PIP_CACHE_DIR "$FLASH_ATTN_WHL"
    else
        echo "Error: Wheel file not found at $FLASH_ATTN_WHL"
        echo "Please ensure the wheel file exists, or the installation will fail."
        exit 1
    fi
else
    echo "flash-attn already installed, skipping..."
fi

pip install --cache-dir=$PIP_CACHE_DIR git+https://github.com/ISEEKYAN/mbridge.git@89eb10887887bc74853f89a4de258c0702932a1c --no-deps
pip install --cache-dir=$PIP_CACHE_DIR --no-build-isolation "transformer_engine[pytorch]==2.10.0"
pip install --cache-dir=$PIP_CACHE_DIR flash-linear-attention==0.4.0
NVCC_APPEND_FLAGS="--threads 4" \
  pip -v install --disable-pip-version-check --cache-dir=$PIP_CACHE_DIR \
  --no-build-isolation \
  --config-settings "--build-option=--cpp_ext --cuda_ext --parallel 8" git+https://github.com/NVIDIA/apex.git@10417aceddd7d5d05d7cbf7b0fc2daad1105f8b4

# Clone Megatron-LM (first instance, use core_v0.14.0 like build_conda_ori.sh)
# Use MEGATRON_COMMIT if set, otherwise use core_v0.14.0
MEGATRON_VERSION=${MEGATRON_COMMIT:-"core_v0.14.0"}

if [ ! -d "$BASE_DIR/Megatron-LM" ]; then
    echo "Cloning Megatron-LM (version: ${MEGATRON_VERSION})..."
    git clone https://github.com/NVIDIA/Megatron-LM.git --recursive
    cd $BASE_DIR/Megatron-LM
    git fetch origin
    git checkout ${MEGATRON_VERSION} || true
    if ! python -c "import megatron.training" 2>/dev/null; then
        pip install --cache-dir=$PIP_CACHE_DIR -e .
    else
        echo "Megatron-LM (${MEGATRON_VERSION}) already installed, skipping..."
    fi
else
    echo "Megatron-LM directory already exists, checking installation..."
    cd $BASE_DIR/Megatron-LM
    git fetch origin
    git checkout ${MEGATRON_VERSION} || true
    if ! python -c "import megatron.training" 2>/dev/null; then
        pip install --cache-dir=$PIP_CACHE_DIR -e .
    else
        echo "Megatron-LM (${MEGATRON_VERSION}) already installed, skipping..."
    fi
fi

pip install --cache-dir=$PIP_CACHE_DIR git+https://github.com/fzyzcjy/torch_memory_saver.git@dc6876905830430b5054325fa4211ff302169c6b --force-reinstall
pip install --cache-dir=$PIP_CACHE_DIR git+https://github.com/fzyzcjy/Megatron-Bridge.git@dev_rl --no-build-isolation
pip install --cache-dir=$PIP_CACHE_DIR nvidia-modelopt[torch]>=0.37.0 --no-build-isolation

# megatron (second instance, core_v0.14.0)
cd $BASE_DIR
MEGATRON_CORE_DIR="$BASE_DIR/Megatron-LM-core"
if [ ! -d "$MEGATRON_CORE_DIR" ]; then
    echo "Cloning Megatron-LM (core_v0.14.0)..."
    git clone https://github.com/NVIDIA/Megatron-LM.git "$MEGATRON_CORE_DIR" --recursive
    cd "$MEGATRON_CORE_DIR"
    git checkout core_v0.14.0
    if ! python -c "import megatron" 2>/dev/null || [ "$(cd $BASE_DIR/Megatron-LM && git rev-parse HEAD 2>/dev/null)" != "$(cd $MEGATRON_CORE_DIR && git rev-parse HEAD 2>/dev/null)" ]; then
        pip install --cache-dir=$PIP_CACHE_DIR -e .
    else
        echo "Megatron-LM (core_v0.14.0) already installed, skipping..."
    fi
else
    echo "Megatron-LM-core directory already exists, checking installation..."
    cd "$MEGATRON_CORE_DIR"
    git fetch origin
    git checkout core_v0.14.0 || true
    if ! python -c "import megatron" 2>/dev/null; then
        pip install --cache-dir=$PIP_CACHE_DIR -e .
    else
        echo "Megatron-LM (core_v0.14.0) already installed, skipping..."
    fi
fi

# https://github.com/pytorch/pytorch/issues/168167
# Check current torch version and install compatible cudnn version
# torch 2.9.1+cu129 requires nvidia-cudnn-cu12==9.10.2.21
# If a specific version is needed for the issue, we can override, but with a warning
CURRENT_CUDNN=$(python -c "import pkg_resources; print(pkg_resources.get_distribution('nvidia-cudnn-cu12').version)" 2>/dev/null || echo "")
TORCH_CUDNN_REQ="9.10.2.21"
ISSUE_CUDNN_VERSION="9.16.0.29"

if [ "$CURRENT_CUDNN" != "$ISSUE_CUDNN_VERSION" ]; then
    echo "WARNING: Installing nvidia-cudnn-cu12==$ISSUE_CUDNN_VERSION"
    echo "         This may conflict with torch 2.9.1+cu129 which requires $TORCH_CUDNN_REQ"
    echo "         If you encounter issues, you may need to downgrade to $TORCH_CUDNN_REQ"
    pip install --cache-dir=$PIP_CACHE_DIR nvidia-cudnn-cu12==$ISSUE_CUDNN_VERSION || {
        echo "Failed to install $ISSUE_CUDNN_VERSION, trying torch-compatible version..."
        pip install --cache-dir=$PIP_CACHE_DIR nvidia-cudnn-cu12==$TORCH_CUDNN_REQ
    }
else
    echo "nvidia-cudnn-cu12 $ISSUE_CUDNN_VERSION already installed"
fi

# install slime and apply patches

# if slime does not exist locally, clone it
if [ ! -d "$BASE_DIR/slime" ]; then
  cd $BASE_DIR
  git clone  https://github.com/THUDM/slime.git
  cd slime/
  export SLIME_DIR=$BASE_DIR/slime
  pip install --cache-dir=$PIP_CACHE_DIR -e .
else
  export SLIME_DIR=$BASE_DIR/
  pip install --cache-dir=$PIP_CACHE_DIR -e .
fi

# apply patch
cd $BASE_DIR/sglang
if ! git diff --quiet HEAD -- 2>/dev/null || ! git log --oneline -1 | grep -q "patch"; then
    echo "Applying sglang patch..."
    git apply $SLIME_DIR/docker/patch/v0.5.6/sglang.patch || echo "Patch may already be applied or failed"
else
    echo "sglang patch appears to be already applied, skipping..."
fi

# Apply patch to the appropriate Megatron-LM directory
# Always apply to the first Megatron-LM instance (the one with training module)
cd $BASE_DIR/Megatron-LM
if ! git diff --quiet HEAD -- 2>/dev/null || ! git log --oneline -1 | grep -q "patch"; then
    echo "Applying megatron patch to $BASE_DIR/Megatron-LM..."
    git apply $SLIME_DIR/docker/patch/v0.5.6/megatron.patch || echo "Patch may already be applied or failed"
else
    echo "megatron patch appears to be already applied, skipping..."
fi

# Also apply patch to Megatron-LM-core if it exists
if [ -d "$MEGATRON_CORE_DIR" ]; then
    cd "$MEGATRON_CORE_DIR"
    if ! git diff --quiet HEAD -- 2>/dev/null || ! git log --oneline -1 | grep -q "patch"; then
        echo "Applying megatron patch to $MEGATRON_CORE_DIR..."
        git apply $SLIME_DIR/docker/patch/v0.5.6/megatron.patch || echo "Patch may already be applied or failed"
    else
        echo "megatron patch appears to be already applied to core, skipping..."
    fi
fi