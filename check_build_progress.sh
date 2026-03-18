#!/bin/bash
# 查看构建进度的辅助脚本

USER_STORAGE_DIR="/nfs_global/S/shiwenxuan"
PROGRESS_FILE="$USER_STORAGE_DIR/.build_progress"
LOG_FILE="$USER_STORAGE_DIR/.build_log"

echo "=========================================="
echo "构建进度查看器"
echo "=========================================="
echo ""

if [ ! -f "$PROGRESS_FILE" ]; then
    echo "⚠️  进度文件不存在，可能还没有开始构建或构建已重置"
    echo ""
    exit 0
fi

# 所有步骤列表
declare -a ALL_STEPS=(
    "01_create_slime_env:创建 slime 环境"
    "02_install_cuda:安装 CUDA 包"
    "03_install_cudnn:安装 cuDNN"
    "04_install_cuda_python:安装 cuda-python"
    "05_install_torch:安装 PyTorch"
    "06_install_sglang:安装 sglang"
    "07_install_cmake_ninja:安装 cmake 和 ninja"
    "08_install_flash_attn:安装 Flash Attention"
    "09_install_other_pip_packages:安装其他 pip 包"
    "10_install_apex:安装 Apex"
    "11_install_megatron_lm:安装 Megatron-LM"
    "12_install_more_pip_packages:安装更多 pip 包"
    "13_install_megatron_lm_core:安装 Megatron-LM-core"
    "14_fix_cudnn_version:修复 cuDNN 版本"
    "15_install_slime:安装 Slime"
    "16_apply_patches:应用补丁"
)

# 统计已完成和未完成的步骤
completed_count=0
total_count=${#ALL_STEPS[@]}

echo "步骤完成情况："
echo "----------------------------------------"
for step_info in "${ALL_STEPS[@]}"; do
    step_name="${step_info%%:*}"
    step_desc="${step_info#*:}"
    
    if grep -q "^${step_name}$" "$PROGRESS_FILE" 2>/dev/null; then
        echo "✓ $step_name - $step_desc"
        ((completed_count++))
    else
        echo "○ $step_name - $step_desc"
    fi
done

echo "----------------------------------------"
echo ""
echo "进度: $completed_count / $total_count 步骤已完成"
echo ""

# 显示最近完成的步骤
if [ -f "$LOG_FILE" ]; then
    echo "最近的活动："
    echo "----------------------------------------"
    tail -5 "$LOG_FILE" | sed 's/^/  /'
    echo ""
fi

# 显示下一步要执行的步骤
if [ $completed_count -lt $total_count ]; then
    for step_info in "${ALL_STEPS[@]}"; do
        step_name="${step_info%%:*}"
        step_desc="${step_info#*:}"
        
        if ! grep -q "^${step_name}$" "$PROGRESS_FILE" 2>/dev/null; then
            echo "下一步将执行: $step_name - $step_desc"
            break
        fi
    done
else
    echo "🎉 所有步骤已完成！"
fi

echo ""
echo "=========================================="
echo "进度文件: $PROGRESS_FILE"
echo "日志文件: $LOG_FILE"
echo "=========================================="
