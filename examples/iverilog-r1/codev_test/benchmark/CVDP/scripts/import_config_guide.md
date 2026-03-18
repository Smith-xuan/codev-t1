# 使用 answer_to_import.jsonl 测试结果配置指南

## 问题诊断

### 当前情况
- **answer_to_import.jsonl**: 包含 35 个问题的响应（共 175 行，支持多采样）
- **实际测试结果**: 只测试了 1 个问题（`cvdp_copilot_lfsr_0001`）

### 根本原因
在 `run_benchmark.py` 的 `benchmark()` 方法中（第 57-60 行），如果 `work/raw_result.json` 文件已存在，程序会**直接加载已有结果**而不重新运行测试：

```python
# If raw_result.json exists, load it instead of rerunning tests
if os.path.exists(raw_result_path):
    print(f"Using existing raw_result.json from {raw_result_path}")
    with open(raw_result_path, 'r') as f:
        res = json.load(f)
```

因此，即使 `answer_to_import.jsonl` 包含 35 个问题的响应，由于 `raw_result.json` 中只有 1 个问题的旧结果，所以只显示了这 1 个问题的结果。

## 解决方案

### 方案 1: 删除旧的结果文件（推荐）

在运行测试前删除 `work/raw_result.json`：

```bash
rm -f work/raw_result.json
python run_benchmark.py -f data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl \
  --model local_import \
  --prompts-responses-file /nfs_global/projects/cvdp_benchmark/results/claude_tool/answer_to_import.jsonl \
  --llm
```

或者使用已更新的 `import.sh` 脚本（已包含清理步骤）。

### 方案 2: 使用 --id 参数测试特定问题

如果你想测试特定问题，可以使用 `--id` 参数：

```bash
python run_benchmark.py -f data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl \
  --model local_import \
  --prompts-responses-file /nfs_global/projects/cvdp_benchmark/results/claude_tool/answer_to_import.jsonl \
  --llm \
  --id cvdp_copilot_32_bit_Brent_Kung_PP_adder_0001
```

### 方案 3: 使用 --regenerate-report 重新生成报告

如果你已经有完整的 `raw_result.json` 但想重新生成报告：

```bash
python run_benchmark.py -f data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl \
  --model local_import \
  --prompts-responses-file /nfs_global/projects/cvdp_benchmark/results/claude_tool/answer_to_import.jsonl \
  --llm \
  --regenerate-report
```

## 多采样支持

`answer_to_import.jsonl` 文件支持多采样（每个问题可能有多个 completion）：

- **35 个问题** × **约 5 个采样/问题** = **175 行**
- 程序会自动根据采样目录（`sample_1`, `sample_2`, 等）选择对应的 completion

### 多采样配置

如果你使用 `run_samples.py` 运行多个采样，每个采样会使用对应的 completion：

```bash
# 假设 answer_to_import.jsonl 中每个问题有 5 个采样
# sample_1 会使用第 1 个 completion (索引 0)
# sample_2 会使用第 2 个 completion (索引 1)
# ...
# sample_5 会使用第 5 个 completion (索引 4)
```

## 验证配置

运行后检查：

1. **检查加载的问题数量**：
   ```
   INFO:root:Loaded responses for 35 problems from ...
   INFO:root:Total completions: 175 (supports multi-sampling)
   ```

2. **检查测试结果**：
   - 查看 `work/report.txt` 中的问题统计
   - 应该看到 35 个问题的结果，而不是只有 1 个

3. **检查 raw_result.json**：
   ```bash
   cat work/raw_result.json | jq 'keys | length'  # 应该是 35
   ```

## 当前配置检查清单

- [x] `answer_to_import.jsonl` 包含所有问题的响应
- [ ] `work/raw_result.json` 已删除（如果需要重新测试）
- [x] 使用 `--model local_import`
- [x] 使用 `--prompts-responses-file` 指定响应文件
- [x] 使用 `--llm` 标志

## 常见问题

### Q: 为什么只测试了部分问题？
**A**: 因为 `work/raw_result.json` 已存在并包含旧结果。删除该文件后重新运行。

### Q: 如何测试所有问题而不是单个问题？
**A**: 删除 `work/raw_result.json` 并运行完整的 benchmark（不要使用 `--id` 参数）。

### Q: 多采样是如何工作的？
**A**: `LocalInferenceModel` 会根据当前工作目录中的 `sample_N` 模式选择对应的 completion。索引从 0 开始，所以 `sample_1` 使用索引 0 的 completion。

## 参考代码位置

- **问题检测逻辑**: `run_benchmark.py:57-60`
- **响应加载逻辑**: `src/llm_lib/local_inference_model.py:67-104`
- **多采样选择逻辑**: `src/llm_lib/local_inference_model.py:259-293`
