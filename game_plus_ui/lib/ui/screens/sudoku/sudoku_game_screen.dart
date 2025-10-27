import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_plus/core/sudoku/engine.dart';
import 'package:game_plus/core/sudoku/types.dart';

class SudokuGameScreen extends StatefulWidget {
  final String difficulty; // 'easy' | 'medium' | 'hard'
  const SudokuGameScreen({super.key, required this.difficulty});

  @override
  State<SudokuGameScreen> createState() => _SudokuGameScreenState();
}

class _SudokuGameScreenState extends State<SudokuGameScreen>
    with TickerProviderStateMixin {
  // --------- CORE ----------
  late SudokuEngine engine;

  // selection
  int selR = 0, selC = 0;
  bool notesMode = false;

  // timer & streak
  static const _streakKey = 'sudoku_streak';
  static const _bestKey = 'sudoku_best_streak';
  int _seconds = 0;
  Timer? _timer;
  int _streak = 0;
  int _best = 0;

  // sfx
  late final AudioPlayer _sfxCorrect = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);
  late final AudioPlayer _sfxMistake = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);
  late final AudioPlayer _sfxComplete = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);
  late final AudioPlayer _sfxSolve = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  // sparkle wave
  final _sparkles = <_Spark>[];
  late final Ticker _sparkTicker;
  Duration _lastTick = Duration.zero;

  // wrong flash
  int? _wrongR, _wrongC, _wrongDigit;
  late final AnimationController _wrongCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  // heart loss anim
  late final AnimationController _heartCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  // overlays
  bool _showWin = false;
  bool _showLose = false;

  // palette
  static const blue = Color(0xFF18A0FB);
  static const blueLight = Color(0xFF5EC0FF);
  static const boardBg = Color(0xFFEFF6FF);
  static const darkInk = Colors.black87;

  // overlay to convert global→local for sparkles
  final _overlayKey = GlobalKey();
  final _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    engine = SudokuEngine.newGame(widget.difficulty);
    _startTimer();
    _loadStreak();
    _sparkTicker = createTicker(_onSparkTick)..start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sparkTicker.dispose();
    _wrongCtrl.dispose();
    _heartCtrl.dispose();
    _sfxCorrect.dispose();
    _sfxMistake.dispose();
    _sfxComplete.dispose();
    _sfxSolve.dispose();
    super.dispose();
  }

  Future<void> _loadStreak() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _streak = sp.getInt(_streakKey) ?? 0;
      _best = sp.getInt(_bestKey) ?? 0;
    });
  }

  Future<void> _saveStreaks() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_streakKey, _streak);
    await sp.setInt(_bestKey, _best);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_showWin && !_showLose) setState(() => _seconds++);
    });
  }

  void _resetGame() {
    HapticFeedback.heavyImpact();
    setState(() {
      engine = SudokuEngine.newGame(widget.difficulty);
      _seconds = 0;
      _showWin = false;
      _showLose = false;
      selR = 0;
      selC = 0;
      _sparkles.clear();
      _wrongR = _wrongC = _wrongDigit = null;
    });
  }

  void _select(int r, int c) => setState(() {
    selR = r;
    selC = c;
  });

  Future<void> _play(AudioPlayer p, String asset, {double vol = 0.7}) async {
    try {
      await p.stop();
      await p.play(AssetSource(asset), volume: vol);
    } catch (_) {}
  }

  // ----------------- SPARKLES -----------------
  void _onSparkTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    var dt = (elapsed - _lastTick).inMilliseconds / 1000.0;
    _lastTick = elapsed;
    if (dt <= 0) return;
    if (dt > 1 / 15) dt = 1 / 15;

    bool alive = false;
    for (final s in _sparkles) {
      s.age += dt;
      if (s.age < s.life) {
        alive = true;
        s.v += s.gravity * dt;
        s.pos += s.v * dt;
      }
    }
    _sparkles.removeWhere((e) => e.age >= e.life);
    if (alive && mounted) setState(() {});
  }

  Offset _toOverlayLocal(Offset globalPos) {
    final rb = _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return globalPos;
    return rb.globalToLocal(globalPos);
  }

  Offset _cellCenterGlobal(int r, int c) {
    final box = _boardKey.currentContext!.findRenderObject() as RenderBox;
    final size = box.size;
    final cellW = size.width / 9;
    final cellH = size.height / 9;
    final topLeft = box.localToGlobal(Offset.zero);
    return Offset(
      topLeft.dx + c * cellW + cellW / 2,
      topLeft.dy + r * cellH + cellH / 2,
    );
  }

  void _emitSparkBurstAtCells(
    Iterable<Offset> globalCenters, {
    int count = 18,
  }) {
    final rnd = Random();
    for (final g in globalCenters) {
      final c = _toOverlayLocal(g);
      for (int i = 0; i < count; i++) {
        final ang = rnd.nextDouble() * pi * 2;
        final spd = 70 + rnd.nextDouble() * 160;
        _sparkles.add(
          _Spark(
            pos: c,
            v: Offset(cos(ang), sin(ang)) * spd,
            gravity: const Offset(0, 120),
            age: 0,
            life: .7 + rnd.nextDouble() * .4,
            size: 1.5 + rnd.nextDouble() * 2.5,
            color: blue.withOpacity(.95),
          ),
        );
      }
    }
  }

  void _sparkRow(int r) => _emitSparkBurstAtCells(
    List.generate(9, (i) => _cellCenterGlobal(r, i)),
    count: 8,
  );

  void _sparkCol(int c) => _emitSparkBurstAtCells(
    List.generate(9, (i) => _cellCenterGlobal(i, c)),
    count: 8,
  );

  void _sparkBlock(int br, int bc) {
    final list = <Offset>[];
    for (var i = 0; i < 3; i++)
      for (var j = 0; j < 3; j++) {
        list.add(_cellCenterGlobal(br * 3 + i, bc * 3 + j));
      }
    _emitSparkBurstAtCells(list, count: 8);
  }

  Future<void> _sparkAll() async {
    final waves = <List<Offset>>[];
    for (var diag = 0; diag <= 16; diag++) {
      final pts = <Offset>[];
      for (var r = 0; r < 9; r++) {
        final c = diag - r;
        if (c >= 0 && c < 9) pts.add(_cellCenterGlobal(r, c));
      }
      if (pts.isNotEmpty) waves.add(pts);
    }
    for (final w in waves) {
      _emitSparkBurstAtCells(w, count: 6);
      await Future.delayed(const Duration(milliseconds: 55));
    }
  }

  // ------------- completion checks ---------------
  bool _rowComplete(int r) {
    for (var c = 0; c < 9; c++) {
      final cell = engine.board.cells[r][c];
      if (cell.value == 0 || !cell.userLocked) return false;
    }
    return true;
  }

  bool _colComplete(int c) {
    for (var r = 0; r < 9; r++) {
      final cell = engine.board.cells[r][c];
      if (cell.value == 0 || !cell.userLocked) return false;
    }
    return true;
  }

  bool _blockComplete(int br, int bc) {
    for (var i = 0; i < 3; i++)
      for (var j = 0; j < 3; j++) {
        final r = br * 3 + i, c = bc * 3 + j;
        final cell = engine.board.cells[r][c];
        if (cell.value == 0 || !cell.userLocked) return false;
      }
    return true;
  }

  // praise text theo thời gian
  String _praise(int secs) {
    if (secs <= 120) return "Nhanh như chớp! ⚡";
    if (secs <= 300) return "Tập trung cực tốt! 🎯";
    if (secs <= 600) return "Bền bỉ và chắc tay! 💪";
    return "Không bỏ cuộc – quá đỉnh! 🙌";
  }

  // ---------------- INPUT ----------------
  void _onNumber(int n) async {
    if (_showWin || _showLose) return;
    HapticFeedback.selectionClick();
    final prevSolved = engine.isSolved;

    final res = notesMode
        ? engine.toggleNote(selR, selC, n)
        : engine.setNumber(selR, selC, n);

    if (res == MoveResult.mistake) {
      // flash đỏ số sai + mất tim
      _wrongR = selR;
      _wrongC = selC;
      _wrongDigit = n;
      _wrongCtrl
        ..reset()
        ..forward();
      _heartCtrl
        ..reset()
        ..forward();
      await _play(_sfxMistake, 'sfx/mistake.mp3', vol: 0.7);
      if (engine.livesLeft <= 0) {
        setState(() => _showLose = true);
      } else {
        setState(() {});
      }
      return;
    }
    if (res == MoveResult.rejectedGiven || res == MoveResult.rejectedLocked) {
      _toast('Ô này không thể thay đổi');
      return;
    }

    // đúng số hoặc solved
    await _play(_sfxCorrect, 'sfx/correct.mp3', vol: 0.6);

    if (_rowComplete(selR)) {
      _sparkRow(selR);
      _play(_sfxComplete, 'sfx/complete.mp3', vol: .5);
    }
    if (_colComplete(selC)) {
      _sparkCol(selC);
      _play(_sfxComplete, 'sfx/complete.mp3', vol: .5);
    }
    final br = selR ~/ 3, bc = selC ~/ 3;
    if (_blockComplete(br, bc)) {
      _sparkBlock(br, bc);
      _play(_sfxComplete, 'sfx/complete.mp3', vol: .5);
    }

    if (!prevSolved && engine.isSolved) {
      await _play(_sfxSolve, 'sfx/solve.mp3', vol: 0.75);
      _sparkAll();
      _streak += 1;
      if (_streak > _best) _best = _streak;
      await _saveStreaks();
      setState(() => _showWin = true);
    } else {
      setState(() {});
    }
  }

  void _erase() {
    if (_showWin || _showLose) return;
    HapticFeedback.lightImpact();
    final res = engine.eraseCell(selR, selC);
    if (res == MoveResult.rejectedGiven || res == MoveResult.rejectedLocked) {
      _toast('Ô này không thể xóa');
    }
    setState(() {});
  }

  void _hint() {
    if (_showWin || _showLose) return;
    HapticFeedback.mediumImpact();
    final wasSolved = engine.isSolved;
    final r = engine.hintFill();
    if (!wasSolved && r == MoveResult.solved) {
      _play(_sfxSolve, 'sfx/solve.mp3', vol: 0.75);
      _sparkAll();
      _streak += 1;
      if (_streak > _best) _best = _streak;
      _saveStreaks();
      setState(() => _showWin = true);
    } else {
      setState(() {});
    }
  }

  void _undo() {
    if (!_showWin && !_showLose && engine.canUndo()) {
      HapticFeedback.selectionClick();
      engine.undo();
      setState(() {});
    }
  }

  void _redo() {
    if (!_showWin && !_showLose && engine.canRedo()) {
      HapticFeedback.selectionClick();
      engine.redo();
      setState(() {});
    }
  }

  // --------------- UI --------------
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1100),
      ),
    );
  }

  String _fmtTime(int s) {
    final m = s ~/ 60;
    final ss = s % 60;
    return '${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final keypadCands = (engine.board.get(selR, selC) == 0)
        ? engine.candidatesAt(selR, selC)
        : <int>{};

    // Kéo cụm TOP gần trung tâm hơn (thấp hơn so với mép trên)
    const double topSectionHeight = 130;

    return Scaffold(
      backgroundColor: blue,
      body: SafeArea(
        child: Stack(
          key: _overlayKey,
          children: [
            Column(
              children: [
                // ======= TOP SECTION (KHÔNG PAUSE) =======
                SizedBox(
                  height: topSectionHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hàng 1: Back • [Streak + All Time] • Refresh
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _roundIcon(
                              Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.pop(context),
                            ),
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Transform.scale(
                                      scale: 0.85,
                                      child: _TopBadge(
                                        title: 'STREAK',
                                        value: '$_streak',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Transform.scale(
                                      scale: 0.85,
                                      child: _TopBadge(
                                        title: 'BEST',
                                        value: '$_best',
                                        crown: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _roundIcon(
                              Icons.refresh_rounded,
                              onTap: _resetGame,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),

                      const SizedBox(height: 8),

                      // Hàng tim
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final alive = i < engine.livesLeft;
                          return ScaleTransition(
                            scale: Tween(begin: 1.0, end: 0.7).animate(
                              CurvedAnimation(
                                parent: _heartCtrl,
                                curve: Curves.easeInOut,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Icon(
                                Icons.favorite,
                                color: alive
                                    ? Colors.red
                                    : Colors.red.withOpacity(.25),
                                size: 26,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // ======= BOARD (khung ngoài đậm) =======
                Expanded(
                  child: Container(
                    color: boardBg,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: darkInk, width: 4.0),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: RepaintBoundary(
                            key: _boardKey,
                            child: _Board(
                              engine: engine,
                              selR: selR,
                              selC: selC,
                              wrongR: _wrongR,
                              wrongC: _wrongC,
                              wrongDigit: _wrongDigit,
                              wrongAnim: _wrongCtrl,
                              onSelect: (r, c) {
                                if (!_showWin && !_showLose) {
                                  _select(r, c);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ======= TOOLBAR =======
                Container(
                  color: blue,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ToolTile(
                        icon: Icons.undo_rounded,
                        label: 'Undo',
                        onTap: _undo,
                        enabled: engine.canUndo(),
                      ),
                      _ToolTile(
                        icon: Icons.backspace_outlined,
                        label: 'Erase',
                        onTap: _erase,
                      ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _ToolTile(
                            icon: notesMode
                                ? Icons.edit_note_rounded
                                : Icons.notes_rounded,
                            label: 'Notes',
                            onTap: () => setState(() => notesMode = !notesMode),
                          ),
                          Positioned(
                            top: -8,
                            right: -10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.15),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Text(
                                notesMode ? 'ON' : 'OFF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      _ToolTile(
                        icon: Icons.lightbulb_rounded,
                        label: 'Hint',
                        onTap: _hint,
                      ),
                    ],
                  ),
                ),

                // ======= KEYPAD =======
                Container(
                  color: blue,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Tính toán width cho mỗi key để fit màn hình
                      final availableWidth = constraints.maxWidth;
                      final spacing = 4.0; // Spacing giữa các key
                      final totalSpacing =
                          spacing * 8; // 8 khoảng cách giữa 9 keys
                      final keyWidth = (availableWidth - totalSpacing) / 9;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(9, (i) {
                          final n = i + 1;
                          final isCand = (engine.board.get(selR, selC) == 0)
                              ? engine.candidatesAt(selR, selC).contains(n)
                              : false;
                          final opacity = (engine.board.get(selR, selC) != 0)
                              ? 0.30
                              : (isCand ? 1.0 : 0.28);
                          return SizedBox(
                            width: keyWidth,
                            child: _Key(
                              label: '$n',
                              onTap: () => _onNumber(n),
                              opacity: opacity,
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Sparkles layer
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _SparkPainter(_sparkles)),
              ),
            ),

            // ---------- Overlays ----------
            if (_showWin)
              _WinOverlay(
                timeText: _fmtTime(_seconds),
                praise: _praise(_seconds),
                onHome: () => Navigator.pop(context),
                onPlayNext: _resetGame,
                onStats: () {
                  /* TODO: mở stats */
                },
              ),
            if (_showLose)
              _LoseOverlay(
                onHome: () => Navigator.pop(context),
                onRetry: _resetGame, // “Chơi lại”
                onStats: () {
                  /* TODO: mở stats */
                },
              ),
          ],
        ),
      ),
    );
  }

  // small helpers
  Widget _roundIcon(IconData icon, {VoidCallback? onTap}) {
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
}

// ================== BOARD ==================

class _Board extends StatelessWidget {
  final SudokuEngine engine;
  final int selR, selC;
  final int? wrongR, wrongC, wrongDigit;
  final AnimationController wrongAnim;
  final void Function(int r, int c) onSelect;

  const _Board({
    required this.engine,
    required this.selR,
    required this.selC,
    required this.wrongR,
    required this.wrongC,
    required this.wrongDigit,
    required this.wrongAnim,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
      ),
      itemCount: 81,
      itemBuilder: (context, index) {
        final r = index ~/ 9, c = index % 9;
        final cell = engine.board.cells[r][c];
        final selected = (r == selR && c == selC);
        final sameRow = r == selR, sameCol = c == selC;
        final sameBlock = (r ~/ 3 == selR ~/ 3) && (c ~/ 3 == selC ~/ 3);

        final bg = selected
            ? const Color(0xFFD0E7FF)
            : (sameRow || sameCol || sameBlock)
            ? const Color(0xFFF2F8FF)
            : Colors.white;

        final BorderSide thin = const BorderSide(
          width: 1.0,
          color: Colors.black87,
        );
        final BorderSide thick = const BorderSide(
          width: 3.0,
          color: Colors.black87,
        );

        final border = Border(
          top: (r % 3 == 0) ? thick : thin,
          left: (c % 3 == 0) ? thick : thin,
          right: ((c + 1) % 3 == 0) ? thick : thin,
          bottom: ((r + 1) % 3 == 0) ? thick : thin,
        );

        // content
        Widget child;
        final isWrongFlash =
            (wrongR == r &&
            wrongC == c &&
            wrongDigit != null &&
            wrongAnim.isAnimating);

        if (isWrongFlash) {
          child = AnimatedBuilder(
            animation: wrongAnim,
            builder: (_, __) {
              final t = 1 - Curves.easeOut.transform(wrongAnim.value);
              return Transform.scale(
                scale: 0.85,
                child: Text(
                  '${wrongDigit!}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.red.withOpacity(t),
                    fontSize: 22,
                  ),
                ),
              );
            },
          );
        } else if (cell.value != 0) {
          child = Text(
            '${cell.value}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cell.given ? Colors.black : const Color(0xFF0D6EFD),
              fontSize: 20,
            ),
          );
        } else if (cell.notes.isNotEmpty) {
          child = _NotesGrid(notes: cell.notes);
        } else {
          child = const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => onSelect(r, c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(color: bg, border: border),
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
    );
  }
}

class _NotesGrid extends StatelessWidget {
  final Set<int> notes;
  const _NotesGrid({required this.notes});
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(4),
      children: List.generate(9, (i) {
        final n = i + 1;
        return Center(
          child: Text(
            notes.contains(n) ? '$n' : '',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }),
    );
  }
}

// ================== UI pieces ==================

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white : Colors.white70;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double opacity;
  const _Key({required this.label, required this.onTap, required this.opacity});
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.2, 1.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF5EC0FF),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  final String title;
  final String value;
  final bool crown;
  const _TopBadge({
    required this.title,
    required this.value,
    this.crown = false,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF083A51),
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
              color: Colors.tealAccent,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ================== Sparkles painter ==================

class _Spark {
  Offset pos;
  Offset v;
  Offset gravity;
  double age;
  double life;
  double size;
  Color color;
  _Spark({
    required this.pos,
    required this.v,
    required this.gravity,
    required this.age,
    required this.life,
    required this.size,
    required this.color,
  });
}

class _SparkPainter extends CustomPainter {
  final List<_Spark> list;
  _SparkPainter(this.list);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final s in list) {
      final t = (1 - s.age / s.life).clamp(0.0, 1.0);
      if (t <= 0) continue;
      p.color = s.color.withOpacity(t);
      canvas.drawCircle(s.pos, s.size * t, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) => true;
}

// ================== Overlays ==================

class _WinOverlay extends StatelessWidget {
  final String timeText;
  final String praise;
  final VoidCallback onHome;
  final VoidCallback onPlayNext;
  final VoidCallback onStats;
  const _WinOverlay({
    required this.timeText,
    required this.praise,
    required this.onHome,
    required this.onPlayNext,
    required this.onStats,
  });

  @override
  Widget build(BuildContext context) {
    return _Dim(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'YEAH, YOU DID IT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.amber.shade600,
                fontWeight: FontWeight.w900,
                fontSize: 42,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$praise  •  $timeText',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
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
                    label: 'PLAY NEXT',
                    color: const Color(0xFF31C25A),
                    onTap: onPlayNext,
                  ),
                ),
                const SizedBox(width: 16),
                _RoundSquareBtn(
                  color: const Color(0xFF8E72C7),
                  icon: Icons.bar_chart_rounded,
                  onTap: onStats,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoseOverlay extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onRetry;
  final VoidCallback onStats;
  const _LoseOverlay({
    required this.onHome,
    required this.onRetry,
    required this.onStats,
  });

  @override
  Widget build(BuildContext context) {
    return _Dim(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Spacer(),
          const Text(
            'Level Failed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Try again and beat it!",
            style: TextStyle(
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
                  color: const Color(0xFF8E72C7),
                  icon: Icons.bar_chart_rounded,
                  onTap: onStats,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _PrimaryBigBtn(
                    label: 'CHƠI LẠI',
                    color: const Color(0xFF31C25A),
                    onTap: onRetry,
                  ),
                ),
                const SizedBox(width: 16),
                _RoundSquareBtn(
                  color: const Color(0xFFE97A6A),
                  icon: Icons.home_rounded,
                  onTap: onHome,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dim extends StatelessWidget {
  final Widget child;
  const _Dim({required this.child});
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0B1120).withOpacity(.86),
        child: child,
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
