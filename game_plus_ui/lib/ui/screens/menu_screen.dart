import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_plus/configs/difficulty.dart';

typedef PlayBuilder = Widget Function(BuildContext ctx, Difficulty diff);

class GameMenuScreen extends StatefulWidget {
  final String title; // Tiêu đề (vd: SUDOKU / NUMBER SLIDE)
  final Map<Difficulty, String> images; // ảnh theo độ khó
  final Map<Difficulty, Color> primaryColors; // màu theo độ khó
  final String prefKey; // key lưu diff riêng cho từng game
  final PlayBuilder onPlay; // điều hướng vào game tương ứng

  // ✨ NEW: Slot chèn control tuỳ biến (ví dụ toggle VS Bot / 2 Players)
  // Sẽ render ngay dưới slider.
  final Widget Function(
    BuildContext context,
    Difficulty difficulty,
    ValueNotifier<bool> vsBot,
  )?
  extraControlsBuilder;

  // ✨ NEW: Cho phép truyền vào một ValueNotifier để đọc chế độ ngoài (nếu cần)
  final ValueNotifier<bool>? vsBot;

  const GameMenuScreen({
    super.key,
    required this.title,
    required this.images,
    required this.primaryColors,
    required this.prefKey,
    required this.onPlay,
    this.extraControlsBuilder,
    this.vsBot,
  });

  @override
  State<GameMenuScreen> createState() => _GameMenuScreenState();
}

class _GameMenuScreenState extends State<GameMenuScreen>
    with TickerProviderStateMixin {
  Difficulty difficulty = Difficulty.easy;

  late final AudioPlayer _sfxChange = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);
  late final AudioPlayer _sfxPlay = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  late final AnimationController _bgCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);
  late final Animation<double> _pulse = Tween<double>(
    begin: 0,
    end: 0.06,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulseCtrl);
  late final AnimationController _cloudCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  final List<_Particle> _particles = [];
  late final Ticker _particleTicker;
  Duration _lastTick = Duration.zero;

  static const _topBlueA = Color(0xFF2196F3);
  static const _topBlueB = Color(0xFF1976D2);
  static const _bottomCream = Color(0xFFFFF1E2);
  static const _helpPurple = Color(0xFF7D57C2);

  Color get _primary => widget.primaryColors[difficulty]!;
  String get _asset => widget.images[difficulty]!;
  int get _sliderIndex => Difficulty.values.indexOf(difficulty);

  // ✨ NEW: nếu ngoài không truyền vào thì tự tạo
  late final ValueNotifier<bool> _vsBot =
      widget.vsBot ?? ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _loadLastDifficulty();
    _particleTicker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _cloudCtrl.dispose();
    _particleTicker.dispose();
    _sfxChange.dispose();
    _sfxPlay.dispose();
    if (widget.vsBot == null) _vsBot.dispose(); // chỉ dispose nếu tự tạo
    super.dispose();
  }

  Future<void> _loadLastDifficulty() async {
    final sp = await SharedPreferences.getInstance();
    final idx = sp.getInt(widget.prefKey);
    if (idx != null && idx >= 0 && idx <= 2) {
      setState(() => difficulty = Difficulty.values[idx]);
    }
  }

  Future<void> _saveDifficulty() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(widget.prefKey, _sliderIndex);
  }

  Future<void> _playChangeSfx() async {
    try {
      await _sfxChange.stop();
      await _sfxChange.play(AssetSource('sfx/change.mp3'), volume: .5);
    } catch (_) {}
  }

  Future<void> _playPlaySfx() async {
    try {
      await _sfxPlay.stop();
      await _sfxPlay.play(AssetSource('sfx/play.mp3'), volume: .6);
    } catch (_) {}
  }

  void _spawnParticles(Offset center, Color color) {
    final rnd = Random();
    for (int i = 0; i < 24; i++) {
      final ang = rnd.nextDouble() * pi * 2;
      final spd = 40 + rnd.nextDouble() * 120;
      _particles.add(
        _Particle(
          position: center,
          velocity: Offset(cos(ang), sin(ang)) * spd,
          life: 0.0,
          maxLife: 0.9 + rnd.nextDouble() * 0.6,
          color: color.withOpacity(0.9),
          size: 2 + rnd.nextDouble() * 4,
          gravity: Offset(0, 30 + rnd.nextDouble() * 40),
        ),
      );
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMilliseconds / 1000.0;
    _lastTick = elapsed;
    if (dt <= 0) return;
    bool anyAlive = false;
    for (final p in _particles) {
      p.life += dt;
      if (p.life < p.maxLife) {
        anyAlive = true;
        p.velocity += p.gravity * dt;
        p.position += p.velocity * dt;
      }
    }
    if (anyAlive) setState(() {});
  }

  void _onSlider(double v, Size screen, double emojiY) {
    final i = v.round().clamp(0, 2);
    if (i != _sliderIndex) {
      setState(() => difficulty = Difficulty.values[i]);
      HapticFeedback.lightImpact();
      _playChangeSfx();
      final center = Offset(screen.width / 2, emojiY);
      _spawnParticles(center, _primary);
      _saveDifficulty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final baseH = 844.0;
    final scale = screen.height / baseH;

    final topH = 270.0 * scale;
    final headerPad = EdgeInsets.fromLTRB(
      16 * scale,
      12 * scale,
      16 * scale,
      0,
    );
    final iconHeaderSize = 40.0 * scale;
    final emojiOuter = 88.0 * scale;
    final emojiInner = 76.0 * scale;
    final sliderTrackH = 22.0 * scale;
    final playH = 60.0 * scale;
    final squareBtn = 56.0 * scale;

    final emojiCenterY =
        MediaQuery.of(context).padding.top +
        8 * scale +
        12 * scale +
        iconHeaderSize +
        12 * scale +
        28 * scale +
        8 * scale +
        topH * 0.10 +
        (emojiOuter);

    return Scaffold(
      backgroundColor: _bottomCream,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // top gradient
            AnimatedBuilder(
              animation: _bgCtrl,
              builder: (context, _) {
                final t = _bgCtrl.value;
                final c1 = Color.lerp(_topBlueA, _topBlueB, t)!;
                final c2 = Color.lerp(_topBlueB, _topBlueA, t)!;
                return Container(
                  height: topH,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c1, c2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                );
              },
            ),
            // clouds
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _cloudCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _CloudPainter(progress: _cloudCtrl.value),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            // content
            Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).padding.top + 8 * scale,
                ),
                // header
                Padding(
                  padding: headerPad,
                  child: Row(
                    children: [
                      _circleIcon(
                        icon: Icons.arrow_back_ios_new_rounded,
                        bg: Colors.white,
                        fg: Colors.black87,
                        size: iconHeaderSize,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      _circleIcon(
                        icon: Icons.settings_rounded,
                        size: iconHeaderSize,
                        onTap: () {},
                      ),
                      SizedBox(width: 12 * scale),
                      _circleIcon(
                        icon: Icons.star_rounded,
                        size: iconHeaderSize,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                // title
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24 * scale,
                    vertical: 12 * scale,
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                          fontSize: 28 * scale,
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      Text(
                        'Play, train your brain and beat your highscore',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 13 * scale,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                // emoji
                SizedBox(height: (topH * 0.10)),
                _EmojiFadeScale(
                  key: ValueKey(_asset),
                  outer: emojiOuter,
                  inner: emojiInner,
                  image: _asset,
                ),
                SizedBox(height: 24 * scale),
                // difficulty label
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: _primary,
                    fontSize: 38 * scale,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    height: 1,
                  ),
                  child: Text(difficulty.label),
                ),
                SizedBox(height: 14 * scale),
                // slider
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28 * scale),
                  child: Column(
                    children: [
                      _DifficultySlider(
                        value: _sliderIndex.toDouble(),
                        activeColor: _primary,
                        trackHeight: sliderTrackH,
                        onChanged: (v) => setState(
                          () => difficulty = Difficulty.values[v.round()],
                        ),
                        onChangedEnd: (v) => _onSlider(v, screen, emojiCenterY),
                      ),
                      SizedBox(height: 8 * scale),
                      Text(
                        'Drag to adjust difficulty',
                        style: TextStyle(
                          color: const Color(0xFF404040),
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      // ✨ NEW: chỗ chèn control tuỳ biến (toggle VS Bot / 2P,…)
                      if (widget.extraControlsBuilder != null) ...[
                        SizedBox(height: 12 * scale),
                        widget.extraControlsBuilder!(
                          context,
                          difficulty,
                          _vsBot,
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                // footer
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    22 * scale,
                    0,
                    22 * scale,
                    20 * scale,
                  ),
                  child: Row(
                    children: [
                      _squareSolid(
                        size: squareBtn,
                        color: _primary,
                        icon: Icons.bar_chart_rounded,
                        onTap: () {},
                      ),
                      SizedBox(width: 14 * scale),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) {
                            final s = 1.0 + _pulse.value;
                            return Transform.scale(
                              scale: s,
                              child: _PlayButton(
                                height: playH,
                                color: _primary,
                                label: 'PLAY',
                                onTap: () async {
                                  await _playPlaySfx();
                                  HapticFeedback.mediumImpact();
                                  // gọi builder do từng game truyền vào
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          widget.onPlay(context, difficulty),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 14 * scale),
                      _squareSolid(
                        size: squareBtn,
                        color: _helpPurple,
                        icon: Icons.help_rounded,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // particles
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ParticlePainter(particles: _particles),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==== small widgets reused (copy y nguyên từ file của bạn) ====
  Widget _circleIcon({
    required IconData icon,
    required double size,
    Color bg = const Color(0xFFFFFFFF),
    Color fg = Colors.black87,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(size),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg.withOpacity(0.96),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: fg, size: size * 0.55),
      ),
    );
  }

  Widget _squareSolid({
    required double size,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.38),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: size * 0.5, color: Colors.white),
      ),
    );
  }
}

// ==== components giữ nguyên từ màn cũ ====
class _EmojiFadeScale extends StatelessWidget {
  final double outer;
  final double inner;
  final String image;
  const _EmojiFadeScale({
    super.key,
    required this.outer,
    required this.inner,
    required this.image,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: .95, end: 1).animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(image),
        padding: EdgeInsets.all(6 * (outer / 88)),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: Container(
            width: inner,
            height: inner,
            color: Colors.black,
            padding: EdgeInsets.all(6 * (inner / 76)),
            child: ClipOval(
              child: Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFE0E0E0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DifficultySlider extends StatelessWidget {
  final double value;
  final Color activeColor;
  final double trackHeight;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangedEnd;
  const _DifficultySlider({
    required this.value,
    required this.activeColor,
    required this.trackHeight,
    required this.onChanged,
    required this.onChangedEnd,
  });
  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: trackHeight,
        activeTrackColor: activeColor,
        inactiveTrackColor: const Color(0xFFBDBDBD),
        thumbColor: Colors.white,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 16,
          pressedElevation: 4,
        ),
        overlayColor: activeColor.withOpacity(0.15),
        trackShape: const RoundedRectSliderTrackShape(),
        inactiveTickMarkColor: Colors.transparent,
        activeTickMarkColor: Colors.transparent,
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 0),
      ),
      child: Slider(
        value: value,
        min: 0,
        max: 2,
        divisions: 2,
        onChanged: onChanged,
        onChangeEnd: onChangedEnd,
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  final double progress;
  _CloudPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final topHeight = min(size.height * 0.32, 300);
    final y = topHeight * 0.6;
    final p = Paint()..color = Colors.white.withOpacity(0.15);
    final p2 = Paint()..color = Colors.white.withOpacity(0.10);
    final dx = (progress * size.width);
    void drawCloud(Offset center, double r, Paint pp) {
      canvas.drawCircle(center.translate(-r * 0.8, 0), r * 0.9, pp);
      canvas.drawCircle(center.translate(-r * 0.3, -r * 0.4), r * 0.75, pp);
      canvas.drawCircle(center, r, pp);
      canvas.drawCircle(center.translate(r * 0.5, -r * 0.35), r * 0.8, pp);
      canvas.drawCircle(center.translate(r * 0.9, 0), r * 0.6, pp);
    }

    drawCloud(Offset(dx - size.width * 0.7, y), 60, p);
    drawCloud(Offset(dx - size.width * 0.2, y - 18), 48, p2);
    drawCloud(Offset(dx + size.width * 0.3, y + 10), 54, p);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Particle {
  Offset position, velocity, gravity;
  double life, maxLife, size;
  Color color;
  _Particle({
    required this.position,
    required this.velocity,
    required this.gravity,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter({required this.particles});
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (1 - (p.life / p.maxLife)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final paint = Paint()..color = p.color.withOpacity(t);
      canvas.drawCircle(p.position, p.size * t, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _PlayButton extends StatefulWidget {
  final String label;
  final Color color;
  final double height;
  final VoidCallback onTap;
  const _PlayButton({
    required this.label,
    required this.color,
    required this.height,
    required this.onTap,
  });
  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.0,
    upperBound: 0.06,
  );
  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapCancel: () => _press.reverse(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, __) => Transform.scale(
          scale: 1 - _press.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
