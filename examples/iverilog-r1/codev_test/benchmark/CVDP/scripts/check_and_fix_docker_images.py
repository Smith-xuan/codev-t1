#!/usr/bin/env python3
"""
Docker 镜像检查和修复脚本

用于检查 CVDP benchmark 所需的所有 Docker 镜像是否存在，
并提供修复建议和自动修复功能。
"""

import subprocess
import sys
import os
from pathlib import Path

# 添加项目根目录到路径
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

from src.config_manager import config

def run_command(cmd, check=True):
    """运行 shell 命令"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            check=check
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.CalledProcessError as e:
        return False, e.stdout, e.stderr

def check_image_exists(image_name):
    """检查 Docker 镜像是否存在"""
    success, stdout, stderr = run_command(
        f"docker image inspect {image_name}",
        check=False
    )
    return success

def pull_image(image_name):
    """拉取 Docker 镜像"""
    print(f"正在拉取镜像: {image_name}")
    success, stdout, stderr = run_command(f"docker pull {image_name}")
    if success:
        print(f"✓ 成功拉取镜像: {image_name}")
    else:
        print(f"✗ 拉取镜像失败: {image_name}")
        print(f"  错误信息: {stderr}")
    return success

def check_and_report_image(name, description, required=True, auto_fix=False):
    """检查镜像并报告状态"""
    exists = check_image_exists(name)
    status = "✓" if exists else "✗"
    print(f"{status} {name}")
    print(f"  描述: {description}")
    
    if not exists:
        print(f"  状态: 缺失")
        if required:
            print(f"  重要性: 必需")
            if auto_fix:
                print(f"  尝试自动修复...")
                if pull_image(name):
                    return True
                else:
                    print(f"  ⚠ 自动修复失败，请手动处理")
                    return False
            else:
                print(f"  建议: 运行 'docker pull {name}' 或检查镜像配置")
        else:
            print(f"  重要性: 可选")
        return False
    else:
        print(f"  状态: 已存在")
        return True

def check_patch_image():
    """检查 patch_image 是否存在，如果不存在则尝试构建"""
    exists = check_image_exists("patch_image")
    if exists:
        print("✓ patch_image")
        print("  状态: 已存在")
        return True
    
    print("✗ patch_image")
    print("  状态: 缺失")
    print("  重要性: 必需（用于代码补丁）")
    print("  注意: patch_image 通常由 benchmark 自动构建，但可以手动构建")
    print("  建议: 如果测试时自动构建失败，请检查 Docker 构建日志")
    return False

def main():
    """主函数"""
    print("=" * 70)
    print("CVDP Benchmark Docker 镜像检查工具")
    print("=" * 70)
    print()
    
    # 获取配置的镜像
    oss_sim_image = config.get('OSS_SIM_IMAGE', 'ghcr.io/hdl/sim/osvb')
    oss_pnr_image = config.get('OSS_PNR_IMAGE', 'ghcr.io/hdl/impl/pnr')
    verif_eda_image = config.get('VERIF_EDA_IMAGE', 'cvdp-cadence-verif:latest')
    
    print("配置的镜像:")
    print(f"  OSS_SIM_IMAGE: {oss_sim_image}")
    print(f"  OSS_PNR_IMAGE: {oss_pnr_image}")
    print(f"  VERIF_EDA_IMAGE: {verif_eda_image}")
    print()
    
    print("=" * 70)
    print("检查必需的基础镜像")
    print("=" * 70)
    
    all_ok = True
    
    # 检查基础镜像
    results = []
    results.append(check_and_report_image(
        oss_sim_image,
        "开源 EDA 工具 - 仿真镜像",
        required=True,
        auto_fix=True
    ))
    
    results.append(check_and_report_image(
        oss_pnr_image,
        "开源 EDA 工具 - 布局布线镜像",
        required=True,
        auto_fix=True
    ))
    
    results.append(check_patch_image())
    
    print()
    print("=" * 70)
    print("检查可选的商业 EDA 镜像")
    print("=" * 70)
    
    # 检查商业 EDA 镜像（如果配置了）
    if verif_eda_image and verif_eda_image != 'cvdp-cadence-verif:latest':
        check_and_report_image(
            verif_eda_image,
            "商业 EDA 工具 - 验证镜像",
            required=False,
            auto_fix=False
        )
    else:
        print("ℹ VERIF_EDA_IMAGE 使用默认值，如果数据集需要商业 EDA 工具，")
        print("  请确保已构建 cvdp-cadence-verif:latest 镜像")
        print("  构建方法: cd examples/cadence_docker && docker build -t cvdp-cadence-verif:latest .")
    
    print()
    print("=" * 70)
    print("检查测试相关的动态镜像")
    print("=" * 70)
    print("ℹ 测试过程中会动态构建镜像（如 cvdp_copilot_* 等）")
    print("  这些镜像在测试时自动构建，如果构建失败会在测试日志中显示")
    print()
    
    # 统计结果
    missing_required = sum(1 for r in results if not r)
    
    print("=" * 70)
    print("检查结果总结")
    print("=" * 70)
    
    if missing_required == 0:
        print("✓ 所有必需的镜像都已存在")
        print()
        print("如果测试结果仍然异常，请检查:")
        print("1. 测试日志中是否有镜像构建失败的错误")
        print("2. Docker 构建过程中是否有网络或权限问题")
        print("3. 测试时动态构建的镜像是否成功构建")
        return 0
    else:
        print(f"✗ 发现 {missing_required} 个必需的镜像缺失")
        print()
        print("修复建议:")
        print("1. 对于 OSS_SIM_IMAGE 和 OSS_PNR_IMAGE:")
        print(f"   运行: docker pull {oss_sim_image}")
        print(f"   运行: docker pull {oss_pnr_image}")
        print()
        print("2. 对于 patch_image:")
        print("   通常由 benchmark 自动构建，如果失败请检查:")
        print("   - Docker 构建日志")
        print("   - Docker 构建权限")
        print("   - 网络连接（如果需要下载依赖）")
        print()
        print("3. 检查测试日志:")
        print("   查看测试输出目录中的日志文件，搜索 'docker build' 或 'image' 相关错误")
        return 1

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)




