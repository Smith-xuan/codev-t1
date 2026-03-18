#!/bin/bash
#SBATCH --job-name=ray_diag
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:1
#SBATCH --output=ray_diag_%j.out
#SBATCH --error=ray_diag_%j.err

# === 1. 环境加载 ===
source ~/.bashrc
if [ -f "/workspace/S/shiwenxuan/bin/micromamba" ]; then
    export MAMBA_EXE='/workspace/S/shiwenxuan/bin/micromamba'
    export MAMBA_ROOT_PREFIX='/nfs_global/S/shiwenxuan/micromamba'
    eval "$($MAMBA_EXE shell hook --shell bash --root-prefix $MAMBA_ROOT_PREFIX 2>/dev/null)"
    
    # 优先激活 workspace 环境
    if [ -d "/workspace/S/shiwenxuan/envs/slime" ]; then
        micromamba activate /workspace/S/shiwenxuan/envs/slime
        echo "✅ Activated environment: /workspace/S/shiwenxuan/envs/slime"
    else
        micromamba activate slime
        echo "⚠️ Activated environment: slime (fallback)"
    fi
fi

echo "=================================================="
echo "Diagnostics for Ray Cluster on Slurm"
echo "Date: $(date)"
echo "Node: $(hostname)"
echo "User: $(whoami)"
echo "=================================================="

# === 2. 网络接口检测 ===
echo "[Network Check]"
echo "Host IPs:"
hostname -I
echo "InfiniBand IPs (if any):"
ibdev2netdev 2>/dev/null || echo "No IB devices found"

# 获取主节点 IP（尝试 10.200 网段优先）
HEAD_IP=$(hostname -I | grep -o '10\.200\.[0-9]*\.[0-9]*' | head -1)
if [ -z "$HEAD_IP" ]; then
    HEAD_IP=$(hostname -I | awk '{print $1}')
fi
echo "Selected HEAD_IP: $HEAD_IP"

# === 3. 端口占用检测 ===
echo "[Port Check]"
for PORT in 6379 8265 8266 10001; do
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
        echo "⚠️ Port $PORT is already in use!"
        lsof -Pi :$PORT -sTCP:LISTEN
    else
        echo "✅ Port $PORT is free"
    fi
done

# === 4. 文件系统测试 ===
echo "[Filesystem Check]"
check_dir() {
    DIR=$1
    if [ -w "$DIR" ]; then
        echo "✅ Writable: $DIR"
        # Test Exec
        TEST_BIN="$DIR/test_exec_$$"
        cp /bin/ls "$TEST_BIN"
        chmod +x "$TEST_BIN"
        "$TEST_BIN" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "  ✅ Executable"
        else
            echo "  ❌ NOEXEC (Cannot execute binaries)"
        fi
        rm -f "$TEST_BIN"
    else
        echo "❌ Not Writable: $DIR"
    fi
}
check_dir "/tmp"
check_dir "/dev/shm"
check_dir "/workspace/S/shiwenxuan"

# === 5. Ray 最小化启动测试 ===
echo "[Ray Minimal Cluster Test]"

# 获取节点列表
NODES=$(scontrol show hostnames $SLURM_JOB_NODELIST)
NODES_ARRAY=($NODES)
HEAD_NODE=${NODES_ARRAY[0]}
WORKER_NODE=${NODES_ARRAY[1]}

echo "Head Node: $HEAD_NODE"
echo "Worker Node: $WORKER_NODE (if exists)"

if [ "$(hostname)" == "$HEAD_NODE" ]; then
    # === HEAD NODE ===
    echo "Starting Ray Head..."
    # 显式指定 dashboard host 为 0.0.0.0
    ray start --head --node-ip-address=$HEAD_IP --port=6379 --dashboard-port=8266 --dashboard-host=0.0.0.0 --disable-usage-stats --temp-dir=/tmp/ray_diag_$$ --block & 
    RAY_PID=$!
    
    echo "Waiting for Ray Head to start..."
    sleep 10
    
    echo "Checking Ray Status:"
    ray status
    
    echo "Checking Dashboard Connectivity (Local):"
    curl -v http://127.0.0.1:8266/api/version || echo "❌ Failed to connect to Dashboard via 127.0.0.1"
    
    echo "Checking Dashboard Connectivity (Public IP):"
    curl -v http://$HEAD_IP:8266/api/version || echo "❌ Failed to connect to Dashboard via $HEAD_IP"
    
    # 保持主节点运行，等待 Worker 连接
    sleep 30
    
    echo "Checking Ray Status after Worker join:"
    ray status
    
    # 尝试提交一个简单的 Python Job
    echo "Submitting simple Python Job..."
    cat <<EOF > test_ray.py
import ray
import time
import socket

ray.init()

@ray.remote
def ping():
    return f"Pong from {socket.gethostname()}"

# Wait for 2 nodes
print("Waiting for nodes...")
timeout = 30
start = time.time()
while time.time() - start < timeout:
    if len(ray.nodes()) >= 2:
        break
    time.sleep(1)

print(f"Nodes found: {len(ray.nodes())}")
refs = [ping.remote() for _ in range(4)]
print(ray.get(refs))
EOF
    
    # 使用 ray job submit 提交
    echo "Running 'ray job submit'..."
    export RAY_ADDRESS="http://127.0.0.1:8266"
    ray job submit --working-dir . -- python test_ray.py
    
    echo "Stopping Ray..."
    kill $RAY_PID
    ray stop --force
    
else
    # === WORKER NODE ===
    # 等待 Head 启动
    sleep 5
    
    # 获取本机 IP
    MY_IP=$(hostname -I | grep -o '10\.200\.[0-9]*\.[0-9]*' | head -1)
    if [ -z "$MY_IP" ]; then MY_IP=$(hostname -I | awk '{print $1}'); fi
    
    echo "Starting Ray Worker on $MY_IP connecting to $HEAD_IP:6379..."
    ray start --address=$HEAD_IP:6379 --node-ip-address=$MY_IP --disable-usage-stats --temp-dir=/tmp/ray_diag_$$ --block &
    WORKER_PID=$!
    
    sleep 40
    
    echo "Stopping Worker..."
    kill $WORKER_PID
    ray stop --force
fi

echo "Diagnostics Complete."
