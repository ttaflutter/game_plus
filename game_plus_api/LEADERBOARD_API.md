# LEADERBOARD API Documentation

## Overview

API cho chức năng bảng xếp hạng (leaderboard) với các tính năng xem danh sách, xem chi tiết người chơi, và tương tác kết bạn.

---

## Endpoints

### 1. GET `/api/leaderboard/` - Lấy bảng xếp hạng

**Description:** Lấy danh sách xếp hạng người chơi theo rating.

**Query Parameters:**

- `game_name` (string, optional): Tên game (mặc định: "Caro")
- `limit` (int, optional): Số lượng người chơi tối đa (1-100, mặc định: 50)
- `offset` (int, optional): Vị trí bắt đầu cho phân trang (mặc định: 0)
- `search` (string, optional): Tìm kiếm theo username

**Headers:**

- `Authorization: Bearer <token>` (optional) - Nếu có token, sẽ hiển thị trạng thái kết bạn

**Response:**

```json
[
  {
    "rank": 1,
    "user_id": 5,
    "username": "devtest",
    "avatar_url": "https://example.com/avatar.jpg",
    "rating": 1450,
    "wins": 25,
    "losses": 10,
    "draws": 2,
    "total_games": 37,
    "win_rate": 67.57,
    "is_online": false,
    "is_friend": false,
    "has_pending_request": false
  },
  {
    "rank": 2,
    "user_id": 4,
    "username": "tta1612",
    "avatar_url": null,
    "rating": 1380,
    "wins": 20,
    "losses": 15,
    "draws": 1,
    "total_games": 36,
    "win_rate": 55.56,
    "is_online": true,
    "is_friend": true,
    "has_pending_request": false
  }
]
```

**Use Cases:**

- Hiển thị bảng xếp hạng chính
- Tìm kiếm người chơi theo username
- Phân trang với limit và offset
- Xem trạng thái kết bạn (nếu đã đăng nhập)

---

### 2. GET `/api/leaderboard/user/{user_id}` - Xem chi tiết người chơi

**Description:** Lấy thông tin chi tiết của một người chơi, bao gồm stats và lịch sử trận đấu.

**Path Parameters:**

- `user_id` (int): ID của người chơi

**Query Parameters:**

- `game_name` (string, optional): Tên game (mặc định: "Caro")

**Headers:**

- `Authorization: Bearer <token>` (optional)

**Response:**

```json
{
  "user_id": 5,
  "username": "devtest",
  "avatar_url": "https://example.com/avatar.jpg",
  "bio": "Professional Caro player",
  "rating": 1450,
  "rank": 1,
  "wins": 25,
  "losses": 10,
  "draws": 2,
  "total_games": 37,
  "win_rate": 67.57,
  "created_at": "2025-10-20T10:30:00Z",
  "is_friend": false,
  "has_pending_request": false,
  "is_online": false,
  "recent_matches": [
    {
      "match_id": 123,
      "opponent_username": "tta1612",
      "result": "win",
      "finished_at": "2025-10-26T05:30:00Z",
      "symbol": "X"
    },
    {
      "match_id": 122,
      "opponent_username": "test",
      "result": "loss",
      "finished_at": "2025-10-25T18:45:00Z",
      "symbol": "O"
    }
  ]
}
```

**Use Cases:**

- Xem profile chi tiết khi click vào người chơi trong leaderboard
- Xem lịch sử các trận đấu gần đây
- Quyết định có gửi lời mời kết bạn hay không

---

### 3. GET `/api/leaderboard/my-stats` - Xem stats của chính mình

**Description:** Lấy thống kê và thông tin chi tiết của người dùng hiện tại.

**Query Parameters:**

- `game_name` (string, optional): Tên game (mặc định: "Caro")

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:** Giống như `/api/leaderboard/user/{user_id}`

**Use Cases:**

- Xem stats của chính mình
- Hiển thị profile screen
- Xem rank hiện tại của mình

---

### 4. GET `/api/leaderboard/top/{top_n}` - Lấy top N người chơi

**Description:** Lấy danh sách top N người chơi hàng đầu.

**Path Parameters:**

- `top_n` (int): Số lượng top players (1-100)

**Query Parameters:**

- `game_name` (string, optional): Tên game (mặc định: "Caro")

**Headers:**

- `Authorization: Bearer <token>` (optional)

**Response:** Giống như `/api/leaderboard/`

**Examples:**

- `GET /api/leaderboard/top/10` - Lấy top 10 người chơi
- `GET /api/leaderboard/top/3` - Lấy top 3 người chơi

**Use Cases:**

- Hiển thị top players trên home screen
- Hiển thị podium (top 3)
- Widget "Top Players" trong game

---

## Integration với Friend System

### Kết bạn từ Leaderboard:

1. **Xem leaderboard** → `GET /api/leaderboard/`

   - Nhận được danh sách với `is_friend` và `has_pending_request`

2. **Click vào người chơi** → `GET /api/leaderboard/user/{user_id}`

   - Xem chi tiết profile

3. **Gửi lời mời kết bạn** → `POST /api/friends/requests`

   ```json
   {
     "receiver_username": "devtest"
   }
   ```

4. **Xem lại leaderboard** → `GET /api/leaderboard/`
   - `has_pending_request` sẽ là `true`

---

## Workflow cho Flutter App

### Screen: Leaderboard

```dart
// 1. Load leaderboard
Future<List<LeaderboardEntry>> loadLeaderboard({
  int limit = 50,
  int offset = 0,
  String? search,
}) async {
  final response = await dio.get(
    '/api/leaderboard/',
    queryParameters: {
      'limit': limit,
      'offset': offset,
      if (search != null) 'search': search,
    },
  );
  return (response.data as List)
      .map((e) => LeaderboardEntry.fromJson(e))
      .toList();
}

// 2. Handle user tap - View profile
Future<UserProfileDetail> viewProfile(int userId) async {
  final response = await dio.get('/api/leaderboard/user/$userId');
  return UserProfileDetail.fromJson(response.data);
}

// 3. Send friend request from profile
Future<void> sendFriendRequest(String username) async {
  await dio.post(
    '/api/friends/requests',
    data: {'receiver_username': username},
  );
}
```

### Screen Features:

**LeaderboardScreen:**

- List view với pull-to-refresh
- Search bar ở top
- Infinite scroll (load more khi scroll xuống cuối)
- Hiển thị rank, avatar, username, rating, win rate
- Badge cho friends (is_friend = true)
- Badge cho pending request (has_pending_request = true)

**UserProfileScreen:**

- Avatar, username, bio
- Stats card (rank, rating, W/L/D, win rate)
- Recent matches list
- Action buttons:
  - "Add Friend" nếu chưa là bạn và chưa gửi request
  - "Pending" nếu đã gửi request
  - "Challenge" nếu đã là bạn
  - "Message" (future feature)

---

## Tips cho Frontend:

1. **Phân trang hiệu quả:**

   ```dart
   // Load 20 items mỗi lần
   int currentOffset = 0;
   final limit = 20;

   void loadMore() {
     currentOffset += limit;
     loadLeaderboard(offset: currentOffset, limit: limit);
   }
   ```

2. **Cache data:**

   - Cache leaderboard data trong 30 giây
   - Refresh khi user pull-to-refresh
   - Invalidate cache khi gửi friend request

3. **Optimistic UI:**

   - Khi gửi friend request, update `has_pending_request = true` ngay lập tức
   - Nếu API fail, revert lại

4. **Search debouncing:**
   - Đợi 300ms sau khi user ngừng typing mới call API
   - Tránh gọi API quá nhiều lần

---

## Error Handling

### Common Errors:

- `404 Not Found` - User hoặc game không tồn tại
- `400 Bad Request` - top_n out of range (không nằm trong 1-100)
- `401 Unauthorized` - Token không hợp lệ (khi gọi `/my-stats`)

### Example Error Response:

```json
{
  "detail": "User not found"
}
```

---

## Testing Examples

### 1. Get leaderboard

```bash
curl -X GET "http://localhost:8000/api/leaderboard/?limit=10"
```

### 2. Search users

```bash
curl -X GET "http://localhost:8000/api/leaderboard/?search=dev"
```

### 3. View profile

```bash
curl -X GET "http://localhost:8000/api/leaderboard/user/5"
```

### 4. Get my stats (with auth)

```bash
curl -X GET "http://localhost:8000/api/leaderboard/my-stats" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 5. Get top 10

```bash
curl -X GET "http://localhost:8000/api/leaderboard/top/10"
```

---

## Future Enhancements

1. **Online Status:** Implement WebSocket để track online/offline status
2. **Real-time Updates:** Cập nhật leaderboard real-time khi có người thắng
3. **Filters:** Filter theo time range (today, week, month, all-time)
4. **More Stats:** Thêm average game duration, longest win streak, etc.
5. **Achievements:** Hiển thị badges/achievements của người chơi
