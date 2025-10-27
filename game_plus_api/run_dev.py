# run_dev.py
"""
Development runner với hot-reload.
Dùng trong development, không dùng trong production.
"""
if __name__ == "__main__":
    import uvicorn
    
    print("🔧 Starting GamePlus API in DEVELOPMENT mode...")
    print("♻️  Hot-reload enabled")
    
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,  # Hot-reload cho development
        log_level="debug",  # Verbose logging
        # WebSocket settings
        ws_ping_interval=20.0,
        ws_ping_timeout=20.0,
    )
