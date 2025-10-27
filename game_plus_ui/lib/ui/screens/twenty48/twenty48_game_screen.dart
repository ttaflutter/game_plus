import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:game_plus/core/twenty48/engine.dart';

/// difficulty: 'easy' | 'medium' | 'hard' (mặc định: 'medium')
class Twenty48GameScreen extends StatefulWidget {
  final String difficulty;
  const Twenty48GameScreen({super.key, this.difficulty = 'medium'});

  @override
  State<Twenty48GameScreen> createState() => _Twenty48GameScreenState();
}

class _Twenty48GameScreenState extends State<Twenty48GameScreen>
    with TickerProviderStateMixin {
  // ------------------ CORE ------------------
  late Game2048 game;
  int best = 0;

  // ------------------ ANIM ------------------
  late final AnimationController moveCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260), // chậm & mượt
  );
  late final AnimationController spawnCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    lowerBound: .65,
    upperBound: 1.0,
  );

  bool _inputLocked = false;

  // states phục vụ animation
  List<List<int>>? _before; // grid trước khi move
  List<_MoveAnim> _moves = []; // các tile đang trượt
  _SpawnTile? _pendingSpawn; // tile spawn sau khi trượt
  Set<_Cell> _destinations = {}; // tập vị trí đích (để ẩn đứng yên đúng ô)
  Map<_Cell, int> _destNewValues = {}; // giá trị mới ở đích (để hiển thị sớm)

  // ------------------ UI palette ------------------
  static const bg = Color(0xFFC97565);
  static const board = Color(0xFF855561);
  static const boardEdge = Color(0xFF6F4350);
  static const badge = Color(0xFF4D332E);

  // swipe detect
  Offset _dragStart = Offset.zero;
  Offset _delta = Offset.zero;
  static const _swipeThresh = 90;

  double get _spawn4Prob {
    switch (widget.difficulty) {
      case 'easy':
        return 0.05;
      case 'hard':
        return 0.20;
      default:
        return 0.10;
    }
  }

  // overlays
  bool _win = false;
  bool _lose = false;

  @override
  void initState() {
    super.initState();
    game = Game2048(spawn4Prob: _spawn4Prob);
    _loadBest();

    // khi trượt xong -> nếu có spawn thì scale-in, rồi cleanup anim
    moveCtl.addStatusListener((s) async {
      if (s == AnimationStatus.completed && _pendingSpawn != null) {
        await spawnCtl.forward(from: .65);
        _pendingSpawn = null;
        _finishAnimCycle();
      } else if (s == AnimationStatus.completed) {
        _finishAnimCycle();
      }
    });
  }

  @override
  void dispose() {
    moveCtl.dispose();
    spawnCtl.dispose();
    super.dispose();
  }

  // --------------- PERSIST BEST ---------------
  Future<void> _loadBest() async {
    final sp = await SharedPreferences.getInstance();
    setState(() => best = sp.getInt('ttfe_best') ?? 0);
  }

  Future<void> _saveBest() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('ttfe_best', best);
  }

  // --------------- HELPERS ---------------
  List<List<int>> _copy(List<List<int>> g) => [
    for (final r in g) [...r],
  ];
  bool _isSpawnValue(int v) => v == 2 || v == 4;

  void _restart() {
    setState(() {
      _win = _lose = false;
      _clearAnimState();
      game.reset();
    });
  }

  void _undo() {
    if (_inputLocked) return;
    if (game.canUndo()) {
      setState(() {
        _clearAnimState();
        game.undo();
      });
    }
  }

  void _clearAnimState() {
    _moves.clear();
    _pendingSpawn = null;
    _destinations.clear();
    _destNewValues.clear();
    _before = null;
    moveCtl.value = 0;
    spawnCtl.value = .65;
  }

  // Kết thúc chu kỳ anim, check thắng/thua, mở khóa input
  void _finishAnimCycle() {
    if (game.maxTile > best) {
      best = game.maxTile;
      _saveBest();
    }
    // QUAN TRỌNG: xóa dữ liệu anim để không “phân thân”
    _clearAnimState();
    setState(() {});
    _inputLocked = false;

    if (!game.hasMove) {
      setState(() => _lose = true);
    }
    if (game.maxTile >= 2048) {
      setState(() => _win = true);
    }
  }

  // --------------- SWIPE ---------------
  Future<void> _swipe(Dir d) async {
    if (_inputLocked || _win || _lose) return;
    _inputLocked = true;

    // 1) chụp state trước move
    _before = _copy(game.grid);

    // 2) engine thực hiện move (đã gồm spawn)
    final changed = game.move(d);
    if (!changed) {
      _inputLocked = false;
      return;
    }

    // 3) tính dữ liệu anim cho UI
    final after = _copy(game.grid);
    final calc = _computeMovesAndSpawn(_before!, after, d);
    _moves = calc.moves;
    _pendingSpawn = calc.spawn;
    _destinations = calc.destinations;
    _destNewValues = calc.destNewValues;

    setState(() {}); // cho grid build với dữ liệu mới
    await moveCtl.forward(from: 0); // trượt
  }

  // --------------- BUILD ---------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 8),

                // TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _roundIcon(
                        Icons.arrow_back_ios_new_rounded,
                        () => Navigator.pop(context),
                      ),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: _badge(
                                'MODE',
                                widget.difficulty.toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: _badge('BEST', '$best', crown: true),
                            ),
                          ],
                        ),
                      ),
                      _roundIcon(Icons.refresh_rounded, _restart),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // BOARD
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GestureDetector(
                        onPanStart: (d) {
                          _dragStart = d.localPosition;
                          _delta = Offset.zero;
                        },
                        onPanUpdate: (d) {
                          _delta = d.localPosition - _dragStart;
                        },
                        onPanEnd: (_) {
                          final dx = _delta.dx, dy = _delta.dy;
                          if (dx.abs() < _swipeThresh &&
                              dy.abs() < _swipeThresh)
                            return;
                          if (dx.abs() > dy.abs()) {
                            _swipe(dx > 0 ? Dir.right : Dir.left);
                          } else {
                            _swipe(dy > 0 ? Dir.down : Dir.up);
                          }
                          _delta = Offset.zero;
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: board,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: boardEdge, width: 6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.15),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(10),
                          child: _AnimatedGrid(
                            before: _before,
                            after: game.grid,
                            moves: _moves,
                            moveAnim: moveCtl,
                            spawnAnim: spawnCtl,
                            spawn: _pendingSpawn,
                            destinations: _destinations,
                            destNewValues: _destNewValues,
                            boardColor: boardEdge,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // UNDO
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _undo,
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2B233),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.18),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.undo_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Undo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),

            // OVERLAYS
            if (_win)
              _TTFEOverlay.win(
                onHome: () => Navigator.pop(context),
                onRestart: _restart,
              ),
            if (_lose)
              _TTFEOverlay.lose(
                onHome: () => Navigator.pop(context),
                onRestart: _restart,
              ),
          ],
        ),
      ),
    );
  }

  // widgets nhỏ
  Widget _badge(String title, String value, {bool crown = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: badge,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (crown) ...[
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.tealAccent,
                  size: 16,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .6,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black87),
      ),
    );
  }

  // ---------------- MOVE CALC ----------------

  _CalcResult _computeMovesAndSpawn(
    List<List<int>> before,
    List<List<int>> after,
    Dir dir,
  ) {
    _SpawnTile? spawn;

    // tìm spawn (before=0 & after in {2,4})
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        if (before[r][c] == 0 && _isSpawnValue(after[r][c])) {
          spawn = _SpawnTile(r: r, c: c, value: after[r][c]);
        }
      }
    }

    // after không gồm spawn để tính mapping
    final afterNoSpawn = _copy(after);
    if (spawn != null) afterNoSpawn[spawn.r][spawn.c] = 0;

    final moves = <_MoveAnim>[];
    final dests = <_Cell>{};

    final forward = dir == Dir.left || dir == Dir.up;

    for (int i = 0; i < 4; i++) {
      List<int> bLine, aLine;

      if (dir == Dir.left || dir == Dir.right) {
        bLine = [for (int c = 0; c < 4; c++) before[i][c]];
        aLine = [for (int c = 0; c < 4; c++) afterNoSpawn[i][c]];
      } else {
        bLine = [for (int r = 0; r < 4; r++) before[r][i]];
        aLine = [for (int r = 0; r < 4; r++) afterNoSpawn[r][i]];
      }

      final mapping = _lineMapping(bLine, aLine, forward);

      for (final m in mapping) {
        int fr = 0, fc = 0, tr = 0, tc = 0;
        if (dir == Dir.left || dir == Dir.right) {
          fr = i;
          fc = m.from;
          tr = i;
          tc = m.to;
        } else {
          fr = m.from;
          fc = i;
          tr = m.to;
          tc = i;
        }
        if (dir == Dir.right) {
          fc = 3 - fc;
          tc = 3 - tc;
        }
        if (dir == Dir.down) {
          fr = 3 - fr;
          tr = 3 - tr;
        }

        moves.add(
          _MoveAnim(
            value: m.value,
            fromR: fr,
            fromC: fc,
            toR: tr,
            toC: tc,
            merged: m.merged,
          ),
        );
        dests.add(_Cell(tr, tc));
      }
    }

    // giá trị mới tại các đích => lấy trực tiếp từ afterNoSpawn (đảm bảo chính xác)
    final destNewValues = <_Cell, int>{};
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final cell = _Cell(r, c);
        if (dests.contains(cell) && afterNoSpawn[r][c] != 0) {
          destNewValues[cell] = afterNoSpawn[r][c];
        }
      }
    }

    return _CalcResult(
      moves: moves,
      spawn: spawn,
      destinations: dests,
      destNewValues: destNewValues,
    );
  }

  /// Mapping trong 1 line (4 phần tử) từ before -> afterNoSpawn.
  /// Trả về list các bước di chuyển theo chỉ số 0..3 (theo chiều forward).
  List<_LineMove> _lineMapping(
    List<int> before,
    List<int> after,
    bool forward,
  ) {
    List<int> b = forward ? before : before.reversed.toList();
    List<int> a = forward ? after : after.reversed.toList();

    // nguồn
    final srcIdx = <int>[];
    final srcVal = <int>[];
    for (int i = 0; i < 4; i++) {
      if (b[i] != 0) {
        srcIdx.add(i);
        srcVal.add(b[i]);
      }
    }

    // đích (không 0)
    final dstVal = <int>[];
    for (int i = 0; i < 4; i++) {
      if (a[i] != 0) dstVal.add(a[i]);
    }

    final out = <_LineMove>[];
    int write = 0;
    int i = 0;
    while (i < srcVal.length) {
      if (write >= dstVal.length) break;

      final cur = srcVal[i];
      final hasPair = (i + 1 < srcVal.length) && (srcVal[i + 1] == cur);

      if (hasPair && dstVal[write] == cur * 2) {
        out.add(
          _LineMove(from: srcIdx[i], to: write, value: cur, merged: true),
        );
        out.add(
          _LineMove(from: srcIdx[i + 1], to: write, value: cur, merged: true),
        );
        i += 2;
        write += 1;
      } else {
        out.add(
          _LineMove(from: srcIdx[i], to: write, value: cur, merged: false),
        );
        i += 1;
        write += 1;
      }
    }

    if (!forward) {
      for (final m in out) {
        m.from = 3 - m.from;
        m.to = 3 - m.to;
      }
    }
    return out;
  }
}

// ===================== GRID WIDGET (animated) =====================

class _AnimatedGrid extends StatelessWidget {
  final List<List<int>>? before; // null -> không có anim
  final List<List<int>> after;
  final List<_MoveAnim> moves;
  final Animation<double> moveAnim;
  final Animation<double> spawnAnim;
  final _SpawnTile? spawn;
  final Set<_Cell> destinations; // vị trí đích của các ô trượt
  final Map<_Cell, int> destNewValues; // giá trị mới ở đích (để hiển thị sớm)
  final Color boardColor;

  const _AnimatedGrid({
    required this.before,
    required this.after,
    required this.moves,
    required this.moveAnim,
    required this.spawnAnim,
    required this.spawn,
    required this.destinations,
    required this.destNewValues,
    required this.boardColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final cell = (c.maxWidth - 15) / 4; // 3*5 spacing
        const spacing = 5.0;

        Widget baseGrid = GridView.count(
          crossAxisCount: 4,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          children: List.generate(
            16,
            (_) => Container(
              decoration: BoxDecoration(
                color: boardColor.withOpacity(.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );

        // Không có anim: vẽ toàn bộ "after"
        if (before == null || moves.isEmpty) {
          return Stack(
            children: [baseGrid, ..._tilesFromGrid(after, cell, spacing)],
          );
        }

        // Có anim
        return AnimatedBuilder(
          animation: moveAnim,
          builder: (_, __) {
            // nếu anim đã hoàn tất, trả về lưới sau cùng để tránh “phân thân”
            if (moveAnim.value >= 0.999) {
              return Stack(
                children: [baseGrid, ..._tilesFromGrid(after, cell, spacing)],
              );
            }

            final afterNoSpawn = [
              for (final r in after) [...r],
            ];
            if (spawn != null) afterNoSpawn[spawn!.r][spawn!.c] = 0;

            final t = Curves.easeInOutCubic.transform(moveAnim.value);

            return Stack(
              children: [
                baseGrid,

                // 1) Ô đứng yên (không phải đích)
                ..._staticTiles(afterNoSpawn, destinations, cell, spacing),

                // 2) Preview ô ĐÍCH với GIÁ TRỊ MỚI (fade lên từ 70% anim)
                ...destNewValues.entries.map((e) {
                  final appear = ((t - .7) / .3).clamp(0.0, 1.0);
                  return Positioned(
                    left: e.key.c * (cell + spacing),
                    top: e.key.r * (cell + spacing),
                    width: cell,
                    height: cell,
                    child: Opacity(
                      opacity: appear,
                      child: Transform.scale(
                        scale: .88 + .12 * appear,
                        child: _Tile(value: e.value),
                      ),
                    ),
                  );
                }),

                // 3) Ô đang trượt
                ...moves.map((m) {
                  final dx = (m.toC - m.fromC) * (cell + spacing) * t;
                  final dy = (m.toR - m.fromR) * (cell + spacing) * t;
                  final left = m.fromC * (cell + spacing) + dx;
                  final top = m.fromR * (cell + spacing) + dy;

                  // merge: pop nhẹ ở cuối
                  final scale = m.merged ? (1.0 + 0.06 * sin(t * pi)) : 1.0;

                  return Positioned(
                    left: left,
                    top: top,
                    width: cell,
                    height: cell,
                    child: Transform.scale(
                      scale: scale,
                      child: _Tile(value: m.value),
                    ),
                  );
                }),

                // 4) Spawn ô mới (scale-in)
                if (spawn != null)
                  AnimatedBuilder(
                    animation: spawnAnim,
                    builder: (_, __) {
                      final left = spawn!.c * (cell + spacing);
                      final top = spawn!.r * (cell + spacing);
                      return Positioned(
                        left: left,
                        top: top,
                        width: cell,
                        height: cell,
                        child: Transform.scale(
                          scale: spawnAnim.value,
                          child: _Tile(value: spawn!.value),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _tilesFromGrid(List<List<int>> g, double cell, double spacing) {
    final children = <Widget>[];
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final v = g[r][c];
        if (v == 0) continue;
        children.add(
          Positioned(
            left: c * (cell + spacing),
            top: r * (cell + spacing),
            width: cell,
            height: cell,
            child: _Tile(value: v),
          ),
        );
      }
    }
    return children;
  }

  // Ô đứng yên = tất cả ô trong afterNoSpawn trừ những ô là điểm đến của các moves
  List<Widget> _staticTiles(
    List<List<int>> afterNoSpawn,
    Set<_Cell> destinations,
    double cell,
    double spacing,
  ) {
    final children = <Widget>[];
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        final v = afterNoSpawn[r][c];
        if (v == 0) continue;
        if (destinations.contains(_Cell(r, c))) continue; // sẽ có tile tới
        children.add(
          Positioned(
            left: c * (cell + spacing),
            top: r * (cell + spacing),
            width: cell,
            height: cell,
            child: _Tile(value: v),
          ),
        );
      }
    }
    return children;
  }
}

// ===================== SMALL UI PIECES =====================

class _Tile extends StatelessWidget {
  final int value;
  const _Tile({required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = _tileColors(value);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: TextStyle(
          color: colors.fg,
          fontWeight: FontWeight.w900,
          fontSize: value >= 1024
              ? 26
              : value >= 128
              ? 30
              : 34,
        ),
      ),
    );
  }

  _TileColors _tileColors(int v) {
    switch (v) {
      case 2:
        return _TileColors(const Color(0xFFF2EAD8), const Color(0xFF2E2E2E));
      case 4:
        return _TileColors(const Color(0xFFEFE1C6), const Color(0xFF2E2E2E));
      case 8:
        return _TileColors(const Color(0xFFF6B17A), Colors.white);
      case 16:
        return _TileColors(const Color(0xFFE79F62), Colors.white);
      case 32:
        return _TileColors(const Color(0xFFE28462), Colors.white);
      case 64:
        return _TileColors(const Color(0xFFD96C5F), Colors.white);
      case 128:
        return _TileColors(const Color(0xFFCDBB7D), const Color(0xFF2E2E2E));
      case 256:
        return _TileColors(const Color(0xFFBFAE6F), const Color(0xFF2E2E2E));
      case 512:
        return _TileColors(const Color(0xFFAFA05F), Colors.white);
      case 1024:
        return _TileColors(const Color(0xFF8C874A), Colors.white);
      case 2048:
        return _TileColors(const Color(0xFF7C7A3F), Colors.white);
      default:
        return _TileColors(const Color(0xFF766B61), Colors.white);
    }
  }
}

class _TileColors {
  final Color bg;
  final Color fg;
  const _TileColors(this.bg, this.fg);
}

// ===================== OVERLAYS =====================

class _TTFEOverlay extends StatelessWidget {
  final bool win;
  final VoidCallback onHome;
  final VoidCallback onRestart;

  const _TTFEOverlay._({
    required this.win,
    required this.onHome,
    required this.onRestart,
  });

  factory _TTFEOverlay.win({
    required VoidCallback onHome,
    required VoidCallback onRestart,
  }) => _TTFEOverlay._(win: true, onHome: onHome, onRestart: onRestart);

  factory _TTFEOverlay.lose({
    required VoidCallback onHome,
    required VoidCallback onRestart,
  }) => _TTFEOverlay._(win: false, onHome: onHome, onRestart: onRestart);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0B1120).withOpacity(.86),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Spacer(),
            Text(
              win ? 'YEAH, YOU DID IT' : 'GAME OVER',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: win ? Colors.amber.shade600 : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 42,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              win
                  ? 'Mức tile cao khủng khiếp! 🎉'
                  : 'Thử lại để phá kỷ lục nhé!',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
              child: Row(
                children: [
                  _RoundSquareBtn(
                    color: const Color(0xFFE97A6A),
                    icon: Icons.home_rounded,
                    onTap: onHome,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _PrimaryBigBtn(
                      label: win ? 'PLAY NEXT' : 'CHƠI LẠI',
                      color: const Color(0xFF31C25A),
                      onTap: onRestart,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _RoundSquareBtn(
                    color: const Color(0xFF8E72C7),
                    icon: Icons.bar_chart_rounded,
                    onTap: () {}, // TODO: thống kê
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryBigBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PrimaryBigBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class _RoundSquareBtn extends StatelessWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _RoundSquareBtn({
    required this.color,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 68,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

// ===================== DATA CLASSES =====================

class _Cell {
  final int r, c;
  const _Cell(this.r, this.c);
  @override
  bool operator ==(Object other) =>
      other is _Cell && other.r == r && other.c == c;
  @override
  int get hashCode => Object.hash(r, c);
}

class _LineMove {
  int from;
  int to;
  int value;
  bool merged;
  _LineMove({
    required this.from,
    required this.to,
    required this.value,
    required this.merged,
  });
}

class _MoveAnim {
  final int value;
  final int fromR, fromC;
  final int toR, toC;
  final bool merged;
  _MoveAnim({
    required this.value,
    required this.fromR,
    required this.fromC,
    required this.toR,
    required this.toC,
    required this.merged,
  });
}

class _SpawnTile {
  final int r, c, value;
  _SpawnTile({required this.r, required this.c, required this.value});
}

class _CalcResult {
  final List<_MoveAnim> moves;
  final _SpawnTile? spawn;
  final Set<_Cell> destinations;
  final Map<_Cell, int> destNewValues;
  _CalcResult({
    required this.moves,
    required this.spawn,
    required this.destinations,
    required this.destNewValues,
  });
}
