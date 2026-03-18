from eda_tools.utils import eda_tools
import json
import re
import os
from multiprocessing import Process, Queue
import psutil
import hashlib
import random
import traceback
# import platform

# # 根据不同系统导入不同的文件锁模块
# if platform.system() == 'Windows':
#     import msvcrt
# else:
#     import fcntl

# # 假设的锁文件路径
# LOCK_FILE_PATH = '.lock'


# def create_lock_file():
#     if not os.path.exists(LOCK_FILE_PATH):
#         with open(LOCK_FILE_PATH, 'w') as f:
#             pass


# def acquire_lock():
#     if platform.system() == 'Windows':
#         f = open(LOCK_FILE_PATH, 'r+')
#         msvcrt.locking(f.fileno(), msvcrt.LK_LOCK, 1)
#         return f
#     else:
#         f = open(LOCK_FILE_PATH, 'r+')
#         fcntl.flock(f.fileno(), fcntl.LOCK_EX)
#         return f


# def release_lock(f):
#     if platform.system() == 'Windows':
#         msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)
#     else:
#         fcntl.flock(f.fileno(), fcntl.LOCK_UN)
#     f.close()



def verify_one_sample(gold_code, dut_code, uid=None):
    uid = dut_code + str(random.randint(0,2147483647))
    uid = hashlib.md5(uid.encode("utf-8")).hexdigest()
    v = eda_tools(quiet=True)
    # v = eda_tools(quiet=False)

    if not gold_code or not dut_code:
        return {"correct": False}

    try:
        gold_top = v.auto_top(gold_code)
        gate_top = v.auto_top(dut_code)
    except Exception as e:
        # exception in verification, gold code or dut code have syntax problems
        # print("Parse error:", e.args)
        return {"correct": False, "parse_error": e.args}

    gold_path, dut_path = f"./tmp/testcase/{uid}_gold.v", f"./tmp/testcase/{uid}_dut.v"
    test_path = f"./tmp/work/{uid}"
    
    try:
        if not os.path.exists("./tmp/testcase"):
            os.makedirs("./tmp/testcase", exist_ok=True)
        if not os.path.exists("./tmp/work"):
            os.makedirs("./tmp/work", exist_ok=True)
        if not os.path.exists(test_path):
            os.makedirs(test_path, exist_ok=True)
    finally:
        # release_lock(f)
        pass
    
    with open(gold_path, "w") as f:
        f.write(gold_code)
    with open(dut_path, "w") as f:
        f.write(dut_code)

    # 如果想生成testbench代码并运行，参考以下内容
    result = None
    try:
        equiv = v.equiv_with_testbench(
            gold_path,
            dut_path,
            gold_top,
            gate_top,
            test_path,
        )
    except Exception as e:
        # print("Test error:", e.args)
        result = {"correct": False, "test_error": e.args}
    finally:
        if os.path.exists(gold_path):
            os.remove(gold_path)
        if os.path.exists(dut_path):
            os.remove(dut_path)
        if os.path.exists(test_path):
            os.system(f"rm -r {test_path}")

    if result is None:
        result = {"correct": equiv[0], "error_rate": equiv[1], "detail": equiv[2]}
    return result


def ppa_one_sample(code, uid=None):
    uid = code + str(random.randint(0,2147483647))
    uid = hashlib.md5(uid.encode("utf-8")).hexdigest()
    eda = eda_tools(quiet=True)
    # v = eda_tools(quiet=False)

    try:
        top = eda.auto_top(code)
    except Exception as e:
        # exception in verification, gold code or dut code have syntax problems
        # print("Parse error:", e.args)
        return {"correct": False, "parse_error": e.args}

    file_path = os.path.abspath(f"./tmp/testcase/{uid}_syn.v")
    build_dir = os.path.abspath(f"./tmp/work/{uid}")
    
    try:
        if not os.path.exists("./tmp/testcase"):
            os.makedirs("./tmp/testcase", exist_ok=True)
        if not os.path.exists("./tmp/work"):
            os.makedirs("./tmp/work", exist_ok=True)
        if not os.path.exists(build_dir):
            os.makedirs(build_dir, exist_ok=True)
    finally:
        # release_lock(f)
        pass

    with open(file_path, "w") as f:
        f.write(code)

    try:
        # Properly call the method from utils (eda is instantiated now)
        input_ports, output_ports, clock_port_polarity, reset_ports = eda.extract_golden_ports(
            golden_path=file_path,  # Path to temporary file (required)
            golden_top=top               # Top module name (required)
        )

        # 4. Safely handle clock ports (avoid empty set/multiple clocks exceptions)
        if clock_port_polarity:
            # Take first clock (handle multi-clock scenario, utils doesn't support multiple clocks)
            first_clock = next(iter(clock_port_polarity))
            clk_name = first_clock[0]  # Extract clock name (e.g., "clk")
            clk_edge = "posedge" if first_clock[1] == 1 else "negedge"
            print(f"[INFO] Extracted clock for id={uid}: {clk_name} ({clk_edge})")
            
            # Warn about multiple clocks
            if len(clock_port_polarity) > 1:
                print(f"[WARNING] Multiple clocks found for id={uid} (only use {clk_name})")
        else:
            print(f"[WARNING] No clock port found for id={uid}, use default 'clk'")
            clk_name = "clk"

    except Exception as e:
        # Catch all exceptions (e.g., Yosys not installed, Verilog syntax errors, etc.)
        print(f"[ERROR] Failed to extract ports for id={uid}: {str(e)}")
        clk_name = "clk"  # Keep default on exception
    

    # 如果想生成testbench代码并运行，参考以下内容
    result = None
    base_dir = os.path.dirname(os.path.abspath(os.path.dirname(__file__)))
    try:
        result = eda.yosys_opensta_ppa(
            job_name=f"syn_{uid}",
            rtl_paths=[file_path],
            top=top,
            clk=clk_name,
            tech="freepdk45",
            timeout=60,
            build_dir=build_dir,
            yosys_script=f'{base_dir}/scripts/yosys.ys'
        )
    except Exception as e:
        traceback.print_exc()
        result = {
            "area": "N/A",
            "power": "N/A",
            "time": "N/A",
            "premap_cells": "N/A",
            "premap_wires": "N/A",
            "postmap_cells": "N/A",
            "postmap_wires": "N/A",
            "error": str(e)
        }
    finally:
        if os.path.exists(file_path):
            os.remove(file_path)
        if os.path.exists(build_dir):
            os.system(f"rm -r {build_dir}")

    return result


def kill_process_tree(pid):
    parent = psutil.Process(pid)
    children = parent.children(recursive=True)  # 获取所有子进程
    for child in children:
        child.terminate()  # 终止子进程
    parent.terminate()  # 终止父进程


def run_function_with_timeout(func, *args, timeout=30, **kwargs):
    # print(timeout)
    def target(queue):
        result = func(*args, **kwargs)
        queue.put(result)

    queue = Queue()
    process = Process(target=target, args=(queue,))
    process.start()
    process.join(timeout=timeout)  # 使用传入的timeout参数

    if process.is_alive():
        kill_process_tree(process.pid)
        process.join()
        print(f"Function timed out after {timeout} seconds!")
        return {"correct": False, "timeout": True}
    else:
        return queue.get()


def extract_verilog(verilog_code):
    """
    从 Verilog 代码中提取 module 声明部分（module_head）。
    """
    pattern = re.compile(r"```verilog\s*([\s\S]*?)\s*```")
    matches = re.findall(pattern, verilog_code)
    if matches:
        return matches[-1]  # 返回匹配的 module 声明
    return None


if __name__ == "__main__":
    # file = "/nfs_global/S/zhuyaoyu/projects/CodeV-o1/data/source/codev_dataset_165k_wo_module_head.jsonl"
    file = "/nfs_global/datasets/codev/codev_dataset_165k_v3.jsonl"
    import json
    with open(file, "r") as f:
        data = list(map(json.loads, f.read().strip().splitlines()))
    
    sep = "============================================"
    
    # 正确
    example_ans = data[2]["response"]
    example_output = f"<think></think>  <answer>\n```verilog\n{example_ans}```\n</answer>"
    # reward = compute_score(example_output, example_ans)
    ppa = ppa_one_sample(example_ans)
    print(f"{sep}\n{example_output}\n{sep}\n{ppa}")