#!/usr/bin/env python3
"""
修复 Dockerfile 中的 cocotb 版本指定问题

这个脚本可以：
1. 修复已生成的 Dockerfile 文件
2. 或者作为代码修改的参考
"""

import os
import re
import sys
from pathlib import Path

def fix_dockerfile_cocotb_version(filepath, cocotb_version=">=1.6.0"):
    """
    修复 Dockerfile 中的 cocotb 安装指令，添加版本要求
    
    Args:
        filepath: Dockerfile 路径
        cocotb_version: cocotb 版本要求，默认 ">=1.6.0"
    
    Returns:
        bool: 是否进行了修改
    """
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original_content = content
        
        # 匹配模式1: RUN pip install cocotb-bus (没有版本)
        pattern1 = r'(RUN\s+(?:pip|pip3)\s+install\s+)(cocotb-bus|cocotb_bus)(?!\s*[=<>!])'
        replacement1 = r'\1cocotb' + cocotb_version + r' \2'
        content = re.sub(pattern1, replacement1, content)
        
        # 匹配模式2: RUN pip3 install cocotb_bus (下划线版本)
        # 注意：cocotb-bus 和 cocotb_bus 是不同的包
        # cocotb-bus 是 cocotb 的扩展包，但我们需要确保 cocotb 本身有正确版本
        
        # 如果文件中只有 cocotb-bus 或 cocotb_bus，但没有 cocotb，需要添加
        if 'cocotb-bus' in content or 'cocotb_bus' in content:
            # 检查是否已经有 cocotb 的安装（带或不带版本）
            if not re.search(r'pip.*install.*\bcocotb\b(?!-bus|_bus)', content):
                # 在 cocotb-bus 之前添加 cocotb
                content = re.sub(
                    r'(RUN\s+(?:pip|pip3)\s+install\s+)(cocotb-bus|cocotb_bus)',
                    r'\1cocotb' + cocotb_version + r' \2',
                    content
                )
        
        if content != original_content:
            with open(filepath, 'w') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"错误: 无法处理文件 {filepath}: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("用法:")
        print("  1. 修复单个文件: python fix_cocotb_version.py <Dockerfile路径>")
        print("  2. 修复目录: python fix_cocotb_version.py --dir <目录路径>")
        print("  3. 修复 work 目录: python fix_cocotb_version.py --work")
        print("  4. 修复 results 目录: python fix_cocotb_version.py --results")
        sys.exit(1)
    
    project_root = Path(__file__).parent.parent
    
    if sys.argv[1] == '--work':
        target_dir = project_root / 'work'
    elif sys.argv[1] == '--results':
        target_dir = project_root / 'results'
    elif sys.argv[1] == '--dir' and len(sys.argv) > 2:
        target_dir = Path(sys.argv[2])
    else:
        # 单个文件
        filepath = Path(sys.argv[1])
        if fix_dockerfile_cocotb_version(filepath):
            print(f"✓ 已修复: {filepath}")
        else:
            print(f"  无需修改: {filepath}")
        return
    
    # 批量处理目录
    print(f"正在扫描目录: {target_dir}")
    dockerfiles = list(target_dir.rglob("Dockerfile*"))
    print(f"找到 {len(dockerfiles)} 个 Dockerfile 文件")
    
    fixed_count = 0
    for df in dockerfiles:
        if fix_dockerfile_cocotb_version(df):
            fixed_count += 1
            if fixed_count <= 10:  # 只显示前10个
                print(f"✓ 已修复: {df.relative_to(project_root)}")
    
    print(f"\n总共修复了 {fixed_count} 个文件")

if __name__ == "__main__":
    main()



