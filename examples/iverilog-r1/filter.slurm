#!/bin/bash

#- Job parameters

# (TODO)
# Please modify job name

#SBATCH -J filter-rl-data               # The job name
#SBATCH -o ret_one/%j.out        # Write the standard output to file named 'ret-<job_number>.out'
#SBATCH -e ret_one/%j.err        # Write the standard error to file named 'ret-<job_number>.err'


#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --ntasks-per-node=1          # Request P tasks per node
###SBATCH --cpus-per-task=48           # Request Q core per task; means that P*Q cores per node

# SBATCH
#SBATCH -p r8nv-gpu-hw           # Submit to 'r8nv-gpu-hw' Partitiion
#SBATCH -t 3-00:00:00                # Run for a maximum time of 0 days, 12 hours, 00 mins, 00 secs
#SBATCH --nodes=1                    # Request N nodes
#SBATCH --gres=gpu:8                 # Request M GPU per node
#SBATCH --gres-flags=enforce-binding # CPU-GPU Affinity
#SBATCH --qos=gpu-long            # Request QOS Type
###SBATCH --constraint="L40"
###SBATCH --nodelist=r8a100-a02
#SBATCH --nodelist=r8a100-b05


#==========================================================================#
# Please add the SLURM parameter configuration above this horizontal line, #
# and read the README and F.A.Q. at the end of this document.              #
#==========================================================================#

export USER_GPUS_PER_NODE=8          # <--------------------- Modify it in time!

export USER_NGPUS=$(($USER_GPUS_PER_NODE*$SLURM_JOB_NUM_NODES))
nodelist_h_format=$(scontrol show hostnames $SLURM_JOB_NODELIST | \
    awk -v gpu=$USER_GPUS_PER_NODE '{printf ((NR>1?",":"")$0":%s"), gpu}')


#- Check

if [[ -z $SLURM_NTASKS ]]; then
    echo "SLURM_NTASKS is empty, please check your SBATCH parameter."
    exit -1
fi
if [[ -z $SLURM_NTASKS_PER_NODE ]]; then
    echo "SLURM_NTASKS_PER_NODE is empty, please check your SBATCH parameter."
    exit -1
fi
task_size=$(($SLURM_NNODES * $SLURM_NTASKS_PER_NODE))
if [[ $task_size != $SLURM_NTASKS ]]; then
    echo "NTASKS_PER_NODE * NNODE != NNTASK, please check your SBATCH parameter."
    exit -1
fi

if [[ $task_size != $USER_NGPUS ]]; then
    echo "INFO..."
    echo "That's a total of $SLURM_NTASKS tasks, requiring a total of $USER_NGPUS GPUs"
    echo "Becareful whether your program requires \$SLURM_NTASKS or NGPUS"
fi

#- Global Info

master_addr=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
export MASTER_ADDR=$master_addr
export MASTER_PORT=$(expr 50000 + $(echo -n $SLURM_JOBID | tail -c 4))

### (TODO)
### Warning:
### Sometimes WORLD_SIZE is not the number of tasks, it may be the number of GPUs,
### or even other values which need to be decided according to the actual situation
###
### export WORLD_SIZE=${USER_NGPUS}
### or
### export WORLD_SIZE=${task_size}
###
export WORLD_SIZE=${USER_NGPUS}

#- NCCL Setting

###
### IB here refers to RDMA, not the InfiniBand network in the narrow sense,
### it consists of RDMA over IB network, or RDMA over Converged Ethernet
### 
### RDMA's advantages: Zero-Copy and Kernel Bypass, make it faster than TCP stack
### Since the cluster is basically configured with IB NICs, the best performance is obtained when using RDMA
###
### The NCCL_DEBUG variable controls the debug information that is displayed from NCCL
### INFO - Prints debug information
### export NCCL_DEBUG="INFO"
###

export NCCL_IB_DISABLE=0                          # 0: Using RDMA,        1: Using TCP/IP
export NCCL_P2P_DISABLE=0                         # 0: Using P2P,         1: Not P2P, using cpu forwarding (high latency)
export NCCL_IB_CUDA_SUPPORT=1
export NCCL_NET_GDR_LEVEL=2
export NCCL_IB_HCA="mlx5_0,mlx5_1,mlx5_2,mlx5_3"


#- Log information
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX "
echo "Nodelist:=        " $SLURM_JOB_NODELIST
echo "Nodelistname:=    " $nodelist_h_format
echo "Number of nodes:= " $SLURM_JOB_NUM_NODES
echo "Ntasks per node:= " $SLURM_NTASKS_PER_NODE
echo "Ntasks of jobs:=  " $SLURM_NTASKS
echo "NGPUs of jobs:=   " $USER_NGPUS
echo "MASTER_ADDR:=     " $MASTER_ADDR
echo "MASTER_PORT:=     " $MASTER_PORT
echo "WORLD_SIZE:=      " $WORLD_SIZE
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX "

echo "Job start at $(date "+%Y-%m-%d %H:%M:%S")"
echo "The job is triggered on node:"
echo "$(hostnamectl)"

#- Load environments
source /tools/module_env.sh
module list                       # list modules loaded

#- Tools
module load cluster-tools/v1.0
module load slurm-tools/v1.0

echo "$(df -h | grep -v tmpfs)"
cluster-quota                     # nas quota

#- Job step
# 提交方式:
#   sbatch --export=ALL,DATA_TYPE=cid002 filter.slurm
#   sbatch --export=ALL,DATA_TYPE=cid003 filter.slurm
export DATA_TYPE=cid003

export MODEL_PATH=/nfs_global/S/shiwenxuan/LLaMA-Factory/saves/qwen3-8b/full/87k_sft_8.1k_ds32_10epochs
export DATA_TYPE="${DATA_TYPE:?Set DATA_TYPE via --export=ALL,DATA_TYPE=cid002|cid003}"
echo "slurm procid is" $SLURM_PROCID
echo "DATA_TYPE is" $DATA_TYPE
echo "=============== srun begins =================="
srun bash filter.sh

#- End
echo "Job end at $(date "+%Y-%m-%d %H:%M:%S")"
