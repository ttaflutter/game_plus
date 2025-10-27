import 'package:flutter/material.dart';
import 'package:game_plus/models/user_model.dart';
import 'package:game_plus/ui/screens/caro/play/caro_playing_screen.dart';
import 'package:game_plus/ui/screens/caro/play/caro_matching_screen.dart';
import 'package:game_plus/ui/screens/caro/room/room_lobby_screen.dart';
import 'package:game_plus/ui/screens/caro/auth/login_screen.dart';
import 'package:game_plus/ui/widgets/custom_bottom_nav.dart';
import 'package:provider/provider.dart';
import 'package:game_plus/game/caro/caro_controller.dart';
import 'package:game_plus/services/auth_service.dart';

class CaroHomeScreen extends StatefulWidget {
  const CaroHomeScreen({super.key});

  @override
  State<CaroHomeScreen> createState() => _CaroHomeScreenState();
}

class _CaroHomeScreenState extends State<CaroHomeScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  UserModel? _currentUser;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _checkLoginAndLoadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginAndLoadData() async {
    // Check xem đã đăng nhập chưa
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      // Chưa đăng nhập → chuyển về LoginScreen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    // Đã đăng nhập → load user data
    try {
      final user = await AuthService().getCurrentUser();
      print("🔍 Loaded user: ${user.username}, Rating: ${user.rating}");
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      print("❌ Error loading user: $e");
      // Token không hợp lệ hoặc hết hạn → xóa và quay về LoginScreen
      await AuthService().logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    } finally {
      if (mounted) {
        _animationController.forward();
      }
    }
  }

  Future<void> _handlePlayNow() async {
    setState(() => _loading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Vui lòng đăng nhập trước.")),
          );
        }
        setState(() => _loading = false);
        return;
      }

      UserModel currentUser =
          _currentUser ?? await AuthService().getCurrentUser();
      print(
        "👤 Current user: ${currentUser.username} (ID: ${currentUser.id}, Rating: ${currentUser.rating})",
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaroMatchingScreen(
            myUsername: currentUser.username,
            myAvatar: currentUser.avatarUrl,
            myRating: currentUser.rating ?? 1200,
            onMatchFound: (matchId, myRating, opponentRating) {
              print(
                "🎮 Navigating to game with match ID: $matchId, My Rating: $myRating, Opponent Rating: $opponentRating",
              );
              if (!mounted) return;

              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => CaroController(
                      matchId: matchId,
                      initialMyRating: myRating,
                      initialOpponentRating: opponentRating,
                    ),
                    child: const CaroScreen(),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      print("❌ Error in _handlePlayNow: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Lỗi khi tìm trận.")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleRoomPlay() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoomLobbyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final isTablet = screenWidth > 600;
            final isDesktop = screenWidth > 900;

            return Column(
              children: [
                _buildModernHeader(screenWidth, isTablet),
                Expanded(
                  child: _loading
                      ? _buildLoadingState(isTablet)
                      : _buildMainContent(
                          screenWidth,
                          screenHeight,
                          isTablet,
                          isDesktop,
                        ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 2),
    );
  }

  Widget _buildLoadingState(bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: isTablet ? 80 : 60,
            height: isTablet ? 80 : 60,
            child: CircularProgressIndicator(
              strokeWidth: isTablet ? 6 : 4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          ),
          SizedBox(height: isTablet ? 32 : 24),
          Text(
            'Đang tải...',
            style: TextStyle(
              fontSize: isTablet ? 20 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader(double screenWidth, bool isTablet) {
    final username = _currentUser?.username ?? 'Player';
    final avatarUrl = _currentUser?.avatarUrl;
    final elo = _currentUser?.rating ?? 1000;
    final maxWidth = isTablet ? 800.0 : screenWidth;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade600, Colors.blue.shade800],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Caro logo pattern background
            Positioned(
              top: 10,
              left: 20,
              child: Opacity(
                opacity: 0.05,
                child: Icon(
                  Icons.grid_4x4_rounded,
                  size: isTablet ? 80 : 60,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 40,
              child: Opacity(
                opacity: 0.05,
                child: Icon(
                  Icons.close_rounded,
                  size: isTablet ? 60 : 50,
                  color: Colors.white,
                ),
              ),
            ),

            // Main content
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Row(
                    children: [
                      // Avatar with animated glow
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Container(
                            width: isTablet ? 75 : 60,
                            height: isTablet ? 75 : 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.4 * value),
                                  blurRadius: 20 * value,
                                  spreadRadius: 3 * value,
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2 * value),
                                  blurRadius: 30 * value,
                                  spreadRadius: 5 * value,
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 3,
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.amber.shade300,
                                    Colors.amber.shade600,
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: ClipOval(
                                  child:
                                      avatarUrl != null && avatarUrl.isNotEmpty
                                      ? Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return _buildDefaultAvatar(
                                                  isTablet,
                                                );
                                              },
                                        )
                                      : _buildDefaultAvatar(isTablet),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: isTablet ? 20 : 16),

                      // User info with animations
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Username with gradient
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [Colors.white, Colors.amber.shade200],
                              ).createShader(bounds),
                              child: Text(
                                username.toUpperCase(),
                                style: TextStyle(
                                  fontSize: isTablet ? 24 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(height: isTablet ? 10 : 8),

                            // ELO badge with premium design
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 14 : 12,
                                    vertical: isTablet ? 8 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.amber.shade400,
                                        Colors.orange.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: isTablet ? 20 : 18,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            offset: const Offset(0, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                      SizedBox(width: isTablet ? 6 : 5),
                                      Text(
                                        '$elo',
                                        style: TextStyle(
                                          fontSize: isTablet ? 18 : 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                              offset: const Offset(0, 1),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: isTablet ? 6 : 4),
                                      Text(
                                        'ELO',
                                        style: TextStyle(
                                          fontSize: isTablet ? 12 : 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.9),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isTablet ? 12 : 10),

                            // Animated progress bar
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: isTablet ? 10 : 8,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0.0,
                                      end: (elo % 100) / 100,
                                    ),
                                    duration: const Duration(
                                      milliseconds: 1200,
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      return FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: value,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.amber.shade300,
                                                Colors.amber.shade500,
                                                Colors.orange.shade500,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.amber.withOpacity(
                                                  0.6,
                                                ),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.blue.shade700],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: isTablet ? 36 : 28,
        ),
      ),
    );
  }

  Widget _buildMainContent(
    double screenWidth,
    double screenHeight,
    bool isTablet,
    bool isDesktop,
  ) {
    final maxWidth = isDesktop ? 600.0 : (isTablet ? 500.0 : screenWidth);
    final logoSize = isDesktop ? 280.0 : (isTablet ? 240.0 : 200.0);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(minHeight: screenHeight - 200),
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32 : 20,
                  vertical: isTablet ? 48 : 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with hero animation
                    Hero(
                      tag: 'caro_logo',
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: logoSize,
                          maxHeight: logoSize,
                        ),
                        child: Image.asset(
                          "assets/images/logo_caro.png",
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: isTablet ? 50 : 25),

                    // Title with gradient
                    Text(
                      'Kết nối – Đấu trí – Chiến thắng!',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        color: const Color.fromARGB(255, 87, 86, 86),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: isTablet ? 56 : 40),
                    // Action buttons
                    _buildModernButton(
                      text: 'CHƠI NGAY',
                      icon: Icons.play_arrow_rounded,
                      onPressed: _handlePlayNow,
                      isPrimary: true,
                      isTablet: isTablet,
                    ),
                    SizedBox(height: isTablet ? 20 : 16),
                    _buildModernButton(
                      text: 'PHÒNG CHƠI',
                      icon: Icons.people_rounded,
                      onPressed: _handleRoomPlay,
                      isPrimary: false,
                      isTablet: isTablet,
                    ),
                    SizedBox(height: isTablet ? 40 : 24),
                    // Stats or info cards
                    _buildInfoCards(isTablet),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
    required bool isTablet,
  }) {
    return SizedBox(
      width: double.infinity,
      height: isTablet ? 64 : 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style:
            ElevatedButton.styleFrom(
              backgroundColor: isPrimary ? Colors.blue.shade600 : Colors.white,
              foregroundColor: isPrimary ? Colors.white : Colors.blue.shade600,
              elevation: isPrimary ? 8 : 2,
              shadowColor: isPrimary
                  ? Colors.blue.shade600.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                side: isPrimary
                    ? BorderSide.none
                    : BorderSide(color: Colors.blue.shade600, width: 2),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith<Color?>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return isPrimary
                      ? Colors.white.withOpacity(0.2)
                      : Colors.blue.shade600.withOpacity(0.1);
                }
                return null;
              }),
            ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isTablet ? 28 : 24),
            SizedBox(width: isTablet ? 12 : 10),
            Text(
              text,
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards(bool isTablet) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            icon: Icons.emoji_events_rounded,
            title: 'Xếp hạng',
            subtitle: 'Thử thách',
            color: Colors.amber,
            isTablet: isTablet,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.people_outline_rounded,
            title: 'Bạn bè',
            subtitle: 'Đối đầu',
            color: Colors.green,
            isTablet: isTablet,
          ),
        ),
        SizedBox(width: isTablet ? 16 : 12),
        Expanded(
          child: _buildInfoCard(
            icon: Icons.history_rounded,
            title: 'Lịch sử',
            subtitle: 'Xem lại',
            color: Colors.purple,
            isTablet: isTablet,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isTablet,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isTablet ? 32 : 28),
          SizedBox(height: isTablet ? 10 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isTablet ? 4 : 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isTablet ? 11 : 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
