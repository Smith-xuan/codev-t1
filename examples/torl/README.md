# ToRL Training with SLIME Framework

This directory contains the training scripts and code for ToRL (Tool-oriented Reinforcement Learning) using the SLIME framework.

## Overview

ToRL is a reinforcement learning framework for training language models to use tools effectively. This implementation adapts ToRL from the verl framework to work with SLIME, using:

- **SGLang** as the inference engine (instead of vLLM)
- **Megatron-LM** format for model checkpoints
- **SandboxFusion** for Python code execution (required for ToRL)

## Directory Structure

```
torl/
├── generate_with_torl.py          # Custom generation function for Python tool calls
├── run_qwen3_1.5b_multinode_megatron.sh  # Multi-node training script
└── README.md                       # This file
```

## Prerequisites

1. **SLIME Environment**: Ensure the `slime` micromamba environment is set up
2. **SandboxFusion**: Required for Python code execution
   - Install SandboxFusion at `/nfs_global/projects/verl/SandboxFusion`
   - Create `sandbox-runtime` conda environment
3. **Model Checkpoint**: Qwen2.5-Math-1.5B model in Megatron format
4. **Data**: ToRL training data in parquet format at `/nfs_global/ToRL/data/torl_data`

## Key Differences from Iverilog-R1

1. **Tool Execution**: 
   - Iverilog-R1: Executes Verilog code (can use local execution)
   - ToRL: Executes Python code (must use SandboxFusion)

2. **Tool Call Format**:
   - Iverilog-R1: `{"name": "verilog_simulator", "arguments": {"code": "..."}}`
   - ToRL: `{"name": "python_executor", "arguments": {"code": "..."}}`

3. **Execution Method**:
   - Iverilog-R1: Supports `sandbox_fusion`, `local_iverilog`, or `iverilog_server`
   - ToRL: Only supports `sandbox_fusion` (Python code must run in sandbox)

## Configuration

### Model Configuration

The script is configured for **Qwen2.5-Math-1.5B**:
- 24 layers
- 1536 hidden size
- 12 attention heads
- 4 query groups (GQA)

### Training Configuration

- **Rollout batch size**: 32
- **Samples per prompt**: 16
- **Max response length**: 3072 tokens
- **Max context length**: 4096 tokens
- **Temperature**: 1.0
- **Learning rate**: 1e-6
- **GRPO** advantage estimator

### SandboxFusion Configuration

- **Port**: 8185 (default, can be overridden with `SANDBOX_PORT`)
- **Host**: 0.0.0.0 (listens on all interfaces)
- **Concurrency**: 32 (controlled by `SANDBOX_FUSION_CONCURRENCY`)

## Usage

### Single Node Training

For single node training, you can modify the script to use `NUM_NODES=1`:

```bash
export NUM_NODES=1
export GPUS_PER_NODE=8
bash run_qwen3_1.5b_multinode_megatron.sh
```

### Multi-Node Training

1. **Configure network settings**:
   ```bash
   export MASTER_ADDR="10.21.0.3"  # Master node IP
   export WORKER_ADDR="10.21.0.12"  # Worker node IP
   export NETWORK_INTERFACE="eth0"  # Network interface
   ```

2. **Ensure SSH access** to worker node (passwordless SSH recommended)

3. **Run the training script**:
   ```bash
   bash run_qwen3_1.5b_multinode_megatron.sh
   ```

### Environment Variables

- `SANDBOX_PORT`: SandboxFusion server port (default: 8185)
- `SANDBOX_URL`: Override SandboxFusion URL (default: `http://${HOST_IP}:${SANDBOX_PORT}/run_code`)
- `SANDBOX_FUSION_CONCURRENCY`: Max concurrent Python executions (default: 32)
- `USE_DIRECT_SANDBOX_API`: Use direct API calls (default: true)
- `MASTER_ADDR`: Master node IP address
- `WORKER_ADDR`: Worker node IP address
- `NUM_NODES`: Number of nodes (default: 2)
- `GPUS_PER_NODE`: GPUs per node (default: 8)

## Custom Generation Function

The `generate_with_torl.py` module provides:

1. **`generate()`**: Multi-turn generation function that:
   - Handles tool calls (`<tool_call>` tags)
   - Executes Python code via SandboxFusion
   - Processes tool responses
   - Continues until final answer (`<answer>` tag)

2. **`reward_func()`**: Reward calculation function:
   - Extracts Python code from solution
   - Compares with ground truth
   - Returns reward score (0.0 to 1.0)

3. **`execute_predictions()`**: Tool execution function:
   - Parses tool calls from model output
   - Calls SandboxFusion API
   - Formats execution results
   - Returns tool response for next turn

## Tool Call Format

The model should generate tool calls in the following format:

```xml
<tool_call>
{"name": "python_executor", "arguments": {"code": "print('Hello, World!')"}}
</tool_call>
```

Supported tool names:
- `python_executor` (preferred)
- `python`
- `python_tool`

## SandboxFusion Integration

The script automatically:
1. Starts SandboxFusion server if not already running
2. Waits for server to be ready
3. Configures Ray workers with `SANDBOX_URL`
4. Cleans up server on script exit

SandboxFusion server runs in the `sandbox-runtime` conda environment, while training runs in the `slime` micromamba environment.

## Troubleshooting

### SandboxFusion Not Starting

- Check if `sandbox-runtime` conda environment exists: `conda env list`
- Verify SandboxFusion directory exists: `/nfs_global/projects/verl/SandboxFusion`
- Check logs: `tail -f sandbox_fusion.log`

### Ray Cluster Issues

- Verify SSH access to worker node
- Check network interface configuration
- Ensure Ray ports are not in use (default: 8266 for dashboard, 6379 for GCS)

### Python Execution Errors

- Check SandboxFusion server logs
- Verify `SANDBOX_URL` is accessible from Ray workers
- Check concurrency limits (`SANDBOX_FUSION_CONCURRENCY`)

## Comparison with Verl Framework

| Feature | Verl Framework | SLIME Framework |
|---------|---------------|-----------------|
| Inference Engine | vLLM | SGLang |
| Model Format | HuggingFace | Megatron-LM |
| Parallelism | FSDP | Megatron (TP/PP/CP) |
| Tool Execution | SandboxFusion | SandboxFusion (same) |
| Training Backend | PyTorch FSDP | Megatron-LM |

## References

- [SLIME Framework](../README.md)
- [Iverilog-R1 Example](../iverilog-r1/README_zh.md)
- [ToRL Original Implementation](../../../ToRL/README.md)
- [SandboxFusion Documentation](https://github.com/bytedance/SandboxFusion)

