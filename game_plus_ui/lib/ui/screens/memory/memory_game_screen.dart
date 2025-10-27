import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Tương thích cả enum cũ & enum mới
import 'package:game_plus/configs/difficulty.dart' as legacy;
import 'package:game_plus/configs/memory_difficulty.dart';

enum MemoryMode { bot, friend }

class MemoryGameScreen extends StatefulWidget {
  final MemoryMode mode;
  final MemoryDifficulty? memoryDifficulty; // 4 mức (ưu tiên)
  final legacy.Difficulty? difficulty; // 3 mức (fallback)

  const MemoryGameScreen({
    super.key,
    required this.mode,
    this.memoryDifficulty,
    this.difficulty,
  });

  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen>
    with TickerProviderStateMixin {
  // ---------------- CONFIG ----------------
  late final _Config _cfg = _resolveConfig(
    widget.memoryDifficulty,
    widget.difficulty,
  );

  _Config _resolveConfig(MemoryDifficulty? md, legacy.Difficulty? ld) {
    if (md != null) {
      switch (md) {
        case MemoryDifficulty.easy:
          return const _Config(title: 'EASY', totalCards: 16, botSmart: .35);
        case MemoryDifficulty.medium:
          return const _Config(title: 'MEDIUM', totalCards: 18, botSmart: .65);
        case MemoryDifficulty.hard:
          return const _Config(title: 'HARD', totalCards: 20, botSmart: .85);
        case MemoryDifficulty.extraHard:
          return const _Config(
            title: 'EXTRA HARD',
            totalCards: 24,
            botSmart: 1.0,
          );
      }
    }
    switch (ld ?? legacy.Difficulty.easy) {
      case legacy.Difficulty.easy:
        return const _Config(title: 'EASY', totalCards: 16, botSmart: .35);
      case legacy.Difficulty.medium:
        return const _Config(title: 'MEDIUM', totalCards: 18, botSmart: .7);
      case legacy.Difficulty.hard:
        return const _Config(title: 'HARD', totalCards: 20, botSmart: .9);
    }
  }

  bool get _isBot => widget.mode == MemoryMode.bot;

  // ---------------- STATE ----------------
  late List<_CardModel> _deck;
  late int _pairsLeft;
  int _you = 0, _opponent = 0;
  int _turn = 0; // 0 = you/p1, 1 = bot/p2
  int? _pickedA;
  bool _lock = false;

  // human combo streak (chỉ người chơi)
  int _humanStreak = 0;

  // bot memory
  final Map<int, Set<int>> _botSeen = {};

  // hủy hành động bot (cancel token)
  int _botGen = 0;

  // layout (để animate bay ra giữa)
  Size _boardSize = Size.zero;
  List<Rect> _cardRects = const [];

  // combo banner
  late final AnimationController _comboCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  String _comboText = '';

  // banner đổi lượt (nửa hình tròn)
  late final AnimationController _turnCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  // overlay “bay ra giữa”
  late final AnimationController _flyCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  int? _flyA, _flyB; // index lá đang bay (ghost)
  Set<int> _hiding = {}; // ẩn lá gốc trong lúc bay
  bool get _flying => _flyA != null && _flyB != null;

  @override
  void initState() {
    super.initState();
    _newGame();
    _playTurnBanner();
  }

  @override
  void dispose() {
    _comboCtl.dispose();
    _turnCtl.dispose();
    _flyCtl.dispose();
    super.dispose();
  }

  void _newGame() {
    final pairs = _cfg.totalCards ~/ 2;
    _deck = _buildDeck(pairs);
    _pairsLeft = pairs;
    _you = _opponent = 0;
    _turn = 0;
    _pickedA = null;
    _lock = false;
    _botSeen.clear();
    _comboText = '';
    _comboCtl.reset();
    _turnCtl.reset();
    _flyCtl.reset();
    _flyA = _flyB = null;
    _hiding.clear();
    _humanStreak = 0;
    _botGen++; // hủy bot pending
    setState(() {});
    if (_isBot && _turn == 1) _queueBot();
  }

  List<_CardModel> _buildDeck(int pairs) {
    final rnd = Random();
    final icons = [
      Icons.favorite,
      Icons.star,
      Icons.pets,
      Icons.flash_on,
      Icons.cake,
      Icons.coffee,
      Icons.home,
      Icons.palette,
      Icons.icecream,
      Icons.spa,
      Icons.face,
      Icons.park,
      Icons.directions_bike,
      Icons.camera_alt,
      Icons.beach_access,
      Icons.bolt_rounded,
      Icons.anchor_rounded,
      Icons.sports_esports,
      Icons.music_note,
      Icons.travel_explore,
    ]..shuffle(rnd);

    final colors = [
      const Color(0xFF26C6DA),
      const Color(0xFF66BB6A),
      const Color(0xFFFFCA28),
      const Color(0xFFAB47BC),
      const Color(0xFFEF5350),
      const Color(0xFF42A5F5),
      const Color(0xFFFF7043),
      const Color(0xFF8D6E63),
      const Color(0xFFEC407A),
      const Color(0xFF7E57C2),
      const Color(0xFF26A69A),
      const Color(0xFF9CCC65),
      const Color(0xFFFFB74D),
      const Color(0xFF5C6BC0),
      const Color(0xFF26A69A),
    ]..shuffle(rnd);

    final list = <_CardModel>[];
    for (var i = 0; i < pairs; i++) {
      final pid = i;
      final ic = icons[i % icons.length];
      final co = colors[i % colors.length];
      list.add(_CardModel.newPair(pid, ic, co));
      list.add(_CardModel.newPair(pid, ic, co));
    }
    list.shuffle(rnd);
    for (var i = 0; i < list.length; i++) list[i].id = i;
    return list;
  }

  // ---------------- GAME FLOW ----------------
  Future<void> _onTap(int i) async {
    if (_lock || _flying) return;
    // Hủy mọi tác vụ bot đang chờ (người chơi thao tác)
    _botGen++;

    if (_deck[i].isMatched || _deck[i].isFaceUp) return;
    _flipUp(i);

    if (_pickedA == null) {
      _pickedA = i;
      return;
    }

    final a = _pickedA!;
    final b = i;
    _pickedA = null;
    _lock = true;

    await Future.delayed(const Duration(milliseconds: 300));
    final isMatch = _deck[a].pairId == _deck[b].pairId;

    if (isMatch) {
      _deck[a].isMatched = true;
      _deck[b].isMatched = true;
      _pairsLeft--;

      if (_turn == 0) {
        _you++;
        _humanStreak++;
        if (_humanStreak >= 2) _playComboBanner(_humanStreak);
      } else {
        _opponent++;
      }

      // animate 2 lá bay ra giữa (kích thước giữ nguyên)
      _botGen++; // hủy bot pending trong suốt thời gian bay
      await _flyMatchedToCenter(a, b);

      _lock = false;
      setState(() {});
      if (_pairsLeft == 0) {
        await Future.delayed(const Duration(milliseconds: 420));
        _showWinOverlay(); // chỉ show khi người chơi thắng (check bên trong)
        return;
      }
      if (_isBot && _turn == 1) _queueBot();
    } else {
      await Future.delayed(const Duration(milliseconds: 260));
      _flipDown(a);
      _flipDown(b);
      if (_turn == 0) _humanStreak = 0; // reset streak của người chơi khi miss
      _comboText = '';
      _comboCtl.reset();
      _switchTurn();
    }
  }

  void _switchTurn() {
    _turn = 1 - _turn;
    _lock = false;
    setState(() {});
    _playTurnBanner();
    // đổi lượt -> hủy bot cũ và xếp bot mới nếu cần
    _botGen++;
    if (_isBot && _turn == 1) _queueBot();
  }

  void _flipUp(int i) {
    _deck[i].isFaceUp = true;
    if (_isBot) {
      _botSeen.putIfAbsent(_deck[i].pairId, () => {}).add(i);
    }
    setState(() {});
  }

  void _flipDown(int i) {
    _deck[i].isFaceUp = false;
    setState(() {});
  }

  // ---------------- BANNERS / EFFECTS ----------------
  void _playComboBanner(int streak) {
    _comboText = 'COMBO x$streak';
    _comboCtl
      ..stop()
      ..reset()
      ..forward();
  }

  void _playTurnBanner() {
    _turnCtl
      ..stop()
      ..reset()
      ..forward();
  }

  // Bay 2 lá ra giữa rồi biến mất
  Future<void> _flyMatchedToCenter(int a, int b) async {
    if (_cardRects.isEmpty || _boardSize == Size.zero) return;

    _hiding
      ..add(a)
      ..add(b); // ẩn lá gốc
    _flyA = a;
    _flyB = b;
    _flyCtl
      ..stop()
      ..reset();
    setState(() {});

    await _flyCtl.forward();
    // fade out nhanh
    await Future.delayed(const Duration(milliseconds: 120));

    // đánh dấu remove
    _deck[a].isRemoved = true;
    _deck[b].isRemoved = true;
    _hiding.remove(a);
    _hiding.remove(b);
    _flyA = _flyB = null;
    setState(() {});
  }

  // ---------------- BOT với cancel token ----------------
  Future<void> _queueBot() async {
    if (!_isBot) return;

    // snapshot token
    final token = ++_botGen;

    Future<bool> alive([int delayMs = 0]) async {
      if (delayMs > 0) await Future.delayed(Duration(milliseconds: delayMs));
      return token == _botGen && _turn == 1 && !_flying && !_lock && mounted;
    }

    if (!await alive(520)) return;

    int? a = _chooseKnownSingle() ?? _chooseRandomFaceDown();
    if (a == null) return;
    if (!await alive()) return;
    await _onTapBot(a);

    if (!await alive(320)) return;
    int? b = _choosePairOf(a) ?? _chooseRandomFaceDown(except: a);
    if (b == null) return;
    if (!await alive()) return;
    await _onTapBot(b);
  }

  Future<void> _onTapBot(int i) async {
    HapticFeedback.selectionClick();
    await _onTap(i);
  }

  int? _chooseRandomFaceDown({int? except}) {
    final list = <int>[];
    for (var i = 0; i < _deck.length; i++) {
      if (i == except) continue;
      final c = _deck[i];
      if (!c.isRemoved && !c.isMatched && !c.isFaceUp) list.add(i);
    }
    if (list.isEmpty) return null;
    list.shuffle();
    return list.first;
  }

  int? _chooseKnownSingle() {
    if (Random().nextDouble() > _cfg.botSmart) return null;
    for (final e in _botSeen.entries) {
      if (e.value.length == 1) return e.value.first;
    }
    return null;
  }

  int? _choosePairOf(int a) {
    final pid = _deck[a].pairId;
    final seen = _botSeen[pid];
    if (seen == null) return null;
    if (Random().nextDouble() > _cfg.botSmart) return null;
    if (seen.length >= 2) {
      final other = seen.firstWhere((x) => x != a, orElse: () => -1);
      return (other >= 0 && !_deck[other].isMatched && !_deck[other].isRemoved)
          ? other
          : null;
    }
    return null;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final header = const Color(0xFFFFB39A);
    final boardColor = const Color(0xFF3E3E47);

    return Scaffold(
      backgroundColor: header,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 4),
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _roundIcon(
                        Icons.arrow_back_ios_new_rounded,
                        () => Navigator.pop(context),
                      ),
                      _scoreBadge(
                        title: _cfg.title,
                        left: _isBot ? 'YOU' : 'P1',
                        right: _isBot ? 'BOT' : 'P2',
                        lScore: _you,
                        rScore: _opponent,
                      ),
                      _roundIcon(Icons.refresh_rounded, _newGame),
                    ],
                  ),
                ),

                // BOARD
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: boardColor,
                      border: const Border(
                        top: BorderSide(color: Colors.black54, width: 4),
                        bottom: BorderSide(color: Colors.black54, width: 4),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (_, c) {
                        _boardSize = Size(c.maxWidth, c.maxHeight);
                        return _ScatterBoard(
                          deck: _deck,
                          hiding: _hiding,
                          onTap: (i) =>
                              (_turn == 0 || !_isBot) ? _onTap(i) : null,
                          onLayout: (rects) => _cardRects = rects,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            // COMBO BANNER (chỉ text _comboText)
            if (_comboText.isNotEmpty)
              Positioned(
                top: 56,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _comboCtl,
                  child: ScaleTransition(
                    scale: _comboCtl.drive(
                      Tween(
                        begin: .7,
                        end: 1.0,
                      ).chain(CurveTween(curve: Curves.elasticOut)),
                    ),
                    child: Center(child: _StrokeText(_comboText, size: 30)),
                  ),
                ),
              ),

            // đổi lượt (nửa hình tròn) – người chơi: cam/đỏ, P2/Bot: xanh
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizeTransition(
                    sizeFactor: _turnCtl.drive(
                      CurveTween(curve: Curves.easeOut),
                    ),
                    axisAlignment: -1,
                    child: _TurnSemicircle(
                      text: _turn == 0
                          ? (_isBot ? 'Your turn' : 'P1 turn')
                          : (_isBot ? 'Bot turn' : 'P2 turn'),
                      color: _turn == 0
                          ? const Color(0xFFE6957E)
                          : const Color.fromARGB(255, 66, 190, 228),
                    ),
                  ),
                ),
              ),
            ),

            // overlay bay ra giữa (vẽ trong khung board)
            if (_flying && _cardRects.length == _deck.length)
              Positioned(
                top:
                    MediaQuery.of(context).padding.top +
                    58, // trừ header + topbar
                left: 0,
                right: 0,
                bottom: 0,
                child: _FlyingPairLayer(
                  boardSize: _boardSize,
                  a: _deck[_flyA!],
                  b: _deck[_flyB!],
                  rectA: _cardRects[_flyA!],
                  rectB: _cardRects[_flyB!],
                  controller: _flyCtl,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- small widgets ----------
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

  Widget _scoreBadge({
    required String title,
    required String left,
    required String right,
    required int lScore,
    required int rScore,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2327),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
            ),
          ),
          Row(
            children: [
              Text(
                left,
                style: const TextStyle(
                  color: Color(0xFFE57373),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$lScore',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'VS',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$rScore',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                right,
                style: const TextStyle(
                  color: Color(0xFF64B5F6),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- WIN OVERLAY ----------------
  Future<void> _showWinOverlay() async {
    // chỉ show khi người chơi thắng
    if (_you < _opponent) return;
    await showGeneralDialog(
      context: context,
      barrierLabel: 'win',
      barrierDismissible: true,
      barrierColor: Colors.transparent, // để BackdropFilter tự làm mờ
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) {
        return _WinOverlay(
          onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onPlayAgain: () {
            Navigator.of(context).pop(); // đóng overlay
            _newGame();
          },
        );
      },
    );
  }
}

// ===================== Scatter board =====================

class _ScatterBoard extends StatelessWidget {
  final List<_CardModel> deck;
  final Set<int> hiding;
  final void Function(int index)? onTap;
  final void Function(List<Rect> rects) onLayout;

  const _ScatterBoard({
    required this.deck,
    required this.hiding,
    required this.onTap,
    required this.onLayout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final n = deck.length;

        // lưới gần sqrt + jitter
        final cols = max(3, min(5, (sqrt(n)).round()));
        final spacing = 10.0;
        final cellW = (w - (cols - 1) * spacing - 20) / cols;
        final cellH = cellW * 1.05;
        final rows = (n / cols).ceil();
        final startY = (h - (rows * cellH + (rows - 1) * spacing)) / 2;

        final rnd = Random(n);
        final rects = <Rect>[];
        final children = <Widget>[];

        for (var i = 0; i < n; i++) {
          final r = i ~/ cols;
          final cIdx = i % cols;

          double x = 10 + cIdx * (cellW + spacing);
          double y = startY + r * (cellH + spacing);
          x += (r.isEven ? 6 : -6);
          x += (rnd.nextDouble() - .5) * 6;
          y += (rnd.nextDouble() - .5) * 6;

          final rot = (rnd.nextDouble() - .5) * .18;
          rects.add(Rect.fromLTWH(x, y, cellW, cellH));

          final card = deck[i];
          if (card.isRemoved) continue;

          children.add(
            Positioned(
              left: x,
              top: y,
              width: cellW,
              height: cellH,
              child: Transform.rotate(
                angle: rot,
                child: Opacity(
                  opacity: hiding.contains(i) ? 0.0 : 1.0,
                  child: _FlipCard(
                    isFaceUp: card.isFaceUp || card.isMatched,
                    onTap: onTap == null ? null : () => onTap!(i),
                    front: _CardFaceFront(icon: card.icon, color: card.color),
                    back: _CardFaceBack(matched: card.isMatched),
                    pulse: card.isMatched,
                  ),
                ),
              ),
            ),
          );
        }

        // trả layout cho parent
        WidgetsBinding.instance.addPostFrameCallback((_) => onLayout(rects));

        return Stack(children: children);
      },
    );
  }
}

// ===================== Flying pair layer =====================

class _FlyingPairLayer extends StatelessWidget {
  final Size boardSize;
  final _CardModel a, b;
  final Rect rectA, rectB;
  final AnimationController controller;

  const _FlyingPairLayer({
    required this.boardSize,
    required this.a,
    required this.b,
    required this.rectA,
    required this.rectB,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final center = Offset(boardSize.width / 2, boardSize.height / 2);
    final aCenter = rectA.center;
    final bCenter = rectB.center;
    final aDelta = center - aCenter;
    final bDelta = center - bCenter;

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = Curves.easeOut.transform(controller.value);
        // dịch chuyển tới giữa, kích cỡ giữ nguyên, sau đó fade
        final fade = 1.0 - t * 0.9;

        return Stack(
          children: [
            Positioned.fromRect(
              rect: rectA.shift(aDelta * t),
              child: Opacity(
                opacity: fade,
                child: _CardFaceFront(icon: a.icon, color: a.color),
              ),
            ),
            Positioned.fromRect(
              rect: rectB.shift(bDelta * t),
              child: Opacity(
                opacity: fade,
                child: _CardFaceFront(icon: b.icon, color: b.color),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ===================== Turn semicircle =====================

class _TurnSemicircle extends StatelessWidget {
  final String text;
  final Color color;
  const _TurnSemicircle({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      color: Colors.transparent,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 300,
          height: 150,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: const Alignment(0, .32),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== Win overlay (blur nền) =====================

class _WinOverlay extends StatefulWidget {
  final VoidCallback onHome;
  final VoidCallback onPlayAgain;
  const _WinOverlay({required this.onHome, required this.onPlayAgain});

  @override
  State<_WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<_WinOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _starsCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _starsCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // blur nền + bóng mờ
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: Colors.black.withOpacity(.35)),
            ),
          ),

          // star burst
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _starsCtl,
              builder: (_, __) {
                final t = Curves.easeOut.transform(_starsCtl.value);
                final stars = <Widget>[];
                final rnd = Random(1);
                final size = MediaQuery.of(context).size;
                for (var i = 0; i < 28; i++) {
                  final dx = rnd.nextDouble() * size.width;
                  final dy = rnd.nextDouble() * size.height * .6;
                  final s = 12.0 + rnd.nextDouble() * 18.0;
                  stars.add(
                    Positioned(
                      left: dx,
                      top: dy * t,
                      child: Opacity(
                        opacity: min(1, t + .2),
                        child: Icon(
                          Icons.star_rounded,
                          color: Colors.amber.shade200,
                          size: s,
                        ),
                      ),
                    ),
                  );
                }
                return Stack(children: stars);
              },
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.emoji_events_rounded,
                size: 120,
                color: Color(0xFFFFC107),
              ),
              SizedBox(height: 12),
              _StrokeText('YOU WIN!', size: 42),
              SizedBox(height: 18),
            ],
          ),

          Positioned(
            bottom: 28,
            left: 18,
            right: 18,
            child: Row(
              children: [
                Expanded(
                  child: _largeBtn(
                    label: 'HOME',
                    color: const Color(0xFFE97A6A),
                    icon: Icons.home_rounded,
                    onTap: widget.onHome,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _largeBtn(
                    label: 'PLAY AGAIN',
                    color: const Color(0xFF31C25A),
                    icon: Icons.refresh_rounded,
                    onTap: widget.onPlayAgain,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _largeBtn({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// chữ có stroke nhẹ cho nổi bật
class _StrokeText extends StatelessWidget {
  final String text;
  final double size;
  const _StrokeText(this.text, {this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = Colors.black.withOpacity(.6),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFE74C3C),
          ),
        ),
      ],
    );
  }
}

// ===================== Card widgets =====================

class _FlipCard extends StatelessWidget {
  final bool isFaceUp;
  final bool pulse;
  final Widget front;
  final Widget back;
  final VoidCallback? onTap;

  const _FlipCard({
    required this.isFaceUp,
    required this.front,
    required this.back,
    this.onTap,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final angle = isFaceUp ? 0.0 : pi; // 0 = front, pi = back
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: angle, end: angle),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      builder: (_, value, child) {
        final showFront = value < pi / 2;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(value);
        final scale = pulse ? 1.0 + 0.04 * sin(value) : 1.0;

        return GestureDetector(
          onTap: onTap,
          child: Transform(
            alignment: Alignment.center,
            transform: transform..scale(scale),
            child: showFront
                ? front
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: back,
                  ),
          ),
        );
      },
    );
  }
}

class _CardFaceBack extends StatelessWidget {
  final bool matched;
  const _CardFaceBack({required this.matched});

  @override
  Widget build(BuildContext context) {
    final board = const Color(0xFF855561);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: matched ? board.withOpacity(.35) : board,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6F4350), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.15),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.help_rounded,
          color: Colors.white.withOpacity(matched ? .35 : .85),
          size: 34,
        ),
      ),
    );
  }
}

class _CardFaceFront extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _CardFaceFront({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.90), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 40)),
    );
  }
}

// ===================== Models =====================

class _CardModel {
  int id;
  final int pairId;
  final IconData icon;
  final Color color;

  bool isFaceUp = false;
  bool isMatched = false;
  bool isRemoved = false; // sau khi bay ra giữa, xóa khỏi board

  _CardModel({
    required this.id,
    required this.pairId,
    required this.icon,
    required this.color,
  });

  factory _CardModel.newPair(int pairId, IconData icon, Color color) =>
      _CardModel(id: -1, pairId: pairId, icon: icon, color: color);
}

class _Config {
  final String title;
  final int totalCards; // chẵn
  final double botSmart; // 0..1
  const _Config({
    required this.title,
    required this.totalCards,
    required this.botSmart,
  });
}
