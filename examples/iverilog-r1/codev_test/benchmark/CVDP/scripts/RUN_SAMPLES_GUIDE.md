# 运行5次Sample测试的脚本说明

## 脚本位置

**主脚本**: `/nfs_global/projects/cvdp_benchmark/run_samples.py`

这是运行多次sample测试并合并报告的Python脚本。

## 功能说明

`run_samples.py` 会：
1. 运行指定数量的sample（默认5次）
2. 为每个sample创建独立的目录（`sample_1`, `sample_2`, ...）
3. 将响应文件复制到每个sample目录
4. 运行 `run_benchmark.py` 对每个sample进行评估
5. 合并所有sample的报告生成 `composite_report.json` 和 `composite_report.txt`

## 关键参数

- `-n, --n-samples <number>`: 运行的sample数量（默认：5）
- `-k, --k-threshold <number>`: Pass@k的阈值（默认：1，即pass@1）
- `--prefix <path>`: 输出目录前缀（所有sample都会在这个目录下）

## 基于 run.log 的命令示例

根据 `results/experiment_tool/run.log`，生成 `experiment_tool` 结果的命令是：

```bash
python run_samples.py \
  --filename data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl \
  --llm \
  --model local_import \
  --threads 64 \
  --prompts-responses-file results/experiment_tool/sample_1/answer_to_import.jsonl \
  --prefix results/experiment_tool \
  --n-samples 1 \
  --k-threshold 1 \
  --external-network \
  --network-name cvdp-bridge-cvdp_v1-0-2_nonagentic_code_generation_no_commercial
```

**注意**：脚本会自动处理：
- 为每个sample创建独立的响应文件路径
- Docker网络管理（使用共享网络或为每个sample创建独立网络）

## 简化版本（推荐）

```bash
python run_samples.py \
  -f data/raw/cvdp_v1.0.2_nonagentic_code_generation_no_commercial.jsonl \
  --llm \
  --model local_import \
  --threads 64 \
  --prompts-responses-file results/claude_tool/answer_to_import.jsonl \
  --prefix results/experiment_tool \
  -n 5 \
  -k 1
```

## 输出结构

运行后会在 `--prefix` 指定的目录下创建：

```
results/experiment_tool/
├── sample_1/
│   ├── raw_result.json
│   ├── report.json
│   ├── report.txt
│   └── answer_to_import.jsonl  # 复制自源文件
├── sample_2/
│   └── ...
├── sample_3/
│   └── ...
├── sample_4/
│   └── ...
├── sample_5/
│   └── ...
├── composite_report.json    # 合并的JSON报告
├── composite_report.txt    # 合并的文本报告
└── run.log                  # 运行日志
```

## 关键代码位置

### 1. 主运行逻辑
```192:364:run_samples.py
def run_samples(args: argparse.Namespace, n_samples: int, k_threshold: int) -> None:
    """Run multiple samples of run_benchmark.py and combine the results."""
    # ... 创建sample目录 ...
    # ... 为每个sample运行run_benchmark.py ...
    # ... 合并报告 ...
```

### 2. Sample循环
```272:355:run_samples.py
for i in range(n_samples):
    sample_prefix = sample_prefixes[i]
    # ... 复制响应文件到sample目录 ...
    # ... 构建并运行命令 ...
```

### 3. 报告合并
```54:190:run_samples.py
def combine_reports(sample_prefixes: List[str], output_prefix: str, n_samples: int, k_threshold: int) -> None:
    """Combine multiple report.json files into a composite report."""
    # ... 加载所有sample的报告 ...
    # ... 统计问题 ...
    # ... 生成合并报告 ...
```

### 4. 统计信息输出
```157:177:run_samples.py
print(f"Found {len(problem_ids)} unique problems across {len(composite_report['samples'])} samples")

# Print sample statistics
for i, sample in enumerate(composite_report["samples"]):
    # ... 计算通过率 ...
    print(f"Sample {i+1}: {total_passed}/{total_problems} problems passed ({pass_rate:.2f}%)")
```

## 相关脚本

- **示例脚本**: `scripts/run_samples_example.sh` - 包含完整命令示例
- **导入脚本**: `scripts/import.sh` - 用于单次测试（不使用sample）

## 注意事项

1. **响应文件路径**: 
   - `--prompts-responses-file` 指定源文件路径
   - 脚本会自动将其复制到每个sample目录

2. **多采样支持**: 
   - 如果响应文件中每个问题有多个completion，需要准备多个文件
   - 或者使用 `LocalInferenceModel` 的多采样功能（根据sample目录选择对应的completion）

3. **Docker网络**: 
   - 脚本会自动创建共享Docker网络
   - 所有sample使用同一个网络以提高效率

4. **重新生成报告**: 
   - 如果已有raw_result.json，可以使用 `--regenerate-report` 只重新生成报告而不重新运行测试

## 使用 run_reporter.py 分析结果

运行完成后，可以使用 `run_reporter.py` 进行进一步的pass@k分析：

```bash
python run_reporter.py results/experiment_tool/composite_report.json
```
