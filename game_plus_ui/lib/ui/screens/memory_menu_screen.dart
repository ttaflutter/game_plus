import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum 4 mức dành riêng cho Memory
import 'package:game_plus/configs/memory_difficulty.dart';
// Enum cũ 3 mức của các game khác (alias: legacy)
import 'package:game_plus/configs/difficulty.dart' as legacy;

import 'package:game_plus/ui/screens/memory_game_screen.dart';

class MemoryMenuScreen extends StatefulWidget {
  const MemoryMenuScreen({super.key});

  @override
  State<MemoryMenuScreen> createState() => _MemoryMenuScreenState();
}

class _MemoryMenuScreenState extends State<MemoryMenuScreen>
    with TickerProviderStateMixin {
  static const _prefKey = 'memory_last_difficulty';
  MemoryDifficulty _difficulty = MemoryDifficulty.easy;

  late final AnimationController _bg = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _p = Tween(
    begin: 0.0,
    end: 0.06,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulse);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final i = sp.getInt(_prefKey);
    setState(() => _difficulty = MemoryDifficultyX.fromIndex(i));
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_prefKey, _difficulty.idx);
  }

  @override
  void dispose() {
    _bg.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // Map 4 mức (MemoryDifficulty) -> 3 mức (legacy.Difficulty) để không sửa game screen cũ
  legacy.Difficulty _toLegacy(MemoryDifficulty d) {
    switch (d) {
      case MemoryDifficulty.easy:
        return legacy.Difficulty.easy;
      case MemoryDifficulty.medium:
        return legacy.Difficulty.medium;
      case MemoryDifficulty.hard:
      case MemoryDifficulty.extraHard:
        return legacy.Difficulty.hard; // tạm gom extraHard vào hard cũ
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final primary = _difficulty.color;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF1E2),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Header gradient tối giống mock
            AnimatedBuilder(
              animation: _bg,
              builder: (_, __) {
                final c1 = Color.lerp(
                  const Color(0xFF4E3B6E),
                  const Color(0xFF2C2A47),
                  _bg.value,
                )!;
                final c2 = Color.lerp(
                  const Color(0xFF2C2A47),
                  const Color(0xFF4E3B6E),
                  _bg.value,
                )!;
                return Container(
                  height: min(size.height * 0.34, 300),
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

            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 12),
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _circleIcon(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      _circleIcon(icon: Icons.star_rounded, onTap: () {}),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Title + subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Text(
                        'MEMORY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                          fontSize: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Flip 2 cards and find pairs.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.95),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Avatar hình độ khó (tròn, viền trắng)
                ScaleTransition(
                  scale: Tween(begin: .94, end: 1.0).animate(_pulse),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: Image.asset(
                          _difficulty.assetPath,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Nhãn độ khó
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 40,
                    letterSpacing: 1.3,
                  ),
                  child: Text(_difficulty.label),
                ),

                const SizedBox(height: 10),

                // Slider 4 mức (0..3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 18,
                          activeTrackColor: primary,
                          inactiveTrackColor: const Color(0xFFBDBDBD),
                          thumbColor: Colors.white,
                          overlayColor: primary.withOpacity(.15),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 16,
                            pressedElevation: 4,
                          ),
                        ),
                        child: Slider(
                          value: MemoryDifficulty.values
                              .indexOf(_difficulty)
                              .toDouble(),
                          min: 0,
                          max: 3,
                          divisions: 3,
                          onChanged: (v) => setState(
                            () => _difficulty =
                                MemoryDifficulty.values[v.round()],
                          ),
                          onChangeEnd: (_) => _save(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Drag to adjust difficulty',
                        style: TextStyle(
                          color: Color(0xFF404040),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                  child: Column(
                    children: [
                      _bigBtn(
                        color: primary,
                        labelTop: 'PLAY VS.',
                        labelBottom: 'BOT',
                        icon: Icons.smart_toy_rounded,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemoryGameScreen(
                                mode: MemoryMode.bot,
                                difficulty: _toLegacy(_difficulty),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _bigBtn(
                        color: const Color(0xFF8E72C7),
                        labelTop: 'PLAY VS.',
                        labelBottom: 'FRIEND',
                        icon: Icons.person_rounded,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MemoryGameScreen(
                                mode: MemoryMode.friend,
                                difficulty: _toLegacy(_difficulty),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= Helpers =================

  Widget _circleIcon({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87),
      ),
    );
  }

  Widget _bigBtn({
    required Color color,
    required String labelTop,
    required String labelBottom,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.0 + _p.value).animate(_pulse),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    labelTop,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    labelBottom,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
