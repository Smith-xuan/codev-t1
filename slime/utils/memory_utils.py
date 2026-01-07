import gc
import logging
import subprocess

import torch
import torch.distributed as dist

logger = logging.getLogger(__name__)


def clear_memory(clear_host_memory: bool = False):
    """Clear GPU memory cache. Safe to call even if CUDA is not available."""
    if not torch.cuda.is_available():
        return
    try:
        torch.cuda.synchronize()
        gc.collect()
        torch.cuda.empty_cache()
        if clear_host_memory:
            torch._C._host_emptyCache()
    except Exception:
        # Ignore errors if CUDA operations fail
        logger.warning(f"Failed to clear memory: {e}")


def _get_memory_from_nvidia_smi():
    """Fallback: Get GPU memory info from nvidia-smi."""
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=index,memory.total,memory.used,memory.free", "--format=csv,noheader,nounits"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            if lines:
                # Parse first GPU (or all GPUs)
                gpu_info = []
                for line in lines:
                    parts = [p.strip() for p in line.split(',')]
                    if len(parts) >= 4:
                        gpu_info.append({
                            "gpu": parts[0],
                            "total_GB": round(float(parts[1]) / 1024, 2),
                            "used_GB": round(float(parts[2]) / 1024, 2),
                            "free_GB": round(float(parts[3]) / 1024, 2),
                        })
                return gpu_info[0] if len(gpu_info) == 1 else {"all_gpus": gpu_info}
    except Exception:
        pass
    return None


def available_memory():
    """Get GPU memory information. Returns None if CUDA is not available."""
    if not torch.cuda.is_available():
        # Try nvidia-smi as fallback
        nvidia_smi_info = _get_memory_from_nvidia_smi()
        if nvidia_smi_info:
            nvidia_smi_info["note"] = "From nvidia-smi (CUDA not available in this process)"
            return nvidia_smi_info
        return {
            "gpu": "N/A",
            "total_GB": "N/A",
            "free_GB": "N/A",
            "used_GB": "N/A",
            "allocated_GB": "N/A",
            "reserved_GB": "N/A",
            "note": "CUDA not available"
        }
    
    try:
        device = torch.cuda.current_device()
        free, total = torch.cuda.mem_get_info(device)
        return {
            "gpu": str(device),
            "total_GB": _byte_to_gb(total),
            "free_GB": _byte_to_gb(free),
            "used_GB": _byte_to_gb(total - free),
            "allocated_GB": _byte_to_gb(torch.cuda.memory_allocated(device)),
            "reserved_GB": _byte_to_gb(torch.cuda.memory_reserved(device)),
        }
    except Exception as e:
        # Try nvidia-smi as fallback
        nvidia_smi_info = _get_memory_from_nvidia_smi()
        if nvidia_smi_info:
            nvidia_smi_info["note"] = f"From nvidia-smi (PyTorch CUDA error: {str(e)})"
            return nvidia_smi_info
        return {
            "gpu": "ERROR",
            "error": str(e),
            "note": "Failed to get memory info"
        }


def _byte_to_gb(n: int):
    return round(n / (1024**3), 2)


def print_memory(msg, clear_before_print: bool = False):
    """Print GPU memory usage. Handles cases where CUDA is not available."""
    try:
        if clear_before_print and torch.cuda.is_available():
            clear_memory()
    except Exception as e:
        logger.warning(f"Failed to clear memory: {e}")

    try:
        memory_info = available_memory()
    except Exception as e:
        logger.warning(f"Failed to get memory info: {e}")
        memory_info = {"error": str(e), "note": "Failed to get memory info"}
    
    # Try to get rank, but handle case where distributed is not initialized
    try:
        rank = dist.get_rank()
        rank_str = f"[Rank {rank}]"
    except (ValueError, RuntimeError):
        # Distributed not initialized, use process ID or "Main" instead
        import os
        rank_str = f"[Main PID {os.getpid()}]"
    
    # Need to print for all ranks, b/c different rank can have different behaviors
    logger.info(
        f"{rank_str} Memory-Usage {msg}{' (cleared before print)' if clear_before_print else ''}: {memory_info}"
    )
    return memory_info
