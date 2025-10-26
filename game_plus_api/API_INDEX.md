# GamePlus API - Complete Documentation

## 📚 API Documentation Index

### Core APIs

1. **[Authentication API](./README.md#authentication)** - Đăng nhập, đăng ký, Google OAuth
2. **[Users API](./README.md#users)** - Quản lý thông tin người dùng
3. **[Games API](./README.md#games)** - Danh sách games có sẵn

### Game Features

4. **[Matches API](./README.md#matches)** - Tạo và quản lý trận đấu Caro
5. **[Match History API](./MATCH_HISTORY_API.md)** - Xem lịch sử đấu, replay, chi tiết trận 🆕
6. **[Scores API](./README.md#scores)** - Lưu và xem điểm số

### Social Features

7. **[Friends API](./FRIEND_SYSTEM_API.md)** - Kết bạn, gửi/nhận lời mời
8. **[Leaderboard API](./LEADERBOARD_API.md)** - Bảng xếp hạng, xem profile 🆕
9. **[Challenges API](./FRIEND_SYSTEM_API.md#challenge-system)** - Thách đấu bạn bè

### Real-time

10. **[WebSocket API](./WEBSOCKET_API.md)** - Real-time matchmaking, notifications

---

## 🚀 Quick Start

### Base URL

```
http://localhost:8000
```

### Swagger UI

```
http://localhost:8000/docs
```

### ReDoc

```
http://localhost:8000/redoc
```

---

## 📋 API Summary

### Match History APIs (New! 🆕)

```
GET  /api/match-history/my-matches           # Lịch sử đấu của mình
GET  /api/match-history/user/{user_id}       # Lịch sử đấu của người khác
GET  /api/match-history/match/{match_id}     # Chi tiết trận đấu + replay
GET  /api/match-history/stats/summary        # Tổng hợp thống kê
```

**Features:**

- ✅ Lọc theo kết quả (win/loss/draw)
- ✅ Lọc theo status (finished/playing/abandoned)
- ✅ Xem chi tiết moves và ma trận bàn cờ
- ✅ Tìm đường thắng (winning line)
- ✅ Phân trang với limit & offset

---

### Leaderboard APIs

```
GET  /api/leaderboard/                       # Bảng xếp hạng
GET  /api/leaderboard/user/{user_id}         # Profile người chơi
GET  /api/leaderboard/my-stats               # Stats của mình
GET  /api/leaderboard/top/{top_n}            # Top N players
```

**Features:**

- ✅ Xếp hạng theo rating
- ✅ Tìm kiếm theo username
- ✅ Hiển thị W/L/D và win rate
- ✅ Integration với friend system
- ✅ Lịch sử 10 trận gần nhất

---

### Friends APIs

```
# Friend Requests
POST   /api/friends/requests                 # Gửi lời mời kết bạn
GET    /api/friends/requests/received        # Lời mời nhận được
GET    /api/friends/requests/sent            # Lời mời đã gửi
PUT    /api/friends/requests/{id}            # Accept/Reject
DELETE /api/friends/requests/{id}            # Hủy lời mời

# Friends List
GET    /api/friends                          # Danh sách bạn bè
DELETE /api/friends/{friend_id}              # Hủy kết bạn (by user_id)
DELETE /api/friends/friendship/{id}          # Hủy kết bạn (by friendship_id)

# Search
GET    /api/friends/search                   # Tìm user để kết bạn

# Challenges
POST   /api/friends/challenges               # Gửi thách đấu
GET    /api/friends/challenges/received      # Thách đấu nhận được
GET    /api/friends/challenges/sent          # Thách đấu đã gửi
PUT    /api/friends/challenges/{id}          # Accept/Reject thách đấu
DELETE /api/friends/challenges/{id}          # Hủy thách đấu
```

---

### Matches APIs

```
POST   /api/matches/create                   # Tạo trận mới
GET    /api/matches/{match_id}               # Thông tin trận
POST   /api/matches/{match_id}/join          # Join vào trận
POST   /api/matches/{match_id}/move          # Đánh nước đi
POST   /api/matches/{match_id}/leave         # Rời khỏi trận
GET    /api/matches/waiting                  # Danh sách trận đang chờ
```

---

## 🎯 Common Use Cases

### 1. Xem lịch sử đấu của mình

```bash
curl -X GET "http://localhost:8000/api/match-history/my-matches?limit=10" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 2. Lọc chỉ xem trận thắng

```bash
curl -X GET "http://localhost:8000/api/match-history/my-matches?result=win" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 3. Xem chi tiết trận đấu để replay

```bash
curl -X GET "http://localhost:8000/api/match-history/match/123"
```

### 4. Xem bảng xếp hạng

```bash
curl -X GET "http://localhost:8000/api/leaderboard/?limit=50"
```

### 5. Xem profile người chơi khác

```bash
curl -X GET "http://localhost:8000/api/leaderboard/user/5"
```

### 6. Gửi lời mời kết bạn

```bash
curl -X POST "http://localhost:8000/api/friends/requests" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"receiver_username": "devtest"}'
```

### 7. Thách đấu bạn bè

```bash
curl -X POST "http://localhost:8000/api/friends/challenges" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "opponent_id": 5,
    "message": "Let'\''s play!"
  }'
```

---

## 📱 Flutter Integration Flow

### Complete User Journey

```
1. Login/Register
   ↓
2. Home Screen
   ├─→ Play Now (Matchmaking)
   ├─→ Leaderboard
   ├─→ Friends
   └─→ Profile

3. Leaderboard Screen
   ├─→ View player profile
   ├─→ Send friend request
   └─→ View match history

4. Friends Screen
   ├─→ Send/Accept requests
   ├─→ Challenge friend
   └─→ View friend's profile

5. Match History Screen
   ├─→ Filter wins/losses
   ├─→ View match detail
   └─→ Replay match

6. Match Detail Screen
   ├─→ View moves list
   ├─→ Replay step by step
   └─→ See winning line

7. Challenge Accepted
   ↓
8. Play Match
   ↓
9. Match Finished
   ├─→ View result
   ├─→ Replay
   └─→ Rematch
```

---

## 🔐 Authentication

Tất cả endpoints yêu cầu authentication (trừ login/register và một số GET public) cần header:

```
Authorization: Bearer <access_token>
```

### Get Token

```bash
curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "devtest",
    "password": "password123"
  }'
```

Response:

```json
{
  "access_token": "eyJhbGc...",
  "token_type": "bearer"
}
```

---

## 📊 Response Structures

### Match History Item

```json
{
  "match_id": 123,
  "game_name": "Caro",
  "status": "finished",
  "result": "win",
  "opponent_username": "tta1612",
  "opponent_avatar_url": null,
  "opponent_symbol": "O",
  "my_symbol": "X",
  "board_rows": 15,
  "board_cols": 19,
  "total_moves": 42,
  "duration_seconds": 840
}
```

### Match Detail

```json
{
  "match_id": 123,
  "players": [...],
  "moves": [...],
  "board": [[null, "X", "O"], ...],
  "winning_line": [{"x": 0, "y": 0}, ...]
}
```

### Leaderboard Entry

```json
{
  "rank": 1,
  "user_id": 5,
  "username": "devtest",
  "rating": 1450,
  "wins": 25,
  "losses": 10,
  "draws": 2,
  "win_rate": 67.57,
  "is_friend": false
}
```

---

## ⚠️ Error Handling

### Standard Error Response

```json
{
  "detail": "Error message"
}
```

### Common Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request (invalid parameters)
- `401` - Unauthorized (invalid token)
- `403` - Forbidden (no permission)
- `404` - Not Found
- `500` - Internal Server Error

---

## 🧪 Testing

### Run Server

```bash
cd game_plus_api
uvicorn app.main:app --reload
```

### Access Swagger UI

```
http://localhost:8000/docs
```

### Test với curl

```bash
# Get leaderboard
curl http://localhost:8000/api/leaderboard/

# Get match history (with auth)
curl -H "Authorization: Bearer TOKEN" \
  http://localhost:8000/api/match-history/my-matches
```

---

## 📝 Data Models

### Match Status

- `waiting` - Chờ người chơi
- `playing` - Đang chơi
- `finished` - Đã kết thúc
- `abandoned` - Bị bỏ

### Match Result

- `win` - Thắng
- `loss` - Thua
- `draw` - Hòa

### Friend Request Status

- `pending` - Đang chờ
- `accepted` - Đã chấp nhận
- `rejected` - Đã từ chối

### Challenge Status

- `pending` - Đang chờ
- `accepted` - Đã chấp nhận
- `rejected` - Đã từ chối
- `expired` - Hết hạn

---

## 🎨 UI Suggestions

### Match History Screen

- Tab bar: All / Wins / Losses / Draws
- List với pull-to-refresh
- Card hiển thị opponent, result badge, duration
- Search bar để tìm trận cụ thể

### Match Detail Screen

- Board view (readonly)
- Player cards (cả 2 người)
- Move list với scroll
- Replay controls (play/pause/step forward/back)
- Highlight winning line màu vàng

### Leaderboard Screen

- Podium cho top 3
- List với infinite scroll
- Search bar
- Badge cho friends
- Click vào player → profile screen

---

## 🚀 Performance Tips

1. **Cache data**: Cache leaderboard, match history trong 30-60s
2. **Pagination**: Load 10-20 items mỗi lần
3. **Lazy load**: Chỉ load match detail khi cần
4. **Debounce search**: Đợi 300ms sau khi user ngừng typing
5. **Optimistic UI**: Update UI ngay, revert nếu API fail

---

## 📚 Additional Documentation

- [Friend System API](./FRIEND_SYSTEM_API.md)
- [Match History API](./MATCH_HISTORY_API.md)
- [Leaderboard API](./LEADERBOARD_API.md)
- [WebSocket API](./WEBSOCKET_API.md)
- [Matchmaking Flow](./MATCHMAKING_FLOW.md)

---

## 🆘 Support

Nếu gặp vấn đề, check:

1. Server có đang chạy không?
2. Token có hợp lệ không?
3. Parameters có đúng format không?
4. Check Swagger UI để test trực tiếp

---

## ✅ Feature Checklist

- [x] Authentication (Login, Register, Google OAuth)
- [x] User Management
- [x] Friend System (Add, Accept, Remove)
- [x] Challenge System (Send, Accept challenge)
- [x] Matchmaking & Matches
- [x] Leaderboard & Rankings
- [x] Match History & Replay 🆕
- [x] Stats & Analytics
- [ ] Chat/Messaging (Future)
- [ ] Achievements (Future)
- [ ] Daily Quests (Future)

---

Made with ❤️ for GamePlus
