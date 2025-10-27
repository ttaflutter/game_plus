import platform
import uvicorn
import multiprocessing

def get_workers():
    cpu_count = multiprocessing.cpu_count()
    return min((2 * cpu_count) + 1, 8)

if __name__ == "__main__":
    system = platform.system().lower()
    loop_type = "uvloop" if system not in ["windows"] else "asyncio"

    workers = get_workers()
    print(f"🚀 Starting GamePlus API with {workers} workers...")
    print(f"💻 CPU cores: {multiprocessing.cpu_count()}")
    print(f"🎯 Target: 50+ concurrent users")
    print(f"🧠 Event Loop: {loop_type}")

    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        workers=workers,
        loop=loop_type,
        http="httptools",
        ws_ping_interval=20.0,
        ws_ping_timeout=20.0,
        limit_concurrency=200,
        limit_max_requests=10000,
        timeout_keep_alive=65,
        log_level="info",
        access_log=True,
    )
