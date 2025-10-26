# MATCH HISTORY API Documentation

## Overview

API cho chức năng xem lịch sử đấu (match history) với khả năng xem chi tiết từng trận, replay moves, và lọc theo kết quả.

---

## Endpoints

### 1. GET `/api/match-history/my-matches` - Lịch sử đấu của mình

**Description:** Lấy danh sách lịch sử đấu của người dùng hiện tại.

**Query Parameters:**

- `game_name` (string, optional): Tên game (mặc định: "Caro")
- `status` (string, optional): Filter theo status ("finished", "abandoned", "playing", "waiting")
- `result` (string, optional): Filter theo kết quả ("win", "loss", "draw")
- `limit` (int, optional): Số lượng trận tối đa (1-50, mặc định: 10)
- `offset` (int, optional): Vị trí bắt đầu (mặc định: 0)

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:**

```json
[
  {
    "match_id": 123,
    "game_name": "Caro",
    "status": "finished",
    "result": "win",
    "opponent_username": "tta1612",
    "opponent_avatar_url": "https://example.com/avatar.jpg",
    "opponent_symbol": "O",
    "my_symbol": "X",
    "board_rows": 15,
    "board_cols": 19,
    "total_moves": 42,
    "created_at": "2025-10-26T10:30:00Z",
    "started_at": "2025-10-26T10:31:00Z",
    "finished_at": "2025-10-26T10:45:00Z",
    "duration_seconds": 840
  }
]
```

**Use Cases:**

- Hiển thị lịch sử đấu của mình
- Filter chỉ xem trận thắng: `?result=win`
- Filter chỉ xem trận thua: `?result=loss`
- Xem trận đang chơi: `?status=playing`
- Phân trang: `?limit=10&offset=0`

---

### 2. GET `/api/match-history/user/{user_id}` - Lịch sử đấu của người khác

**Description:** Xem lịch sử đấu của một người chơi khác.

**Path Parameters:**

- `user_id` (int): ID của người chơi

**Query Parameters:** Giống như `/my-matches`

**Headers:**

- `Authorization: Bearer <token>` (optional)

**Response:** Giống như `/my-matches`

**Use Cases:**

- Xem lịch sử đấu của đối thủ
- Research đối thủ trước khi thách đấu
- Xem profile người chơi khác

---

### 3. GET `/api/match-history/match/{match_id}` - Chi tiết trận đấu

**Description:** Lấy thông tin chi tiết đầy đủ của một trận đấu, bao gồm:

- Danh sách tất cả nước đi (moves)
- Ma trận bàn cờ
- Thông tin 2 người chơi
- Đường thắng (winning line)

**Path Parameters:**

- `match_id` (int): ID của trận đấu

**Headers:**

- `Authorization: Bearer <token>` (optional)

**Response:**

```json
{
  "match_id": 123,
  "game_name": "Caro",
  "status": "finished",
  "board_rows": 15,
  "board_cols": 19,
  "win_len": 5,
  "created_at": "2025-10-26T10:30:00Z",
  "started_at": "2025-10-26T10:31:00Z",
  "finished_at": "2025-10-26T10:45:00Z",
  "duration_seconds": 840,
  "players": [
    {
      "user_id": 5,
      "username": "devtest",
      "avatar_url": "https://example.com/avatar.jpg",
      "symbol": "X",
      "is_winner": true,
      "rating_before": 1400,
      "rating_after": 1450
    },
    {
      "user_id": 4,
      "username": "tta1612",
      "avatar_url": null,
      "symbol": "O",
      "is_winner": false,
      "rating_before": 1380,
      "rating_after": 1330
    }
  ],
  "moves": [
    {
      "turn_no": 1,
      "user_id": 5,
      "username": "devtest",
      "x": 7,
      "y": 9,
      "symbol": "X",
      "made_at": "2025-10-26T10:31:05Z"
    },
    {
      "turn_no": 2,
      "user_id": 4,
      "username": "tta1612",
      "x": 7,
      "y": 10,
      "symbol": "O",
      "made_at": "2025-10-26T10:31:12Z"
    }
  ],
  "board": [
    [null, null, null, "X", null, null],
    [null, "O", null, "X", null, null],
    ["X", "O", "X", "O", "X", null]
  ],
  "winning_line": [
    { "x": 2, "y": 0 },
    { "x": 2, "y": 2 },
    { "x": 2, "y": 4 },
    { "x": 2, "y": 6 },
    { "x": 2, "y": 8 }
  ]
}
```

**Response Fields:**

**`players`**: Mảng 2 người chơi

- `symbol`: 'X' hoặc 'O'
- `is_winner`: true/false/null (null = draw)

**`moves`**: Mảng tất cả nước đi theo thứ tự

- `turn_no`: Lượt thứ (1, 2, 3, ...)
- `x`, `y`: Tọa độ (0-indexed)
- `symbol`: 'X' hoặc 'O'

**`board`**: Ma trận 2D của bàn cờ

- Mỗi ô có giá trị: "X", "O", hoặc null (rỗng)
- board[x][y] = symbol tại tọa độ (x, y)

**`winning_line`**: Đường thắng (nếu có)

- Mảng các tọa độ tạo thành đường thắng
- null nếu trận hòa hoặc chưa kết thúc

**Use Cases:**

- Replay trận đấu
- Phân tích nước đi
- Học từ trận đấu của người khác
- Hiển thị màn hình "Match Detail"

---

### 4. GET `/api/match-history/stats/summary` - Tổng hợp thống kê

**Description:** Lấy tổng hợp thống kê nhanh của người dùng.

**Query Parameters:**

- `game_name` (string, optional): Tên game (mặc định: "Caro")

**Headers:**

- `Authorization: Bearer <token>` (required)

**Response:**

```json
{
  "total_matches": 37,
  "wins": 25,
  "losses": 10,
  "draws": 2,
  "win_rate": 67.57,
  "latest_match_id": 123,
  "latest_match_date": "2025-10-26T10:45:00Z"
}
```

**Use Cases:**

- Hiển thị stats overview
- Dashboard screen
- Profile summary

---

## Data Structures

### Match Status

- `waiting`: Chờ người chơi
- `playing`: Đang chơi
- `finished`: Đã kết thúc
- `abandoned`: Bị bỏ (disconnect, timeout)

### Match Result

- `win`: Thắng
- `loss`: Thua
- `draw`: Hòa

### Board Representation

Ma trận 2D:

```json
[
  [null, "X", null], // Row 0
  ["O", "X", null], // Row 1
  ["O", null, "X"] // Row 2
]
```

---

## Workflow cho Flutter App

### Screen: Match History List

```dart
// 1. Load match history
Future<List<MatchHistoryItem>> loadMyMatches({
  String? result,  // 'win', 'loss', 'draw'
  int limit = 10,
  int offset = 0,
}) async {
  final response = await dio.get(
    '/api/match-history/my-matches',
    queryParameters: {
      'limit': limit,
      'offset': offset,
      if (result != null) 'result': result,
    },
  );
  return (response.data as List)
      .map((e) => MatchHistoryItem.fromJson(e))
      .toList();
}

// 2. Load with filters
Future<List<MatchHistoryItem>> loadWins() {
  return loadMyMatches(result: 'win');
}

Future<List<MatchHistoryItem>> loadLosses() {
  return loadMyMatches(result: 'loss');
}

// 3. View match detail
Future<MatchDetailResponse> viewMatchDetail(int matchId) async {
  final response = await dio.get('/api/match-history/match/$matchId');
  return MatchDetailResponse.fromJson(response.data);
}
```

### Screen: Match Detail / Replay

```dart
class MatchReplayScreen extends StatefulWidget {
  final int matchId;

  @override
  State<MatchReplayScreen> createState() => _MatchReplayScreenState();
}

class _MatchReplayScreenState extends State<MatchReplayScreen> {
  MatchDetailResponse? matchDetail;
  int currentMoveIndex = 0;

  @override
  void initState() {
    super.initState();
    loadMatchDetail();
  }

  Future<void> loadMatchDetail() async {
    final detail = await api.viewMatchDetail(widget.matchId);
    setState(() {
      matchDetail = detail;
    });
  }

  // Replay từng nước đi
  void nextMove() {
    if (currentMoveIndex < matchDetail!.moves.length) {
      setState(() {
        currentMoveIndex++;
      });
    }
  }

  void previousMove() {
    if (currentMoveIndex > 0) {
      setState(() {
        currentMoveIndex--;
      });
    }
  }

  // Build board từ moves cho đến currentMoveIndex
  List<List<String?>> getCurrentBoard() {
    final board = List.generate(
      matchDetail!.board_rows,
      (_) => List<String?>.filled(matchDetail!.board_cols, null),
    );

    for (int i = 0; i < currentMoveIndex; i++) {
      final move = matchDetail!.moves[i];
      board[move.x][move.y] = move.symbol;
    }

    return board;
  }

  @override
  Widget build(BuildContext context) {
    if (matchDetail == null) {
      return CircularProgressIndicator();
    }

    return Column(
      children: [
        // Board view
        BoardWidget(
          board: getCurrentBoard(),
          winningLine: currentMoveIndex == matchDetail!.moves.length
              ? matchDetail!.winning_line
              : null,
        ),

        // Controls
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: previousMove,
            ),
            Text('Move $currentMoveIndex / ${matchDetail!.moves.length}'),
            IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: nextMove,
            ),
          ],
        ),

        // Move list
        MoveListWidget(
          moves: matchDetail!.moves,
          currentMoveIndex: currentMoveIndex,
          onMoveTap: (index) {
            setState(() {
              currentMoveIndex = index;
            });
          },
        ),
      ],
    );
  }
}
```

### Features để implement:

**Match History Screen:**

- Tab bar: All / Wins / Losses / Draws
- List view với infinite scroll
- Pull-to-refresh
- Card hiển thị: opponent, result badge, date, duration

**Match Detail Screen:**

- Board view (readonly)
- Player info cards (cả 2 người)
- Move list
- Replay controls (play/pause/step)
- Highlight winning line

**Stats Screen:**

- Win/Loss/Draw chart
- Total games
- Win rate
- Recent performance

---

## Filter Examples

### 1. Chỉ xem trận thắng

```bash
GET /api/match-history/my-matches?result=win&limit=10
```

### 2. Chỉ xem trận thua

```bash
GET /api/match-history/my-matches?result=loss&limit=10
```

### 3. Chỉ xem trận hòa

```bash
GET /api/match-history/my-matches?result=draw&limit=10
```

### 4. Xem trận đã kết thúc

```bash
GET /api/match-history/my-matches?status=finished&limit=10
```

### 5. Phân trang (load more)

```bash
# Page 1
GET /api/match-history/my-matches?limit=10&offset=0

# Page 2
GET /api/match-history/my-matches?limit=10&offset=10

# Page 3
GET /api/match-history/my-matches?limit=10&offset=20
```

---

## Board Rendering trong Flutter

```dart
class BoardWidget extends StatelessWidget {
  final List<List<String?>> board;
  final List<Map<String, int>>? winningLine;

  bool isWinningCell(int x, int y) {
    if (winningLine == null) return false;
    return winningLine!.any((cell) => cell['x'] == x && cell['y'] == y);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: board[0].length,
      ),
      itemCount: board.length * board[0].length,
      itemBuilder: (context, index) {
        final x = index ~/ board[0].length;
        final y = index % board[0].length;
        final symbol = board[x][y];
        final isWinning = isWinningCell(x, y);

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            color: isWinning ? Colors.yellow.withOpacity(0.3) : null,
          ),
          child: Center(
            child: Text(
              symbol ?? '',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: symbol == 'X' ? Colors.blue : Colors.red,
              ),
            ),
          ),
        );
      },
    );
  }
}
```

---

## Tips

### 1. Caching

Cache match detail để replay nhanh:

```dart
final Map<int, MatchDetailResponse> _matchCache = {};

Future<MatchDetailResponse> getMatchDetail(int matchId) async {
  if (_matchCache.containsKey(matchId)) {
    return _matchCache[matchId]!;
  }

  final detail = await api.viewMatchDetail(matchId);
  _matchCache[matchId] = detail;
  return detail;
}
```

### 2. Animation

Animate moves với delay:

```dart
void autoPlayMoves() async {
  for (int i = 0; i < matchDetail.moves.length; i++) {
    await Future.delayed(Duration(milliseconds: 500));
    setState(() {
      currentMoveIndex = i + 1;
    });
  }
}
```

### 3. Share Match

Tạo link để share trận đấu:

```dart
void shareMatch(int matchId) {
  final link = 'https://gameplus.com/match/$matchId';
  Share.share('Check out my match: $link');
}
```

---

## Error Handling

### Common Errors:

- `404 Not Found` - Match hoặc user không tồn tại
- `400 Bad Request` - Invalid filter values
- `401 Unauthorized` - Token không hợp lệ

### Example:

```json
{
  "detail": "Match not found"
}
```

---

## Performance Tips

1. **Lazy load moves**: Chỉ load moves khi user mở match detail
2. **Paginate history**: Load 10 items mỗi lần
3. **Cache boards**: Cache computed boards thay vì tính lại
4. **Optimize rendering**: Chỉ re-render cells thay đổi

---

## Future Enhancements

1. **Video Export**: Export replay thành video
2. **Share Replay**: Share link replay với bạn bè
3. **Analysis**: AI phân tích nước đi tốt/xấu
4. **Heatmap**: Hiển thị vùng hay đánh nhất
5. **Time per move**: Hiển thị thời gian suy nghĩ mỗi nước
