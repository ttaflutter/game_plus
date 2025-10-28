import 'package:flutter/material.dart';
import 'package:game_plus/ui/widgets/caro/caro_chat_overlay.dart';
import 'package:game_plus/ui/widgets/caro/caro_rematch_dialog.dart';
import 'package:game_plus/ui/widgets/caro/caro_surrender_dialog.dart';
import 'package:provider/provider.dart';
import 'package:game_plus/game/caro/caro_controller.dart';
import 'package:game_plus/game/caro/caro_board.dart';
import 'package:game_plus/ui/screens/caro/caro_home_screen.dart';

class CaroScreen extends StatefulWidget {
  const CaroScreen({super.key});

  @override
  State<CaroScreen> createState() => _CaroScreenState();
}

class _CaroScreenState extends State<CaroScreen> {
  bool _hasShownEndDialog = false;
  bool _isNavigatingToRematch = false; // Flag để prevent duplicate navigation
  CaroController? _controller; // Lưu reference

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller = context.read<CaroController>();
      // initBoard() đã được gọi trong constructor
      _controller!.connectToServer();

      // Lắng nghe khi game kết thúc
      _controller!.addListener(_checkGameEnd);
    });
  }

  @override
  void dispose() {
    // Sử dụng reference đã lưu thay vì context.read
    _controller?.removeListener(_checkGameEnd);
    _controller?.disconnect();
    super.dispose();
  }

  void _checkGameEnd() {
    if (_controller == null) return;

    if (_controller!.isFinished && !_hasShownEndDialog) {
      _hasShownEndDialog = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showEndGameDialog(_controller!);
        }
      });
    }

    // Kiểm tra nếu có match mới → navigate (CHỈ 1 LẦN)
    if (_controller!.newMatchId != null && !_isNavigatingToRematch) {
      _isNavigatingToRematch = true; // Set flag
      print("🔔 Rematch detected: ${_controller!.newMatchId}");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToNewMatch(_controller!.newMatchId!);
        }
      });
    }
  }

  void _navigateToNewMatch(int newMatchId) {
    if (!mounted) return;

    // Lưu score VÀ RATINGS trước khi disconnect
    final oldMyWins = _controller?.myWins ?? 0;
    final oldOpponentWins = _controller?.opponentWins ?? 0;
    final oldDraws = _controller?.draws ?? 0;
    final oldMyRating = _controller?.myRating; // Lưu rating
    final oldOpponentRating = _controller?.opponentRating; // Lưu rating

    print(
      "🔄 Navigating to rematch: $newMatchId (Score: $oldMyWins-$oldOpponentWins, Ratings: $oldMyRating-$oldOpponentRating)",
    );

    // QUAN TRỌNG: Reset newMatchId để tránh re-trigger
    if (_controller != null) {
      _controller!.newMatchId = null;
    }

    // Remove listener để tránh callback duplicate
    _controller?.removeListener(_checkGameEnd);

    // Disconnect khỏi match hiện tại
    _controller?.disconnect();

    // Đóng dialog (nếu có)
    if (Navigator.canPop(context)) {
      Navigator.pop(context); // Close dialog
    }

    // QUAN TRỌNG: Replace screen hiện tại thay vì pop về home
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) {
            final newController = CaroController(
              matchId: newMatchId,
              initialMyRating: oldMyRating, // Preserve rating
              initialOpponentRating: oldOpponentRating, // Preserve rating
            );
            // Preserve score từ trận cũ
            newController.myWins = oldMyWins;
            newController.opponentWins = oldOpponentWins;
            newController.draws = oldDraws;
            print(
              "✅ New controller created with preserved score: $oldMyWins-$oldOpponentWins, ratings: $oldMyRating-$oldOpponentRating",
            );
            return newController;
          },
          child: const CaroScreen(),
        ),
      ),
    );
  }

  void _showEndGameDialog(CaroController controller) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ChangeNotifierProvider.value(
        value: controller,
        child: Consumer<CaroController>(
          builder: (context, ctrl, _) => CaroRematchDialog(
            controller: ctrl,
            onRematch: () {
              ctrl.requestRematch();
              // Dialog sẽ tự cập nhật khi nhận response từ server
            },
            onGoHome: () {
              // Đóng dialog trước
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }

              // Disconnect và về home
              _controller?.disconnect();

              // Clear navigation stack and make CaroHomeScreen the new root
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const CaroHomeScreen()),
                    (route) => false,
                  );
                }
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CaroController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 👤 HEADER - Thông tin đối thủ
            _buildOpponentHeader(controller),

            // 🎮 BOARD - Bàn cờ full screen
            Expanded(
              child: Container(
                color: Colors.grey.shade100,
                child: const Center(child: CaroBoard()),
              ),
            ),

            // 👤 FOOTER - Thông tin của mình + buttons
            _buildPlayerFooter(controller),
          ],
        ),
      ),
    );
  }

  /// Header: Thông tin đối thủ (top)
  Widget _buildOpponentHeader(CaroController controller) {
    final opponentName = controller.opponentUsername ?? 'Đối thủ';
    final opponentSymbol = controller.mySymbol == 'X' ? 'O' : 'X';
    final isOpponentTurn = controller.currentTurn == opponentSymbol;
    final opponentRating =
        controller.opponentRating ?? 1200; // Lấy từ controller

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar với timer ring
              Stack(
                alignment: Alignment.center,
                children: [
                  // Timer ring (nếu là lượt đối thủ)
                  if (isOpponentTurn && controller.timeLeft != null)
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value:
                            controller.timeLeft! /
                            (controller.initialTimeLeft ?? 30),
                        strokeWidth: 2.5,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      color: Colors.grey.shade300,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 24,
                      color: Colors.grey,
                    ),
                  ),
                  // Symbol badge
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade500,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          opponentSymbol,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                            letterSpacing: 0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 10),

              // Name & Rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      opponentName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$opponentRating',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Timer display
              if (isOpponentTurn && controller.timeLeft != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _formatTime(controller.timeLeft!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              // Online indicator
              Container(
                margin: const EdgeInsets.only(left: 6),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade400,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),

          // Turn indicator - LUÔN HIỂN THỊ ĐỂ GIỮ LAYOUT CỐ ĐỊNH
          Container(
            height: 28, // Cố định chiều cao
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOpponentTurn
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isOpponentTurn
                  ? Border.all(color: Colors.white, width: 1)
                  : null,
            ),
            alignment: Alignment.center,
            child: isOpponentTurn
                ? const Text(
                    'Lượt đối thủ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Footer: Thông tin của mình (bottom) + buttons
  Widget _buildPlayerFooter(CaroController controller) {
    final myName = controller.myUsername ?? 'Bạn';
    final mySymbol = controller.mySymbol ?? 'O';
    final isMyTurn = controller.currentTurn == mySymbol;
    final myRating = controller.myRating ?? 1200; // Lấy từ controller

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Turn indicator - LUÔN HIỂN THỊ ĐỂ GIỮ LAYOUT CỐ ĐỊNH
          Container(
            height: 28, // Cố định chiều cao
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isMyTurn
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isMyTurn
                  ? Border.all(color: Colors.white, width: 1)
                  : null,
            ),
            alignment: Alignment.center,
            child: isMyTurn
                ? const Text(
                    'Lượt của bạn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          Row(
            children: [
              // Avatar với timer ring
              Stack(
                alignment: Alignment.center,
                children: [
                  // Timer ring (nếu là lượt mình)
                  if (isMyTurn && controller.timeLeft != null)
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value:
                            controller.timeLeft! /
                            (controller.initialTimeLeft ?? 30),
                        strokeWidth: 2.5,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      color: Colors.grey.shade300,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 24,
                      color: Colors.grey,
                    ),
                  ),
                  // Symbol badge
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade700,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          mySymbol,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                            letterSpacing: 0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 10),

              // Name & Rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      myName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$myRating',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Timer display
              if (isMyTurn && controller.timeLeft != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _formatTime(controller.timeLeft!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              const SizedBox(width: 8),

              // Action buttons
              Row(
                children: [
                  // Chat button
                  _buildActionButton(
                    icon: Icons.chat_bubble,
                    onTap: () {
                      controller.openChat();
                      CaroChatOverlay.show(context, controller);
                    },
                    badge: controller.unreadMessageCount > 0
                        ? controller.unreadMessageCount
                        : null,
                  ),
                  const SizedBox(width: 6),
                  // Menu button
                  _buildActionButton(
                    icon: Icons.menu,
                    onTap: () => _showMenuBottomSheet(controller),
                  ),
                  const SizedBox(width: 6),
                  // Settings button
                  _buildActionButton(
                    icon: Icons.settings,
                    onTap: () => _showSettingsBottomSheet(controller),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Action button helper
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    int? badge,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
        if (badge != null && badge > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badge > 9 ? '9+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  /// Format time as MM:SS
  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Menu bottom sheet
  void _showMenuBottomSheet(CaroController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('Thông tin trận đấu'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show match info
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Đầu hàng'),
              onTap: () {
                Navigator.pop(context);
                _showSurrenderDialog(controller);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Thoát trận'),
              onTap: () {
                // Close the bottom sheet first
                Navigator.pop(context);
                // Disconnect controller/network
                controller.disconnect();
                // Clear the entire navigation stack and set CaroHomeScreen as new root
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const CaroHomeScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Settings bottom sheet
  void _showSettingsBottomSheet(CaroController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const ListTile(
              leading: Icon(Icons.volume_up, color: Colors.blue),
              title: Text('Âm thanh'),
              trailing: Icon(Icons.toggle_on, color: Colors.blue, size: 32),
            ),
            const ListTile(
              leading: Icon(Icons.vibration, color: Colors.blue),
              title: Text('Rung'),
              trailing: Icon(Icons.toggle_on, color: Colors.blue, size: 32),
            ),
            const ListTile(
              leading: Icon(Icons.notifications, color: Colors.blue),
              title: Text('Thông báo'),
              trailing: Icon(Icons.toggle_on, color: Colors.blue, size: 32),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSurrenderDialog(CaroController controller) {
    CaroSurrenderDialog.show(context, () => controller.surrender());
  }
}
