#!/bin/bash

#- Job parameters

#SBATCH -J slime-qwen3-8b-multinodes              # The job name
#SBATCH -o ret_one/%j.out        # Write the standard output to file named 'ret-<job_number>.out'
#SBATCH -e ret_one/%j.err        # Write the standard error to file named 'ret-<job_number>.err'

#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --ntasks-per-node=1          # Request 1 task per node

# SBATCH
#SBATCH -p r8nv-gpu-hw-80g              # Submit to 'r8nv-gpu-hw' Partition
#SBATCH -t 1-6:00:00                # Run for a maximum time of 1 day, 6 hours
#SBATCH --nodes=2                    # Request 2 nodes
#SBATCH --gres=gpu:8                 # Request 8 GPUs per node
#SBATCH --gres-flags=enforce-binding # CPU-GPU Affinity
#SBATCH --qos=gpu-normal            # Request QOS Type
#SBATCH --nodelist=r8a100-d[00,05]  # Optional: specify nodes, comment out for auto allocation

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

export WORLD_SIZE=${USER_NGPUS}

#- NCCL Setting

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
# Run the training script on all nodes
echo "slurm procid is" $SLURM_PROCID
echo "=============== srun begins =================="
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
TARGET_SCRIPT="/workspace/S/shiwenxuan/slime/examples/iverilog-r1/run_qwen3_8b_cvdp_testbench.sh"
export TRAIN_STAGE="stage1"

# Export SLURM environment variables for the training script
export SLURM_GPUS_ON_NODE=${USER_GPUS_PER_NODE}

# 1. Get Node List and Head Info
nodes=$(scontrol show hostnames "$SLURM_JOB_NODELIST")
nodes_array=($nodes)
head_node=${nodes_array[0]}

echo "Node List: $nodes"
echo "Head Node: $head_node"

# 2. Get Head Node IP Explicitly (crucial for connection)
# We run this command ON the head node to get its actual InfiniBand/Ethernet IP
HEAD_IP=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname -I | awk '{print $1}')
export MASTER_ADDR=$HEAD_IP
echo "MASTER_ADDR set to IP: $MASTER_ADDR"

# 3. Start Head Node
echo ">>> Starting Head Node on $head_node (Rank 0)..."
export NODE_RANK=0
srun --nodes=1 --ntasks=1 -w "$head_node" bash "$TARGET_SCRIPT" &
HEAD_PID=$!

# 4. Wait for Ray to be Ready
echo ">>> Waiting for Ray Head to start on $head_node:$MASTER_PORT..."

# Define the ready flag path (must match the logic in the run script)
JOB_ID_SHORT=$(echo "${SLURM_JOB_ID}" | cut -c1-6)
READY_FILE="/workspace/S/shiwenxuan/tmp/job_${JOB_ID_SHORT}/ray_head_ready"

echo "Watching for flag file: $READY_FILE"

# Check for flag file
for i in {1..120}; do # Wait up to 10 minutes
    if [ -f "$READY_FILE" ]; then
        echo "✓ Ray Head is UP (Flag file found)!"
        break
    fi
    
    if ! kill -0 $HEAD_PID 2>/dev/null; then
        echo "ERROR: Head node process died!"
        exit 1
    fi
    
    # Echo to stderr to avoid buffering issues
    >&2 echo "Waiting for Ray Head... ($i/120)"
    sleep 5
done

# 5. Start Worker Nodes
echo ">>> Ray Head is ready. Starting Worker Nodes..."
for ((i=1; i<SLURM_JOB_NUM_NODES; i++)); do
    worker_node=${nodes_array[$i]}
    export NODE_RANK=$i
    echo "Starting Worker $i on $worker_node..."
    srun --nodes=1 --ntasks=1 -w "$worker_node" bash "$TARGET_SCRIPT" &
done

# 6. Wait for job completion
wait

#- End
echo "Job end at $(date "+%Y-%m-%d %H:%M:%S")"
