# 🐛 Debug Timeout Issue

## Vấn đề

Server gửi timeout message nhưng frontend không xử lý.

## Đã fix

### 1. ✅ Thêm debug logs

```dart
void _handleServerMessage(Map<String, dynamic> msg) {
  print("📨 Received message: $type");
  print("   Payload: $payload");
  ...
}
```

### 2. ✅ Cập nhật timeout handler

```dart
case "timeout":
  isFinished = true;
  winnerId = payload["winner_user_id"];
  timeLeft = 0; // Dừng timer
  notifyListeners();
```

### 3. ✅ Cải thiện dialog

- Phân biệt "Thắng do timeout" vs "Thua do timeout"
- Hiển thị message rõ ràng hơn

## Cách test

### A. Kiểm tra message từ server

1. Mở DevTools Console (F12)
2. Chờ timeout (30s)
3. Xem log:
   ```
   📨 Received message: timeout
      Payload: {winner_user_id: 2, loser_user_id: 1, reason: "Time's up!"}
   ⏰ Timeout! Loser: 1, Winner: user 2
   ```

### B. Kiểm tra dialog hiển thị

1. Nếu timeout → dialog phải hiện với:
   - **Nếu bạn hết giờ**: "⏰ Thua do Timeout! - Bạn đã hết thời gian!"
   - **Nếu đối thủ hết giờ**: "⏰ Thắng do Timeout! - Đối thủ đã hết thời gian!"

### C. Nếu vẫn không hiển thị

#### Kiểm tra 1: Message có đến không?

Check console log xem có dòng "📨 Received message: timeout" không.

**Nếu KHÔNG có** → Vấn đề ở WebSocket connection hoặc server không gửi đúng format.

#### Kiểm tra 2: notifyListeners() có chạy không?

Thêm log trong `_checkGameEnd()`:

```dart
void _checkGameEnd() {
  print("🔍 Checking game end: isFinished=${controller.isFinished}, hasShown=$_hasShownEndDialog");
  ...
}
```

**Nếu không in ra** → Provider không trigger rebuild.

#### Kiểm tra 3: Dialog có được call không?

Thêm log trong `_showEndGameDialog()`:

```dart
void _showEndGameDialog(CaroController controller) {
  print("🎬 Showing end game dialog: winner=${controller.winnerId}");
  ...
}
```

## Nguyên nhân có thể

### 1. Server gửi sai format

Backend gửi:

```python
await broadcast(state, {
    "type": "timeout",
    "payload": {
        "loser_user_id": current_player_id,
        "winner_user_id": winner_id,
        "reason": "Time's up!"
    }
})
```

Frontend expect: ✅ Đúng format

### 2. WebSocket disconnect trước khi nhận message

- Server gọi `handle_timeout()` → gửi message
- Nhưng connection đã close → message không đến client

**Fix**: Đảm bảo server gửi message TRƯỚC KHI close connection hoặc cleanup room.

### 3. Race condition

- Timer countdown về 0 cùng lúc server gửi timeout
- Frontend timer dừng nhưng chưa set `isFinished = true`
- Message đến nhưng không trigger dialog vì state chưa đồng bộ

**Fix**: Luôn set `isFinished = true` và `timeLeft = 0` khi nhận timeout message.

## ✅ Checklist Fix

- [x] Thêm debug logs cho message handler
- [x] Set `timeLeft = 0` trong timeout handler
- [x] Cải thiện dialog message (phân biệt win/lose by timeout)
- [x] Đảm bảo `notifyListeners()` được gọi
- [ ] Test với 2 clients thực tế
- [ ] Verify console logs

## Next Steps

1. **Hot restart app** (không chỉ hot reload)
2. **Join match với 2 users**
3. **Chờ 30s không đánh quân**
4. **Xem console log** để debug
5. **Kiểm tra dialog có hiện không**

Nếu vẫn không work, paste console log vào để debug tiếp!
