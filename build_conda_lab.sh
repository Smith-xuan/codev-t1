#!/bin/bash
# set -ex

# ==========================================
# 1. 基础路径配置
# ==========================================

# 工作目录 (存放代码、micromamba 二进制文件)
USER_WORK_DIR="/workspace/S/shiwenxuan"
# 存储目录 (存放环境数据、缓存、模型、Wheel包)
USER_STORAGE_DIR="/nfs_global/S/shiwenxuan"

# 确保目录存在
mkdir -p "$USER_WORK_DIR"
mkdir -p "$USER_STORAGE_DIR"

# 配置缓存路径到 NFS 存储，避免占用系统盘空间
export PIP_CACHE_DIR="$USER_STORAGE_DIR/.cache/pip"
export XDG_CACHE_HOME="$USER_STORAGE_DIR/.cache"
mkdir -p "$PIP_CACHE_DIR" "$XDG_CACHE_HOME"

# ==========================================
# 进度跟踪系统
# ==========================================
PROGRESS_FILE="$USER_STORAGE_DIR/.build_progress"
LOG_FILE="$USER_STORAGE_DIR/.build_log"

# 记录步骤完成的函数
mark_step_done() {
    local step_name="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [DONE] $step_name" >> "$LOG_FILE"
    echo "$step_name" >> "$PROGRESS_FILE"
    echo "✓ 步骤完成: $step_name"
}

# 检查步骤是否已完成
is_step_done() {
    local step_name="$1"
    [ -f "$PROGRESS_FILE" ] && grep -q "^${step_name}$" "$PROGRESS_FILE"
}

# 显示当前进度
show_progress() {
    echo ""
    echo "=========================================="
    echo "当前执行步骤: $1"
    echo "=========================================="
    if [ -f "$PROGRESS_FILE" ]; then
        local completed_steps=$(wc -l < "$PROGRESS_FILE")
        echo "已完成步骤数: $completed_steps"
        echo "最近完成的步骤:"
        tail -3 "$PROGRESS_FILE" | sed 's/^/  - /'
    fi
    echo ""
}

# 初始化日志文件
echo "==========================================" >> "$LOG_FILE"
echo "构建开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "==========================================" >> "$LOG_FILE"

# 显示当前进度（如果存在）
if [ -f "$PROGRESS_FILE" ]; then
    completed_steps=$(wc -l < "$PROGRESS_FILE")
    echo ""
    echo "=========================================="
    echo "检测到之前的构建进度"
    echo "已完成步骤数: $completed_steps"
    echo "=========================================="
    echo "最近完成的步骤:"
    tail -3 "$PROGRESS_FILE" | sed 's/^/  - /' || true
    echo ""
    echo "将继续从未完成的步骤开始..."
    echo "如需查看完整进度，请运行: ./check_build_progress.sh"
    echo ""
    sleep 2
fi

# ==========================================
# 2. Micromamba 初始化 (修正版)
# ==========================================

# 开启 alias 扩展功能
shopt -s expand_aliases

# [关键修改] 指定你在 ls -l 中确认的正确路径
export MAMBA_EXE="$USER_WORK_DIR/bin/micromamba"
# 环境安装位置放在 NFS 上以节省 workspace 空间
export MAMBA_ROOT_PREFIX="$USER_STORAGE_DIR/micromamba"

# 确保二进制文件存在且可执行
if [ ! -x "$MAMBA_EXE" ]; then
    echo "Error: micromamba binary not found or not executable at $MAMBA_EXE"
    exit 1
fi

# 将 bin 目录加入 PATH
export PATH="$USER_WORK_DIR/bin:$PATH"

# 初始化 Micromamba 钩子
__mamba_setup="$("$MAMBA_EXE" shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias micromamba="$MAMBA_EXE"
fi
unset __mamba_setup

# ==========================================
# 3. 环境构建流程
# ==========================================

export PS1=tmp

# 配置 cargo (如有需要)
mkdir -p $HOME/.cargo/
touch $HOME/.cargo/env

# 尝试加载 .bashrc (忽略错误)
# set +e
source ~/.bashrc 2>/dev/null || true
# set -e

# 再次确保变量正确 (防止被 bashrc 覆盖)
export MAMBA_ROOT_PREFIX="$USER_STORAGE_DIR/micromamba"

# 检查 slime 环境
STEP_NAME="01_create_slime_env"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 创建 slime 环境"
    if micromamba env list | grep -q "slime"; then
        echo "slime environment already exists, skipping creation"
    else
        echo "Creating slime environment..."
        micromamba create -n slime python=3.12 pip -c conda-forge -y
    fi
    mark_step_done "$STEP_NAME"
fi

# 激活环境
micromamba activate slime

export CUDA_HOME="$CONDA_PREFIX"
# 设置代码下载和编译的工作目录
export BASE_DIR="$USER_WORK_DIR"
cd $BASE_DIR

# --- 检查并安装 CUDA ---
STEP_NAME="02_install_cuda"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 CUDA 包"
    # 动态获取 site-packages 路径
    PYTHON_SITE_PACKAGES="$MAMBA_ROOT_PREFIX/envs/slime/lib/python3.12/site-packages"
    
    if python -c "import sys; sys.path.insert(0, '$PYTHON_SITE_PACKAGES'); import cuda" 2>/dev/null; then
        echo "CUDA packages appear to be installed, skipping..."
    else
        echo "Installing CUDA packages..."
        micromamba clean -a -y || true
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
    mark_step_done "$STEP_NAME"
fi

# --- 检查并安装 cuDNN ---
STEP_NAME="03_install_cudnn"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 cuDNN"
    PYTHON_SITE_PACKAGES="$MAMBA_ROOT_PREFIX/envs/slime/lib/python3.12/site-packages"
    if python -c "import sys; sys.path.insert(0, '$PYTHON_SITE_PACKAGES'); import cudnn" 2>/dev/null; then
        echo "cudnn appears to be installed, skipping..."
    else
        micromamba install -n slime -c conda-forge cudnn -y
    fi
    mark_step_done "$STEP_NAME"
fi

# --- PIP 安装 Python 包 ---
# cuda-python
STEP_NAME="04_install_cuda_python"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 cuda-python"
    if ! python -c "import cuda_python" 2>/dev/null; then
        pip install --cache-dir=$PIP_CACHE_DIR cuda-python==13.1.0
    else
        echo "cuda-python already installed, skipping..."
    fi
    mark_step_done "$STEP_NAME"
fi

# torch
STEP_NAME="05_install_torch"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 PyTorch"
    if ! python -c "import torch; assert torch.__version__.startswith('2.9.1')" 2>/dev/null; then
        pip install --cache-dir=$PIP_CACHE_DIR torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 --index-url https://download.pytorch.org/whl/cu129
    else
        echo "torch 2.9.1 already installed, skipping..."
    fi
    mark_step_done "$STEP_NAME"
fi

# --- sglang ---
STEP_NAME="06_install_sglang"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 sglang"
    if [ ! -d "$BASE_DIR/sglang" ]; then
        echo "Cloning sglang repository..."
        git clone https://github.com/sgl-project/sglang.git
        cd sglang
        git checkout 5e2cda6158e670e64b926a9985d65826c537ac82
    else
        echo "sglang directory already exists, checking commit..."
        cd sglang
        git fetch origin
        git checkout 5e2cda6158e670e64b926a9985d65826c537ac82 || true
    fi
    
    # Install sglang
    if ! python -c "import sglang" 2>/dev/null; then
        pip install --cache-dir=$PIP_CACHE_DIR -e "python[all]"
    else
        echo "sglang already installed, skipping..."
    fi
    mark_step_done "$STEP_NAME"
fi

# cmake & ninja
STEP_NAME="07_install_cmake_ninja"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 cmake 和 ninja"
    if ! command -v cmake &> /dev/null; then
        pip install --cache-dir=$PIP_CACHE_DIR cmake
    fi
    if ! python -c "import ninja" 2>/dev/null; then
        pip install --cache-dir=$PIP_CACHE_DIR ninja
    fi
    mark_step_done "$STEP_NAME"
fi

# --- Flash Attention ---
STEP_NAME="08_install_flash_attn"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 Flash Attention"
    if ! python -c "import flash_attn" 2>/dev/null; then
        # 请确保该文件确实存在于 NFS 路径下
        FLASH_ATTN_WHL="$USER_STORAGE_DIR/flash_attn-2.7.4.post1+cu12torch2.7cxx11abiFALSE-cp312-cp312-linux_x86_64.whl"
        
        if [ -f "$FLASH_ATTN_WHL" ]; then
            echo "Found flash-attn wheel file, installing directly from: $FLASH_ATTN_WHL"
            pip install --cache-dir=$PIP_CACHE_DIR "$FLASH_ATTN_WHL"
        else
            echo "Error: Wheel file not found at $FLASH_ATTN_WHL"
            echo "Please upload the wheel file to $USER_STORAGE_DIR or adjust the path."
            exit 1 
        fi
    else
        echo "flash-attn already installed, skipping..."
    fi
    mark_step_done "$STEP_NAME"
fi

# 其他 pip 包
STEP_NAME="09_install_other_pip_packages"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装其他 pip 包 (mbridge, transformer_engine, flash-linear-attention)"
    pip install --cache-dir=$PIP_CACHE_DIR git+https://github.com/ISEEKYAN/mbridge.git@89eb10887887bc74853f89a4de258c0702932a1c --no-deps
    pip install --cache-dir=$PIP_CACHE_DIR --no-build-isolation "transformer_engine[pytorch]==2.10.0"
    pip install --cache-dir=$PIP_CACHE_DIR flash-linear-attention==0.4.0
    mark_step_done "$STEP_NAME"
fi

# Apex
STEP_NAME="10_install_apex"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 Apex (这可能需要较长时间)"
    NVCC_APPEND_FLAGS="--threads 4" \
    pip -v install --disable-pip-version-check --cache-dir=$PIP_CACHE_DIR \
    --no-build-isolation \
    --config-settings "--build-option=--cpp_ext --cuda_ext --parallel 8" \
    git+https://github.com/NVIDIA/apex.git@10417aceddd7d5d05d7cbf7b0fc2daad1105f8b4
    mark_step_done "$STEP_NAME"
fi

# --- Megatron-LM (First Instance) ---
STEP_NAME="11_install_megatron_lm"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 Megatron-LM"
    MEGATRON_VERSION=${MEGATRON_COMMIT:-"core_v0.14.0"}
    if [ ! -d "$BASE_DIR/Megatron-LM" ]; then
        echo "Cloning Megatron-LM (version: ${MEGATRON_VERSION})..."
        git clone https://github.com/NVIDIA/Megatron-LM.git --recursive
        cd $BASE_DIR/Megatron-LM
        git fetch origin
        git checkout ${MEGATRON_VERSION} || true
        if ! python -c "import megatron.training" 2>/dev/null; then
            pip install --cache-dir=$PIP_CACHE_DIR -e .
        fi
    else
        echo "Megatron-LM directory exists..."
        cd $BASE_DIR/Megatron-LM
        git fetch origin
        git checkout ${MEGATRON_VERSION} || true
        if ! python -c "import megatron.training" 2>/dev/null; then
            pip install --cache-dir=$PIP_CACHE_DIR -e .
        fi
    fi
    mark_step_done "$STEP_NAME"
fi

# More Pip packages
STEP_NAME="12_install_more_pip_packages"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装更多 pip 包 (torch_memory_saver, Megatron-Bridge, nvidia-modelopt)"
    pip install --cache-dir=$PIP_CACHE_DIR git+https://github.com/fzyzcjy/torch_memory_saver.git@dc6876905830430b5054325fa4211ff302169c6b --force-reinstall
    pip install --cache-dir=$PIP_CACHE_DIR git+https://github.com/fzyzcjy/Megatron-Bridge.git@dev_rl --no-build-isolation
    pip install --cache-dir=$PIP_CACHE_DIR nvidia-modelopt[torch]>=0.37.0 --no-build-isolation
    mark_step_done "$STEP_NAME"
fi

# --- Megatron-LM (Core Instance) ---
STEP_NAME="13_install_megatron_lm_core"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 Megatron-LM-core"
    cd $BASE_DIR
    MEGATRON_CORE_DIR="$BASE_DIR/Megatron-LM-core"
    if [ ! -d "$MEGATRON_CORE_DIR" ]; then
        echo "Cloning Megatron-LM-core..."
        git clone https://github.com/NVIDIA/Megatron-LM.git "$MEGATRON_CORE_DIR" --recursive
        cd "$MEGATRON_CORE_DIR"
        git checkout core_v0.14.0
        pip install --cache-dir=$PIP_CACHE_DIR -e .
    else
        echo "Megatron-LM-core directory exists..."
        cd "$MEGATRON_CORE_DIR"
        git fetch origin
        git checkout core_v0.14.0 || true
        pip install --cache-dir=$PIP_CACHE_DIR -e .
    fi
    mark_step_done "$STEP_NAME"
fi

# --- cudnn version fix ---
STEP_NAME="14_fix_cudnn_version"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 修复 cuDNN 版本"
    CURRENT_CUDNN=$(python -c "import pkg_resources; print(pkg_resources.get_distribution('nvidia-cudnn-cu12').version)" 2>/dev/null || echo "")
    TORCH_CUDNN_REQ="9.10.2.21"
    ISSUE_CUDNN_VERSION="9.16.0.29"
    
    if [ "$CURRENT_CUDNN" != "$ISSUE_CUDNN_VERSION" ]; then
        echo "WARNING: Adjusting nvidia-cudnn-cu12 version..."
        pip install --cache-dir=$PIP_CACHE_DIR nvidia-cudnn-cu12==$ISSUE_CUDNN_VERSION || {
            echo "Failed to install $ISSUE_CUDNN_VERSION, fallback..."
            pip install --cache-dir=$PIP_CACHE_DIR nvidia-cudnn-cu12==$TORCH_CUDNN_REQ
        }
    fi
    mark_step_done "$STEP_NAME"
fi

# --- Install Slime ---
STEP_NAME="15_install_slime"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 安装 Slime"
    if [ ! -d "$BASE_DIR/slime" ]; then
        cd $BASE_DIR
        git clone https://github.com/THUDM/slime.git
        cd slime/
        export SLIME_DIR=$BASE_DIR/slime
        pip install --cache-dir=$PIP_CACHE_DIR -e .
    else
        export SLIME_DIR=$BASE_DIR/slime
        cd $SLIME_DIR
        pip install --cache-dir=$PIP_CACHE_DIR -e .
    fi
    mark_step_done "$STEP_NAME"
fi

# --- Apply Patches ---
STEP_NAME="16_apply_patches"
if is_step_done "$STEP_NAME"; then
    echo "步骤 $STEP_NAME 已完成，跳过..."
else
    show_progress "$STEP_NAME: 应用补丁"
    # Sglang Patch
    cd $BASE_DIR/sglang
    if ! git diff --quiet HEAD -- 2>/dev/null || ! git log --oneline -1 | grep -q "patch"; then
        echo "Applying sglang patch..."
        git apply $SLIME_DIR/docker/patch/v0.5.6/sglang.patch || echo "Patch failed or already applied"
    fi
    
    # Megatron Patch
    cd $BASE_DIR/Megatron-LM
    if ! git diff --quiet HEAD -- 2>/dev/null || ! git log --oneline -1 | grep -q "patch"; then
        echo "Applying megatron patch..."
        git apply $SLIME_DIR/docker/patch/v0.5.6/megatron.patch || echo "Patch failed or already applied"
    fi
    
    # Megatron Core Patch
    if [ -d "$MEGATRON_CORE_DIR" ]; then
        cd "$MEGATRON_CORE_DIR"
        if ! git diff --quiet HEAD -- 2>/dev/null || ! git log --oneline -1 | grep -q "patch"; then
            echo "Applying megatron patch to core..."
            git apply $SLIME_DIR/docker/patch/v0.5.6/megatron.patch || echo "Patch failed or already applied"
        fi
    fi
    mark_step_done "$STEP_NAME"
fi

echo ""
echo "=========================================="
echo "环境构建完成！"
echo "=========================================="
echo "进度文件: $PROGRESS_FILE"
echo "日志文件: $LOG_FILE"
echo "=========================================="