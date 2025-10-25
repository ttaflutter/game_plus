# 🎮 Caro Game - Features Documentation

## ✨ Tính năng đã hoàn thành

### 🔌 WebSocket Integration

- ✅ Kết nối realtime với backend qua WebSocket
- ✅ Tự động reconnect khi mất kết nối
- ✅ Xử lý disconnect của đối thủ → người còn lại thắng
- ✅ Load full board state khi join (hỗ trợ rejoin)

### 🎯 Game Logic

- ✅ Bàn cờ 15x19, thắng khi 5 quân liên tiếp
- ✅ Luân phiên X-O
- ✅ Kiểm tra thắng/thua/hòa
- ✅ Highlight winning line (5 ô thắng sáng lên)
- ✅ Đếm số nước đã đi
- ✅ Phân biệt "Bạn" vs "Đối thủ"

### ⏰ Timer System

- ✅ Mỗi lượt có 30 giây
- ✅ Countdown hiển thị realtime
- ✅ Cảnh báo màu đỏ khi còn ≤10s
- ✅ Timeout → đối thủ thắng

### 🎨 UI/UX

- ✅ **Thanh trạng thái**: Hiển thị trạng thái game (kết nối, chờ đối thủ, lượt của ai)
- ✅ **Thông tin người chơi**: Hiển thị X/O, ai đang đánh (highlight)
- ✅ **Timer trên AppBar**: Hiển thị thời gian còn lại
- ✅ **Match ID**: Hiện ở góc phải để debug
- ✅ **Ô cờ đẹp**:
  - Màu xanh (X) / đỏ (O)
  - Border radius + shadow
  - Animation khi đánh
  - Highlight winning line với màu vàng + shadow

### 🏆 Kết thúc trận

- ✅ Dialog tự động hiện khi kết thúc
- ✅ Phân biệt thắng/thua/hòa
- ✅ Hiển thị tổng số nước
- ✅ Nút "Chơi lại" và "Về trang chủ"
- ✅ Xử lý các trường hợp:
  - Win (có người thắng)
  - Draw (hòa)
  - Timeout (hết giờ)
  - Surrender (đầu hàng)
  - Disconnect (người chơi thoát)

### 🏳️ Surrender

- ✅ Nút đầu hàng trên AppBar (icon cờ trắng)
- ✅ Confirm dialog trước khi đầu hàng
- ✅ Đối thủ thắng ngay lập tức

### 💬 Chat

- ✅ Chat realtime giữa 2 người chơi
- ✅ Phân biệt tin nhắn của mình/đối thủ
- ✅ Hiển thị thời gian
- ✅ Auto scroll xuống tin mới nhất

### 🎲 Matchmaking

- ✅ Tự động ghép 2 người vào cùng match
- ✅ Người đầu tiên join → chờ đối thủ
- ✅ Người thứ 2 join → game bắt đầu
- ✅ Hỗ trợ spectator (xem không chơi)

### 📊 Rating System (Backend)

- ✅ ELO rating tự động cập nhật sau mỗi trận
- ✅ K-factor = 32
- ✅ Track wins/losses/draws

## 🔧 Backend WebSocket Messages

### Server → Client

```json
// Khi join
{
  "type": "joined",
  "payload": {
    "you": {"user_id": 1, "symbol": "X"},
    "players": [{"user_id": 1, "symbol": "X"}, {"user_id": 2, "symbol": "O"}],
    "turn": "X",
    "turn_no": 0,
    "status": "waiting|playing|finished",
    "time_left": 30,
    "board": [["", "", ...], [...]]
  }
}

// Game bắt đầu
{
  "type": "start",
  "payload": {
    "turn": "X",
    "players": [...],
    "time_limit": 30
  }
}

// Có người đánh
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

// Có người thắng
{
  "type": "win",
  "payload": {
    "winner_user_id": 1,
    "symbol": "X",
    "line": [{"x": 5, "y": 5}, {"x": 5, "y": 6}, ...]
  }
}

// Hòa
{
  "type": "draw",
  "payload": {"reason": "board_full"}
}

// Timeout
{
  "type": "timeout",
  "payload": {
    "loser_user_id": 1,
    "winner_user_id": 2,
    "reason": "Time's up!"
  }
}

// Đầu hàng
{
  "type": "surrender",
  "payload": {
    "surrendered_user_id": 1,
    "winner_user_id": 2
  }
}

// Disconnect
{
  "type": "disconnect",
  "payload": {
    "disconnected_user_id": 1,
    "winner_user_id": 2,
    "reason": "Player disconnected"
  }
}

// Chat
{
  "type": "chat",
  "payload": {
    "from": 1,
    "message": "Hello!",
    "time": "2025-10-24T14:35:01.123Z"
  }
}
```

### Client → Server

```json
// Đánh quân
{
  "type": "move",
  "payload": {"x": 5, "y": 7}
}

// Đầu hàng
{
  "type": "surrender",
  "payload": {}
}

// Chat
{
  "type": "chat",
  "payload": {"message": "gg wp"}
}

// Ping
{
  "type": "ping",
  "payload": {}
}
```

## 📱 Files Structure

```
lib/
├── game/caro/
│   ├── caro_controller.dart      # Game logic + WebSocket handler
│   ├── caro_board.dart            # Bàn cờ GridView
│   ├── caro_cell.dart             # 1 ô cờ (X/O)
│   ├── caro_chat_panel.dart      # Chat UI
│   └── winning_line_data.dart    # Model winning line
├── services/
│   └── caro_service.dart          # WebSocket connection
├── ui/screens/
│   └── caro_screen.dart           # Main game screen
└── configs/
    └── app_config.dart            # Base URL + WebSocket URL
```

## 🎯 Cách test

1. **Start backend**: `uvicorn app.main:app --reload`
2. **Mở 2 Flutter apps** (hoặc 2 browsers nếu web)
3. **User 1**: Đăng nhập → "Chơi ngay" → chờ
4. **User 2**: Đăng nhập → "Chơi ngay" → ghép vào cùng match
5. **Test các tính năng**:
   - Đánh quân luân phiên
   - Chat
   - Timer countdown
   - Đầu hàng
   - Disconnect (tắt 1 app)
   - Thắng (5 quân liên tiếp)

## 🚀 Next Features (Tùy chọn)

- [ ] Spectator mode UI
- [ ] Replay match
- [ ] Match history
- [ ] Leaderboard
- [ ] Friend challenge (không random)
- [ ] Sound effects
- [ ] Vibration khi đánh
- [ ] Dark mode
- [ ] Custom board size
- [ ] Undo move (nếu đối thủ đồng ý)

---

**Version**: 1.0.0  
**Last Updated**: 2025-10-24  
**Author**: Your Name
