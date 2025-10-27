import 'package:flutter/material.dart';
import 'package:game_plus/ui/screens/caro/caro_playing_screen.dart';
import 'package:game_plus/ui/screens/caro/caro_matching_screen.dart';
import 'package:game_plus/ui/screens/auth/login_screen.dart';
import 'package:game_plus/ui/widgets/custom_bottom_nav.dart';
import 'package:game_plus/ui/screens/friends/friends_screen.dart';
import 'package:provider/provider.dart';
import 'package:game_plus/game/caro/caro_controller.dart';
import 'package:game_plus/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final authService = AuthService();
      await authService.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã đăng xuất thành công')),
        );
        // Navigate back to login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
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

      // Lấy thông tin user thật từ backend
      final authService = AuthService();
      final currentUser = await authService.getCurrentUser();
      print("👤 Current user: ${currentUser.username} (ID: ${currentUser.id})");

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
              print("🎮 Navigating to game with match ID: $matchId");
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
      appBar: AppBar(
        title: const Text("GamePlus"),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _handlePlayNow,
                icon: const Icon(Icons.sports_esports),
                label: const Text("🎮 Chơi ngay"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
      ),
    );
  }
}
