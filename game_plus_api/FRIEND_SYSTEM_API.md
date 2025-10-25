# Friend System API Documentation

## Overview

Hệ thống bạn bè cho phép users:

- Tìm kiếm users khác theo username
- Gửi lời mời kết bạn
- Chấp nhận/từ chối lời mời
- Xem danh sách bạn bè
- Hủy kết bạn

## Setup Database

```bash
# Chạy SQL script để tạo tables
psql -U postgres -d gameplus < create_friend_tables.sql
```

## API Endpoints

### 1. Search Users

**Endpoint:** `GET /api/friends/search?query={username}`

**Description:** Tìm kiếm users theo username để thêm bạn

**Headers:**

```
Authorization: Bearer {token}
```

**Query Parameters:**

- `query` (string, required): Username hoặc một phần của username

**Response:**

```json
[
  {
    "id": 2,
    "username": "player123",
    "avatar_url": "https://...",
    "rating": 1350,
    "is_friend": false,
    "has_pending_request": false
  }
]
```

---

### 2. Send Friend Request

**Endpoint:** `POST /api/friends/requests`

**Description:** Gửi lời mời kết bạn

**Headers:**

```
Authorization: Bearer {token}
```

**Body:**

```json
{
  "receiver_username": "player123"
}
```

**Response:**

```json
{
  "id": 1,
  "sender_id": 1,
  "receiver_id": 2,
  "status": "pending",
  "created_at": "2025-01-25T10:00:00Z",
  "sender_username": "you",
  "sender_avatar_url": "https://...",
  "receiver_username": "player123",
  "receiver_avatar_url": "https://..."
}
```

---

### 3. Get Received Friend Requests

**Endpoint:** `GET /api/friends/requests/received`

**Description:** Lấy danh sách lời mời kết bạn nhận được (pending)

**Headers:**

```
Authorization: Bearer {token}
```

**Response:**

```json
[
  {
    "id": 1,
    "sender_id": 2,
    "receiver_id": 1,
    "status": "pending",
    "created_at": "2025-01-25T10:00:00Z",
    "sender_username": "player123",
    "sender_avatar_url": "https://...",
    "receiver_username": "you",
    "receiver_avatar_url": "https://..."
  }
]
```

---

### 4. Get Sent Friend Requests

**Endpoint:** `GET /api/friends/requests/sent`

**Description:** Lấy danh sách lời mời kết bạn đã gửi (pending)

**Headers:**

```
Authorization: Bearer {token}
```

**Response:** Same as received requests

---

### 5. Respond to Friend Request

**Endpoint:** `PUT /api/friends/requests/{request_id}`

**Description:** Chấp nhận hoặc từ chối lời mời kết bạn

**Headers:**

```
Authorization: Bearer {token}
```

**Body:**

```json
{
  "action": "accept" // or "reject"
}
```

**Response:**

```json
{
  "id": 1,
  "sender_id": 2,
  "receiver_id": 1,
  "status": "accepted",
  "created_at": "2025-01-25T10:00:00Z",
  "sender_username": "player123",
  "sender_avatar_url": "https://...",
  "receiver_username": "you",
  "receiver_avatar_url": "https://..."
}
```

---

### 6. Cancel Friend Request

**Endpoint:** `DELETE /api/friends/requests/{request_id}`

**Description:** Hủy lời mời kết bạn đã gửi (chỉ sender)

**Headers:**

```
Authorization: Bearer {token}
```

**Response:**

```json
{
  "message": "Friend request cancelled"
}
```

---

### 7. Get Friends List

**Endpoint:** `GET /api/friends`

**Description:** Lấy danh sách bạn bè

**Headers:**

```
Authorization: Bearer {token}
```

**Response:**

```json
[
  {
    "id": 1,
    "user_id": 2,
    "username": "player123",
    "avatar_url": "https://...",
    "rating": 1350,
    "is_online": false,
    "created_at": "2025-01-20T10:00:00Z"
  }
]
```

---

### 8. Remove Friend

**Endpoint:** `DELETE /api/friends/{friend_id}`

**Description:** Hủy kết bạn

**Headers:**

```
Authorization: Bearer {token}
```

**Response:**

```json
{
  "message": "Friend removed"
}
```

---

## Error Responses

### 400 Bad Request

```json
{
  "detail": "Already friends"
}
```

### 403 Forbidden

```json
{
  "detail": "Not authorized"
}
```

### 404 Not Found

```json
{
  "detail": "User not found"
}
```

---

## Database Schema

### friend_requests

```sql
id              SERIAL PRIMARY KEY
sender_id       INTEGER REFERENCES users(id)
receiver_id     INTEGER REFERENCES users(id)
status          ENUM('pending', 'accepted', 'rejected')
created_at      TIMESTAMP
updated_at      TIMESTAMP

UNIQUE(sender_id, receiver_id)
CHECK(sender_id != receiver_id)
```

### friends

```sql
id              SERIAL PRIMARY KEY
user1_id        INTEGER REFERENCES users(id)
user2_id        INTEGER REFERENCES users(id)
created_at      TIMESTAMP

UNIQUE(user1_id, user2_id)
CHECK(user1_id < user2_id)  -- Đảm bảo không duplicate
```

---

## Usage Flow

### 1. Tìm và thêm bạn

```
1. User A search: GET /api/friends/search?query=player
2. User A gửi lời mời: POST /api/friends/requests {"receiver_username": "player123"}
3. User B nhận thông báo: GET /api/friends/requests/received
4. User B chấp nhận: PUT /api/friends/requests/1 {"action": "accept"}
5. Cả 2 thấy nhau trong danh sách: GET /api/friends
```

### 2. Hủy kết bạn

```
1. User A: DELETE /api/friends/2
2. Friendship bị xóa
```

### 3. Hủy lời mời đã gửi

```
1. User A: DELETE /api/friends/requests/1
```

---

## Testing với cURL

### Search users

```bash
curl -X GET "http://localhost:8000/api/friends/search?query=player" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Send friend request

```bash
curl -X POST "http://localhost:8000/api/friends/requests" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"receiver_username": "player123"}'
```

### Accept friend request

```bash
curl -X PUT "http://localhost:8000/api/friends/requests/1" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action": "accept"}'
```

### Get friends

```bash
curl -X GET "http://localhost:8000/api/friends" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

## TODO: Thách đấu bạn bè

Sẽ implement sau khi friend system hoạt động:

- Endpoint để gửi challenge (tạo match và mời friend join)
- WebSocket notification cho challenge
- Accept/Decline challenge
