#!/bin/bash

# Extract device names and merge them into a comma-separated string
THIS_UP_IB_DEV=$(ibdev2netdev | grep Up | grep ib | awk '{print $1}' | paste -sd ',' -)
export NCCL_IB_HCA=$THIS_UP_IB_DEV

#- Log infomation

node_dev_msg="
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Task run on: $(hostname -s);
GPU devices: $(nvidia-smi --format=csv --query-gpu=name,driver_version,power.limit);
InfiniBand devices: $(ibdev2netdev);
NCCL_IB_HCA=$THIS_UP_IB_DEV;
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
"

node_task_msg="
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Task run on: $(hostname -s), PID: ${SLURM_TASK_PID},
USE GPU ${CUDA_VISIBLE_DEVICES} of this node (GPUs_PER_Node, not PER_Task);
GlobalID : $SLURM_PROCID    of $SLURM_NTASKS,
NodeID   : $SLURM_NODEID    of $SLURM_JOB_NUM_NODES,
LocalID  : $SLURM_LOCALID    of $SLURM_NTASKS_PER_NODE;
GPUs_PER_Task = $USER_NGPUS / $SLURM_NTASKS = $(($USER_NGPUS/$SLURM_NTASKS)),
MASTER_ADDR   = $MASTER_ADDR
MASTER_PORT   = $MASTER_PORT
WORLD_SIZE    = $WORLD_SIZE
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
"



echo $node_dev_msg
echo $node_task_msg

#- Important setting!!!
##  otherwise it will cause an error of insufficient RDMA resources:
ulimit -l unlimited
##  otherwise it will result in an insufficient virtual memory size error, especially when loading LLM:
ulimit -v unlimited
ulimit -n 65535
ulimit -u 4125556

#- Load environments
source /tools/module_env.sh
source ~/.bashrc
##- language
# module load python3/3.8.16
module load gcc/9.3.0

##- CUDA
module unload cuda-cudnn
module load cuda-cudnn/12.1-8.9.3
export CUDA_HOME=/tools/cluster-software/cuda-cudnn/cuda-12.1.1-8.9.3
which nvcc
echo $CUDA_HOME

echo "Task $SLURM_PROCID: "$(module list)              # list modules loaded
echo "Task $SLURM_PROCID: "$(which gcc)
echo "Task $SLURM_PROCID: "$(which python)
echo "Task $SLURM_PROCID: "$(which python3)

#- WARNING! DO NOT MODIFY your CUDA_VISIBLE_DEVICES
#- in `.bashrc`, `env.sh`, or your job script
echo "Node $SLURM_NODEID, LocalID $SLURM_LOCALID: Use GPU ${CUDA_VISIBLE_DEVICES}"
#- The CUDA_VISIBLE_DEVICES variable is assigned and specified by SLURM

##- Monitor
# The script continues executing other tasks while the following command will execute after a while
module load slurm-tools/v1.0
(sleep 3h && slurm-gpu-atop-log-stats $SLURM_JOB_ID $CUDA_VISIBLE_DEVICES) &
echo "Main program continues to run. Monitoring information will be exported after three hours."

#- Main program execution

##- virtualenv

source /nfs_global/S/shiwenxuan/miniconda3/bin/activate /nfs_global/S/shiwenxuan/miniconda3/envs/llama/
export PATH="/nfs_global/S/shiwenxuan/miniconda3/envs/llama/:$PATH"
which python


# wandb login your_api_key!!!!
export WANDB_API_KEY='e8f26cb646aea4a12ef982270212804afa4fa31e'
wandb login $WANDB_API_KEY
export WANDB_MODE=offline



##- Job step TODO

# ray's default GCS(Global Control Store) port is 6379 
# and default dashboard port is 8265
# need to set `"working_dir": "."` in --runtime-env-json, otherwise working_dir will set to ~(/home/S/your_name) by default

export TORCH_NCCL_ASYNC_ERROR_HANDLING=1
export NCCL_DEBUG=INFO
export NCCL_TIMEOUT=120
export RAY_record_ref_creation_sites=1
export RAY_IGNORE_UNHANDLED_ERRORS=0
export HYDRA_FULL_ERROR=1
export PYTHONUNBUFFERED=TRUE
export VLLM_USE_V1=1

export RAY_TEMP_DIR="/tmp/ray_$SLURM_JOBID"
echo "RAY TEMP DIR is $RAY_TEMP_DIR"
export CURR_DIR=$(realpath .)

USER=$(whoami)
LOCAL_SCRATCH="/tmp/$USER/job_$SLURM_JOB_ID"
mkdir -p $LOCAL_SCRATCH
export TORCH_EXTENSIONS_DIR="$LOCAL_SCRATCH/torch_extensions"
export HF_HOME="$LOCAL_SCRATCH/hf_home"
export PIP_TOOLS_CACHE_DIR="$LOCAL_SCRATCH/pip_cache"
export TRITON_CACHE_DIR="$LOCAL_SCRATCH/triton_autotune"
export HF_DATASETS_CACHE="$LOCAL_SCRATCH/hf_datasets"

# export TORCH_EXTENSIONS_DIR="/workspace/S/$USER/.cache/torch_extensions"
# export HF_HOME="/workspace/S/$USER/.cache"
# export PIP_TOOLS_CACHE_DIR="/workspace/S/$USER/.cache/pip-tools"
# export TRITON_CACHE_DIR="/workspace/S/$USER/.triton/autotune"


echo "USER GPUS PER NODE IS $USER_GPUS_PER_NODE"
# ray stop --force


MASTER_IP=$(nslookup $MASTER_ADDR | awk '/^Address: / { print $2 }')
DASHBOARD_PORT=$(($MASTER_PORT-10000))
DAL_PORT=$(($MASTER_PORT-20000))
RCS_PORT=$(($MASTER_PORT-30000))
RS_PORT=$(($MASTER_PORT-5000))
NM_PORT=$(($MASTER_PORT-15000))
OM_PORT=$(($MASTER_PORT-25000))


export FORCE_TORCHRUN=1
export NNODES=$SLURM_JOB_NUM_NODES    
export NODE_RANK=$SLURM_NODEID       
export LOCAL_RANK=$SLURM_LOCALID        
export MASTER_ADDR=$MASTER_ADDR
export MASTER_PORT=$MASTER_PORT

cd /workspace/S/shiwenxuan/LLaMA-Factory
# sh /nfs_global/S/shiwenxuan/LLaMA-Factory/recipe/start_multi_8.8k_10epochs_8b.sh

echo "Checking shared memory size on $(hostname -s):"
df -h /dev/shm

#!/bin/bash
CONFIG_FILE="/workspace/S/shiwenxuan/LLaMA-Factory/examples/tool_using/test_qwen3_32b_with_history_think.yaml"
LOGDIR="./logs"
mkdir -p $LOGDIR 

LOG_FILE="$LOGDIR/32b_node_${SLURM_NODEID}.log"

echo "Starting training on NODE_RANK: $SLURM_NODEID, log will be saved to $LOG_FILE"

llamafactory-cli train $CONFIG_FILE > $LOG_FILE 2>&1


# python /nfs_global/S/shiwenxuan/LLaMA-Factory/src/llamafactory/cli.py train examples/tool_using/test_qwen3.yaml

# only need to submit job on the master node, 
# and submitting on other nodes will cause network errors
# if [ "$SLURM_PROCID" -eq 0 ]; then
#     ray list nodes

#     SCRIPT_TO_RUN="$CURR_DIR/recipe/dapo/run_dapo_codev_7b_14k.sh"
#     export SAVE_DIR="$CURR_DIR/results/run_dapo_codev_7b_14k"

#     # SCRIPT_TO_RUN=recipe/dapo/run_dapo_codev_7b_20k_err_l0.2_r1_continuous_reward.sh
#     # export SAVE_DIR="$CURR_DIR/results/run_dapo_codev_7b_20k_continuous_reward"

#     # SCRIPT_TO_RUN=recipe/dapo/dapo_7b_test.sh
#     # export SAVE_DIR="$CURR_DIR/results/dapo_7b_test"

#     mkdir -p $SAVE_DIR
#     chmod 777 $SAVE_DIR
#     cp $SCRIPT_TO_RUN $SAVE_DIR

#     copy_log_and_plot() {
#         sleep 30m
#         while true; do
#             cp $CURR_DIR/ret_one/$SLURM_JOBID.* $SAVE_DIR && python $CURR_DIR/plot_and_analyze/plot.py --folder $SAVE_DIR
#             find $SAVE_DIR \( -type d -o -type f \) -exec chmod 777 {} +
#             sleep 3m  # 每隔3分钟执行一次，你可以根据需要调整时间
#         done
#     }

#     copy_log_and_plot &
#     COPY_PID=$!

#     RUNTIME_ENV=$(jq -n --arg save_dir "$SAVE_DIR" --arg path "$PATH" '{
#             "pip": ["ray"],
#             "working_dir": ".",
#             "excludes": ["ckpt/", "xxx/", "ret_one/", "data/", "results/", ".git/"],
#             "disable_caching": true,
#             "env_vars": {"SAVE_DIR": $save_dir, "WANDB_DIR":$save_dir, "PATH":$path}
#         }')
#     ray job submit --address="http://127.0.0.1:$DASHBOARD_PORT" --runtime-env-json="$RUNTIME_ENV" -- bash $SCRIPT_TO_RUN

#     kill $COPY_PID
#     cp $CURR_DIR/ret_one/$SLURM_JOBID.* $SAVE_DIR && python $CURR_DIR/plot_and_analyze/plot.py --folder $SAVE_DIR

#     # sleep 48h
#     mkdir -p ../tmp/ray_$USER
#     chmod 777 ../tmp
#     cp -rfL $RAY_TEMP_DIR/session_latest ../tmp/ray_$USER/
#     ray stop --force
# else
#     # echo "Worker node $SLURM_PROCID is waiting for head node to finish"
    
#     # Function to check connection to master node
#     check_connection() {
#         timeout 60 bash -c "while ! nc -z $MASTER_ADDR ${MASTER_PORT}; do sleep 5; done"
#         return $?
#     }
    
#     while true; do
#         if ! check_connection; then
#             echo "Connection to master node lost. Exiting worker node."
#             break
#         fi
#         sleep 60  # Check every 60 seconds
#     done
#     ray stop --force
# fi



#- End
slurm-gpu-atop-log-stats $SLURM_JOB_ID $CUDA_VISIBLE_DEVICES
echo "Job end at $(date "+%Y-%m-%d %H:%M:%S")"
# This will overwrite any existing atop logs from previous runs.
# WARNING: If your program times out or is terminated by scancel,
#          the above script part might not execute correctly.
