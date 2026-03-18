# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**slime** is an LLM post-training framework for RL scaling. It connects Megatron-LM (training) with SGLang (inference) via Ray for distributed orchestration. It powers models like GLM-4.5/4.6/4.7 and supports Qwen3, DeepSeek V3/R1, and Llama 3 series.

## Build & Install

```bash
pip install -e .           # Standard install
pip install -e ".[fsdp]"   # With FSDP extras
```

Python >= 3.10 required. Dependencies in `requirements.txt`.

## Code Quality

Pre-commit hooks handle linting/formatting:
```bash
pre-commit install
pre-commit run --all-files
```

Tools: **ruff** (lint + fix), **autoflake** (unused imports), **isort** (imports, black profile), **black** (formatting). Line length: 119 (black/isort), 320 (ruff — relaxed for now).

## Running Tests

```bash
pytest tests/ -m "unit"                        # Unit tests
pytest tests/ -m "integration"                 # Integration tests
pytest tests/test_qwen2.5_0.5B_gsm8k.py -v    # Single test
```

Test markers: `unit`, `integration`, `system`, `acceptance`, `skipduringci`, `pleasefixme`. Config in `pyproject.toml`.

## Architecture

### Training Loop (`train.py`)

The main entry point runs a rollout-and-train loop:
1. `create_placement_groups(args)` — allocate GPUs across nodes via Ray
2. `create_rollout_manager()` — initialize SGLang inference engines
3. `create_training_models()` — initialize actor (and optional critic) models
4. Loop over rollout iterations:
   - `rollout_manager.generate()` — generate completions + compute rewards
   - `actor_model.async_train()` — update model weights (GRPO/PPO)
   - Periodically save checkpoints and run evaluation
   - Offload/onload weights between training and inference when colocated

### Core Package (`slime/`)

| Directory | Purpose |
|-----------|---------|
| `backends/megatron_utils/` | Megatron-LM distributed training (tensor/pipeline/sequence/expert parallelism) |
| `backends/fsdp_utils/` | PyTorch FSDP alternative backend |
| `backends/sglang_utils/` | SGLang inference engine management |
| `ray/` | Ray actors: `placement_group.py` (GPU allocation), `rollout.py` (RolloutManager), `train_actor.py` (training actor), `actor_group.py` |
| `rollout/sglang_rollout.py` | Generation pipeline using SGLang |
| `rollout/rm_hub/` | Reward model implementations (math, code, etc.) |
| `rollout/generate_hub/` | Custom generation functions (tool use, search, code execution) |
| `rollout/filter_hub/` | Dynamic sampling filters |
| `router/` | SGLang router configuration |
| `utils/` | ~40 utility modules: arguments, logging, memory, metrics, distributed, profiling |

### Plugins (`slime_plugins/`)

| Directory | Purpose |
|-----------|---------|
| `mbridge/` | Megatron-Bridge model wrappers (qwen3, glm4, mimo, etc.) |
| `models/` | HuggingFace-compatible model definitions |
| `rollout_buffer/` | Rollout data buffering for training |
| `megatron_bridge/` | Integration layer between Megatron and HF models |

### Arguments

Three categories (parsed in `slime/utils/arguments.py`):
1. **Megatron arguments**: e.g. `--tensor-model-parallel-size 2`
2. **SGLang arguments**: prefixed with `--sglang-`, e.g. `--sglang-mem-fraction-static 0.8`
3. **slime-specific arguments**: cluster config (`--actor-num-nodes`, `--rollout-num-gpus`, `--colocate`), rollout config (`--prompt-data`, `--rm-type`, `--n-samples-per-prompt`), training config (`--num-rollout`, `--advantage-estimator grpo`), backend selection (`--megatron` vs `--fsdp`)

### Key Extension Points

- **Custom reward models**: implement in `slime/rollout/rm_hub/`, use with `--rm-type`
- **Custom generation functions**: implement in `slime/rollout/generate_hub/`, use with `--custom-generate-function-path`
- **New model support**: add model wrapper in `slime_plugins/mbridge/`, config in `scripts/models/`

## Project Layout

```
train.py                    # Main entry point
slime/                      # Core framework
slime_plugins/              # Model wrappers, data buffers, bridge layers
scripts/                    # Training launch scripts (run-*.sh) and model configs
examples/                   # Use-case examples (search-r1, torl, iverilog-r1, etc.)
tests/                      # Pytest test suite
tools/                      # Checkpoint conversion utilities
docker/                     # Dockerfile with Megatron/SGLang/CUDA setup
docs/                       # Sphinx docs (en/ and zh/)
```
