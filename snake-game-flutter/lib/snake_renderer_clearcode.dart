import 'package:flame/components.dart';
import 'snake_assets_clearcode.dart';

/// grid: danh sách ô (Vector2(x,y) nguyên), index 0 là head.
/// Y tăng xuống dưới (mặc định của Flame). Nếu bạn dùng hệ trục khác, đảo ngược up/down ở hàm _headSprite/_tailSprite/_bodySprite.
class SnakeRendererClearCode extends Component with HasGameRef {
  final double cellSize;    // ví dụ 64 nếu ảnh 64px; hoặc 32 nếu muốn scale nhỏ
  final double tickSeconds; // 0.18–0.22 là vừa mắt
  final List<Vector2> grid; // dữ liệu logic hiện tại (ô đầu -> ô cuối)
  final SnakeAssetsClearCode assets;

  SnakeRendererClearCode({
    required this.cellSize,
    required this.tickSeconds,
    required this.grid,
    required this.assets,
  });

  late final SpriteComponent head;
  late final List<SpriteComponent> body; // gồm cả thân giữa và đuôi (tail ở cuối)

  // nội suy giữa 2 trạng thái logic
  double _elapsed = 0.0;
  late List<Vector2> _prevWorld, _nextWorld;

  Vector2 _toWorld(Vector2 cell) => (cell + Vector2(0.5, 0.5)) * cellSize;

  @override
  Future<void> onLoad() async {
    await assets.load(game.images);

    head = SpriteComponent(
      size: Vector2.all(cellSize),
      anchor: Anchor.center,
    )..paint.filterQuality = FilterQuality.none;

    body = List.generate(
      grid.length - 1,
      (_) => SpriteComponent(
        size: Vector2.all(cellSize),
        anchor: Anchor.center,
      )..paint.filterQuality = FilterQuality.none,
    );

    await add(head);
    for (final b in body) { await add(b); }

    _prevWorld = grid.map(_toWorld).toList();
    _nextWorld = List.from(_prevWorld);

    _assignSpritesForCurrentGrid(); // chọn sprite ban đầu
    _applyTransform(0.0);           // đặt vị trí ban đầu
  }

  /// Gọi hàm này MỖI KHI logic sang “tick” mới (rắn tiến thêm 1 ô).
  /// newGrid: danh sách ô mới (head ở index 0).
  /// grew: true nếu vừa ăn mồi và dài thêm 1.
  void onLogicalStep(List<Vector2> newGrid, {bool grew = false}) {
    // chụp vị trí hiện tại (để nội suy)
    _prevWorld = _currentWorldPositions();

    // cập nhật grid
    grid
      ..clear()
      ..addAll(newGrid);

    // thêm segment mới khi lớn
    if (grew) {
      final seg = SpriteComponent(
        size: Vector2.all(cellSize),
        anchor: Anchor.center,
      )..paint.filterQuality = FilterQuality.none;
      body.add(seg);
      add(seg);
    } else {
      // đảm bảo body = grid.length - 1
      while (body.length > grid.length - 1) {
        final removed = body.removeLast();
        removed.removeFromParent();
      }
      while (body.length < grid.length - 1) {
        final seg = SpriteComponent(
          size: Vector2.all(cellSize),
          anchor: Anchor.center,
        )..paint.filterQuality = FilterQuality.none;
        body.add(seg);
        add(seg);
      }
    }

    _nextWorld = grid.map(_toWorld).toList();
    _elapsed = 0.0;

    // Chọn sprite theo hướng/khúc cua mới (chỉ update 1 lần ở đầu tick — không “animation” khi đổi hướng)
    _assignSpritesForCurrentGrid();
  }

  List<Vector2> _currentWorldPositions() {
    final list = <Vector2>[];
    list.add(head.position.clone());
    for (final b in body) list.add(b.position.clone());
    return list;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_nextWorld.isEmpty) return;
    _elapsed += dt;
    final t = (_elapsed / tickSeconds).clamp(0.0, 1.0);
    _applyTransform(t);
  }

  void _applyTransform(double t) {
    final n = _nextWorld.length;
    for (int i = 0; i < n; i++) {
      final p0 = _prevWorld[i];
      final p1 = _nextWorld[i];
      final pos = p0 + (p1 - p0) * t;

      if (i == 0) {
        head.position.setFrom(pos);
      } else {
        body[i - 1].position.setFrom(pos);
      }
    }
  }

  // -------------------- chọn sprite theo lưới --------------------

  void _assignSpritesForCurrentGrid() {
    if (grid.isEmpty) return;
    // Head
    if (grid.length >= 2) {
      head.sprite = _headSprite(grid[0], grid[1]);
    } else {
      // chỉ có 1 ô — cho head facing right mặc định
      head.sprite = assets.headRight;
    }

    // Middle + Tail
    for (int i = 1; i < grid.length; i++) {
      final comp = body[i - 1];
      if (i == grid.length - 1) {
        // tail
        final tail = grid[i];
        final before = grid[i - 1];
        comp.sprite = _tailSprite(before, tail);
      } else {
        // body giữa
        final prev = grid[i - 1];
        final cur  = grid[i];
        final next = grid[i + 1];
        comp.sprite = _bodySprite(prev, cur, next);
      }
    }
  }

  // vector đơn vị theo lưới
  static final Vector2 up    = Vector2(0, -1);
  static final Vector2 down  = Vector2(0,  1);
  static final Vector2 left  = Vector2(-1, 0);
  static final Vector2 right = Vector2(1,  0);

  Sprite _headSprite(Vector2 headCell, Vector2 neckCell) {
    final d = headCell - neckCell; // hướng từ cổ -> đầu
    if (d == right) return assets.headRight;
    if (d == left)  return assets.headLeft;
    if (d == up)    return assets.headUp;
    return assets.headDown; // d == down
  }

  Sprite _tailSprite(Vector2 beforeTail, Vector2 tailCell) {
    final d = beforeTail - tailCell; // hướng từ đuôi -> trước đuôi
    if (d == right) return assets.tailRight;
    if (d == left)  return assets.tailLeft;
    if (d == up)    return assets.tailUp;
    return assets.tailDown; // d == down
  }

  Sprite _bodySprite(Vector2 prev, Vector2 cur, Vector2 next) {
    final inDir  = cur - prev;  // từ prev -> cur
    final outDir = next - cur;  // từ cur -> next

    // thẳng
    if ((inDir.x != 0 && outDir.x != 0)) return assets.bodyHorizontal;
    if ((inDir.y != 0 && outDir.y != 0)) return assets.bodyVertical;

    // khúc cua: xét "tập" hướng có mặt
    final hasUp    = (inDir == up)    || (outDir == up);
    final hasDown  = (inDir == down)  || (outDir == down);
    final hasLeft  = (inDir == left)  || (outDir == left);
    final hasRight = (inDir == right) || (outDir == right);

    if (hasUp && hasRight)   return assets.bodyTopRight;
    if (hasUp && hasLeft)    return assets.bodyTopLeft;
    if (hasDown && hasLeft)  return assets.bodyBottomLeft;
    // hasDown && hasRight
    return assets.bodyBottomRight;
  }
}
