# setup.py
from setuptools import setup, find_packages

install_requires=[
    "siliconcompiler",
    "networkx",
    "openai",
    "psutil",
]

setup(
    name="eda_tools",  # 包名（安装后用这个名字导入）
    version="0.1.0",   # 版本号（后续更新可递增，如0.1.1）
    packages=find_packages(),  # 自动发现所有子包（这里会找到eda_tools/）
    author="Your Name",
    description="A set of EDA tools for Verilog analysis (including PPA)",
    long_description=open("README.md").read() if __name__ == "__main__" else "",
    long_description_content_type="text/markdown",
    # 声明依赖库（你的代码需要哪些库才能运行）
    install_requires=install_requires,
)