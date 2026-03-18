项目主要在/workspace/S/shiwenxuan/slime/examples/iverilog-r1下

## 目录

- [系统架构](#系统架构)
- [一次性准备工作](#一次性准备工作)
- [多节点启动方法](#多节点启动方法)
- [环境变量配置说明](#环境变量配置说明)
- [关键文件说明](#关键文件说明)
- [训练流程概述](#训练流程概述)

---

## 系统架构

```
2 节点 × 8 GPU（共 16 GPU）
┌─────────────────────────────────────┐
│  Node 0（Master）                   │
│  - Ray Head                         │
│  - SandboxFusion server             │
│  - Megatron 训练（8 GPU, tp=8）     │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│  Node 1（Worker）                   │
│  - Ray Worker                       │
│  - SGLang 推理引擎（8 GPU, tp=8）   │
└─────────────────────────────────────┘
```

训练入口为 `train_async.py`（全异步模式），训练与推理运行在不同节点上，每 2 个训练步同步一次权重。

---

## 一次性准备工作

### 1. 安装依赖

先参考slime的build_conda.sh安装相关配置，安装好slime相关的环境



然后安装eda_tools
```bash
cd examples/iverilog-r1/eda_tools
pip install -e .
```

确保以下工具可用（或通过 `IVERILOG_PATH`/`VVP_PATH` 指定路径）：

```bash
which iverilog vvp yosys
```

### 2. 安装 cocotb（用于 CVDP testbench 评估）

CVDP testbench 评估依赖 pytest + cocotb。需要在一个单独的环境中安装，并通过 `CVDP_PYTEST_PATH` 指向该环境的 pytest：

```bash
# 示例：在当前 slime 环境中安装
pip install pytest cocotb
```

### 3. 准备预生成的测试环境（CVDP_TESTENV_ROOT）

如果使用仓库内的 `codev_test/train_testenv`（已预生成），无需此步骤。

如需重新生成：

```bash
cd examples/iverilog-r1/codev_test
python scripts/custom_test/cvdp_preprocess.py \
    --jsonl benchmark/CVDP/data/raw/cvdp_v1.0.2_cid002_cid003.jsonl \
    --outdir train_testenv
```

### 4. 准备模型检查点

需要两份格式的检查点（HuggingFace 格式 + Megatron 格式），分别通过 `MODEL_PATH` 和 `CKPT_BASE` 指定。

Megatron 格式转换命令：

```bash
bash tools/convert_hf_to_megatron_qwen3_1.7b.sh  # 实际配置 8B 参数
```

---

## 多节点启动方法

启动脚本为 `examples/iverilog-r1/run_qwen3_8b_cvdp_testbench.sh`，在**每个节点**上各运行一次，通过 `NODE_RANK` 区分主节点（0）和工作节点（1+）。

### 手动多节点启动

**步骤一：在所有节点上 export 必要的环境变量**（见下方[环境变量配置说明](#环境变量配置说明)）

**步骤二：在 Master 节点（Node 0）上运行：**

```bash
export NODE_RANK=0
export MASTER_ADDR=<Master节点IP>
export NUM_NODES=2
bash /workspace/S/shiwenxuan/slime/examples/iverilog-r1/run_qwen3_8b_cvdp_testbench.sh
```

**步骤三：在 Worker 节点（Node 1）上运行：**

```bash
export NODE_RANK=1
export MASTER_ADDR=<Master节点IP>
export NUM_NODES=2
bash /workspace/S/shiwenxuan/slime/examples/iverilog-r1/run_qwen3_8b_cvdp_testbench.sh
```

Worker 节点脚本会加入 Ray 集群后进入等待状态，直到 Master 节点的训练任务结束后自动退出。

### 通过 Slurm 提交

如果集群支持 Slurm，可使用 `train_qwen3_8b_multinode.slurm`：

```bash
cd examples/iverilog-r1
sbatch train_qwen3_8b_multinode.slurm
```

---

## 环境变量配置说明

以下变量在 `run_qwen3_8b_cvdp_testbench.sh` 中均有默认值，可通过 `export` 或在脚本顶部修改来覆盖。**建议在启动前通过 `export` 设置，以避免修改脚本本身。**

### 必须配置（无合理默认值）

| 变量 | 说明 | 示例 |
|------|------|------|
| `MODEL_PATH` | HuggingFace 格式模型检查点路径 | `/path/to/qwen3-8b-sft/checkpoint-1270` |
| `CKPT_BASE` | Megatron 格式检查点基础目录（`--ref-load` 和 `--load`/`--save` 的父目录） | `/path/to/checkpoint_torch_dist` |
| `MASTER_ADDR` | Master 节点 IP 地址（非 Slurm 环境必须指定） | `10.21.0.3` |

### 工具路径（auto-detect，通常无需设置）

脚本会通过 `which` 自动查找工具路径，仅在工具不在 `PATH` 上时才需手动指定。

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `IVERILOG_PATH` | iverilog 可执行文件路径 | `$(which iverilog)` |
| `VVP_PATH` | vvp 可执行文件路径 | `$(which vvp)` |
| `YOSYS_PATH` | yosys 可执行文件路径（功能等价性验证用） | `$(which yosys)` |
| `CVDP_EXTRA_BIN_PATH` | 追加到 Ray worker `PATH` 的额外 bin 目录（当工具只在某个 conda 环境的 bin 下时使用） | `""` (不追加) |

**示例**（工具在 conda 环境中，不在系统 PATH）：
```bash
export CVDP_EXTRA_BIN_PATH=/opt/miniconda3/envs/eda/bin
```

### 数据路径（默认使用仓库内数据）

| 变量 | 说明 | 默认值（相对仓库目录） |
|------|------|----------------------|
| `DATA_PATH` | 训练数据目录（含 `train.parquet`，172 道 CVDP 题目） | `examples/iverilog-r1/data/cvdp_testbench_172` |
| `CVDP_TESTENV_ROOT` | 预生成的 CVDP testbench 环境目录 | `examples/iverilog-r1/codev_test/train_testenv` |
| `CODEV_TEST_ROOT` | codev_test 根目录（含 benchmark JSONL、测试脚本等） | `examples/iverilog-r1/codev_test` |
| `IVERILOG_TMP_DIR` | iverilog 仿真临时文件目录（**应指向本地磁盘，避免 NFS**） | `/tmp/iverilog_tmp` |

**注意**：`IVERILOG_TMP_DIR` 必须是本地磁盘路径，NFS 路径会导致 I/O 卡死。

### Python 依赖路径（Ray worker 的 PYTHONPATH）

Ray worker 进程需要能 import Megatron-LM、SGLang 等库，通过以下变量配置（这个要看你的相关库在哪）：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `MEGATRON_LM_PATH` | Megatron-LM 源码目录 | `/workspace/S/shiwenxuan/Megatron-LM` |
| `SGLANG_GATEWAY_PATH` | SGLang model-gateway Python bindings 目录 | `/workspace/S/shiwenxuan/sglang/sgl-model-gateway/bindings/python` |
| `SGLANG_PYTHON_PATH` | SGLang Python 目录 | `/workspace/S/shiwenxuan/sglang/python` |
| `VERL_PATH` | verl 源码目录（用于导入 SandboxFusion 工具函数， 现在默认是不用sandboxfusion的，因为我发现会有很多不知名的执行错误现象，默认是做了各种限制的本地命令行执行，因此这里可以随便填一个路径） | `/workspace/S/shiwenxuan/verl` |

### 评估相关

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `CVDP_PYTEST_PATH` | 含 cocotb 的 pytest 可执行文件路径（Ray worker 运行 testbench 时使用） | `$(which pytest)` |

**注意**：如果 slime 训练环境中没有安装 cocotb，需要指向一个安装了 cocotb 的独立环境的 pytest：
```bash
export CVDP_PYTEST_PATH=/opt/miniconda3/envs/cocotb-env/bin/pytest
```

### SandboxFusion

SandboxFusion 用于在 `local_iverilog` 方式以外提供代码沙箱执行服务（当前默认使用本地 iverilog，SandboxFusion 为备选）。

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `SANDBOX_DIR` | SandboxFusion 服务目录 | `/workspace/S/shiwenxuan/verl/SandboxFusion` |
| `SANDBOX_PORT` | SandboxFusion 服务端口 | `8181` |

### 网络与节点配置

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `NUM_NODES` | 总节点数 | `2` |
| `NODE_RANK` | 当前节点编号（Master=0，Worker=1,2,...） | `0` |
| `MASTER_PORT` | Ray GCS 端口（同时用于计算其他 Ray 端口） | `59553` |
| `NETWORK_INTERFACE` | 节点间通信使用的网卡名（**多节点必须正确配置，否则 NCCL 通信失败**） | 自动检测 InfiniBand/eth0 |

**网卡配置说明**：如果自动检测不正确，手动指定：
```bash
export NETWORK_INTERFACE=eth0   # 或 ib0、bond0 等
```

### W&B 日志

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `WANDB_API_KEY` | W&B API Key（设置后自动启用 W&B 日志） | 未设置（不传 key） |

### 其他运行时路径

以下路径在脚本中直接硬编码，如需修改请编辑脚本：

| 变量/路径 | 位置 | 说明 |
|----------|------|------|
| `EXEC_ROOT_DIR` | 脚本约第 86 行 | Python/triton 临时文件根目录，应指向节点本地可写路径 |
| `RAY_SPILL_DIR` | 脚本约第 113 行 | Ray object spill 目录，应指向 NFS 共享路径（跨节点） |
| micromamba 路径 | 脚本约第 42-52 行 | conda/micromamba 初始化路径，按实际环境修改 |

---

## 关键文件说明

| 文件 | 职责 |
|------|------|
| `run_qwen3_8b_cvdp_testbench.sh` | 主启动脚本，管理环境初始化、Ray 集群、训练提交 |
| `generate_with_iverilog.py` | 多轮工具调用生成函数（`generate`）+ 自动生成testbench的奖励函数（`reward_func`，目前过拟合实验阶段用不到） |
| `cvdp_testbench_reward.py` | 基于官方 CVDP testbench 的奖励函数（当前过拟合实验用cvdp benchmark当训练集时使用其作为reward_func） |
| `custom_eval_cvdp.py` | CVDP benchmark 评估函数（每隔 N 步调用一次，动态筛选训练课程） |
| `verilog_utils.py` | Verilog 代码提取、清洗、格式检查工具函数 |
| `codev_test/` | CVDP benchmark 数据、测试脚本、预生成 testbench 环境 |
| `data/cvdp_testbench_172/` | 172 道 CVDP 训练题目（parquet 格式） |
| `data/eval_parquet/` | 评估用 parquet 数据 |
| `eda_tools/` | EDA 工具函数库（功能等价性验证，yosys/iverilog， 过拟合阶段用不到，但后续正式训练要用到） |

---

## 训练流程概述

### 奖励信号

过拟合实验阶段训练奖励来自官方 CVDP testbench：模型生成的 Verilog 代码通过 pytest + cocotb + iverilog 运行 testbench，全部测试用例通过则奖励 1.0，否则 0.0。

训练中的 iverilog 工具调用奖励（`generate_with_iverilog.reward_func`）用于后续的训练中没有testbench的大规模数据进行等价性验证给奖励

### 动态课程（Dynamic Curriculum）

每次 eval 后，根据 3 次采样结果自动筛选训练数据：

- 3 次采样中通过次数为 **1 或 2** 的题目被认为是当前模型的"中等难度"题目，纳入下一轮训练
- 全通过（3/3）的题目太简单，全失败（0/3）的题目太难，都不纳入训练
- 首次训练（第一次 eval 之后）即启用动态筛选

### GRPO 训练配置

- 每个 prompt 生成 8 个样本，用 GRPO 计算组内相对优势
- 奖励方差为零的组（全通或全错）被过滤掉，不参与训练
- 每 2 个训练步将更新后的权重同步回 SGLang 推理引擎

### 评估

- 每 20 个 rollout 步运行一次 CVDP benchmark 评估（172 题，每题 3 次采样）
- 指标：`pass@1`（平均通过率）、`pass@3`（至少 1 次通过的题目比例）
- 评估结果同时用于更新动态课程筛选列表

---

## 常见问题

**Q: iverilog/vvp 命令找不到**

设置 `CVDP_EXTRA_BIN_PATH` 指向包含这些工具的目录，或直接设置 `IVERILOG_PATH` 和 `VVP_PATH`。

**Q: pytest 运行 testbench 报 `ModuleNotFoundError: cocotb`**

`CVDP_PYTEST_PATH` 指向的 pytest 所在的 Python 环境缺少 cocotb。请安装 cocotb 或指向正确环境的 pytest。

**Q: 多节点 NCCL 连接失败**

手动设置 `NETWORK_INTERFACE` 为节点间互通的网卡名（如 `eth0`、`ib0`）。

**Q: /tmp 空间不足导致 DeepGEMM 编译 OOM**

脚本已设置 `SGLANG_DISABLE_DEEPGEMM=1`，这是预期行为，会损失约 10% 推理性能但可避免 OOM。

