# app/core/cache.py
import redis.asyncio as redis
import json
import os
from typing import Optional, Any
from dotenv import load_dotenv

load_dotenv()

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# Redis client singleton
_redis_client: Optional[redis.Redis] = None


async def get_redis() -> redis.Redis:
    """Lấy Redis client (singleton pattern)."""
    global _redis_client
    if _redis_client is None:
        _redis_client = redis.from_url(
            REDIS_URL,
            encoding="utf-8",
            decode_responses=True,
            max_connections=20,  # Connection pool cho 50 users
        )
    return _redis_client


async def close_redis():
    """Đóng Redis connection khi shutdown."""
    global _redis_client
    if _redis_client:
        await _redis_client.close()
        _redis_client = None


# Cache helpers
async def cache_get(key: str) -> Optional[Any]:
    """Lấy giá trị từ cache."""
    try:
        client = await get_redis()
        data = await client.get(key)
        if data:
            return json.loads(data)
        return None
    except Exception as e:
        print(f"⚠️ Redis GET error: {e}")
        return None


async def cache_set(key: str, value: Any, ttl: int = 5):
    """Lưu giá trị vào cache với TTL (mặc định 5 giây)."""
    try:
        client = await get_redis()
        await client.setex(key, ttl, json.dumps(value))
    except Exception as e:
        print(f"⚠️ Redis SET error: {e}")


async def cache_delete(key: str):
    """Xóa key khỏi cache."""
    try:
        client = await get_redis()
        await client.delete(key)
    except Exception as e:
        print(f"⚠️ Redis DELETE error: {e}")


async def cache_delete_pattern(pattern: str):
    """Xóa tất cả keys matching pattern."""
    try:
        client = await get_redis()
        keys = await client.keys(pattern)
        if keys:
            await client.delete(*keys)
    except Exception as e:
        print(f"⚠️ Redis DELETE PATTERN error: {e}")
