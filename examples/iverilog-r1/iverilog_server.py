"""
Iverilog Server for Verilog Code Execution

This server provides an HTTP interface for executing Verilog code using iverilog.
It mimics the sandbox fusion API but runs iverilog directly.

Usage:
    python iverilog_server.py --host 0.0.0.0 --port 8000
"""

import asyncio
import os
import subprocess
import tempfile
import shutil
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Iverilog Server")


class RunCodeRequest(BaseModel):
    code: str
    language: str = "verilog"
    compile_timeout: int = 3  # Reduced default timeout
    run_timeout: int = 3  # Strict timeout to prevent infinite loops (防线 1)
    stdin: str = ""
    files: dict = {}
    fetch_files: list = []


class RunCodeResponse(BaseModel):
    status: str  # "Success", "Failed", "SandboxError"
    message: str = ""
    compile_result: Optional[dict] = None
    run_result: Optional[dict] = None
    files: dict = {}


async def run_iverilog(code: str, compile_timeout: int = 3, run_timeout: int = 3) -> tuple[dict, dict]:
    """
    Execute Verilog code using iverilog.
    
    Args:
        code: Verilog code string (should include testbench)
        compile_timeout: Compilation timeout in seconds (default: 3)
        run_timeout: Execution timeout in seconds (default: 3, 防线 1: 严格超时限制)
    
    Returns:
        Tuple of (compile_result, run_result) dictionaries
    """
    # 防线 2: 限制输出大小，防止内存爆炸
    MAX_OUTPUT_BYTES = 100 * 1024  # 限制只读取前 100KB
    
    # Always use /nfs_global/tmp/iverilog_tmp to avoid /tmp space issues
    # VCD files can be very large (16GB+), so we need to use shared filesystem
    iverilog_tmp_base = "/nfs_global/tmp/iverilog_tmp"
    os.makedirs(iverilog_tmp_base, exist_ok=True)
    
    # 防线 3: 使用临时目录，确保清理
    tmp_dir = None
    try:
        tmp_dir = tempfile.mkdtemp(dir=iverilog_tmp_base)
        
        # Write code to temporary file (使用原始代码，不注入看门狗)
        verilog_file = os.path.join(tmp_dir, "design.sv")
        with open(verilog_file, "w") as f:
            f.write(code)
        
        # Compile command: iverilog -Wall -Winfloop -Wno-timescale -g2012 -s testbench -o test.vvp design.sv
        compile_cmd = [
            "iverilog",
            "-Wall",
            "-Winfloop",
            "-Wno-timescale",
            "-g2012",
            "-s", "testbench",
            "-o", os.path.join(tmp_dir, "test.vvp"),
            verilog_file
        ]
        
        # Run compilation
        try:
            compile_process = await asyncio.wait_for(
                asyncio.create_subprocess_exec(
                    *compile_cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd=tmp_dir
                ),
                timeout=compile_timeout
            )
            compile_stdout, compile_stderr = await compile_process.communicate()
            # 防线 2: 限制输出大小
            compile_stdout = compile_stdout.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES]
            compile_stderr = compile_stderr.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES]
            
            compile_result = {
                "status": "Finished" if compile_process.returncode == 0 else "Error",
                "return_code": compile_process.returncode,
                "stdout": compile_stdout,
                "stderr": compile_stderr,
                "execution_time": 0.0,  # Could measure actual time if needed
            }
            
            # If compilation failed, return early
            if compile_process.returncode != 0:
                return compile_result, None
            
        except asyncio.TimeoutError:
            compile_result = {
                "status": "TimeLimitExceeded",
                "return_code": 1,
                "stdout": "",
                "stderr": f"Compilation timeout after {compile_timeout} seconds",
                "execution_time": compile_timeout,
            }
            return compile_result, None
        except Exception as e:
            compile_result = {
                "status": "Error",
                "return_code": 1,
                "stdout": "",
                "stderr": f"Compilation error: {str(e)}",
                "execution_time": 0.0,
            }
            return compile_result, None
        
        # Run command: vvp -n test.vvp
        # 防线 1: 使用严格的超时限制，防止死循环
        run_cmd = ["vvp", "-n", os.path.join(tmp_dir, "test.vvp")]
        
        try:
            # 使用 Popen 而不是 create_subprocess_exec，以便更好地控制进程
            run_process = await asyncio.create_subprocess_exec(
                *run_cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=tmp_dir
            )
            
            try:
                # 防线 1: 严格的超时限制
                # 防线 2: 限制输出大小 - 使用 communicate 但限制读取
                run_stdout, run_stderr = await asyncio.wait_for(
                    run_process.communicate(),
                    timeout=run_timeout
                )
                # 防线 2: 截断输出，防止内存爆炸
                run_stdout = run_stdout.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES]
                run_stderr = run_stderr.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES]
                
                run_result = {
                    "status": "Finished" if run_process.returncode == 0 else "Error",
                    "return_code": run_process.returncode,
                    "stdout": run_stdout,
                    "stderr": run_stderr,
                    "execution_time": 0.0,
                }
                
            except asyncio.TimeoutError:
                # 防线 1: 超时后强制杀死进程
                try:
                    run_process.kill()
                    # 等待进程真正退出
                    await asyncio.wait_for(run_process.wait(), timeout=2)
                except Exception:
                    # 如果 kill 失败，尝试更强制的方式
                    try:
                        run_process.terminate()
                        await asyncio.wait_for(run_process.wait(), timeout=1)
                    except Exception:
                        pass
                
                # 读取已输出的内容（如果有）
                try:
                    remaining_stdout, remaining_stderr = await asyncio.wait_for(
                        run_process.communicate(),
                        timeout=0.5
                    )
                    run_stdout = remaining_stdout.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES] if remaining_stdout else ""
                    run_stderr = remaining_stderr.decode("utf-8", errors="ignore")[:MAX_OUTPUT_BYTES] if remaining_stderr else ""
                except Exception:
                    run_stdout = ""
                    run_stderr = ""
                
                run_result = {
                    "status": "TimeLimitExceeded",
                    "return_code": 1,
                    "stdout": run_stdout,
                    "stderr": f"Execution timeout after {run_timeout} seconds (Infinite loop suspected)" + (f"\nPartial output: {run_stderr[:200]}" if run_stderr else ""),
                    "execution_time": run_timeout,
                }
                
        except Exception as e:
            run_result = {
                "status": "Error",
                "return_code": 1,
                "stdout": "",
                "stderr": f"Execution error: {str(e)}",
                "execution_time": 0.0,
            }
        
        return compile_result, run_result
        
    finally:
        # 防线 3: 必须清理临时目录，无论成功失败
        if tmp_dir and os.path.exists(tmp_dir):
            try:
                shutil.rmtree(tmp_dir, ignore_errors=True)
            except Exception as e:
                # Log error but don't fail the request
                print(f"Warning: Failed to cleanup temp directory {tmp_dir}: {e}")


def parse_run_status(compile_result: dict, run_result: Optional[dict]) -> tuple[str, str]:
    """
    Parse compile and run results to determine overall status.
    
    Returns:
        Tuple of (status, message)
    """
    if compile_result["status"] == "TimeLimitExceeded":
        return "Failed", "Compilation timeout"
    if compile_result["status"] == "Error" or compile_result["return_code"] != 0:
        return "Failed", "Compilation error"
    
    if run_result is None:
        return "Failed", "No run result"
    
    if run_result["status"] == "TimeLimitExceeded":
        return "Failed", "Execution timeout"
    if run_result["status"] == "Error" or run_result["return_code"] != 0:
        return "Failed", "Execution error"
    
    # Success
    return "Success", ""


@app.post("/run_code", response_model=RunCodeResponse)
async def run_code(request: RunCodeRequest):
    """Execute Verilog code using iverilog."""
    if request.language != "verilog":
        raise HTTPException(status_code=400, detail=f"Unsupported language: {request.language}")
    
    try:
        compile_result, run_result = await run_iverilog(
            request.code,
            request.compile_timeout,
            request.run_timeout
        )
        
        status, message = parse_run_status(compile_result, run_result)
        
        response = RunCodeResponse(
            status=status,
            message=message,
            compile_result=compile_result,
            run_result=run_result,
            files={}
        )
        
        return response
    except Exception as e:
        return RunCodeResponse(
            status="SandboxError",
            message=f"Exception: {str(e)}",
            compile_result=None,
            run_result=None,
            files={}
        )


if __name__ == "__main__":
    import argparse
    import uvicorn
    import multiprocessing
    
    # 禁用uvloop防止高并发下的socket管理问题导致SIGABRT  
    try:
        import uvloop
        asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())
        print("⚠ uvloop detected in iverilog server and disabled to prevent SIGABRT crashes")
    except ImportError:
        pass
    
    parser = argparse.ArgumentParser(description="Iverilog Server for Verilog Code Execution")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8000, help="Port to bind to")
    parser.add_argument("--log-level", type=str, default="info", help="Log level")
    parser.add_argument("--workers", type=int, default=0, help="Number of worker processes (0 = auto-detect)")
    args = parser.parse_args()
    
    # 智能决定worker数量
    if args.workers == 0:
        # 自动检测：对于IO+CPU混合负载，使用CPU核心数的一半到全部之间
        cpu_count = multiprocessing.cpu_count()
        # 对于iverilog这种subprocess密集型应用，适中的进程数比较好
        args.workers = max(2, min(cpu_count // 2, 100))  # 2-8个worker之间
        print(f"🚀 Auto-detected {args.workers} workers for {cpu_count} CPU cores")
    
    # 优化uvicorn配置以提高高并发处理能力
    uvicorn.run(
        "iverilog_server:app",  # 使用import字符串而不是app对象，支持多worker
        host=args.host, 
        port=args.port, 
        log_level=args.log_level,
        # 高并发优化配置
        workers=args.workers,  # 使用多进程提高处理能力
        loop="asyncio",  # 强制使用asyncio而不是uvloop
        backlog=2048,  # 增加TCP backlog队列大小
        limit_concurrency=1000,  # 增加并发连接数限制
        limit_max_requests=50000,  # 增加最大请求数
        timeout_keep_alive=60,  # 保持连接时间
        timeout_graceful_shutdown=30,  # 优雅关闭超时
        # 针对subprocess密集型应用的优化
        access_log=False,  # 关闭访问日志减少IO开销
    )

