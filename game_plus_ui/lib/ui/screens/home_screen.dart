import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:game_plus/ui/screens/memory_menu_screen.dart'; //memory
import 'package:game_plus/configs/difficulty.dart';
import 'package:game_plus/ui/screens/menu_screen.dart'; // GameMenuScreen (chung)
import 'package:game_plus/ui/screens/settings_screen.dart';
import 'package:game_plus/ui/screens/sudoku_game_screen.dart'; // SudokuGameScreen
import 'package:game_plus/ui/screens/twenty48_game_screen.dart'; // Twenty48GameScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _cloudCtrl;

  late final List<Map<String, dynamic>> _games = [
    {
      'title': 'MEMORY',
      'image': 'assets/images/memory_icon.png', // icon bạn vừa có
      'color': const Color(0xFF2ECC71), // xanh lá tươi
      'favorite': true,
      // dùng menu riêng của Memory (có Bot/Friend + slider độ khó)
      'screen': const MemoryMenuScreen(),
    },
    // --------------------- SUDOKU ---------------------
    {
      'title': 'SUDOKU',
      'image': 'assets/images/sudoku_icon.png',
      'color': const Color(0xFF4AA9F3),
      'favorite': true,
      'screen': GameMenuScreen(
        title: 'SUDOKU',
        images: {
          Difficulty.easy: 'assets/images/easy.png',
          Difficulty.medium: 'assets/images/medium.png',
          Difficulty.hard: 'assets/images/hard.png',
        },
        primaryColors: {
          Difficulty.easy: const Color(0xFF26A65B),
          Difficulty.medium: const Color(0xFFF5A623),
          Difficulty.hard: const Color(0xFFE74C3C),
        },
        prefKey: 'sudoku_last_difficulty',
        onPlay: (ctx, diff) => SudokuGameScreen(
          difficulty: diff.label.toLowerCase(), // 'easy' | 'medium' | 'hard'
        ),
      ),
    },

    // -------------------- NUMBER SLIDE / 2048 --------------------
    {
      'title': 'NUMBER SLIDE',
      'image': 'assets/images/2048_icon.png', // avatar 2048
      'color': const Color(0xFFFFC85E),
      'favorite': true,
      'screen': GameMenuScreen(
        title: 'NUMBER SLIDE',
        images: {
          Difficulty.easy: 'assets/images/easy.png',
          Difficulty.medium: 'assets/images/medium.png',
          Difficulty.hard: 'assets/images/hard.png',
        },
        primaryColors: {
          Difficulty.easy: const Color(0xFF26A65B),
          Difficulty.medium: const Color(0xFFF5A623),
          Difficulty.hard: const Color(0xFFE74C3C),
        },
        prefKey: 'twenty48_last_difficulty',
        onPlay: (ctx, diff) => Twenty48GameScreen(
          difficulty: diff.name, // <= đổi từ diff -> diff.name
        ),
      ),
    },

    // -------------------- ví dụ game khác (chưa làm) --------------------
    {
      'title': 'COLOR BLOCKS',
      'image': 'assets/images/block_icon.png',
      'color': const Color(0xFFFFB64D),
      'favorite': false,
      'screen': null, // chưa có
    },
    {
      'title': 'NUTS & BOLTS',
      'image': 'assets/images/nuts_icon.png',
      'color': const Color(0xFFEA5E5E),
      'favorite': false,
      'screen': null, // chưa có
    },
  ];

  @override
  void initState() {
    super.initState();
    _cloudCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _cloudCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _games.where((g) => g['favorite'] == true).toList();
    final others = _games.where((g) => g['favorite'] == false).toList();
    final allGames = [...favorites, ...others];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF1E2),
      body: SafeArea(
        child: Stack(
          children: [
            // 🌤️ Background animation
            Positioned(
              top: 80,
              left: -100,
              right: -100,
              bottom: -100,
              child: AnimatedBuilder(
                animation: _cloudCtrl,
                builder: (_, __) {
                  return Transform.translate(
                    offset: Offset(80 * _cloudCtrl.value, 0),
                    child: Opacity(
                      opacity: 0.4,
                      child: Image.asset(
                        'assets/images/clouds_bg.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 🌈 Main content
            Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Menu button (Settings)
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                        child: _circleButton(Icons.settings_rounded),
                      ),
                      const Spacer(),
                      _infoBox(
                        Icons.bolt_rounded,
                        "0",
                        const Color(0xFFFFD97D),
                      ),
                      const SizedBox(width: 8),
                      _infoBox(
                        Icons.star_rounded,
                        "REMOVE ADS",
                        const Color(0xFFB388EB),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ===== GAME GRID =====
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: allGames.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.9,
                        ),
                    itemBuilder: (context, i) {
                      final game = allGames[i];
                      return _GameCard(
                        title: game['title'],
                        image: game['image'],
                        color: game['color'],
                        favorite: game['favorite'],
                        onFavoriteToggle: () {
                          setState(() => game['favorite'] = !game['favorite']);
                        },
                        onTap: game['screen'] != null
                            ? () => Navigator.push(
                                context,
                                PageRouteBuilder(
                                  transitionDuration: const Duration(
                                    milliseconds: 400,
                                  ),
                                  pageBuilder: (_, __, ___) => game['screen'],
                                  transitionsBuilder:
                                      (_, animation, __, child) =>
                                          FadeTransition(
                                            opacity: animation,
                                            child: ScaleTransition(
                                              scale: Tween(
                                                begin: 0.95,
                                                end: 1.0,
                                              ).animate(animation),
                                              child: child,
                                            ),
                                          ),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== Components =====

  Widget _circleButton(IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black87),
    );
  }

  Widget _infoBox(IconData icon, String text, Color color) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  final String title;
  final String image;
  final Color color;
  final bool favorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onTap;

  const _GameCard({
    required this.title,
    required this.image,
    required this.color,
    required this.favorite,
    required this.onFavoriteToggle,
    this.onTap,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0,
    upperBound: 0.06,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final scale = 1 - _ctrl.value;
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Ảnh game căn giữa
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child:
                                Image.asset(widget.image, fit: BoxFit.contain)
                                    .animate()
                                    .fadeIn(duration: 400.ms)
                                    .scale(begin: const Offset(0.95, 0.95)),
                          ),
                        ),
                      ),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                  // ⭐ Nút yêu thích
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: widget.onFavoriteToggle,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: widget.favorite
                              ? const Color(0xFFF5B400)
                              : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
