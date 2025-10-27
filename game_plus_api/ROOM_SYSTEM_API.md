# ROOM SYSTEM API Documentation

## Overview

Hệ thống phòng chơi với tính năng:

- **Tạo phòng** với room code 6 ký tự
- **Join phòng** bằng room code
- **Host controls**: kick players, start game
- **Ready system**: Players phải ready trước khi start
- **Password protection**: Phòng có thể có mật khẩu

---

## Database Schema

### Tables

**rooms**

```sql
- id (serial primary key)
- room_code (varchar(6) unique) - Mã phòng 6 ký tự
- room_name (varchar(100)) - Tên phòng
- host_id (integer FK users) - Người tạo phòng
- game_id (integer FK games) - Game (Caro)
- password (varchar(255)) - Hash password (optional)
- is_public (boolean) - Công khai hay riêng tư
- max_players (integer 2-4) - Số người tối đa
- board_rows, board_cols, win_len - Cấu hình bàn cờ
- status (enum: waiting|playing|finished)
- match_id (integer FK matches) - Match khi game bắt đầu
- created_at, started_at, finished_at
```

**room_players**

```sql
- room_id (integer FK rooms) - PK
- user_id (integer FK users) - PK
- is_ready (boolean) - Trạng thái sẵn sàng
- joined_at (timestamp)
```

---

## API Endpoints

### 1. POST `/api/rooms/create` - Tạo phòng mới

**Description:** Tạo phòng chơi mới, host tự động join.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Request Body:**

```json
{
  "room_name": "Pro Players Only",
  "password": "secret123",
  "max_players": 2,
  "board_rows": 15,
  "board_cols": 19,
  "win_len": 5,
  "is_public": true
}
```

**Fields:**

- `room_name` (string, required): 1-100 ký tự
- `password` (string, optional): Mật khẩu phòng (max 50 ký tự)
- `max_players` (int, default=2): 2-4 người
- `board_rows` (int, default=15): 10-20
- `board_cols` (int, default=19): 10-25
- `win_len` (int, default=5): 3-7
- `is_public` (bool, default=true): Hiện trong danh sách công khai

**Response:**

```json
{
  "id": 123,
  "room_code": "A3X9K2",
  "room_name": "Pro Players Only",
  "host_id": 5,
  "status": "waiting",
  "is_public": true,
  "has_password": true,
  "max_players": 2,
  "current_players": 1,
  "board_rows": 15,
  "board_cols": 19,
  "win_len": 5,
  "created_at": "2025-10-26T10:00:00Z",
  "players": [
    {
      "user_id": 5,
      "username": "proPlayer",
      "avatar_url": "https://...",
      "rating": 1450,
      "is_ready": true,
      "is_host": true,
      "joined_at": "2025-10-26T10:00:00Z"
    }
  ],
  "match_id": null
}
```

**Use Cases:**

- Tạo phòng riêng chơi với bạn bè
- Tạo phòng công khai cho random players
- Custom board size và win condition

---

### 2. GET `/api/rooms/list` - Danh sách phòng

**Description:** Lấy danh sách phòng công khai.

**Query Parameters:**

- `status` (string, optional): Filter theo status (waiting, playing, finished)
- `only_public` (bool, default=true): Chỉ lấy phòng công khai
- `skip` (int, default=0): Pagination offset
- `limit` (int, default=20): Số phòng tối đa

**Request:**

```
GET /api/rooms/list?status=waiting&skip=0&limit=10
```

**Response:**

```json
[
  {
    "id": 123,
    "room_code": "A3X9K2",
    "room_name": "Pro Players Only",
    "host_username": "proPlayer",
    "status": "waiting",
    "is_public": true,
    "has_password": true,
    "current_players": 1,
    "max_players": 2,
    "created_at": "2025-10-26T10:00:00Z"
  },
  {
    "id": 124,
    "room_code": "B7Y4M1",
    "room_name": "Casual Game",
    "host_username": "casualGamer",
    "status": "waiting",
    "is_public": true,
    "has_password": false,
    "current_players": 2,
    "max_players": 2,
    "created_at": "2025-10-26T10:05:00Z"
  }
]
```

**Use Cases:**

- Hiển thị lobby với danh sách phòng
- Filter phòng đang chờ
- Refresh danh sách định kỳ

---

### 3. POST `/api/rooms/join` - Tham gia phòng

**Description:** Join phòng bằng room code.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Request Body:**

```json
{
  "room_code": "A3X9K2",
  "password": "secret123"
}
```

**Response:** Giống như `/api/rooms/{room_id}` (RoomDetail)

**Errors:**

- `404` - Room not found với code này
- `401` - Password required / Incorrect password
- `400` - Room is full / Room not accepting players / Already joined

**Use Cases:**

- Join phòng bạn bè bằng code
- Join từ danh sách phòng công khai

---

### 4. GET `/api/rooms/{room_id}` - Chi tiết phòng

**Description:** Xem thông tin chi tiết phòng và danh sách players.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:** RoomDetail (như response của create/join)

---

### 5. POST `/api/rooms/{room_id}/ready` - Toggle ready status

**Description:** Đánh dấu sẵn sàng / bỏ sẵn sàng.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Request Body:**

```json
{
  "is_ready": true
}
```

**Response:**

```json
{
  "message": "Ready status updated",
  "is_ready": true
}
```

**Notes:**

- Host luôn ready mặc định
- Chỉ toggle được khi room đang waiting

---

### 6. POST `/api/rooms/{room_id}/kick` - Kick player (Host only)

**Description:** Host kick người chơi khỏi phòng.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Request Body:**

```json
{
  "user_id": 10
}
```

**Response:**

```json
{
  "message": "Player kicked successfully",
  "kicked_user_id": 10
}
```

**Errors:**

- `403` - Only host can perform this action
- `400` - Cannot kick yourself / Can only kick in waiting room
- `404` - Player not found in room

---

### 7. POST `/api/rooms/{room_id}/start` - Bắt đầu game (Host only)

**Description:** Bắt đầu game khi tất cả players đã ready.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:**

```json
{
  "message": "Game started successfully",
  "match_id": 456,
  "room_id": 123,
  "websocket_url": "/ws/match/456"
}
```

**Flow:**

1. Kiểm tra tất cả players đã ready
2. Tạo Match mới
3. Thêm players vào Match với symbol X, O, A, B
4. Update room status -> playing
5. Return match_id và WebSocket URL

**Errors:**

- `403` - Only host can start game
- `400` - Not all players ready / Need at least 2 players

**Use Cases:**

- Host bấm "Start Game" khi mọi người ready
- Client connect WebSocket với match_id

---

### 8. POST `/api/rooms/{room_id}/leave` - Rời phòng

**Description:** Rời khỏi phòng.

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:**

```json
{
  "message": "Left room successfully",
  "room_deleted": false
}
```

**Special Cases:**

- Nếu host rời -> phòng bị xóa
- Player khác rời -> xóa khỏi danh sách

**Response khi host rời:**

```json
{
  "message": "Room deleted (host left)",
  "room_deleted": true
}
```

---

### 9. DELETE `/api/rooms/{room_id}` - Xóa phòng (Host only)

**Description:** Xóa phòng (chỉ khi đang waiting).

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:**

```json
{
  "message": "Room deleted successfully",
  "room_id": 123
}
```

**Errors:**

- `403` - Only host can delete room
- `400` - Can only delete room in waiting state

---

## Workflow

### Create & Join Flow

```
1. User A: POST /api/rooms/create
   {
     "room_name": "My Room",
     "password": "abc123",
     "max_players": 2
   }
   -> Response: room_code = "X7Y2K9"

2. User B: POST /api/rooms/join
   {
     "room_code": "X7Y2K9",
     "password": "abc123"
   }
   -> Joined successfully

3. User B: POST /api/rooms/{room_id}/ready
   {
     "is_ready": true
   }
   -> Ready!

4. User A (host): POST /api/rooms/{room_id}/start
   -> match_id = 456
   -> websocket_url = "/ws/match/456"

5. Both users: Connect WebSocket
   ws://localhost:8000/ws/match/456?token=JWT_TOKEN
```

### Room Lobby Flow

```
1. Client: GET /api/rooms/list?status=waiting
   -> List of available rooms

2. User clicks room -> POST /api/rooms/join
   {
     "room_code": "X7Y2K9",
     "password": "..." // if needed
   }

3. Poll GET /api/rooms/{room_id} every 2s
   -> Update UI with players list, ready status

4. When all ready -> Host clicks Start
   -> POST /api/rooms/{room_id}/start
   -> Navigate to game with match_id
```

---

## Flutter Implementation

### Room Lobby Screen

```dart
class RoomLobbyScreen extends StatefulWidget {
  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  List<RoomListItem> rooms = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    loadRooms();

    // Auto refresh every 3s
    _refreshTimer = Timer.periodic(Duration(seconds: 3), (_) {
      loadRooms();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadRooms() async {
    try {
      final response = await dio.get('/api/rooms/list', queryParameters: {
        'status': 'waiting',
        'only_public': true,
      });

      setState(() {
        rooms = (response.data as List)
            .map((json) => RoomListItem.fromJson(json))
            .toList();
      });
    } catch (e) {
      print('Error loading rooms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room Lobby'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: loadRooms,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return RoomCard(
            room: room,
            onTap: () => _joinRoom(room),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoomDialog,
        icon: Icon(Icons.add),
        label: Text('Create Room'),
      ),
    );
  }

  void _showCreateRoomDialog() {
    // Show dialog with CreateRoomForm
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateRoomScreen()),
    );
  }

  Future<void> _joinRoom(RoomListItem room) async {
    String? password;

    if (room.has_password) {
      password = await showDialog<String>(
        context: context,
        builder: (context) => PasswordDialog(),
      );

      if (password == null) return;
    }

    try {
      final response = await dio.post('/api/rooms/join', data: {
        'room_code': room.room_code,
        'password': password,
      });

      final roomDetail = RoomDetail.fromJson(response.data);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomWaitingScreen(roomDetail: roomDetail),
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
```

### Room Waiting Screen

```dart
class RoomWaitingScreen extends StatefulWidget {
  final RoomDetail roomDetail;

  const RoomWaitingScreen({required this.roomDetail});

  @override
  State<RoomWaitingScreen> createState() => _RoomWaitingScreenState();
}

class _RoomWaitingScreenState extends State<RoomWaitingScreen> {
  late RoomDetail room;
  Timer? _pollTimer;
  bool isHost = false;

  @override
  void initState() {
    super.initState();
    room = widget.roomDetail;

    // Check if current user is host
    final userId = getCurrentUserId(); // Get from auth state
    isHost = (room.host_id == userId);

    // Poll room status every 2s
    _pollTimer = Timer.periodic(Duration(seconds: 2), (_) {
      loadRoomDetail();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> loadRoomDetail() async {
    try {
      final response = await dio.get('/api/rooms/${room.id}');

      setState(() {
        room = RoomDetail.fromJson(response.data);
      });

      // If game started -> navigate to game
      if (room.status == 'playing' && room.match_id != null) {
        _pollTimer?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(matchId: room.match_id!),
          ),
        );
      }
    } catch (e) {
      print('Error polling room: $e');
    }
  }

  Future<void> toggleReady() async {
    final currentPlayer = room.players.firstWhere(
      (p) => p.user_id == getCurrentUserId(),
    );

    try {
      await dio.post('/api/rooms/${room.id}/ready', data: {
        'is_ready': !currentPlayer.is_ready,
      });

      await loadRoomDetail();
    } catch (e) {
      showError(e.toString());
    }
  }

  Future<void> startGame() async {
    try {
      final response = await dio.post('/api/rooms/${room.id}/start');

      final matchId = response.data['match_id'];

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(matchId: matchId),
        ),
      );
    } catch (e) {
      showError(e.toString());
    }
  }

  Future<void> kickPlayer(int userId) async {
    try {
      await dio.post('/api/rooms/${room.id}/kick', data: {
        'user_id': userId,
      });

      await loadRoomDetail();
    } catch (e) {
      showError(e.toString());
    }
  }

  Future<void> leaveRoom() async {
    try {
      await dio.post('/api/rooms/${room.id}/leave');
      Navigator.pop(context);
    } catch (e) {
      showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final allReady = room.players.every((p) => p.is_ready);
    final canStart = isHost && allReady && room.players.length >= 2;

    return WillPopScope(
      onWillPop: () async {
        await leaveRoom();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(room.room_name),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: leaveRoom,
          ),
        ),
        body: Column(
          children: [
            // Room Info Card
            RoomInfoCard(
              roomCode: room.room_code,
              maxPlayers: room.max_players,
              currentPlayers: room.current_players,
            ),

            // Players List
            Expanded(
              child: ListView.builder(
                itemCount: room.players.length,
                itemBuilder: (context, index) {
                  final player = room.players[index];
                  return PlayerTile(
                    player: player,
                    isHost: isHost,
                    onKick: player.is_host ? null : () => kickPlayer(player.user_id),
                  );
                },
              ),
            ),

            // Bottom Actions
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  if (!isHost)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: toggleReady,
                        child: Text(
                          room.players
                              .firstWhere((p) => p.user_id == getCurrentUserId())
                              .is_ready
                              ? 'Not Ready'
                              : 'Ready',
                        ),
                      ),
                    ),

                  if (isHost) ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canStart ? startGame : null,
                        child: Text('Start Game'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Testing

### Create Room

```bash
curl -X POST "http://localhost:8000/api/rooms/create" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "room_name": "Test Room",
    "password": "test123",
    "max_players": 2,
    "is_public": true
  }'
```

### List Rooms

```bash
curl -X GET "http://localhost:8000/api/rooms/list?status=waiting" \
  -H "Authorization: Bearer TOKEN"
```

### Join Room

```bash
curl -X POST "http://localhost:8000/api/rooms/join" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "room_code": "X7Y2K9",
    "password": "test123"
  }'
```

### Start Game

```bash
curl -X POST "http://localhost:8000/api/rooms/123/start" \
  -H "Authorization: Bearer TOKEN"
```

---

## Migration

Run migration:

```bash
psql -U postgres -d gameplus_db -f migrations/add_room_system.sql
```

---

## Future Enhancements

1. **WebSocket Room Updates**: Real-time updates khi player join/leave/ready
2. **Room Chat**: Chat trong phòng chờ
3. **Spectators**: Cho phép xem game đang chơi
4. **Room History**: Lưu lịch sử phòng đã chơi
5. **Quick Match**: Tự động match vào phòng phù hợp
6. **Room Templates**: Save settings để tạo phòng nhanh
7. **Ban List**: Host có thể ban players
8. **Invite Friends**: Gửi invite link cho bạn bè
