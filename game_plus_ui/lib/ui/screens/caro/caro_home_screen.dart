import 'package:flutter/material.dart';
import 'package:game_plus/models/user_model.dart';
import 'package:game_plus/ui/screens/caro/caro_playing_screen.dart';
import 'package:game_plus/ui/screens/caro/caro_matching_screen.dart';
import 'package:game_plus/ui/screens/caro/widgets/custom_bottom_nav.dart';
import 'package:provider/provider.dart';
import 'package:game_plus/game/caro/caro_controller.dart';
import 'package:game_plus/services/auth_service.dart';

class CaroHomeScreen extends StatefulWidget {
  const CaroHomeScreen({super.key});

  @override
  State<CaroHomeScreen> createState() => _CaroHomeScreenState();
}

class _CaroHomeScreenState extends State<CaroHomeScreen> {
  bool _loading = false;
  UserModel? _currentUser; // Cache user data

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      }
    } catch (e) {
      print("❌ Error loading user: $e");
    }
  }

  Future<void> _handlePlayNow() async {
    setState(() => _loading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng đăng nhập trước.")),
        );
        setState(() => _loading = false);
        return;
      }

      // Sử dụng cached user hoặc fetch lại nếu chưa có
      UserModel currentUser =
          _currentUser ?? await AuthService().getCurrentUser();
      print(
        "👤 Current user: ${currentUser.username} (ID: ${currentUser.id}, Rating: ${currentUser.rating})",
      );

      // Show matching screen với thông tin thật
      if (!mounted) return;
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CaroMatchingScreen(
            myUsername: currentUser.username,
            myAvatar: currentUser.avatarUrl,
            myRating:
                currentUser.rating ??
                1200, // Lấy rating thật từ user hoặc default 1200
            // Callback khi tìm thấy đối thủ - navigate to game
            onMatchFound: (matchId, myRating, opponentRating) {
              print(
                "🎮 Navigating to game with match ID: $matchId, My Rating: $myRating, Opponent Rating: $opponentRating",
              );
              if (!mounted) return;

              // Pop matching screen
              Navigator.pop(context);

              // Navigate to game screen với ratings
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

      // User quay lại (cancel matching) - đảm bảo reset loading
      print("📱 Returned from matching screen. Result: $result");
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with user info
            _buildHeader(),

            // Main content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMainContent(),
            ),
          ],
        ),
      ),
      // Bottom navigation bar
      bottomNavigationBar: CustomBottomNav(currentIndex: 2),
    );
  }

  Widget _buildHeader() {
    // Sử dụng cached user data thay vì FutureBuilder
    final username = _currentUser?.username ?? 'Player';
    final avatarUrl = _currentUser?.avatarUrl;
    final elo = _currentUser?.rating ?? 1000; // Lấy rating thật từ cached user

    print("📊 Header - Username: $username, Rating: $elo"); // Debug log

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orange, width: 3),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.person, color: Colors.grey),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.person, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Username and ELO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'ELO: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$elo',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (elo % 100) / 100,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.blue,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        // Logo shield
        Image.asset("assets/images/logo_caro.png", width: 250),
        const SizedBox(height: 60),
        // Buttons
        _buildPlayButton(text: 'CHƠI NGAY', onPressed: _handlePlayNow),
        const SizedBox(height: 16),
        _buildPlayButton(
          text: 'CHƠI VỚI BẠN',
          onPressed: () {
            // TODO: Implement play with friend
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tính năng đang phát triển')),
            );
          },
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildLogoShield() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Shield background
        Container(
          width: 200,
          height: 220,
          child: CustomPaint(painter: ShieldPainter()),
        ),
        // Content
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ribbon text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'CỜ CARO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 30),
            // X O O X pattern
            const Text(
              'X O\nO X',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                height: 1.0,
                letterSpacing: 8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 280,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 4,
          shadowColor: Colors.blue.withOpacity(0.5),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the shield shape background
class ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blue.shade600, Colors.blue.shade700],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();

    // Start from top center
    path.moveTo(size.width / 2, 0);

    // Top left curve
    path.lineTo(0, size.height * 0.15);

    // Left side
    path.lineTo(0, size.height * 0.6);

    // Bottom curve (shield point)
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height * 0.6,
    );

    // Right side
    path.lineTo(size.width, size.height * 0.15);

    // Top right curve
    path.lineTo(size.width / 2, 0);

    path.close();

    // Draw shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.3), 8, true);

    // Draw shield
    canvas.drawPath(path, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.blue.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
