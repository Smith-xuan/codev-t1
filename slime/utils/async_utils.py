import asyncio
import threading

__all__ = ["get_async_loop", "run"]

# 禁用uvloop防止高并发下的socket管理问题导致SIGABRT
# 必须在创建事件循环之前设置策略
try:
    import uvloop
    asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())
except ImportError:
    pass


# Create a background event loop thread
class AsyncLoopThread:
    def __init__(self):
        # 确保使用默认事件循环策略，不使用uvloop
        # 即使uvloop已安装，也强制使用标准asyncio
        try:
            import uvloop
            # 在创建事件循环之前再次确保策略是默认的
            asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())
        except ImportError:
            pass
        self.loop = asyncio.new_event_loop()
        self._thread = threading.Thread(target=self._start_loop, daemon=True)
        self._thread.start()

    def _start_loop(self):
        asyncio.set_event_loop(self.loop)
        self.loop.run_forever()

    def run(self, coro):
        # Schedule a coroutine onto the loop and block until it's done
        return asyncio.run_coroutine_threadsafe(coro, self.loop).result()


# Create one global instance
async_loop = None


def get_async_loop():
    global async_loop
    if async_loop is None:
        async_loop = AsyncLoopThread()
    return async_loop


def run(coro):
    """Run a coroutine in the background event loop."""
    return get_async_loop().run(coro)
