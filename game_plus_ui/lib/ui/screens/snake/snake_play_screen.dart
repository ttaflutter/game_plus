import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// ===== Food definitions =====
enum FoodType { red, blue, purple, yellow }

int foodPoints(FoodType t) {
  switch (t) {
    case FoodType.red:
      return 1; // apple
    case FoodType.blue:
      return 2; // blueberry
    case FoodType.purple:
      return 3; // grape
    case FoodType.yellow:
      return 5; // banana
  }
}

String foodAsset(FoodType t) {
  switch (t) {
    case FoodType.red:
      return 'assets/images/apple.png';
    case FoodType.blue:
      return 'assets/images/blueberry.png';
    case FoodType.purple:
      return 'assets/images/grape.png';
    case FoodType.yellow:
      return 'assets/images/banana.png';
  }
}

class Food {
  final int x, y;
  final FoodType type;
  const Food(this.x, this.y, this.type);
}

class SnakePlayScreen extends StatefulWidget {
  const SnakePlayScreen({super.key});
  @override
  State<SnakePlayScreen> createState() => _SnakePlayScreenState();
}

class _SnakePlayScreenState extends State<SnakePlayScreen>
    with SingleTickerProviderStateMixin {
  // ===== Board size: 20 x 15 =====
  final int rows = 20; // cao
  final int cols = 15; // dài

  // Assets (14 sprite ClearCode)
  static const String _kSnakeDir = 'assets/sprites/clearcode/';

  // Game state (grid coords, head at index 0)
  // Khởi động: đầu nhìn "lên", thân/đuôi nằm phía dưới đầu
  List<List<int>> snake = [
    [7, 9],
    [7, 10],
    [7, 11],
  ];
  List<int> segIds = [0, 1, 2];
  int _nextId = 3;

  late Food food;

  String direction = 'up';
  String nextDirection = 'up';

  int score = 0;
  int pendingGrowth = 0;

  // Timing cho bước logic + tween vị trí
  final Duration tick = const Duration(milliseconds: 260);
  Timer? _logicTimer;

  // Controls
  final FocusNode _focusNode = FocusNode();
  bool isPlaying = false;

  // Audio
  late final AudioPlayer _sfxEat, _sfxStart, _sfxOver;

  // Random
  final randomGen = Random();

  // ===== Pulsing cho trái cây (2s một chu kỳ, to hơn chút) =====
  late final AnimationController _foodCtrl;
  late final Animation<double> _foodScale; // 1.0 <-> 1.2

  @override
  void initState() {
    super.initState();

    // Mồi ban đầu
    food = const Food(7, 13, FoodType.red);
    _createFoodSafe();

    // Audio
    _sfxEat = AudioPlayer()..setVolume(0.8);
    _sfxStart = AudioPlayer()..setVolume(0.9);
    _sfxOver = AudioPlayer()..setVolume(1.0);

    // Precache sprite để tránh giật lúc mới tải
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final p in [
        'head_up.png',
        'head_down.png',
        'head_left.png',
        'head_right.png',
        'tail_up.png',
        'tail_down.png',
        'tail_left.png',
        'tail_right.png',
        'body_horizontal.png',
        'body_vertical.png',
        'body_topleft.png',
        'body_topright.png',
        'body_bottomleft.png',
        'body_bottomright.png',
      ]) {
        precacheImage(AssetImage('$_kSnakeDir$p'), context);
      }
    });

    // Pulsing scale cho trái cây (2s, 1.0 -> 1.2)
    _foodCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _foodScale = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _foodCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _logicTimer?.cancel();
    _foodCtrl.dispose();
    _focusNode.dispose();
    _sfxEat.dispose();
    _sfxStart.dispose();
    _sfxOver.dispose();
    super.dispose();
  }

  // ===== Logic helpers =====
  bool _isOpposite(String a, String b) =>
      (a == 'up' && b == 'down') ||
      (a == 'down' && b == 'up') ||
      (a == 'left' && b == 'right') ||
      (a == 'right' && b == 'left');

  void _setNextDirection(String dir) {
    if (dir == direction || _isOpposite(direction, dir)) return;
    nextDirection = dir;
  }

  void _onKey(RawKeyEvent e) {
    if (e is! RawKeyDownEvent) return;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW)
      _setNextDirection('up');
    else if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS)
      _setNextDirection('down');
    else if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA)
      _setNextDirection('left');
    else if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD)
      _setNextDirection('right');
    else if (k == LogicalKeyboardKey.space) {
      isPlaying ? _pauseGame() : startGame();
    } else if (k == LogicalKeyboardKey.keyR) {
      startGame();
    }
  }

  // ===== Start / Pause / End =====
  void startGame() {
    _logicTimer?.cancel();
    setState(() {
      final cx = cols ~/ 2; // 7
      final cy = rows ~/ 2; // 10
      snake = [
        [cx, cy - 1], // head nhìn lên
        [cx, cy], // body
        [cx, cy + 1], // tail
      ];
      segIds = [0, 1, 2];
      _nextId = 3;

      direction = 'up';
      nextDirection = 'up';
      score = 0;
      pendingGrowth = 0;
      isPlaying = true;

      _createFoodSafe();
    });

    _logicTimer = Timer.periodic(tick, (_) => _stepLogicOnce());
    _playStart();
  }

  void _pauseGame() {
    setState(() => isPlaying = false);
    _logicTimer?.cancel();
  }

  void _endGame() {
    setState(() => isPlaying = false);
    _logicTimer?.cancel();
    _playOver();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Game Over',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text('Score: $score', style: const TextStyle(fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ===== One logic step (dịch 1 ô, AnimatedPositioned tween mượt) =====
  void _stepLogicOnce() {
    if (!mounted || !isPlaying) return;

    // cập nhật hướng
    direction = nextDirection;

    // tính đầu mới
    final head = snake.first;
    late List<int> newHead;
    switch (direction) {
      case 'up':
        newHead = [head[0], head[1] - 1];
        break;
      case 'down':
        newHead = [head[0], head[1] + 1];
        break;
      case 'left':
        newHead = [head[0] - 1, head[1]];
        break;
      case 'right':
        newHead = [head[0] + 1, head[1]];
        break;
    }

    // chèn đầu + id mới ở đầu
    setState(() {
      snake.insert(0, newHead);
      segIds.insert(0, _nextId++);
    });

    // Ăn mồi?
    final ate = (newHead[0] == food.x && newHead[1] == food.y);
    if (ate) {
      score += foodPoints(food.type);
      pendingGrowth += 1; // mỗi lần ăn dài thêm 1
      _playEat();
      _createFoodSafe();
    }

    // Dài thêm hay di chuyển thường?
    if (pendingGrowth > 0) {
      pendingGrowth -= 1; // giữ đuôi (không xoá)
    } else {
      setState(() {
        snake.removeLast();
        segIds.removeLast();
      });
    }

    // va chạm -> end
    if (_checkGameOverNow()) _endGame();
  }

  bool _checkGameOverNow() {
    final hx = snake.first[0], hy = snake.first[1];
    if (hx < 0 || hx >= cols || hy < 0 || hy >= rows) return true; // tường
    for (int i = 1; i < snake.length; i++) {
      if (snake[i][0] == hx && snake[i][1] == hy) return true; // cắn thân
    }
    return false;
  }

  // ===== Food =====
  FoodType _rollFoodType() {
    final r = randomGen.nextDouble();
    if (r < 0.60) return FoodType.red;
    if (r < 0.90) return FoodType.blue;
    if (r < 0.98) return FoodType.purple;
    return FoodType.yellow;
  }

  void _createFoodSafe() {
    while (true) {
      final x = randomGen.nextInt(cols);
      final y = randomGen.nextInt(rows);
      final overlaps = snake.any((p) => p[0] == x && p[1] == y);
      if (!overlaps) {
        food = Food(x, y, _rollFoodType());
        break;
      }
    }
  }

  // ===== Audio =====
  Future<void> _playStart() async {
    try {
      await _sfxStart.play(AssetSource('sfx/start.mp3'));
    } catch (_) {}
  }

  Future<void> _playEat() async {
    try {
      await _sfxEat.play(AssetSource('sfx/eat.mp3'));
    } catch (_) {}
  }

  Future<void> _playOver() async {
    try {
      await _sfxOver.play(AssetSource('sfx/over.mp3'));
    } catch (_) {}
  }

  // ===== Sprite mapping (14 ảnh ClearCode, không xoay để giữ nét) =====
  bool _eq(List<int> a, List<int> b) => a[0] == b[0] && a[1] == b[1];

  String _headPath(List<int> head, List<int> neck) {
    final dx = head[0] - neck[0], dy = head[1] - neck[1]; // +y đi xuống
    if (dx == 1 && dy == 0) return '${_kSnakeDir}head_right.png';
    if (dx == -1 && dy == 0) return '${_kSnakeDir}head_left.png';
    if (dx == 0 && dy == -1) return '${_kSnakeDir}head_up.png';
    return '${_kSnakeDir}head_down.png';
  }

  String _tailPath(List<int> beforeTail, List<int> tail) {
    // hướng từ đoạn trước đuôi -> ra ngoài đuôi
    final dx = tail[0] - beforeTail[0], dy = tail[1] - beforeTail[1];
    if (dx == 1 && dy == 0) return '${_kSnakeDir}tail_right.png';
    if (dx == -1 && dy == 0) return '${_kSnakeDir}tail_left.png';
    if (dx == 0 && dy == 1) return '${_kSnakeDir}tail_down.png';
    return '${_kSnakeDir}tail_up.png';
  }

  String _bodyPath(List<int> prev, List<int> cur, List<int> next) {
    // thẳng
    if (prev[1] == cur[1] && next[1] == cur[1])
      return '${_kSnakeDir}body_horizontal.png';
    if (prev[0] == cur[0] && next[0] == cur[0])
      return '${_kSnakeDir}body_vertical.png';

    // khúc cua
    final hasUp =
        (_eq(prev, [cur[0], cur[1] - 1]) || _eq(next, [cur[0], cur[1] - 1]));
    final hasDown =
        (_eq(prev, [cur[0], cur[1] + 1]) || _eq(next, [cur[0], cur[1] + 1]));
    final hasLeft =
        (_eq(prev, [cur[0] - 1, cur[1]]) || _eq(next, [cur[0] - 1, cur[1]]));
    final hasRight =
        (_eq(prev, [cur[0] + 1, cur[1]]) || _eq(next, [cur[0] + 1, cur[1]]));

    if (hasUp && hasRight) return '${_kSnakeDir}body_topright.png';
    if (hasUp && hasLeft) return '${_kSnakeDir}body_topleft.png';
    if (hasDown && hasLeft) return '${_kSnakeDir}body_bottomleft.png';
    return '${_kSnakeDir}body_bottomright.png';
  }

  String _bodyForTwo(List<int> head, List<int> body) {
    final dx = head[0] - body[0], dy = head[1] - body[1];
    if (dx != 0) return '${_kSnakeDir}body_horizontal.png';
    return '${_kSnakeDir}body_vertical.png';
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // ----- Bố cục hình chữ nhật theo tỉ lệ rows x cols -----
    final maxW = size.width;
    final maxH = size.height * 0.7; // chừa chỗ cho hàng nút dưới
    final cell = min(maxW / cols, maxH / rows); // cell để vừa cả 2 chiều
    final boardW = cols * cell;
    final boardH = rows * cell;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Snake', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[800],
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: boardW,
                height: boardH,
                child: RawKeyboardListener(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKey: _onKey,
                  child: GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    // Thêm swipe gestures cho mobile
                    onVerticalDragUpdate: (details) {
                      if (details.delta.dy > 5) {
                        _setNextDirection('down');
                      } else if (details.delta.dy < -5) {
                        _setNextDirection('up');
                      }
                    },
                    onHorizontalDragUpdate: (details) {
                      if (details.delta.dx > 5) {
                        _setNextDirection('right');
                      } else if (details.delta.dx < -5) {
                        _setNextDirection('left');
                      }
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E0E0E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 12),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            // Nền cờ vua xanh cỏ (đậm/nhạt) + lưới mờ
                            CustomPaint(
                              size: Size(boardW, boardH),
                              painter: _GridPainter(
                                rows: rows,
                                cols: cols,
                                cell: cell,
                              ),
                            ),

                            // Mồi: AnimatedPositioned + ScaleTransition (pulsing 2s, to hơn)
                            AnimatedPositioned(
                              left: food.x * cell,
                              top: food.y * cell,
                              width: cell,
                              height: cell,
                              duration: tick,
                              curve: Curves.linear,
                              child: Center(
                                child: ScaleTransition(
                                  scale: _foodScale, // 1.0 -> 1.2 trong 2s
                                  child: Image.asset(
                                    foodAsset(food.type),
                                    width: cell,
                                    height: cell,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.none,
                                  ),
                                ),
                              ),
                            ),

                            // Rắn: AnimatedPositioned tween mượt giữa hai ô
                            ..._buildSnakeWidgets(cell),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Hàng nút dưới: chỉ giữ Start/End và điểm
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 16, right: 16),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: () => isPlaying ? _pauseGame() : startGame(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPlaying ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  child: Text(isPlaying ? 'End' : 'Start'),
                ),
                const SizedBox(width: 12),
                _ScoreBadge(score: score),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSnakeWidgets(double cell) {
    final w = <Widget>[];
    for (int i = 0; i < snake.length; i++) {
      final seg = snake[i];
      final id = segIds[i];

      late String path;
      if (i == 0) {
        if (snake.length >= 2) {
          path = _headPath(snake[0], snake[1]);
        } else {
          path = '${_kSnakeDir}head_up.png';
        }
      } else if (snake.length == 2 && i == 1) {
        path = _bodyForTwo(snake[0], snake[1]);
      } else if (i == snake.length - 1 && snake.length >= 3) {
        path = _tailPath(snake[i - 1], snake[i]);
      } else {
        path = _bodyPath(snake[i - 1], snake[i], snake[i + 1]);
      }

      w.add(
        AnimatedPositioned(
          key: ValueKey('seg_$id'),
          left: seg[0] * cell,
          top: seg[1] * cell,
          width: cell,
          height: cell,
          duration: tick,
          curve: Curves.easeInOut,
          child: Image.asset(
            path,
            width: cell,
            height: cell,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
      );
    }
    return w;
  }
}

/// Bàn cờ xanh cỏ xen kẽ (đậm/nhạt) + lưới mờ
class _GridPainter extends CustomPainter {
  final int rows, cols;
  final double cell;
  _GridPainter({required this.rows, required this.cols, required this.cell});
  @override
  void paint(Canvas canvas, Size size) {
    const light = Color(0xFF2E7D32);
    const dark = Color(0xFF1B5E20);
    final fill = Paint();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        fill.color = ((r + c) % 2 == 0) ? light : dark;
        canvas.drawRect(Rect.fromLTWH(c * cell, r * cell, cell, cell), fill);
      }
    }
    final grid = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (int c = 1; c < cols; c++) {
      final x = c * cell;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (int r = 1; r < rows; r++) {
      final y = r * cell;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.rows != rows || old.cols != cols || old.cell != cell;
}

/// Badge điểm gọn (không chữ)
class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stacked_line_chart, color: Colors.white70, size: 18),
          const SizedBox(width: 6),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
