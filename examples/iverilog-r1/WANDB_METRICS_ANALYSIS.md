# Slime 训练过程中 WandB 记录的指标分析

本文档详细列出了 slime 训练过程中被 WandB 记录的所有指标。

## 指标分类

### 1. 训练指标 (train/*)

这些指标在训练步骤中记录，反映模型训练的状态和损失。

#### 核心训练指标
- **`train/step`**: 全局训练步数
- **`train/loss`**: 总损失值（通常是 PG loss + entropy loss + KL loss 等）
- **`train/pg_loss`**: Policy Gradient 损失（GRPO/PPO 的核心损失）
- **`train/entropy_loss`**: 熵损失（用于鼓励探索）
- **`train/grad_norm`**: 梯度范数（用于监控梯度爆炸/消失）

#### PPO/GRPO 相关指标
- **`train/pg_clipfrac`**: PG 损失被裁剪的比例（PPO 中使用的比例）
- **`train/ppo_kl`**: PPO KL 散度（如果启用 KL 损失）
- **`train/kl_loss`**: KL 损失值（如果启用 `--use-kl-loss`）

#### TIS (Training-Inference Similarity) 相关指标
- **`train/tis`**: TIS 权重（训练和推理策略的相似度）
- **`train/tis_clipfrac`**: TIS 被裁剪的比例
- **`train/tis_abs`**: TIS 的绝对值
- **`train/ois`**: OIS (On-policy Importance Sampling) 权重
- **`train/train_rollout_logprob_abs_diff`**: 训练策略和 rollout 策略的 log prob 绝对差值

#### 学习率指标
- **`train/lr-pg_0`**: 参数组 0 的学习率
- **`train/lr-pg_1`**: 参数组 1 的学习率
- **`train/lr-pg_{N}`**: 其他参数组的学习率（根据优化器配置）

#### 其他训练指标（可选）
- **`train/{role}-loss`**: 如果使用 critic，会有 `train/critic-loss` 等
- **`train/{role}-grad_norm`**: 不同角色的梯度范数
- **`train/{role}-mtp_loss`**: 如果启用 MTP 训练

---

### 2. Rollout/生成指标 (rollout/*)

这些指标在每次 rollout（生成）阶段记录，反映模型生成的质量和统计信息。

#### 核心 Rollout 指标
- **`rollout/step`**: Rollout 步数（通常等于 rollout_id）
- **`rollout/rewards`**: 平均奖励值
- **`rollout/raw_reward`**: 原始奖励值（未归一化）
- **`rollout/truncated`**: 被截断的样本比例
- **`rollout/response_lengths`**: 响应长度（平均）
- **`rollout/total_lengths`**: 总长度（prompt + response，平均）

#### Log Probability 相关指标
- **`rollout/log_probs`**: 训练策略下的 log 概率
- **`rollout/rollout_log_probs`**: Rollout 策略下的 log 概率
- **`rollout/ref_log_probs`**: 参考策略下的 log 概率（如果使用）

#### Advantage 和 Return 指标
- **`rollout/advantages`**: 优势函数值（用于策略梯度）
- **`rollout/returns`**: 回报值（用于价值函数训练）

#### 响应长度统计 (response_len/*)
- **`rollout/response_len/mean`**: 响应长度平均值
- **`rollout/response_len/median`**: 响应长度中位数

#### 其他 Rollout 指标
- **`rollout/repetition_frac`**: 重复率（检测重复生成的样本比例）
- **`rollout/entropy`**: 生成时的熵值（如果记录）

#### Zero Std 指标 (zero_std/*) - 仅 GRPO
- **`rollout/zero_std/count_{reward}`**: 对于每个奖励值，有多少组样本的奖励标准差为零
  - 例如：`rollout/zero_std/count_0.0` 表示奖励为 0.0 且标准差为 0 的样本组数

#### Speculative Decoding 指标（如果启用）
- **`rollout/spec_accept_rate`**: Speculative decoding 接受率
- **`rollout/spec_accept_length`**: Speculative decoding 接受长度

#### 错误分类指标 (error_cat/*) - 如果启用
- **`rollout/error_cat/{category}`**: 不同错误类别的样本比例
  - 需要设置 `--log-reward-category` 参数

#### 多轮对话指标 (multi_turn_metric/*) - 如果启用
- **`rollout/multi_turn_metric/round_number_mean`**: 平均轮数
- **`rollout/multi_turn_metric/round_number_max`**: 最大轮数
- **`rollout/multi_turn_metric/round_number_min`**: 最小轮数

#### 原始响应长度指标 (raw_response_length/*) - 如果启用
- **`rollout/raw_response_length/response_length_mean`**: 原始响应长度平均值
- **`rollout/raw_response_length/response_length_max`**: 原始响应长度最大值
- **`rollout/raw_response_length/response_length_min`**: 原始响应长度最小值
- **`rollout/raw_response_length/response_length_clip_ratio`**: 被裁剪的响应比例

#### 无观察响应长度指标 (wo_obs_response_length/*) - 如果启用
- **`rollout/wo_obs_response_length/response_length_mean`**: 无观察响应长度平均值
- **`rollout/wo_obs_response_length/response_length_max`**: 无观察响应长度最大值
- **`rollout/wo_obs_response_length/response_length_min`**: 无观察响应长度最小值

---

### 3. 评估指标 (eval/*)

这些指标在评估阶段记录（当设置 `--eval-interval` 时）。

#### 核心评估指标
- **`eval/step`**: 评估步数
- **`eval/{eval_name}`**: 每个评估数据集的平均奖励
  - 例如：`eval/codev_test` 表示 codev_test 数据集的平均奖励
- **`eval/{eval_name}-truncated_ratio`**: 每个评估数据集的截断比例

#### 评估数据集特定指标
- **`eval/{eval_name}/response_len/mean`**: 评估数据集的响应长度平均值
- **`eval/{eval_name}/response_len/median`**: 评估数据集的响应长度中位数
- **`eval/{eval_name}/repetition_frac`**: 评估数据集的重复率
- **`eval/{eval_name}/truncated_ratio`**: 评估数据集的截断比例

#### Pass Rate 指标（如果启用 `--log-passrate`）
- **`eval/{eval_name}/passrate`**: 通过率（如果 reward 函数支持）

---

### 4. 性能指标 (perf/*)

这些指标反映训练和推理的性能。

#### 时间指标
- **`perf/step_time`**: 每个训练步骤的总时间（包括等待时间）
- **`perf/train_time`**: 实际训练时间（不包括等待）
- **`perf/train_wait_time`**: 训练等待时间（等待 rollout 数据）
- **`perf/wait_time_ratio`**: 等待时间占总时间的比例
- **`perf/actor_train_time`**: Actor 模型训练时间
- **`perf/log_probs_time`**: 计算 log 概率的时间
- **`perf/ref_log_probs_time`**: 计算参考 log 概率的时间（如果使用）
- **`perf/rollout_time`**: Rollout 生成时间
- **`perf/sleep_time`**: 模型卸载到 CPU 的时间
- **`perf/wake_up_time`**: 模型从 CPU 加载到 GPU 的时间
- **`perf/update_weights_time`**: 更新权重的时间（同步到 rollout 引擎）
- **`perf/data_preprocess_time`**: 数据预处理时间

#### 吞吐量指标
- **`perf/actor_train_tok_per_s`**: Actor 训练吞吐量（tokens/秒）
- **`perf/tokens_per_gpu_per_sec`**: 每个 GPU 的 token 生成速度
- **`perf/longest_sample_tokens_per_sec`**: 最长样本的 token 生成速度

#### 计算效率指标 (TFLOPs)
- **`perf/log_probs_tflops`**: Log 概率计算的 TFLOPs
- **`perf/ref_log_probs_tflops`**: 参考 log 概率计算的 TFLOPs
- **`perf/actor_train_tflops`**: Actor 训练的 TFLOPs

---

## 指标记录位置

### 代码位置

1. **训练指标** (`train/*`):
   - FSDP 后端: `slime/backends/fsdp_utils/actor.py` (line ~795-812)
   - Megatron 后端: `slime/backends/megatron_utils/model.py` (line ~612-624)

2. **Rollout 指标** (`rollout/*`):
   - FSDP 后端: `slime/backends/fsdp_utils/actor.py` (line ~509-535)
   - Megatron 后端: `slime/backends/megatron_utils/data.py` (line ~344-379)
   - 通用: `slime/ray/rollout.py` (line ~611-630, 633-643)

3. **评估指标** (`eval/*`):
   - `slime/ray/rollout.py` (line ~584-606)

4. **性能指标** (`perf/*`):
   - `slime/utils/train_metric_utils.py` (line ~13-48)
   - `slime/ray/rollout.py` (line ~620-625)

### 记录函数

所有指标都通过 `slime/utils/tracking_utils.py` 中的 `log()` 函数记录到 WandB：

```python
tracking_utils.log(args, log_dict, step_key="train/step")
```

---

## 指标示例

根据实际训练日志，以下是典型的指标值示例：

### 训练指标示例
```python
{
    'train/step': 0,
    'train/loss': 9.569339454174042e-07,
    'train/pg_loss': 9.569339454174042e-07,
    'train/entropy_loss': 0.265962153673172,
    'train/pg_clipfrac': 0.0,
    'train/ppo_kl': 6.183776581070166e-12,
    'train/train_rollout_logprob_abs_diff': 0.012678711675107479,
    'train/ois': 1.0,
    'train/tis': 1.0001018047332764,
    'train/tis_clipfrac': 1.3600041711470112e-05,
    'train/tis_abs': 0.012597822584211826,
    'train/grad_norm': 0.36285679128745674,
    'train/lr-pg_0': 1e-06,
    'train/lr-pg_1': 1e-06
}
```

### Rollout 指标示例
```python
{
    'rollout/step': 1,
    'rollout/response_lengths': 12245.5,
    'rollout/rewards': 0.0,
    'rollout/truncated': 0.03125,
    'rollout/rollout_log_probs': -0.27513445913791656,
    'rollout/raw_reward': 0.375,
    'rollout/total_lengths': 13109.75,
    'rollout/log_probs': -0.27594758570194244,
    'rollout/advantages': -2.7939677238464355e-09,
    'rollout/returns': -2.7939677238464355e-09
}
```

### 性能指标示例
```python
{
    'perf/sleep_time': 5.323812961578369,
    'perf/update_weights_time': 2.5300958156585693,
    'perf/wake_up_time': 2.575822114944458,
    'perf/data_preprocess_time': 0.056499481201171875,
    'perf/train_wait_time': 347.60552525520325,
    'perf/log_probs_time': 17.18164873123169,
    'perf/actor_train_time': 46.9120090007782,
    'perf/train_time': 64.71815633773804,
    'perf/log_probs_tflops': 24.6083648658699,
    'perf/actor_train_tflops': 27.038638292063737,
    'perf/actor_train_tok_per_s': 7498.93273584093,
    'perf/step_time': 412.3236815929413,
    'perf/wait_time_ratio': 0.8430404092054314
}
```

---

## 注意事项

1. **指标前缀**: 所有指标都有前缀（`train/`, `rollout/`, `eval/`, `perf/`），便于在 WandB 中分类查看。

2. **步数键**: 每个指标组都有自己的步数键：
   - `train/step`: 训练步数
   - `rollout/step`: Rollout 步数
   - `eval/step`: 评估步数

3. **条件记录**: 某些指标只在特定条件下记录：
   - TIS 相关指标：需要启用 `--use-tis`
   - KL 损失指标：需要启用 `--use-kl-loss`
   - Speculative decoding 指标：需要启用 speculative decoding
   - 多轮对话指标：需要启用 `--log-multi-turn`

4. **后端差异**: FSDP 和 Megatron 后端可能记录略有不同的指标，但核心指标保持一致。

5. **离线模式**: 如果使用 `--wandb-mode offline`，指标会先保存到本地，之后可以同步到 WandB 服务器。

---

## 参考

- WandB 配置: `run_qwen3_1.7b_multinode_megatron.sh` (line 564-570)
- 训练主循环: `slime/train.py`
- 指标记录: `slime/utils/tracking_utils.py`

