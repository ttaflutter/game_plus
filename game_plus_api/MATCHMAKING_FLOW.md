# 🎮 Matchmaking Flow - Game Caro

## 📋 Tổng quan

Hệ thống matchmaking tự động ghép cặp 2 người chơi vào cùng một trận đấu thông qua WebSocket realtime.

---

## 🔄 Flow hoàn chỉnh

### 1️⃣ Frontend: Show Matching Screen

```dart
// home_screen.dart
void _handlePlayNow() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => MatchingScreen(
        onFindMatch: () async {
          // Callback này sẽ được gọi từ matching screen
          return await _caroService.findMatch();
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    ),
  );
}
```

### 2️⃣ Matching Screen: Connect WebSocket

```dart
// matching_screen.dart
class MatchingScreen extends StatefulWidget {
  final Future<MatchResult> Function() onFindMatch;
  final VoidCallback onCancel;

  @override
  _MatchingScreenState createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _connectMatchmaking();
  }

  void _connectMatchmaking() async {
    final token = await _storage.read(key: 'access_token');

    // Connect đến matchmaking WebSocket
    _channel = IOWebSocketChannel.connect(
      'ws://your-server/ws/matchmaking?token=$token'
    );

    // Lắng nghe messages
    _channel!.stream.listen(
      (data) {
        final msg = jsonDecode(data);

        if (msg['type'] == 'searching') {
          setState(() {
            _status = 'Searching for opponent...';
            _queueSize = msg['payload']['queue_size'];
          });
        }
        else if (msg['type'] == 'match_found') {
          // Tìm thấy đối thủ!
          final matchId = msg['payload']['match_id'];
          final players = msg['payload']['players'];

          // Chuyển sang game screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CaroGameScreen(matchId: matchId),
            ),
          );
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket closed');
      },
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(_status),
            Text('Players in queue: $_queueSize'),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                _channel?.sink.close();
                widget.onCancel();
              },
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3️⃣ Backend: Matchmaking Logic

```python
# realtime.py

matchmaking_queue: Dict[int, WebSocket] = {}

@router.websocket("/matchmaking")
async def websocket_matchmaking(websocket: WebSocket, token: str, db: AsyncSession):
    # 1. Auth user
    user_id = await decode_token(token)
    await websocket.accept()

    # 2. Thêm vào queue
    matchmaking_queue[user_id] = websocket

    # 3. Gửi thông báo searching
    await websocket.send_text(json.dumps({
        "type": "searching",
        "payload": {
            "message": "Searching for opponent...",
            "queue_size": len(matchmaking_queue)
        }
    }))

    # 4. Tìm hoặc tạo match
    match = await db.scalar(
        select(Match)
        .where(Match.game_id == game.id)
        .where(Match.status == MatchStatus.waiting)
    )

    if not match:
        # Tạo match mới (người chơi đầu tiên)
        match = Match(...)
        db.add(match)
        await db.flush()
        match_id = match.id
    else:
        # Join match đang chờ (người chơi thứ 2)
        match_id = match.id

    # 5. Thêm player vào match
    player_count = await db.scalar(select(func.count()).select_from(MatchPlayer).where(...))

    db.add(MatchPlayer(match_id=match_id, user_id=user_id, symbol=...))

    # 6. Nếu đủ 2 người -> thông báo CẢ HAI
    if player_count + 1 == 2:
        # Update match status
        await db.execute(update(Match).where(...).values(status=MatchStatus.playing))
        await db.commit()

        # Lấy thông tin cả 2 players
        players = await db.execute(select(MatchPlayer, User).join(...).where(...))

        # Gửi match_found cho CẢ 2 người trong queue
        for player in players:
            if player.user_id in matchmaking_queue:
                await matchmaking_queue[player.user_id].send_text(json.dumps({
                    "type": "match_found",
                    "payload": {
                        "match_id": match_id,
                        "players": [...]
                    }
                }))

        # Đóng connections
        await websocket.close()
        matchmaking_queue.pop(user_id, None)
    else:
        # Chưa đủ người, giữ connection và đợi
        while True:
            await websocket.send_text(json.dumps({"type": "ping"}))

            # Check mỗi 3s xem match đã ready chưa
            match_check = await db.scalar(select(Match).where(...))
            if match_check.status == MatchStatus.playing:
                # Đã có đối thủ!
                await websocket.send_text(json.dumps({"type": "match_found", ...}))
                break

            await asyncio.sleep(3)
```

### 4️⃣ Game Screen: Connect to Match WebSocket

```dart
// caro_game_screen.dart
class CaroGameScreen extends StatefulWidget {
  final int matchId;

  @override
  _CaroGameScreenState createState() => _CaroGameScreenState();
}

class _CaroGameScreenState extends State<CaroGameScreen> {
  WebSocketChannel? _gameChannel;

  @override
  void initState() {
    super.initState();
    _connectToMatch();
  }

  void _connectToMatch() async {
    final token = await _storage.read(key: 'access_token');

    // Connect đến game WebSocket
    _gameChannel = IOWebSocketChannel.connect(
      'ws://your-server/ws/match/${widget.matchId}?token=$token'
    );

    _gameChannel!.stream.listen((data) {
      final msg = jsonDecode(data);

      if (msg['type'] == 'joined') {
        // Nhận snapshot bàn cờ
        setState(() {
          _board = msg['payload']['board'];
          _currentTurn = msg['payload']['turn'];
          _timeLeft = msg['payload']['time_left'];
        });
      }
      else if (msg['type'] == 'start') {
        // Game bắt đầu
        setState(() {
          _gameStatus = 'playing';
        });
      }
      else if (msg['type'] == 'move') {
        // Đối thủ đánh
        final x = msg['payload']['x'];
        final y = msg['payload']['y'];
        final symbol = msg['payload']['symbol'];

        setState(() {
          _board[x][y] = symbol;
          _currentTurn = msg['payload']['next_turn'];
        });
      }
      else if (msg['type'] == 'win') {
        // Có người thắng
        _showGameOverDialog('Winner: ${msg['payload']['winner_user_id']}');
      }
      // ... handle other message types
    });
  }

  void _makeMove(int x, int y) {
    _gameChannel!.sink.add(jsonEncode({
      "type": "move",
      "payload": {"x": x, "y": y}
    }));
  }
}
```

---

## 🔑 Key Points

### ✅ Ưu điểm của flow này:

1. **Realtime matching**: Không cần polling, server tự động thông báo khi tìm được đối thủ
2. **Scalable**: Có thể có nhiều người chờ trong queue
3. **User-friendly**: UI hiển thị số người đang chờ, trạng thái realtime
4. **Auto cleanup**: WebSocket tự động cleanup khi người chơi thoát

### 📝 Lưu ý khi implement:

1. **Timeout**: Thêm timeout cho matching (VD: 60s không tìm được thì hủy)
2. **Cancel**: Cho phép người chơi hủy khi đang tìm
3. **Reconnect**: Xử lý khi mất kết nối WebSocket
4. **Error handling**: Xử lý các lỗi network, token expired, etc.

---

## 🎯 API Endpoints Summary

| Endpoint                            | Type      | Purpose                                            |
| ----------------------------------- | --------- | -------------------------------------------------- |
| `POST /api/matches/join`            | REST      | Tạo/join match (legacy, không dùng cho auto-match) |
| `ws://server/ws/matchmaking`        | WebSocket | Tự động tìm đối thủ                                |
| `ws://server/ws/match/{id}`         | WebSocket | Chơi game realtime                                 |
| `GET /api/matches/history`          | REST      | Lịch sử trận đấu                                   |
| `GET /api/matches/leaderboard/caro` | REST      | Bảng xếp hạng                                      |
| `GET /api/matches/stats/me`         | REST      | Thống kê cá nhân                                   |

---

## 🧪 Testing

### Test với 2 clients:

```bash
# Terminal 1 - Player 1
python app/scripts/test_matchmaking.py --user player1

# Terminal 2 - Player 2
python app/scripts/test_matchmaking.py --user player2
```

Khi cả 2 connect đến `/ws/matchmaking`, server sẽ tự động:

1. Ghép cặp họ vào cùng 1 match
2. Gửi `match_found` cho CẢ HAI
3. Họ có thể bắt đầu chơi qua `/ws/match/{id}`

---

## 🐛 Troubleshooting

### Vấn đề: Matching không tự động ghép

**Nguyên nhân:** Có thể do:

- WebSocket connection bị đứt
- Token expired
- Database không commit đúng

**Giải pháp:**

- Check logs server xem có user nào vào queue không
- Verify token còn valid
- Test với 2 browser/device khác nhau

### Vấn đề: Match found nhưng game không start

**Nguyên nhân:**

- Match status không được update sang `playing`
- WebSocket `/ws/match/{id}` không connect được

**Giải pháp:**

- Check database xem match status
- Verify match_id được truyền đúng

---

## 🚀 Enhancements

Các tính năng có thể thêm:

1. **Rank-based matching**: Ghép người có rank gần nhau
2. **Quick rematch**: Sau khi chơi xong, 2 người có thể rematch ngay
3. **Friend match**: Mời bạn bè chơi bằng room code
4. **Tournament mode**: Giải đấu nhiều người
5. **Bot opponent**: Nếu không tìm được người, cho chơi với bot

---

Chúc bạn implement thành công! 🎉
