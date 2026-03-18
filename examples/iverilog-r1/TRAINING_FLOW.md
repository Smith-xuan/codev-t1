# Iverilog-R1 训练流程文档

本文档描述基于 slime 框架的 Verilog 代码生成 RL 训练完整流程。任务目标：通过支持工具调用（iverilog）的强化学习，训练模型生成功能正确的 Verilog RTL 代码。

---

## 一、总体架构

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Slurm 调度层                                │
│  train_qwen3_8b_multinode.slurm                                     │
│  → 申请 2 节点 × 8 GPU，按序启动 Head/Worker 节点                     │
└──────────────────────┬───────────────────────────────────────────────┘
                       │ srun
┌──────────────────────▼───────────────────────────────────────────────┐
│              run_qwen3_8b_multinode_megatron.sh                      │
│  1. 初始化环境（micromamba/conda → slime 环境）                       │
│  2. 启动 SandboxFusion 服务（Master 节点）                            │
│  3. 启动 Ray 集群（Head + Worker）                                   │
│  4. 通过 ray job submit 提交训练任务                                  │
└──────────────────────┬───────────────────────────────────────────────┘
                       │ ray job submit → python3 train.py ...
┌──────────────────────▼───────────────────────────────────────────────┐
│                     slime/train.py 主训练循环                         │
│                                                                      │
│  for rollout_id in range(num_rollout=1000):                          │
│    ┌─── Rollout 阶段（SGLang 推理 + 工具调用 + 奖励计算）───┐         │
│    │  rollout_manager.generate()                              │         │
│    │    → 自定义 generate: generate_with_iverilog.generate    │         │
│    │    → 自定义 reward:   generate_with_iverilog.reward_func │         │
│    └──────────────────────────────────────────────────────────┘         │
│    ┌─── Train 阶段（Megatron 分布式训练）────────────────────┐         │
│    │  actor_model.async_train()                               │         │
│    │    → GRPO 策略梯度更新                                   │         │
│    └──────────────────────────────────────────────────────────┘         │
│    ┌─── 评估阶段（每 10 轮）────────────────────────────────┐         │
│    │  custom_eval_cvdp → CVDP benchmark (cid002/cid003)       │         │
│    └──────────────────────────────────────────────────────────┘         │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 二、模型与数据

### 2.1 模型

- **基础模型**: Qwen3-8B
- **SFT 检查点**: `/nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/87k_sft_8.1k_ds32_10epochs/checkpoint-1270`
  - 由 LLaMA-Factory 进行 SFT 训练得到，训练数据为 87k 条 Verilog 代码生成相关数据（8.1k 去重后，DeepSeek 蒸馏数据集，10 个 epoch）
- **Megatron 格式检查点**: `checkpoint-1270_torch_dist`
  - 由 `tools/convert_hf_to_megatron_qwen3_1.7b.sh`（实际为 8B 配置）从 HF 格式转换而来
  - 转换需要指定模型架构参数（36 层、hidden_size=4096、ffn_hidden_size=12288、32 头、8 KV 组等）
- **模型架构参数**（Megatron 格式）:
  - `--num-layers 36 --hidden-size 4096 --ffn-hidden-size 12288`
  - `--num-attention-heads 32 --num-query-groups 8`（GQA）
  - `--swiglu --normalization RMSNorm --qk-layernorm`
  - `--use-rotary-position-embeddings --rotary-base 1000000`
  - `--vocab-size 151936 --kv-channels 128`

### 2.2 训练数据

- **路径**: `/nfs_global/S/shiwenxuan/verl/data/codev/v1/cvdp_claude_256/train.parquet`
- **规模**: 256 条样本
- **格式**: Parquet 文件，包含以下列：

| 列名 | 内容 |
|------|------|
| `prompt` | 消息列表 `[{role, content}, ...]`，包含系统提示词和用户提出的 Verilog 设计需求 |
| `reward_model` | 字典 `{"ground_truth": "<标准 Verilog 代码>", "style": "rule"}`，用于奖励计算时的功能等价性验证 |
| `tools` | JSON 字符串，定义 `verilog_simulator` 工具的 function calling schema |
| `question` | 与 `prompt` 相同内容（评估时使用） |
| `ability` | 固定为 `"verilog"` |
| `data_source` | 固定为 `"cvdp_claude_distill"` |
| `extra_info` | 包含 `task_id`、`index` 等元信息 |

- **系统提示词要求模型**:
  - 仔细推理规格、接口和边界情况
  - 使用可用工具（iverilog）验证设计
  - 生成可综合的、功能正确的 RTL 代码
  - 最终答案用 ` ```verilog ... ``` ` 代码块包裹在 `<answer>` 标签中

### 2.3 测试/评估数据

- **Rollout 内评估（每 10 轮）**: 使用 `custom_eval_cvdp.py`
  - 评估数据: `/workspace/S/shiwenxuan/verl/data/test/cvdp-codegeneration-codev-tool-1.parquet`
  - 筛选 cid002/cid003 类别（约 172 题）
  - 评估流程: 生成 → 提取 Verilog → 预处理 → 运行功能验证测试 → 解析报告得 pass rate
- **训练集内评估**: `${DATA_PATH}/test.parquet`（codev_test 数据源，与训练数据同格式）

---

## 三、启动流程详解

### 3.1 Slurm 提交 (`train_qwen3_8b_multinode.slurm`)

```bash
cd /workspace/S/shiwenxuan/slime/examples/iverilog-r1
sbatch train_qwen3_8b_multinode.slurm
```

关键配置：
- 分区: `r8nv-gpu-hw-80g`，2 节点 × 8 GPU（A100 80G）
- 运行时限: 1 天 6 小时
- 节点: `r8a100-d[05,06]`（可选指定）

Slurm 脚本的执行顺序：
1. 获取节点列表，确定 Head 节点 IP
2. 在 Head 节点启动 `run_qwen3_8b_multinode_megatron.sh`
3. 等待 Ray Head 就绪（通过共享文件系统中的 flag 文件 `/workspace/S/shiwenxuan/tmp/job_<id>/ray_head_ready`）
4. 在 Worker 节点启动同一脚本

### 3.2 节点启动脚本 (`run_qwen3_8b_multinode_megatron.sh`)

每个节点执行：

1. **环境初始化**:
   - 激活 micromamba/conda 的 `slime` 环境
   - 设置 `LD_LIBRARY_PATH` 解决 GLIBCXX 版本问题
   - 禁用 HTTP 代理（Ray 对代理敏感）
   - 禁用 DeepGEMM 和 FlashInfer Sampling（`SGLANG_DISABLE_DEEPGEMM=1`，避免 NFS/tmp 空间问题）

2. **临时目录设置**:
   - Python 临时目录: `/workspace/S/shiwenxuan/tmp/job_<id>/<node_hash>/`
   - Ray 临时目录: `/tmp/r_<id>`（本地磁盘，避免 NFS 问题）
   - Ray Spill 目录: `/workspace/S/shiwenxuan/tmp/ray_spill`

3. **网络配置**:
   - 自动检测 InfiniBand/Ethernet 网卡
   - 设置 NCCL/Gloo/SGLang 的通信网卡（`NCCL_SOCKET_IFNAME` 等）

4. **SandboxFusion 启动**（仅 Master 节点）:
   - 启动 uvicorn 服务 `/workspace/S/shiwenxuan/verl/SandboxFusion`
   - 注意：当前实际使用 `local_iverilog` 方式执行工具调用，SandboxFusion 作为备选

5. **环境变量传递**:
   - `IVERILOG_EXECUTION_METHOD=local_iverilog` — 指定使用本地 iverilog 调用
   - `IVERILOG_PATH` / `VVP_PATH` — iverilog/vvp 可执行文件路径
   - `IVERILOG_TMP_DIR` — iverilog 临时文件目录

6. **Ray 集群启动**:
   - Head 节点: `ray start --head ...`（20GB object store）
   - Worker 节点: 等待 60s 后 `ray start --address=...` 加入集群
   - 等待所有节点就绪

7. **提交训练任务**（仅 Master 节点）:
   - 通过 `ray job submit` 提交 `python3 train.py` 及所有参数
   - 通过 `--runtime-env-json` 传递环境变量（PYTHONPATH、NCCL 配置、工具路径等）

---

## 四、训练参数详解

### 4.1 集群与推理配置

| 参数 | 值 | 说明 |
|------|-----|------|
| `--actor-num-nodes` | 2 | 训练使用 2 个节点 |
| `--actor-num-gpus-per-node` | 8 | 每节点 8 张 GPU |
| `--colocate` | - | 推理与训练共用 GPU（交替进行） |
| `--rollout-num-gpus-per-engine` | 8 | 每个 SGLang 推理引擎使用 8 GPU（张量并行） |
| `--sglang-mem-fraction-static` | 0.5 | SGLang KV Cache 占用 50% 显存 |
| `--sglang-cuda-graph-bs` | 1 2 4 8 16...256 | 预编译多种 batch size 的 CUDA Graph |

### 4.2 Rollout 配置

| 参数 | 值 | 说明 |
|------|-----|------|
| `--num-rollout` | 1000 | 总共训练 1000 轮 |
| `--rollout-batch-size` | 16 | 每轮 rollout 处理 16 个 prompt |
| `--n-samples-per-prompt` | 8 | 每个 prompt 生成 8 个不同回复（用于 GRPO） |
| `--over-sampling-batch-size` | 36 | 过采样 batch size |
| `--rollout-max-response-len` | 30000 | 最大回复长度 30000 token |
| `--rollout-max-context-len` | 36000 | 最大上下文长度 36000 token |
| `--rollout-temperature` | 1.0 | 采样温度 |
| `--global-batch-size` | 128 | 全局训练 batch size (16 prompts × 8 samples) |
| `--dynamic-sampling-filter-path` | `...check_reward_nonzero_std` | 过滤掉所有样本奖励方差为零的组 |

### 4.3 GRPO 算法配置

| 参数 | 值 | 说明 |
|------|-----|------|
| `--advantage-estimator` | grpo | 使用 Group Relative Policy Optimization |
| `--kl-loss-coef` | 0.00 | 不使用 KL 散度惩罚 |
| `--entropy-coef` | 0.00 | 不使用熵正则化 |
| `--eps-clip` | 0.2 | PPO clip 下界 |
| `--eps-clip-high` | 0.28 | PPO clip 上界 |
| `--use-tis` | - | 使用 Trust-region Importance Sampling |

### 4.4 训练优化配置

| 参数 | 值 | 说明 |
|------|-----|------|
| `--tensor-model-parallel-size` | 8 | 8 路张量并行 |
| `--context-parallel-size` | 2 | 2 路上下文并行 |
| `--sequence-parallel` | - | 启用序列并行 |
| `--recompute-granularity full` | - | 梯度重计算（节省显存） |
| `--use-dynamic-batch-size` | - | 动态 batch size（按 token 数填充） |
| `--max-tokens-per-gpu` | 36000 | 每 GPU 最大 token 数 |
| `--optimizer adam` | lr=1e-6 | Adam 优化器，常数学习率 |

### 4.5 自定义函数路径

| 参数 | 值 | 说明 |
|------|-----|------|
| `--custom-generate-function-path` | `generate_with_iverilog.generate` | 自定义多轮工具调用生成函数 |
| `--custom-rm-path` | `generate_with_iverilog.reward_func` | 自定义奖励函数（功能等价性验证） |
| `--eval-function-path` | `custom_eval_cvdp.custom_eval_cvdp` | 自定义评估函数（CVDP benchmark） |

---

## 五、Rollout 阶段详解（核心）

### 5.1 数据加载

slime 框架在 `slime/rollout/data_source.py` 中读取 `train.parquet`：
- 按 `--input-key prompt` 读取 prompt（消息列表）
- 按 `--label-key reward_model` 读取标签（ground truth Verilog 代码）
- 按 `--tool-key tools` 读取工具定义
- 通过 `--apply-chat-template` 将消息列表 + 工具定义转换为模型输入格式字符串

### 5.2 多轮生成流程 (`generate_with_iverilog.generate`)

对每个 sample，在 `slime/rollout/sglang_rollout.py` 中通过 `load_function(args.custom_generate_function_path)` 动态加载并调用：

```
对每个 sample（最多 max_turns=6 轮）:
  1. 将 prompt + 已积累的 response 发送给 SGLang 推理引擎
  2. 获取模型生成的文本 cur_response
  3. 解析 cur_response:
     ├── 检测到 <tool_call>{"name":"verilog_simulator","arguments":{"code":"..."}} → 动作: tool_call
     ├── 检测到 <answer>...</answer> → 动作: answer（对话结束）
     └── 未检测到有效动作 → 对话结束
  4. 如果是 tool_call:
     ├── 提取 Verilog 代码（包含 testbench）
     ├── 调用 execute_predictions() 执行 iverilog
     │   └── 执行方式由 IVERILOG_EXECUTION_METHOD 决定:
     │       ├── "local_iverilog" (当前使用): 本地 subprocess 调用 iverilog
     │       ├── "sandbox_fusion": 通过 HTTP API 调用 SandboxFusion
     │       └── "iverilog_server": 通过 HTTP 调用自建服务(已弃用)
     ├── 将工具输出包装为 <tool_response>...</tool_response>
     ├── 追加到 response 中（标记 loss_mask=0，不参与训练）
     └── 继续下一轮生成
  5. 如果是 answer 或达到最大轮数 → 结束
  6. 返回 sample（包含 tokens、response、loss_mask、rollout_log_probs）
```

**本地 iverilog 执行流程** (`_execute_iverilog_local`):
- 使用 UUID 创建隔离临时目录（避免高并发文件冲突）
- 编译: `iverilog -Wall -Winfloop -Wno-timescale -g2012 -s testbench -o test.vvp design.sv`
- 仿真: `vvp -n test.vvp`
- 编译超时 30s，仿真超时 10s
- 输出限制 50KB，防止死循环导致的巨量输出
- 通过 `asyncio.Semaphore(32)` 控制并发数
- 完成后自动清理临时文件

**loss_mask 机制**:
- 模型生成的文本（`<think>...` `<tool_call>...` `<answer>...`）: `loss_mask=1`（参与训练）
- 工具返回的文本（`<tool_response>...</tool_response>`）: `loss_mask=0`（不参与训练）

### 5.3 奖励计算 (`generate_with_iverilog.reward_func`)

在 `slime/rollout/rm_hub/__init__.py` 中通过 `load_function(args.custom_rm_path)` 加载并对每个 sample 调用：

**离散模式（默认）四档奖励**:

| 条件 | 奖励 |
|------|------|
| 答案正确 + 格式完美（标签全配对，有工具调用轮次，最终 `<answer>` 中有完整代码） | 1.5 |
| 答案正确 + 格式可接受（无严重错误） | 1.0 |
| 答案正确 + 严重格式错误（如重复100次以上的模式） | 0.0 |
| 答案错误 或 无法提取有效 Verilog 代码 | 0.0 |

**"答案正确"的判定**:
1. 从生成文本中提取 Verilog 代码（优先从 `<answer>` 块，其次从最后一个 `<tool_call>` 块）
2. 移除 testbench 代码，只保留设计模块
3. 使用 `eda_tools.core.verify_one_sample` 进行功能等价性验证
   - 将提取的代码与 `reward_model.ground_truth` 进行比对
   - 通过 Yosys/iverilog 等 EDA 工具验证逻辑等价性

**格式检查细节** (`verilog_utils.py`):
- `_format_ok()`: 宽松检查，只要能提取出完整的 `module...endmodule` 即算通过
- `_check_format_reward()`: 严格检查完美格式（标签配对、工具调用轮次结构、最终 answer 中有完整代码）→ 给 0.3 分（加上正确性 1.0 后总计 1.5 ，但代码中写死为直接返回 1.5）
- `_check_format_penalties()`: 检测过度重复（同一模式重复 100+ 次）→ 扣 0.5 分

### 5.4 过采样与过滤

- 每个 prompt 生成 8 个样本（`--n-samples-per-prompt 8`），构成一个 group
- `--dynamic-sampling-filter-path check_reward_nonzero_std`: 过滤掉 group 内所有样本奖励完全相同的组
  - 如果 8 个样本全部正确（reward 都是 1.5）或全部错误（reward 都是 0.0），该 group 被丢弃
  - 只保留有区分度的组用于 GRPO 训练

---

## 六、Train 阶段

### 6.1 GRPO 训练

使用 Megatron-LM 后端进行分布式训练：
- **并行策略**: TP=8（张量并行）+ CP=2（上下文并行）+ 序列并行
- **算法**: GRPO (Group Relative Policy Optimization)
  - 将同一 prompt 的 8 个样本作为一组
  - 计算组内相对优势（advantage = reward - group_mean_reward）
  - 使用 PPO-clip 目标函数更新策略，clip 范围 [0.2, 0.28]
- **动态 batch**: 按 token 数而非样本数填充 batch（`--use-dynamic-batch-size`），最大 36000 tokens/GPU
- **梯度重计算**: 全层重计算（`--recompute-granularity full`），节省显存
- **权重同步**: 训练完成后通过 `actor_model.update_weights()` 将更新后的权重同步到 SGLang 推理引擎

### 6.2 Colocate 模式

由于使用 `--colocate`，训练和推理共享同一组 GPU：
- Rollout 阶段: SGLang 引擎占用 GPU 进行推理
- Train 阶段: 卸载 SGLang 权重（`offload_train()`），加载 Megatron 训练模型
- 下一轮 Rollout 前: 将更新后的权重同步回 SGLang（`onload_rollout()` + `update_weights()`）

### 6.3 检查点保存

- 每 10 轮保存一次（`--save-interval 10`）
- 保存路径: `--save` 指定的 Megatron 格式目录
- 可通过 `tools/convert_torch_dist_to_hf.py` 转回 HuggingFace 格式

---

## 七、评估阶段

### 7.1 训练中评估（每 10 轮）

由 `custom_eval_cvdp.py` 实现：

1. 加载 CVDP benchmark parquet 文件（302 题，筛选 cid002/cid003 类别共 172 题）
2. 为每个样本应用 chat template（附带 verilog_simulator 工具定义）
3. 使用与训练相同的多轮生成函数（`generate_with_iverilog.generate`）生成回复
4. 保存原始结果为 JSONL
5. 运行 CVDP 测试流水线：
   - `extract_verilog.py` — 从生成文本中提取 Verilog 代码
   - `cvdp_preprocess.py` — 预处理 benchmark 测试数据
   - `cvdp_run_test.py` — 运行功能验证测试（16 worker 并行）
6. 解析测试报告，计算 cid002 + cid003 的 pass rate 作为评估分数

### 7.2 指标追踪

- 使用 WandB 记录训练指标（offline 模式）
- 项目: `verl_onpolicy_modified_format_reward_slime_test`
- 关键指标: reward 分布、pass rate、tool call 统计（编译错误率、超时率等）

---

## 八、文件职责总结

### 当前活跃使用的文件

| 文件 | 职责 |
|------|------|
| `train_qwen3_8b_multinode.slurm` | Slurm 作业提交脚本，协调多节点启动 |
| `run_qwen3_8b_multinode_megatron.sh` | 节点初始化、Ray 集群启动、训练提交 |
| `generate_with_iverilog.py` | **核心**: 多轮生成函数 `generate()` + 奖励函数 `reward_func()` + 工具执行 |
| `verilog_utils.py` | Verilog 代码提取、清洗、格式检查、功能等价性验证的工具函数 |
| `custom_eval_cvdp.py` | CVDP benchmark 评估，调用外部 codev_test 测试流水线 |
| `inspect_train_data.py` | 检查训练数据 parquet 结构的辅助脚本 |

### 已弃用/不再使用的文件

| 文件 | 说明 |
|------|------|
| `iverilog_server.py` | 早期的 HTTP iverilog 服务端（已被 local_iverilog 替代） |
| `local_iverilog_server.py` | 早期的本地 iverilog 封装（已整合进 `generate_with_iverilog.py`） |
| `custom_eval.py` | 旧版评估脚本（已被 `custom_eval_cvdp.py` 替代） |
| `run_qwen3_1.7b_*.sh` | 1.7B 模型的旧训练脚本 |

### 框架层被调用的关键文件

| slime 框架文件 | 作用 |
|---------------|------|
| `train.py` | 主训练循环（rollout → train → eval → save → weight sync） |
| `slime/rollout/sglang_rollout.py:280` | 加载并调用 `custom_generate_function_path` 指定的生成函数 |
| `slime/rollout/rm_hub/__init__.py:31` | 加载并调用 `custom_rm_path` 指定的奖励函数 |
| `slime/ray/placement_group.py` | GPU 分配和 Ray placement group 管理 |
| `slime/ray/rollout.py` | RolloutManager 管理 SGLang 推理引擎的生成和评估 |
| `slime/ray/train_actor.py` | Megatron 分布式训练 actor |

---

## 九、工具调用演化历程

工具调用经历了三个阶段：

1. **HTTP iverilog 服务** (`iverilog_server.py`)
   - 参考 search-r1 的模式，将 iverilog 封装为 HTTP 服务
   - 问题：HTTP 卡死导致 rollout 程序断开

2. **SandboxFusion** (verl 框架的沙箱)
   - 使用 verl 框架的 SandboxFusion API
   - 问题：高并发下大量空白输出，怀疑临时文件覆盖 bug

3. **本地 iverilog 调用** (当前方案, `_execute_iverilog_local`)
   - 直接在 SGLang server 节点调用本地 iverilog
   - UUID 隔离临时目录，3s 编译超时 + 10s 仿真超时
   - 50KB 输出限制，防止死循环
   - 通过 asyncio.Semaphore 控制并发
   - 约 30-40% 工具调用会超时

---

## 十、已知问题与注意事项

1. **DeepGEMM 必须禁用**: `SGLANG_DISABLE_DEEPGEMM=1`，否则 /tmp 空间不足导致编译算子时 OOM
2. **NCCL 网卡配置**: 多节点必须指定 `NCCL_SOCKET_IFNAME` 为正确的内网网卡，否则 worker 节点会使用外网地址导致连接失败
3. **uvloop 必须禁用**: `train.py` 开头就禁用了 uvloop，防止高并发下 SIGABRT 崩溃
4. **工具超时率较高**: 约 30-40% 的 iverilog 调用超时（3s 编译 + 10s 仿真），是正常现象
5. **显存管理**: FSDP 后端存在 OOM 问题（超长上下文的 logits 张量），使用 Megatron 后端 + 梯度重计算解决
6. **sglang 断联**: 高负载下 `httpx.ReadError`，框架层已添加重试机制
