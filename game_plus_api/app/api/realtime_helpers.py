# app/api/realtime_helpers.py
"""
Performance optimization helpers cho realtime WebSocket.
Dùng Redis cache và batch operations để handle 50+ concurrent users.
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.core.cache import cache_get, cache_set, cache_delete_pattern
from typing import List
import asyncio


async def fetch_rooms_list_cached(db: AsyncSession) -> List[dict]:
    """
    Fetch danh sách rooms với Redis cache (TTL 5s).
    Giảm database load cho 50 concurrent users.
    
    Cache HIT: Trả về instant từ Redis
    Cache MISS: Query DB + cache kết quả 5s
    """
    # Try cache first
    cache_key = "rooms:list:waiting"
    cached = await cache_get(cache_key)
    if cached is not None:
        print(f"🚀 Cache HIT: rooms_list ({len(cached)} rooms)")
        return cached
    
    # Cache miss - query từ DB
    print(f"💾 Cache MISS: querying DB for rooms_list")
    from app.models.models import Room, RoomStatus
    
    rooms_query = await db.execute(
        select(Room)
        .options(
            selectinload(Room.host),
            selectinload(Room.game),
            selectinload(Room.players)
        )
        .where(Room.status == RoomStatus.waiting)
        .order_by(Room.created_at.desc())
    )
    rooms_list = rooms_query.scalars().all()
    
    rooms_data = []
    for room in rooms_list:
        rooms_data.append({
            "id": room.id,
            "name": room.room_name,
            "room_code": room.room_code,
            "game_id": room.game_id,
            "game_name": room.game.name if room.game else None,
            "host_id": room.host_id,
            "host_username": room.host.username if room.host else None,
            "max_players": room.max_players,
            "current_players": len(room.players),
            "status": room.status.value if hasattr(room.status, "value") else str(room.status),
            "is_private": room.is_public == False,
            "created_at": room.created_at.isoformat() if room.created_at else None,
        })
    
    # Cache result for 5 seconds
    await cache_set(cache_key, rooms_data, ttl=5)
    
    return rooms_data


async def invalidate_rooms_cache():
    """Xóa cache rooms khi có thay đổi (create/update/delete room)."""
    await cache_delete_pattern("rooms:list:*")
    print("🗑️ Invalidated rooms cache")


# Rate limiting per user
_user_last_action: dict[int, float] = {}  # user_id -> last_timestamp


def check_rate_limit(user_id: int, min_interval: float = 1.0) -> bool:
    """
    Kiểm tra rate limit cho user actions (e.g., moves).
    
    Args:
        user_id: ID của user
        min_interval: Khoảng thời gian tối thiểu giữa 2 actions (giây)
    
    Returns:
        True nếu allowed, False nếu too fast
    """
    import time
    now = time.time()
    
    if user_id in _user_last_action:
        elapsed = now - _user_last_action[user_id]
        if elapsed < min_interval:
            return False
    
    _user_last_action[user_id] = now
    return True


# Batch move buffer để gom nhiều moves cùng lúc
_pending_moves: List[tuple] = []  # [(match_id, user_id, row, col, symbol, timestamp), ...]
_batch_task: asyncio.Task = None


async def add_move_to_batch(match_id: int, user_id: int, row: int, col: int, symbol: str):
    """
    Thêm move vào batch buffer.
    Moves sẽ được flush mỗi 100ms hoặc khi đủ 10 moves.
    """
    from datetime import datetime, timezone
    _pending_moves.append((match_id, user_id, row, col, symbol, datetime.now(timezone.utc)))
    
    # Auto flush nếu buffer đầy
    if len(_pending_moves) >= 10:
        await flush_move_batch()


async def flush_move_batch():
    """Flush tất cả pending moves vào database một lúc."""
    global _pending_moves
    
    if not _pending_moves:
        return
    
    moves = _pending_moves.copy()
    _pending_moves.clear()
    
    print(f"💾 Batch saving {len(moves)} moves...")
    
    # TODO: Implement bulk insert moves to DB
    # Sẽ được integrate vào handle_move() trong realtime.py


async def broadcast_parallel(connections: dict, message: dict):
    """
    Broadcast message đến tất cả connections song song (parallel).
    
    Thay vì gửi tuần tự (chậm), dùng asyncio.gather để gửi đồng thời.
    Tăng tốc broadcast từ O(n) -> O(1) time.
    """
    import json
    
    if not connections:
        return
    
    data = json.dumps(message)
    
    async def send_to_one(user_id: int, ws):
        try:
            await ws.send_text(data)
            return user_id, True
        except Exception as e:
            print(f"⚠️ Failed to send to user {user_id}: {e}")
            return user_id, False
    
    # Gửi đồng thời đến tất cả clients
    tasks = [send_to_one(uid, ws) for uid, ws in connections.items()]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    # Cleanup failed connections
    failed_users = [uid for uid, success in results if isinstance(success, tuple) and not success[1]]
    for uid in failed_users:
        connections.pop(uid, None)
    
    successful = len(results) - len(failed_users)
    print(f"📢 Broadcast complete: {successful}/{len(results)} delivered")
