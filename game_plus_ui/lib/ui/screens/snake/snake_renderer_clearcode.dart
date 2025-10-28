import 'package:flame/components.dart';
import 'package:flame/flame.dart';  // Đảm bảo bạn đã import Flame
import 'package:flutter/material.dart';

class SnakeAssetsClearCode {
  late final Sprite headUp, headDown, headLeft, headRight;
  late final Sprite tailUp, tailDown, tailLeft, tailRight;
  late final Sprite bodyHorizontal, bodyVertical;
  late final Sprite bodyTopLeft, bodyTopRight, bodyBottomLeft, bodyBottomRight;

  // Load assets (chỉ load một lần khi game bắt đầu)
  Future<void> load() async {
    headUp    = Sprite(await Flame.images.load('sprites/clearcode/head_up.png'));
    headDown  = Sprite(await Flame.images.load('sprites/clearcode/head_down.png'));
    headLeft  = Sprite(await Flame.images.load('sprites/clearcode/head_left.png'));
    headRight = Sprite(await Flame.images.load('sprites/clearcode/head_right.png'));

    tailUp    = Sprite(await Flame.images.load('sprites/clearcode/tail_up.png'));
    tailDown  = Sprite(await Flame.images.load('sprites/clearcode/tail_down.png'));
    tailLeft  = Sprite(await Flame.images.load('sprites/clearcode/tail_left.png'));
    tailRight = Sprite(await Flame.images.load('sprites/clearcode/tail_right.png'));

    bodyHorizontal  = Sprite(await Flame.images.load('sprites/clearcode/body_horizontal.png'));
    bodyVertical    = Sprite(await Flame.images.load('sprites/clearcode/body_vertical.png'));
    bodyTopLeft     = Sprite(await Flame.images.load('sprites/clearcode/body_topleft.png'));
    bodyTopRight    = Sprite(await Flame.images.load('sprites/clearcode/body_topright.png'));
    bodyBottomLeft  = Sprite(await Flame.images.load('sprites/clearcode/body_bottomleft.png'));
    bodyBottomRight = Sprite(await Flame.images.load('sprites/clearcode/body_bottomright.png'));
  }
}

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

  double _elapsed = 0.0;
  late List<Vector2> _prevWorld, _nextWorld;

  Vector2 _toWorld(Vector2 cell) => (cell + Vector2(0.5, 0.5)) * cellSize;

  @override
  Future<void> onLoad() async {
    // Tải assets
    await assets.load();

    // Tạo head
    head = SpriteComponent(
      size: Vector2.all(cellSize),
      anchor: Anchor.center,
    )..paint.filterQuality = FilterQuality.none;

    // Tạo body (bao gồm các thành phần thân và đuôi)
    body = List.generate(
      grid.length - 1,
          (_) => SpriteComponent(
        size: Vector2.all(cellSize),
        anchor: Anchor.center,
      )..paint.filterQuality = FilterQuality.none,
    );

    await add(head);
    for (final b in body) { await add(b); }

    // Thiết lập các vị trí ban đầu
    _prevWorld = grid.map(_toWorld).toList();
    _nextWorld = List.from(_prevWorld);

    _assignSpritesForCurrentGrid(); // chọn sprite ban đầu
    _applyTransform(0.0);           // đặt vị trí ban đầu
  }

  void onLogicalStep(List<Vector2> newGrid, {bool grew = false}) {
    // Chụp vị trí hiện tại
    _prevWorld = _currentWorldPositions();

    // Cập nhật grid
    grid
      ..clear()
      ..addAll(newGrid);

    // Thêm segment mới khi rắn lớn thêm
    if (grew) {
      final seg = SpriteComponent(
        size: Vector2.all(cellSize),
        anchor: Anchor.center,
      )..paint.filterQuality = FilterQuality.none;
      body.add(seg);
      add(seg);
    } else {
      // Đảm bảo body có độ dài đúng
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

    // Cập nhật sprite mới cho grid hiện tại
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
