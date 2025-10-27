# Backend Fix: Add room_code to WebSocket Response

## Vấn đề

WebSocket `/rooms` endpoint **không gửi field `room_code`**, khiến Flutter app không thể join room từ card click.

## Backend hiện tại (SAI)

```python
# app/api/realtime.py - Line ~62
rooms_data.append({
    "id": room.id,
    "name": room.room_name,  # ← Fixed: room_name not name
    "game_id": room.game_id,
    "game_name": room.game.name if room.game else None,
    "host_id": room.host_id,
    "host_username": room.host.username if room.host else None,
    "max_players": room.max_players,
    "current_players": len(room.players),
    "status": room.status.value if hasattr(room.status, "value") else str(room.status),
    "is_private": room.is_public == False,  # ← Fixed: is_public inverted
    "created_at": room.created_at.isoformat() if room.created_at else None,
    # ❌ THIẾU: "room_code": room.room_code
})
```

## Fix Backend (ĐÚNG)

Thêm field `"room_code"` vào **3 vị trí** trong file `app/api/realtime.py`:

### 1. Initial rooms_list (Line ~62)

```python
rooms_data.append({
    "id": room.id,
    "name": room.room_name,
    "room_code": room.room_code,  # ← THÊM DÒNG NÀY
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
```

### 2. Refresh rooms_list (Line ~105)

```python
rooms_data.append({
    "id": room.id,
    "name": room.room_name,
    "room_code": room.room_code,  # ← THÊM DÒNG NÀY
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
```

### 3. notify_room_change (app/api/rooms.py - Line ~27)

```python
room_data = {
    "id": room.id,
    "name": room.room_name,
    "room_code": room.room_code,  # ← THÊM DÒNG NÀY
    "game_id": room.game_id,
    "game_name": room.game.name if room.game else None,
    "host_id": room.host_id,
    "host_username": room.host.username if room.host else None,
    "max_players": room.max_players,
    "current_players": len(room.players),
    "status": room.status.value if hasattr(room.status, "value") else str(room.status),
    "is_private": room.is_public == False,
    "created_at": room.created_at.isoformat() if room.created_at else None,
}
```

## Kết quả sau khi fix

WebSocket response sẽ có đủ thông tin:

```json
{
  "type": "rooms_list",
  "payload": {
    "rooms": [
      {
        "id": 13,
        "name": "tta",
        "room_code": "ASFA2N", // ← Field này cần có
        "host_username": "tta1612",
        "max_players": 2,
        "current_players": 1,
        "status": "waiting",
        "is_private": false
      }
    ]
  }
}
```

## Flutter app sẽ hoạt động

- ✅ Click card → Lấy `room_code` từ WebSocket data
- ✅ Join bằng `POST /api/rooms/join` với `room_code`
- ✅ Không cần fetch detail thêm (giảm 1 API call)

## Test sau khi fix

1. Restart backend server
2. Connect WebSocket từ Flutter app
3. Click vào room card
4. Xem console log - không có error "Room not found with this code"
5. Navigate sang RoomWaitingScreen thành công

## Performance improvement

- **Trước fix:** 2 API calls (getRoomDetail + joinRoom)
- **Sau fix:** 1 API call (joinRoom only)
- **Giảm 50% network requests** khi join room

---

**Priority:** 🔴 HIGH - App không thể join room từ lobby screen
**Estimated fix time:** 2 phút (thêm 3 dòng code)
