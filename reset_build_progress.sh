#!/bin/bash
# 重置构建进度的辅助脚本

USER_STORAGE_DIR="/nfs_global/S/shiwenxuan"
PROGRESS_FILE="$USER_STORAGE_DIR/.build_progress"
LOG_FILE="$USER_STORAGE_DIR/.build_log"

echo "=========================================="
echo "构建进度重置工具"
echo "=========================================="
echo ""

if [ ! -f "$PROGRESS_FILE" ] && [ ! -f "$LOG_FILE" ]; then
    echo "⚠️  没有找到进度文件，无需重置"
    exit 0
fi

echo "警告：这将删除所有构建进度记录！"
echo ""
echo "进度文件: $PROGRESS_FILE"
echo "日志文件: $LOG_FILE"
echo ""
read -p "确定要重置吗？(yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "已取消重置"
    exit 0
fi

# 备份现有文件（如果存在）
if [ -f "$PROGRESS_FILE" ]; then
    backup_file="${PROGRESS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$PROGRESS_FILE" "$backup_file"
    echo "已备份进度文件到: $backup_file"
    rm "$PROGRESS_FILE"
fi

if [ -f "$LOG_FILE" ]; then
    backup_file="${LOG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$LOG_FILE" "$backup_file"
    echo "已备份日志文件到: $backup_file"
    rm "$LOG_FILE"
fi

echo ""
echo "✓ 进度已重置！下次运行构建脚本将从头开始。"
