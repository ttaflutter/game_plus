# WebSocket API Documentation - Caro Game

## Kết nối WebSocket

**Endpoint:** `ws://your-server/ws/match/{match_id}?token={jwt_token}`

### Query Parameters:

- `token` (required): JWT authentication token

---

## Message Types

### 1. Client → Server Messages

#### a) Move (Đánh quân)

```json
{
  "type": "move",
  "payload": {
    "x": 5,
    "y": 7
  }
}
```

**Response thành công:**

```json
{
  "type": "move",
  "payload": {
    "x": 5,
    "y": 7,
    "symbol": "X",
    "turn_no": 1,
    "next_turn": "O",
    "time_limit": 30
  }
}
```

**Response lỗi:**

```json
{
  "type": "error",
  "payload": "Not your turn"
}
```

---

#### b) Surrender (Đầu hàng)

```json
{
  "type": "surrender",
  "payload": {}
}
```

**Response:**

```json
{
  "type": "surrender",
  "payload": {
    "surrendered_user_id": 123,
    "winner_user_id": 456
  }
}
```

---

#### c) Chat

```json
{
  "type": "chat",
  "payload": {
    "message": "Good game!"
  }
}
```

**Broadcast to all:**

```json
{
  "type": "chat",
  "payload": {
    "from": 123,
    "message": "Good game!",
    "time": "2025-10-24T10:30:00Z"
  }
}
```

---

#### d) Ping (Kiểm tra kết nối)

```json
{
  "type": "ping",
  "payload": {}
}
```

**Response:**

```json
{
  "type": "pong"
}
```

---

#### e) Rematch (Chơi lại)

```json
{
  "type": "rematch",
  "payload": {}
}
```

**Response khi 1 người gửi:**

```json
{
  "type": "rematch_request",
  "payload": {
    "from_user_id": 123,
    "total_requests": 1,
    "total_players": 2
  }
}
```

**Response khi cả 2 đồng ý:**

```json
{
  "type": "rematch_accepted",
  "payload": {
    "new_match_id": 456,
    "message": "Both players accepted! New match created."
  }
}
```

---

### 2. Server → Client Messages

#### a) Joined (Snapshot khi vào phòng)

```json
{
  "type": "joined",
  "payload": {
    "you": {
      "user_id": 123,
      "symbol": "X"
    },
    "players": [
      {"user_id": 123, "symbol": "X"},
      {"user_id": 456, "symbol": "O"}
    ],
    "turn": "X",
    "turn_no": 5,
    "status": "playing",
    "time_left": 25.5,
    "board": [
      ["X", "", "O", ...],
      ["", "X", "", ...],
      ...
    ]
  }
}
```

---

#### b) Start (Trận bắt đầu)

```json
{
  "type": "start",
  "payload": {
    "turn": "X",
    "players": [
      { "user_id": 123, "symbol": "X" },
      { "user_id": 456, "symbol": "O" }
    ],
    "time_limit": 30
  }
}
```

---

#### c) Win (Có người thắng)

```json
{
  "type": "win",
  "payload": {
    "winner_user_id": 123,
    "symbol": "X",
    "line": [
      { "x": 5, "y": 5 },
      { "x": 5, "y": 6 },
      { "x": 5, "y": 7 },
      { "x": 5, "y": 8 },
      { "x": 5, "y": 9 }
    ]
  }
}
```

---

#### d) Draw (Hòa)

```json
{
  "type": "draw",
  "payload": {
    "reason": "board_full"
  }
}
```

---

#### e) Timeout (Hết giờ)

```json
{
  "type": "timeout",
  "payload": {
    "loser_user_id": 123,
    "winner_user_id": 456,
    "reason": "Time's up!"
  }
}
```

---

#### f) Disconnect (Người chơi disconnect)

```json
{
  "type": "disconnect",
  "payload": {
    "disconnected_user_id": 123,
    "winner_user_id": 456,
    "reason": "Player disconnected"
  }
}
```

---

## Game Rules

### Thời gian mỗi nước đi

- **30 giây** cho mỗi lượt
- Hết giờ → thua tự động
- Timer reset sau mỗi nước đi

### Kết thúc trận đấu

1. **Win:** 5 quân liên tiếp (ngang/dọc/chéo)
2. **Draw:** Bàn cờ đầy mà không ai thắng
3. **Surrender:** Người chơi đầu hàng
4. **Timeout:** Hết giờ suy nghĩ
5. **Disconnect:** Người chơi thoát khi đang chơi → thua

### Rating System (ELO)

- Rating mặc định: **1000**
- K-factor: **32**
- Công thức: `New Rating = Old Rating + K * (Actual Score - Expected Score)`
- Expected Score: `E = 1 / (1 + 10^((Opponent Rating - Your Rating) / 400))`

---

## REST API Endpoints

### 1. Quick Join Match

**POST** `/api/matches/join`

Tự động tìm trận đang chờ hoặc tạo trận mới.

**Response:**

```json
{
  "match_id": 123,
  "status": "waiting",
  "board": "15x19"
}
```

---

### 2. Get Match History

**GET** `/api/matches/history?limit=10&offset=0`

Xem lịch sử các trận đã chơi.

**Response:**

```json
{
  "history": [
    {
      "match_id": 123,
      "status": "finished",
      "result": "win",
      "your_symbol": "X",
      "opponent": {
        "user_id": 456,
        "username": "player2",
        "avatar_url": "https://...",
        "symbol": "O"
      },
      "created_at": "2025-10-24T10:00:00Z",
      "finished_at": "2025-10-24T10:15:00Z"
    }
  ],
  "total": 1
}
```

---

### 3. Get Match Detail (Replay)

**GET** `/api/matches/{match_id}`

Xem chi tiết trận đấu với replay đầy đủ.

**Response:**

```json
{
  "match_id": 123,
  "status": "finished",
  "board_size": "15x19",
  "win_len": 5,
  "players": [
    {
      "user_id": 123,
      "username": "player1",
      "avatar_url": "https://...",
      "symbol": "X",
      "is_winner": true
    }
  ],
  "moves": [
    {
      "turn_no": 1,
      "user_id": 123,
      "x": 7,
      "y": 9,
      "symbol": "X",
      "made_at": "2025-10-24T10:01:00Z"
    }
  ],
  "created_at": "2025-10-24T10:00:00Z",
  "started_at": "2025-10-24T10:00:30Z",
  "finished_at": "2025-10-24T10:15:00Z"
}
```

---

### 4. Get Leaderboard

**GET** `/api/matches/leaderboard/caro?limit=50&offset=0`

Xem bảng xếp hạng.

**Response:**

```json
{
  "leaderboard": [
    {
      "rank": 1,
      "user_id": 123,
      "username": "player1",
      "avatar_url": "https://...",
      "rating": 1250,
      "wins": 15,
      "losses": 5,
      "draws": 2,
      "total_games": 22,
      "win_rate": 68.2
    }
  ]
}
```

---

### 5. Get My Stats

**GET** `/api/matches/stats/me`

Xem thống kê của bản thân.

**Response:**

```json
{
  "rating": 1250,
  "wins": 15,
  "losses": 5,
  "draws": 2,
  "total_games": 22,
  "win_rate": 68.2,
  "rank": 42
}
```

---

## Error Handling

### Common Errors

```json
{
  "type": "error",
  "payload": "Error message here"
}
```

**Possible error messages:**

- `"Match not found"` - Match ID không tồn tại
- `"Invalid token"` - JWT token không hợp lệ
- `"Not your turn"` - Chưa đến lượt
- `"Invalid cell"` - Ô đã có quân hoặc ngoài bàn cờ
- `"Match is not playing"` - Trận chưa bắt đầu hoặc đã kết thúc
- `"Spectator cannot move"` - Người xem không được đánh
- `"Match already finished"` - Trận đã kết thúc

---

## Client Implementation Example (JavaScript)

```javascript
const ws = new WebSocket(
  `ws://localhost:8000/ws/match/${matchId}?token=${token}`
);

ws.onopen = () => {
  console.log("Connected to match");
};

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);

  switch (msg.type) {
    case "joined":
      // Hiển thị snapshot bàn cờ
      updateBoard(msg.payload.board);
      updatePlayerList(msg.payload.players);
      break;

    case "start":
      console.log("Game started!");
      startTimer(msg.payload.time_limit);
      break;

    case "move":
      // Cập nhật bàn cờ
      placeSymbol(msg.payload.x, msg.payload.y, msg.payload.symbol);
      switchTurn(msg.payload.next_turn);
      startTimer(msg.payload.time_limit);
      break;

    case "win":
      // Hiển thị người thắng
      highlightWinLine(msg.payload.line);
      showWinner(msg.payload.winner_user_id);
      break;

    case "timeout":
      showMessage("Time out!");
      break;

    case "error":
      alert(msg.payload);
      break;
  }
};

// Đánh quân
function makeMove(x, y) {
  ws.send(
    JSON.stringify({
      type: "move",
      payload: { x, y },
    })
  );
}

// Đầu hàng
function surrender() {
  ws.send(
    JSON.stringify({
      type: "surrender",
      payload: {},
    })
  );
}

// Chat
function sendChat(message) {
  ws.send(
    JSON.stringify({
      type: "chat",
      payload: { message },
    })
  );
}
```

---

## Features Summary

✅ **Tự động matching** - Tìm đối thủ tự động  
✅ **Time limit** - 30 giây mỗi nước đi  
✅ **Auto timeout** - Hết giờ tự động thua  
✅ **Surrender** - Đầu hàng bất cứ lúc nào  
✅ **Disconnect = Loss** - Thoát game = thua  
✅ **Reconnect** - Vào lại trận đang chơi (snapshot có board state)  
✅ **Chat** - Trò chuyện trong game  
✅ **Spectator mode** - Xem người khác chơi  
✅ **Match history** - Lịch sử trận đấu  
✅ **Replay** - Xem lại từng nước đi  
✅ **Leaderboard** - Bảng xếp hạng  
✅ **ELO Rating** - Hệ thống điểm số  
✅ **Win detection** - Tự động phát hiện thắng  
✅ **Draw detection** - Phát hiện hòa

---

## Notes

1. **Reconnect:** Khi client reconnect, server gửi snapshot đầy đủ của bàn cờ qua message `joined`
2. **Spectator:** Người vào sau 2 player đầu tiên sẽ là khán giả, không được đánh
3. **Room cleanup:** Phòng tự động xóa sau 3 giây khi trận kết thúc
4. **Database persistence:** Tất cả nước đi đều lưu vào database để replay
5. **Rating update:** Rating tự động cập nhật sau mỗi trận

---

## Testing

### Test với 2 clients:

```bash
# Terminal 1 - Player 1
pip install websocket-client
python app/scripts/test_ws_1.py

# Terminal 2 - Player 2
python app/scripts/test_ws_2.py
```

### Quick test flow:

1. Player 1: POST `/api/matches/join` → get `match_id`
2. Player 1: Connect WebSocket với `match_id`
3. Player 2: POST `/api/matches/join` → cùng `match_id`
4. Player 2: Connect WebSocket
5. Trận tự động bắt đầu (status: `playing`)
6. Player X đánh trước (30s timer)
7. Luân phiên đánh cho đến khi có người thắng/hòa
