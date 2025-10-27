import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:game_plus/ui/screens/caro/auth/login_screen.dart';
import 'package:game_plus/ui/screens/caro/caro_home_screen.dart';
import 'package:game_plus/ui/screens/memory/memory_menu_screen.dart';
import 'package:game_plus/ui/screens/sudoku/sudoku_game_screen.dart';
import 'package:game_plus/ui/screens/twenty48/twenty48_game_screen.dart';
import 'package:game_plus/configs/difficulty.dart';
import 'package:game_plus/ui/screens/menu_screen.dart';
import 'package:game_plus/ui/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _floatingCtrl;
  late final AnimationController _glowCtrl;

  late final List<Map<String, dynamic>> _games = [
    {
      'title': 'CARO ONLINE',
      'subtitle': 'Multiplayer Strategy',
      'image': 'assets/images/logo_caro.png',
      'color': const Color(0xFF4A90E2),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
      ),
      'favorite': true,
      'screen': const CaroHomeScreen(),
    },
    {
      'title': 'MEMORY',
      'subtitle': 'Train Your Brain',
      'image': 'assets/images/memory_icon.png',
      'color': const Color(0xFF50C878),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF50C878), Color(0xFF3DA75F)],
      ),
      'favorite': true,
      'screen': const MemoryMenuScreen(),
    },
    {
      'title': 'SUDOKU',
      'subtitle': 'Logic Puzzle',
      'image': 'assets/images/sudoku_icon.png',
      'color': const Color(0xFF6C63FF),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6C63FF), Color(0xFF5549CC)],
      ),
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
        onPlay: (ctx, diff) =>
            SudokuGameScreen(difficulty: diff.label.toLowerCase()),
      ),
    },
    {
      'title': 'NUMBER SLIDE',
      'subtitle': '2048 Challenge',
      'image': 'assets/images/2048_icon.png',
      'color': const Color(0xFFFFB84D),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFB84D), Color(0xFFE69D3D)],
      ),
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
        onPlay: (ctx, diff) => Twenty48GameScreen(difficulty: diff.name),
      ),
    },
    {
      'title': 'COLOR BLOCKS',
      'subtitle': 'Coming Soon',
      'image': 'assets/images/block_icon.png',
      'color': const Color(0xFFFF6B9D),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF6B9D), Color(0xFFE6578A)],
      ),
      'favorite': false,
      'screen': null,
    },
    {
      'title': 'NUTS & BOLTS',
      'subtitle': 'Coming Soon',
      'image': 'assets/images/nuts_icon.png',
      'color': const Color(0xFFEA5E5E),
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEA5E5E), Color(0xFFD14949)],
      ),
      'favorite': false,
      'screen': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _floatingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 900;

    final favorites = _games.where((g) => g['favorite'] == true).toList();
    final others = _games.where((g) => g['favorite'] == false).toList();
    final allGames = [...favorites, ...others];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F2027),
              const Color(0xFF203A43),
              const Color(0xFF2C5364),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(child: _buildHeader(context, isTablet)),

              // Title Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 20,
                    vertical: isTablet ? 32 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _glowCtrl,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.blue.shade200,
                                Colors.white,
                              ],
                              stops: [0.0, _glowCtrl.value, 1.0],
                            ).createShader(bounds),
                            child: Text(
                              'GAME PLUS',
                              style: TextStyle(
                                fontSize: isTablet ? 48 : 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(
                                    color: Colors.blue.withOpacity(0.5),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: isTablet ? 12 : 8),
                      Text(
                        'Choose your challenge',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Games Grid
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 20),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 2),
                    crossAxisSpacing: isTablet ? 24 : 16,
                    mainAxisSpacing: isTablet ? 24 : 16,
                    childAspectRatio: isTablet ? 0.95 : 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final game = allGames[index];
                    return _GameCard(
                      title: game['title'],
                      subtitle: game['subtitle'],
                      image: game['image'],
                      color: game['color'],
                      gradient: game['gradient'],
                      favorite: game['favorite'],
                      isTablet: isTablet,
                      delay: index * 100,
                      onFavoriteToggle: () {
                        setState(() {
                          game['favorite'] = !game['favorite'];
                        });
                      },
                      onTap: game['screen'] != null
                          ? () => _navigateToGame(context, game['screen'])
                          : null,
                    );
                  }, childCount: allGames.length),
                ),
              ),

              // Bottom spacing
              SliverToBoxAdapter(child: SizedBox(height: isTablet ? 40 : 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      child: Row(
        children: [
          // Settings Button
          _AnimatedIconButton(
            icon: Icons.settings_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            isTablet: isTablet,
          ),
          const Spacer(),

          // Energy Badge
          _InfoBadge(
            icon: Icons.bolt_rounded,
            text: "0",
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
            ),
            isTablet: isTablet,
          ),
          SizedBox(width: isTablet ? 12 : 8),

          // Premium Badge
          _InfoBadge(
            icon: Icons.workspace_premium_rounded,
            text: "PRO",
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            isTablet: isTablet,
          ),
        ],
      ),
    );
  }

  void _navigateToGame(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

// ============= ANIMATED ICON BUTTON =============
class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isTablet;

  const _AnimatedIconButton({
    required this.icon,
    required this.onTap,
    required this.isTablet,
  });

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.isTablet ? 56.0 : 48.0;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final scale = 1 - (_ctrl.value * 0.1);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: widget.isTablet ? 28 : 24,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============= INFO BADGE =============
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Gradient gradient;
  final bool isTablet;

  const _InfoBadge({
    required this.icon,
    required this.text,
    required this.gradient,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isTablet ? 44 : 38,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16 : 12,
        vertical: isTablet ? 10 : 8,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isTablet ? 22 : 18, color: Colors.white),
          SizedBox(width: isTablet ? 8 : 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isTablet ? 16 : 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2);
  }
}

// ============= GAME CARD =============
class _GameCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String image;
  final Color color;
  final Gradient gradient;
  final bool favorite;
  final bool isTablet;
  final int delay;
  final VoidCallback onFavoriteToggle;
  final VoidCallback? onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.color,
    required this.gradient,
    required this.favorite,
    required this.isTablet,
    required this.delay,
    required this.onFavoriteToggle,
    this.onTap,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTapDown: widget.onTap != null
                ? (_) => _pressCtrl.forward()
                : null,
            onTapUp: widget.onTap != null
                ? (_) {
                    _pressCtrl.reverse();
                    widget.onTap?.call();
                  }
                : null,
            onTapCancel: widget.onTap != null
                ? () => _pressCtrl.reverse()
                : null,
            child: AnimatedBuilder(
              animation: _pressCtrl,
              builder: (context, child) {
                final scale = 1 - (_pressCtrl.value * 0.05);
                return Transform.scale(
                  scale: scale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: widget.gradient,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isHovered
                            ? Colors.white.withOpacity(0.4)
                            : Colors.white.withOpacity(0.1),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(
                            _isHovered ? 0.6 : 0.4,
                          ),
                          blurRadius: _isHovered ? 24 : 16,
                          offset: Offset(0, _isHovered ? 12 : 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Glassmorphism overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Content
                        Padding(
                          padding: EdgeInsets.all(widget.isTablet ? 20 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title & Favorite
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.title,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: widget.isTablet ? 18 : 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(
                                          height: widget.isTablet ? 4 : 2,
                                        ),
                                        Text(
                                          widget.subtitle,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: widget.isTablet ? 13 : 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Favorite Button
                                  GestureDetector(
                                    onTap: widget.onFavoriteToggle,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        widget.favorite
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: widget.favorite
                                            ? const Color(0xFFFFD700)
                                            : Colors.white.withOpacity(0.6),
                                        size: widget.isTablet ? 24 : 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Game Icon
                              Expanded(
                                child: Center(
                                  child: AnimatedScale(
                                    scale: _isHovered ? 1.1 : 1.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    child: Image.asset(
                                      widget.image,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.videogame_asset_rounded,
                                        size: widget.isTablet ? 72 : 64,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Play Button or Coming Soon
                              if (widget.onTap == null)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    vertical: widget.isTablet ? 10 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    'COMING SOON',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: widget.isTablet ? 13 : 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    vertical: widget.isTablet ? 12 : 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        color: widget.color,
                                        size: widget.isTablet ? 24 : 20,
                                      ),
                                      SizedBox(width: widget.isTablet ? 6 : 4),
                                      Text(
                                        'PLAY NOW',
                                        style: TextStyle(
                                          color: widget.color,
                                          fontSize: widget.isTablet ? 15 : 13,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: widget.delay),
          duration: 500.ms,
        )
        .slideY(begin: 0.3, curve: Curves.easeOutCubic);
  }
}
