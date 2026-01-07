"""
Local Iverilog Server Client

This module provides a client interface for calling the local iverilog server.
It mimics the sandbox fusion API interface.

Usage:
    from local_iverilog_server import iverilog_execute
    
    result = await iverilog_execute(
        server_url="http://127.0.0.1:8000/run_code",
        code=verilog_code,
        timeout=5
    )
"""

import aiohttp
import asyncio
import logging

# 禁用uvloop防止高并发下的socket管理问题导致SIGABRT
try:
    import uvloop
    # 如果uvloop已经被导入，我们需要强制使用标准asyncio
    asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())
    print("⚠ uvloop detected and disabled to prevent SIGABRT crashes under high concurrency")
except ImportError:
    # uvloop未安装，使用标准asyncio
    pass

# 全局连接池，复用连接减少创建/销毁开销
_connector = None
_session_cache = {}

def get_connector():
    """获取优化的TCP连接器，用于高并发场景"""
    global _connector
    if _connector is None:
        _connector = aiohttp.TCPConnector(
            limit=200,  # 总连接池大小
            limit_per_host=50,  # 每个主机的连接数
            keepalive_timeout=60,  # 长连接保活时间
            enable_cleanup_closed=True,  # 启用清理关闭的连接
            use_dns_cache=True,  # 启用DNS缓存
            ttl_dns_cache=600,  # DNS缓存10分钟
            force_close=False,  # 不强制关闭，复用连接
        )
    return _connector

async def get_session():
    """获取复用的ClientSession"""
    loop = asyncio.get_event_loop()
    loop_id = id(loop)
    
    if loop_id not in _session_cache:
        timeout = aiohttp.ClientTimeout(
            total=5,  # 保持原始5秒超时
            sock_connect=2,  # Socket连接超时2秒
            sock_read=3  # Socket读取超时3秒
        )
        
        _session_cache[loop_id] = aiohttp.ClientSession(
            connector=get_connector(),
            timeout=timeout,
            # 避免aiohttp的默认行为可能导致的问题
            connector_owner=False,  # 不让session拥有connector
            auto_decompress=False,  # 关闭自动解压缩减少CPU开销
        )
    
    return _session_cache[loop_id]


async def iverilog_execute(
    server_url: str,
    code: str,
    timeout: int = 5,
    compile_timeout: int = 5,
    run_timeout: int = 5,
) -> dict:
    """
    Call local iverilog server and execute Verilog code.
    
    Args:
        server_url: URL of the local iverilog server (e.g., "http://127.0.0.1:8000/run_code")
        code: Verilog code string (should include testbench)
        timeout: Overall request timeout in seconds (default: 5)
        compile_timeout: Compilation timeout in seconds (default: 5)
        run_timeout: Execution timeout in seconds (default: 5)
    
    Returns:
        Dictionary with format matching sandbox fusion API:
        {
            "status": "Success" | "Failed" | "SandboxError",
            "message": "...",
            "compile_result": {...},
            "run_result": {...},
            "files": {}
        }
    """
    payload = {
        "code": code,
        "language": "verilog",
        "compile_timeout": compile_timeout,
        "run_timeout": run_timeout,
        "stdin": "",
        "files": {},
        "fetch_files": [],
    }
    
    try:
        session = await get_session()
        # 使用复用的session，避免频繁创建销毁连接
        async with session.post(server_url, json=payload) as resp:
            resp.raise_for_status()
            result = await resp.json()
            return result
    except aiohttp.ClientConnectorError as e:
        # Connection error - server may be unreachable
        logger = logging.getLogger(__name__)
        logger.error(f"Failed to connect to iverilog server at {server_url}: {e}")
        logger.error(f"  This usually means the server is not accessible from this Ray worker.")
        logger.error(f"  Check that IVERILOG_URL is set correctly and the server is running.")
        return {
            "status": "SandboxError",
            "message": f"Failed to connect to iverilog server at {server_url}: {e}. Check that the server is accessible from Ray workers.",
            "compile_result": None,
            "run_result": None,
            "files": {},
        }
    except (aiohttp.ServerTimeoutError, asyncio.TimeoutError) as e:
        # Timeout error - 正常超时，不记录为错误，只是调试信息
        logger = logging.getLogger(__name__)
        logger.debug(f"Timeout calling iverilog server at {server_url}: {e}")
        return {
            "status": "Failed", 
            "message": f"Timeout calling iverilog server (this is expected for slow/buggy Verilog code): {e}",
            "compile_result": None,
            "run_result": None,
            "files": {},
        }
    except aiohttp.ClientError as e:
        # Other HTTP client errors
        logger = logging.getLogger(__name__)
        logger.error(f"HTTP error calling iverilog server at {server_url}: {e}")
        return {
            "status": "SandboxError",
            "message": f"HTTP error calling iverilog server at {server_url}: {e}",
            "compile_result": None,
            "run_result": None,
            "files": {},
        }
    except Exception as e:
        # Other errors
        logger = logging.getLogger(__name__)
        import traceback
        tb_str = traceback.format_exc()
        logger.error(f"Unexpected error calling iverilog server at {server_url}: {e}")
        logger.error(f"Traceback: {tb_str}")
        return {
            "status": "SandboxError",
            "message": f"Error calling iverilog server at {server_url}: {e}\nTraceback:\n{tb_str}",
            "compile_result": None,
            "run_result": None,
            "files": {},
        }
