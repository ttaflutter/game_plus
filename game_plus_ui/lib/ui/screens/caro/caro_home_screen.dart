import 'package:flutter/material.dart';
import 'package:game_plus/models/user_model.dart';
import 'package:game_plus/ui/screens/caro/caro_playing_screen.dart';
import 'package:game_plus/ui/screens/caro/caro_matching_screen.dart';
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
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      print("🔍 Loaded user: ${user.username}, Rating: ${user.rating}");
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        _animationController.forward();
      }
    } catch (e) {
      print("❌ Error loading user: $e");
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
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade600, Colors.blue.shade800],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade600.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Row(
              children: [
                // Avatar with glow effect
                Container(
                  width: isTablet ? 70 : 56,
                  height: isTablet ? 70 : 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 3),
                    ),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(isTablet);
                              },
                            )
                          : _buildDefaultAvatar(isTablet),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 20 : 16),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username.toUpperCase(),
                        style: TextStyle(
                          fontSize: isTablet ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isTablet ? 8 : 6),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 12 : 10,
                              vertical: isTablet ? 6 : 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.4),
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
                                  size: isTablet ? 18 : 16,
                                ),
                                SizedBox(width: isTablet ? 6 : 4),
                                Text(
                                  '$elo',
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 10 : 8),
                      // Progress bar with animation
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: isTablet ? 10 : 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (elo % 100) / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.amber, Colors.orange],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
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
                      text: 'CHƠI VỚI BẠN',
                      icon: Icons.people_rounded,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 12),
                                Text('Tính năng đang phát triển'),
                              ],
                            ),
                            backgroundColor: Colors.blue.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
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
