# codev-t1

当前仓库默认使用 **BrainPP + `jlaunch`** 启动 `qwen3_8b_cvdp_testbench` 训练，不再依赖旧的 Slurm 启动方式。

原始 slime 说明仍保留在 `README_ori.md`；这里仅说明现在这套可直接跑的 BrainPP 入口。

## 入口文件

- 配置文件：`examples/iverilog-r1/brainpp/qwen3_8b_cvdp_testbench.conf`
- 容器内实验入口：`examples/iverilog-r1/brainpp/run_qwen3_8b_cvdp_testbench_brainpp.sh`
- `jlaunch` 一键提交脚本：`examples/iverilog-r1/brainpp/submit_qwen3_8b_cvdp_testbench_jlaunch.sh`
- `rjob submit` 风格入口：`examples/iverilog-r1/brainpp/submit_qwen3_8b_cvdp_testbench_rjob.sh`
- 旧 Slurm 脚本：`examples/iverilog-r1/run_qwen3_8b_cvdp_testbench.sh`（仅保留参考）

## 现在的路径约定

这套入口改成了和 `verl/recipe/aec/rjob` 类似的“先同步到挂载存储，再从挂载存储同步到容器本地工作目录”的流程：

1. 本机仓库：`/home/i-zhangxiaoyun/codev-t1`
2. 提交前同步到挂载存储：`/mnt/i-zhangxiaoyun/codev-t1`
3. 每个容器启动后再同步到本地工作目录：`/workspace/codev-t1`

这样做是因为 `jlaunch` / `rjob` 拉起镜像后相当于一台全新的机器，容器里默认没有你的代码目录；不能再假设像以前 Slurm 环境那样直接复用某台机器上的本地路径。

## 默认存储位置

- 起始模型：`/mnt/i-zhangxiaoyun/models/qwen3_8b/checkpoint-1270`
- 训练 checkpoint 根目录：`/mnt/i-zhangxiaoyun/results/codev-t1/checkpoints/qwen3_8b_cvdp_testbench`
- 实际保存目录：`/mnt/i-zhangxiaoyun/results/codev-t1/checkpoints/qwen3_8b_cvdp_testbench/dynamic_curriculum_kl0.0_update2_eval3_lr2e-6`
- W&B 离线目录：`/mnt/i-zhangxiaoyun/results/codev-t1/wandb/<RUN_NAME>`
- 运行时共享状态：`/mnt/i-zhangxiaoyun/results/codev-t1/runtime/<RUN_NAME>`
- 节点 bootstrap 日志：`/mnt/i-zhangxiaoyun/results/codev-t1/logs/<RUN_NAME>`

如果你的模型不在默认位置，直接覆盖 `MODEL_PATH` 即可。

## 训练拓扑

默认训练超参数与旧实验保持一致：

- 总节点数：`2`
- 每节点 GPU：`8`
- actor：`1` 节点 × `8` GPU
- rollout：`8` GPU
- 训练入口：`train_async.py`
- rollout 函数：`iverilog_async_rollout.generate_rollout_fully_async`
- reward 函数：`cvdp_testbench_reward.reward_func`
- eval 函数：`custom_eval_cvdp.custom_eval_cvdp`

## 依赖约定

默认镜像是 `hub.i.basemind.com/diversity/slime:0319`，并假设镜像内已可直接调用：

- `python3`
- `ray`
- `iverilog`
- `vvp`

如果镜像里的工具不在 `PATH` 上，仍可按需覆盖：

- `IVERILOG_PATH`
- `VVP_PATH`
- `YOSYS_PATH`
- `CVDP_PYTEST_PATH`
- `CVDP_EXTRA_BIN_PATH`
- `ENTRY_ACTIVATE_CMD`

## 直接提交流程

先确认配置：

```bash
vim examples/iverilog-r1/brainpp/qwen3_8b_cvdp_testbench.conf
```

最常需要确认的变量：

- `MODEL_PATH`
- `CKPT_BASE`
- `CKPT_SAVE_NAME`
- `JLAUNCH_IMAGE`
- `JLAUNCH_CHARGED_GROUP`
- `JLAUNCH_POSITIVE_TAGS`
- `JLAUNCH_CUSTOM_RESOURCES`
- `RJOB_IMAGE`
- `RJOB_CHARGED_GROUP`
- `RJOB_POSITIVE_TAGS`
- `RJOB_CUSTOM_RESOURCES`

### 用 `jlaunch` / `brainctl rjob launch`

然后直接提交：

```bash
RUN_NAME=qwen3-8b-cvdp-$(date +%d%H%M) \
JLAUNCH_CHARGED_GROUP=step1o \
JLAUNCH_PRIVATE_MACHINE=group \
JLAUNCH_CUSTOM_RESOURCES=rdma/mlnx_shared=8,mellanox.com/mlnx_rdma=1 \
JLAUNCH_POSITIVE_TAGS=H800 \
NUM_NODES=2 \
bash examples/iverilog-r1/brainpp/submit_qwen3_8b_cvdp_testbench_jlaunch.sh
```

如果你的 H800 环境要求显式声明 RDMA 资源，可再加：

```bash
JLAUNCH_CUSTOM_RESOURCES=rdma/mlnx_shared=8,mellanox.com/mlnx_rdma=1
```

### 用 `rjob submit`

如果你所在环境仍提供老的 `rjob submit` CLI，可使用同等入口：

```bash
RUN_NAME=qwen3-8b-cvdp-$(date +%d%H%M) \
RJOB_CHARGED_GROUP=step1o \
RJOB_PRIVATE_MACHINE=group \
RJOB_CUSTOM_RESOURCES=rdma/mlnx_shared=8,mellanox.com/mlnx_rdma=1 \
RJOB_POSITIVE_TAGS=H800 \
NUM_NODES=2 \
bash examples/iverilog-r1/brainpp/submit_qwen3_8b_cvdp_testbench_rjob.sh
```

这个脚本会提交两个 job：

1. 一个 head job
2. 一个 worker job（`replica = NUM_NODES - 1`）

两者仍然共享同一个挂载存储目录，并通过 `HEAD_IP_FILE` 传递 Ray head IP。

提交脚本会自动完成：

1. 把本地仓库同步到 `SYNC_REPO_ROOT`，默认即 `/mnt/i-zhangxiaoyun/codev-t1`
2. 提交一个 head 容器
3. 提交 `NUM_NODES - 1` 个 worker 副本
4. head 把 Ray IP 写入 `HEAD_IP_FILE`
5. worker 读取该文件并自动加入 Ray 集群

## 常见覆盖项

覆盖模型和输出目录：

```bash
MODEL_PATH=/mnt/i-zhangxiaoyun/models/shiyelnts-ori-2-dist \
HF_MODEL_PATH=/mnt/i-zhangxiaoyun/models/shiyelnts-ori-2 \
CKPT_SAVE_NAME=dynamic_curriculum_2stage \
RUN_NAME=qwen3-8b-2stage-$(date +%d%H%M) \
RJOB_CHARGED_GROUP=step1o \
RJOB_PRIVATE_MACHINE=group \
RJOB_CUSTOM_RESOURCES=rdma/mlnx_shared=8,mellanox.com/mlnx_rdma=1 \
RJOB_POSITIVE_TAGS=H800 \
bash examples/iverilog-r1/brainpp/submit_qwen3_8b_cvdp_testbench_rjob.sh
```

覆盖挂载：

```bash
JLAUNCH_MOUNT_SPECS="juicefs+s3://oss.i.shaipower.com/i-zhangxiaoyun:/mnt/i-zhangxiaoyun" \
bash examples/iverilog-r1/brainpp/submit_qwen3_8b_cvdp_testbench_jlaunch.sh
```

`rjob submit` 入口对应变量名分别是：

- `RJOB_MOUNT_SPECS`
- `RJOB_EXTRA_VOLUMES`
- `RJOB_HEAD_CPU`
- `RJOB_HEAD_MEMORY_MIB`
- `RJOB_HEAD_GPU`
- `RJOB_WORKER_CPU`
- `RJOB_WORKER_MEMORY_MIB`
- `RJOB_WORKER_GPU`

如确有额外 volume 需求，可设置：

```bash
JLAUNCH_EXTRA_VOLUMES="/mnt:/mnt"
```

或：

```bash
RJOB_EXTRA_VOLUMES="/mnt:/mnt"
```

## 这次改动去掉了什么

- 不再依赖 `SLURM_JOB_ID`、`scontrol`、`sbatch`
- 不再默认要求手工提供 `iverilog` / `vvp` / `yosys` 绝对路径
- 不再依赖旧的 Sandbox / `ulimit` workaround
- 不再假设代码已经存在于容器里

## 备注

- `jlaunch` 本质上就是 `brainctl rjob launch`
- `submit_qwen3_8b_cvdp_testbench_rjob.sh` 面向仍保留 `rjob submit` 命令的环境
- 当前运行方式是“本机仓库 → 挂载存储 → 容器本地工作目录”
- 如果后续切换其他 BrainPP 提交流程，核心训练入口仍然是 `examples/iverilog-r1/brainpp/run_qwen3_8b_cvdp_testbench_brainpp.sh`
