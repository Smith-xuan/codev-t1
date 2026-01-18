# Slime 框架 Resume 训练问题分析

## 问题描述

用户保存了模型 checkpoint 到 `/nfs_global/LLaMA-Factory/saves/qwen3-8b/full/tool_8.1k_ds32_10epochs/megatron_slime_save`，其中：
- 存在 `iter_0000029` 目录
- `latest_checkpointed_iteration.txt` 文件内容为 `29`

但在训练脚本中设置 `--load` 参数后，训练日志显示仍从 step 0 开始训练，而不是从 step 30 开始。

## 问题根源

### 1. Resume 训练的流程

Slime 框架中 resume 训练的流程如下：

1. **Checkpoint 加载** (`slime/backends/megatron_utils/model.py:initialize_model_and_optimizer`)
   - 调用 `load_checkpoint()` 从 Megatron checkpoint 加载模型
   - 返回 `iteration`（从 `latest_checkpointed_iteration.txt` 读取）

2. **计算 start_rollout_id** (`slime/backends/megatron_utils/actor.py:async_init`)
   ```python
   loaded_rollout_id = iteration  # 从 checkpoint 加载的 iteration
   start_rollout_id = loaded_rollout_id + 1  # 下一个 rollout ID
   ```

3. **设置 start_rollout_id** (`slime/ray/placement_group.py:create_training_models`)
   ```python
   start_rollout_ids = ray.get(actor_model.async_init(...))
   if args.start_rollout_id is None:
       args.start_rollout_id = start_rollout_ids[0]  # 使用从 checkpoint 加载的值
   ```

### 2. 问题所在

在 `slime/utils/arguments.py:slime_validate_args` 函数中（第 1445-1462 行），存在以下逻辑：

```python
# TODO: During loading, we need to set the start_rollout_id here.
if args.megatron_to_hf_mode == "bridge":
    ...
    args.start_rollout_id = 0  # ❌ 强制设置为 0
else:
    ...
    args.start_rollout_id = 0  # ❌ 强制设置为 0
```

**问题**：无论是否有 checkpoint，`start_rollout_id` 都被强制设置为 0，覆盖了从 checkpoint 加载的值。

**影响**：即使 checkpoint 中保存了正确的 iteration（29），`start_rollout_id` 也会被设置为 0，导致训练从 step 0 重新开始。

## 解决方案

需要修改两个文件：

### 1. 修改 `slime/utils/arguments.py`

只在用户没有显式指定 `--start-rollout-id` 时才设置默认值：

```python
# 修改前
args.start_rollout_id = 0  # 强制设置为 0

# 修改后
if args.start_rollout_id is None:
    args.start_rollout_id = 0  # 只在未指定时设置为 0
```

### 2. 修改 `slime/ray/placement_group.py`

增强逻辑以处理 `slime_validate_args` 将 `None` 设置为 0 的情况：

```python
# 修改前
if args.start_rollout_id is None:
    args.start_rollout_id = start_rollout_ids[0]

# 修改后
if args.start_rollout_id is None:
    args.start_rollout_id = start_rollout_ids[0]
elif args.start_rollout_id == 0 and start_rollout_ids[0] > 0:
    # If start_rollout_id is 0 (default from slime_validate_args) but checkpoint was loaded,
    # use the checkpoint value to enable resume training
    args.start_rollout_id = start_rollout_ids[0]
```

这样，即使 `slime_validate_args` 将 `start_rollout_id` 设置为 0，如果 checkpoint 被成功加载（`start_rollout_ids[0] > 0`），也会使用 checkpoint 的值。

## 修复后的行为

1. **用户未指定 `--start-rollout-id`**：
   - `args.start_rollout_id = None`（在 arguments.py 中）
   - 从 checkpoint 加载 iteration = 29
   - `start_rollout_id = 29 + 1 = 30`（在 actor.py 中计算）
   - `args.start_rollout_id = 30`（在 placement_group.py 中设置）
   - ✅ 训练从 step 30 开始

2. **用户显式指定 `--start-rollout-id 50`**：
   - `args.start_rollout_id = 50`（用户指定）
   - ✅ 训练从 step 50 开始（使用用户指定的值）

3. **没有 checkpoint 或 checkpoint 无效**：
   - `args.start_rollout_id = None`（在 arguments.py 中）
   - 无法从 checkpoint 加载，`start_rollout_id = 0 + 1 = 1`（或出错）
   - 但 arguments.py 中会设置为 0
   - ✅ 训练从 step 0 开始

## 验证方法

1. 检查 checkpoint 目录：
   ```bash
   ls /nfs_global/LLaMA-Factory/saves/qwen3-8b/full/tool_8.1k_ds32_10epochs/megatron_slime_save/
   cat /nfs_global/LLaMA-Factory/saves/qwen3-8b/full/tool_8.1k_ds32_10epochs/megatron_slime_save/latest_checkpointed_iteration.txt
   ```

2. 运行训练脚本（不指定 `--start-rollout-id`）：
   ```bash
   # 应该从 step 30 开始训练（iteration 29 + 1）
   python train.py --load /path/to/checkpoint ...
   ```

3. 检查训练日志：
   - 应该看到类似 `[Rollout 30]` 的日志，而不是 `[Rollout 0]`

## 相关代码位置

- `slime/utils/arguments.py:1445-1462` - 参数验证和 start_rollout_id 设置
- `slime/backends/megatron_utils/actor.py:100` - 计算 start_rollout_id
- `slime/ray/placement_group.py:148-149` - 使用从 checkpoint 加载的值
- `slime/backends/megatron_utils/model.py:691-726` - 加载 checkpoint 并返回 iteration

## 注意事项

1. **Rollout ID 和 Iteration 的关系**：
   - Slime 中，`rollout_id` 和 Megatron 的 `iteration` 是一一对应的
   - 保存 checkpoint 时：`save(rollout_id, ...)` → 保存为 `iter_XXXXXXX`
   - 加载 checkpoint 时：返回 `iteration` → `start_rollout_id = iteration + 1`

2. **Checkpoint 格式**：
   - Megatron checkpoint 目录必须包含 `latest_checkpointed_iteration.txt` 文件
   - 该文件内容应该是最后一次保存的 iteration 号（如 `29`）

3. **显式指定 start_rollout_id**：
   - 如果用户显式指定了 `--start-rollout-id`，将使用用户指定的值
   - 这允许用户手动控制训练起始步数


