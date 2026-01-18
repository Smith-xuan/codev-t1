# WandB 指标缺失问题分析

## 问题描述

在执行 `run_qwen3_1.7b_multinode_megatron.sh` 进行 LLM 的 RL 训练时：
- 日志中显示有 eval 指标（如 `eval/codev_test`、`eval/codev_test/truncated_ratio` 等）
- 日志中显示有 rollout 指标（如 `rollout/dynamic_filter/drop_zero_std_0.0` 等）
- 但是通过 `wandb sync` 同步后，wandb 网站上缺少这些指标

## 根本原因分析

### 1. RolloutManager 的 WandB 初始化问题

**问题位置**：`slime/ray/rollout.py:48`

```python
init_tracking(args, primary=False, router_addr=f"http://{args.sglang_router_ip}:{args.sglang_router_port}")
```

**执行流程**：
1. `RolloutManager` 是一个 Ray remote actor，在独立进程中运行
2. 初始化时调用 `init_tracking(args, primary=False)`，这会调用 `init_wandb_secondary`
3. `init_wandb_secondary` 需要 `wandb_run_id` 才能正确关联到主 run

**关键代码**：`slime/utils/wandb_utils.py:101-104`

```python
def init_wandb_secondary(args, router_addr=None):
    wandb_run_id = getattr(args, "wandb_run_id", None)
    if wandb_run_id is None:
        return  # ⚠️ 直接返回，不初始化 wandb！
```

**问题**：如果 `wandb_run_id` 为 None，`init_wandb_secondary` 会直接返回，**不初始化 wandb**。这导致：
- `RolloutManager` 中的 `wandb.log()` 调用无效
- eval 和 rollout 指标不会被记录到 wandb

### 2. 为什么日志中有指标但 wandb 没有

**日志输出位置**：
- `slime/ray/rollout.py:602` - eval 指标通过 `logger.info` 打印
- `slime/ray/rollout.py:627` - rollout 指标通过 `logger.info` 打印

**WandB 记录位置**：
- `slime/ray/rollout.py:606` - `tracking_utils.log(args, log_dict, step_key="eval/step")`
- `slime/ray/rollout.py:630` - `tracking_utils.log(args, log_dict, step_key="rollout/step")`

**问题**：
- 日志中的指标是通过 `logger.info` 打印的，所以会在日志文件中显示
- 但是 `tracking_utils.log` 调用 `wandb.log(metrics)`，如果 wandb 未初始化，这个调用会失败或无效
- 因此日志中有指标，但 wandb 中没有

### 3. 离线模式下的额外问题

**脚本配置**：`run_qwen3_1.7b_multinode_megatron.sh:593`

```bash
--wandb-mode offline # 离线模式，不上传数据到wandb
```

**问题**：
- 在离线模式下，即使 wandb 正确初始化，数据也只保存在本地
- 需要手动运行 `wandb sync` 来上传数据
- 但是，如果 `RolloutManager` 的 wandb 没有正确初始化，即使同步也不会包含这些指标

### 4. 多节点训练时的指标记录

**主进程**：`train.py:30`
```python
init_tracking(args)  # primary=True，初始化主 wandb run
```

**RolloutManager**：`rollout.py:48`
```python
init_tracking(args, primary=False)  # 需要 wandb_run_id 才能关联到主 run
```

**问题**：
- 主进程正确初始化了 wandb，设置了 `args.wandb_run_id`
- 但是 `RolloutManager` 是 Ray remote actor，`args` 对象会被序列化传递
- 如果序列化/反序列化过程中 `wandb_run_id` 丢失，或者传递时机不对，就会导致问题

## 解决方案

### 方案 1：确保 wandb_run_id 正确传递（推荐）

**修改位置**：`slime/utils/wandb_utils.py:101-104`

**当前代码**：
```python
def init_wandb_secondary(args, router_addr=None):
    wandb_run_id = getattr(args, "wandb_run_id", None)
    if wandb_run_id is None:
        return  # ⚠️ 直接返回，不初始化 wandb
```

**修改建议**：
1. 添加日志输出，确认 `wandb_run_id` 是否正确传递
2. 如果 `wandb_run_id` 为 None，尝试从环境变量或其他方式获取
3. 如果仍然无法获取，至少记录警告信息

### 方案 2：在 RolloutManager 初始化前确保 wandb_run_id 已设置

**修改位置**：`slime/ray/placement_group.py:185-189`

**当前代码**：
```python
def create_rollout_manager(args, pg):
    rollout_manager = RolloutManager.options(
        num_cpus=1,
        num_gpus=0,
    ).remote(args, pg)
```

**修改建议**：
在创建 `RolloutManager` 之前，确保 `args.wandb_run_id` 已设置：
```python
def create_rollout_manager(args, pg):
    # 确保 wandb_run_id 已设置
    if args.use_wandb and not hasattr(args, 'wandb_run_id'):
        logger.warning("wandb_run_id not set before creating RolloutManager")
    elif args.use_wandb and args.wandb_run_id is None:
        logger.warning("wandb_run_id is None, RolloutManager wandb may not initialize correctly")
    
    rollout_manager = RolloutManager.options(
        num_cpus=1,
        num_gpus=0,
    ).remote(args, pg)
```

### 方案 3：添加 wandb 初始化检查

**修改位置**：`slime/utils/tracking_utils.py:15-17`

**当前代码**：
```python
def log(args, metrics, step_key: str):
    if args.use_wandb:
        wandb.log(metrics)
```

**修改建议**：
添加 wandb 初始化检查：
```python
def log(args, metrics, step_key: str):
    if args.use_wandb:
        try:
            # 检查 wandb 是否已初始化
            if wandb.run is None:
                logger.warning(f"wandb not initialized, skipping log for metrics: {list(metrics.keys())}")
                return
            wandb.log(metrics)
        except Exception as e:
            logger.error(f"Failed to log metrics to wandb: {e}")
```

### 方案 4：使用共享的 wandb 目录（离线模式）

**修改位置**：`run_qwen3_1.7b_multinode_megatron.sh`

**当前配置**：
```bash
--wandb-mode offline
```

**修改建议**：
如果使用离线模式，确保所有进程使用相同的 wandb 目录：
```bash
--wandb-mode offline
--wandb-dir /nfs_global/wandb_offline  # 使用共享目录
```

这样可以确保所有进程的 wandb 数据保存在同一个位置，方便后续同步。

## 诊断步骤

1. **检查 wandb_run_id 是否正确传递**：
   - 在 `init_wandb_secondary` 中添加日志输出
   - 确认 `args.wandb_run_id` 的值

2. **检查 RolloutManager 的 wandb 初始化**：
   - 在 `RolloutManager.__init__` 中添加日志，确认 wandb 是否成功初始化
   - 检查 `wandb.run` 是否为 None

3. **检查 wandb.log 调用**：
   - 在 `tracking_utils.log` 中添加异常捕获和日志输出
   - 确认是否有 `wandb.log()` 调用失败

4. **检查离线模式下的数据保存**：
   - 确认所有进程的 wandb 数据保存在哪里
   - 检查 `wandb sync` 是否同步了所有数据

## 临时解决方案

如果问题紧急，可以：

1. **切换到在线模式**（如果网络允许）：
   ```bash
   --wandb-mode online  # 或删除 --wandb-mode offline
   ```

2. **手动检查 wandb 离线数据**：
   ```bash
   # 查找所有 wandb 离线数据目录
   find ~/wandb -name "*.wandb" -type f
   find /nfs_global -name "*.wandb" -type f 2>/dev/null
   
   # 同步所有找到的离线数据
   wandb sync <wandb_dir>
   ```

3. **从日志中提取指标**：
   - 如果 wandb 数据确实丢失，可以从日志文件中提取指标
   - 使用正则表达式匹配日志中的指标行

## 相关文件

- `slime/utils/wandb_utils.py` - WandB 初始化逻辑
- `slime/utils/tracking_utils.py` - 指标记录逻辑
- `slime/ray/rollout.py` - RolloutManager 实现
- `slime/ray/placement_group.py` - RolloutManager 创建逻辑
- `train.py` - 主训练脚本


