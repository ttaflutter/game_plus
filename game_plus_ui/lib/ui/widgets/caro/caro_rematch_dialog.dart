import 'package:flutter/material.dart';
import 'package:game_plus/game/caro/caro_controller.dart';
import 'dart:ui';

/// Dialog end game với animation chuyên nghiệp
class CaroRematchDialog extends StatefulWidget {
  final CaroController controller;
  final VoidCallback onRematch;
  final VoidCallback onGoHome;

  const CaroRematchDialog({
    super.key,
    required this.controller,
    required this.onRematch,
    required this.onGoHome,
  });

  @override
  State<CaroRematchDialog> createState() => _CaroRematchDialogState();
}

class _CaroRematchDialogState extends State<CaroRematchDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _autoExitCountdown = 5;
  bool _isCountingDown = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animationController.forward();

    // Listen để detect khi opponent left
    widget.controller.addListener(_checkOpponentLeft);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkOpponentLeft);
    _animationController.dispose();
    super.dispose();
  }

  void _checkOpponentLeft() {
    print(
      "🔍 _checkOpponentLeft called: opponentLeft=${widget.controller.opponentLeft}, isCountingDown=$_isCountingDown",
    );

    if (widget.controller.opponentLeft && !_isCountingDown) {
      _isCountingDown = true;
      print("⏱️ Starting auto-exit countdown from 5 seconds...");
      _startAutoExitCountdown();
    }
  }

  void _startAutoExitCountdown() {
    print("⏱️ Countdown: $_autoExitCountdown seconds remaining");

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _autoExitCountdown--;
        print("⏱️ Countdown: $_autoExitCountdown seconds remaining");
      });

      if (_autoExitCountdown > 0) {
        _startAutoExitCountdown();
      } else {
        print("🚪 Auto-exiting now!");
        // Auto exit sau 5 giây
        widget.onGoHome();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Log mỗi khi rebuild
    print(
      "🔄 Dialog rebuild - opponentLeft: ${widget.controller.opponentLeft}, rematchRequested: ${widget.controller.rematchRequested}",
    );

    final bool iAmWinner =
        widget.controller.winnerId == widget.controller.myUserId;

    // Determine result text
    String resultTitle = "HÒA";
    Color resultColor = Colors.grey.shade700;

    if (widget.controller.winnerId != null) {
      if (iAmWinner) {
        resultTitle = "CHIẾN THẮNG";
        resultColor = Colors.amber.shade700;
      } else {
        resultTitle = "THUA CUỘC";
        resultColor = Colors.red.shade700;
      }
    }

    // Get rating change từ server (đã tính ELO ở backend)
    final int ratingChange = widget.controller.myRatingChange ?? 0;
    final int coinPoints = 0; // Adjust based on your game logic

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade800,
                Colors.blue.shade600,
                Colors.blue.shade500,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header: CHIẾN THẮNG / THUA CUỘC / HÒA
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        resultTitle,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: resultColor,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        iAmWinner
                            ? "${widget.controller.myUsername ?? 'Bạn'} đã thắng"
                            : widget.controller.winnerId != null
                            ? "${widget.controller.opponentUsername ?? 'Đối thủ'} đã thắng"
                            : "Trận đấu hòa",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Points Display: 🏆 Rating change  💰 +0
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Rating change
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Text("🏆", style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(
                              ratingChange > 0
                                  ? "+$ratingChange"
                                  : ratingChange < 0
                                  ? "$ratingChange"
                                  : "0",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: ratingChange > 0
                                    ? Colors.green.shade300
                                    : ratingChange < 0
                                    ? Colors.red.shade300
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Coin points
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Text("💰", style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(
                              "+$coinPoints",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Interactive Notification Area
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildNotificationContent(),
                ),

                const Spacer(),

                // Score Display: Avatar vs Avatar with score
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // My Avatar
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blue.shade700,
                        child: const Icon(
                          Icons.person,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),

                      // Score: myWins - opponentWins
                      Column(
                        children: [
                          const Text(
                            "Tỉ số",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${widget.controller.myWins} - ${widget.controller.opponentWins}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      // Opponent Avatar
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.red.shade700,
                        child: const Icon(
                          Icons.person,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Buttons
                if (!widget.controller.rematchRequested &&
                    !widget.controller.opponentLeft) ...[
                  // CHƠI LẠI button (only show if opponent hasn't left)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onRematch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.refresh, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              "CHƠI LẠI",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // THOÁT button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: widget.onGoHome,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "THOÁT",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else if (widget.controller.opponentLeft) ...[
                  // Chỉ hiển thị nút THOÁT khi đối thủ đã rời
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onGoHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.exit_to_app, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              "THOÁT",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else if (widget.controller.rematchRequested &&
                    !widget.controller.opponentLeft) ...[
                  // Waiting for rematch - show loading + exit button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          "Đang chờ đối thủ...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // THOÁT button - để user có thể cancel nếu muốn
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: widget.onGoHome,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.white, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "HỦY & THOÁT",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build notification content based on game state
  Widget _buildNotificationContent() {
    final String myName = widget.controller.myUsername ?? "Bạn";
    final String opponentName = widget.controller.opponentUsername ?? "Đối thủ";

    // Debug log
    print("🔔 Notification state:");
    print("  - opponentLeft: ${widget.controller.opponentLeft}");
    print("  - rematchRequested: ${widget.controller.rematchRequested}");
    print(
      "  - opponentRematchRequested: ${widget.controller.opponentRematchRequested}",
    );

    // Priority 1: Opponent left the room
    if (widget.controller.opponentLeft) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.red.shade300, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "$opponentName đã rời phòng",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Tự động thoát sau $_autoExitCountdown giây...",
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade200,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    // Priority 2: Both requested rematch (waiting for server)
    if (widget.controller.rematchRequested &&
        widget.controller.opponentRematchRequested) {
      return Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Cả hai đã chọn chơi lại, đang tạo trận...",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Priority 3: I requested, waiting for opponent
    if (widget.controller.rematchRequested &&
        !widget.controller.opponentRematchRequested) {
      return Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "$myName muốn chơi lại, đang chờ $opponentName...",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Priority 4: Opponent requested, I haven't decided
    if (!widget.controller.rematchRequested &&
        widget.controller.opponentRematchRequested) {
      return Row(
        children: [
          Icon(Icons.refresh, color: Colors.green.shade300, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "$opponentName muốn chơi lại!",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    // Default: No action yet
    return Row(
      children: [
        Icon(Icons.info_outline, color: Colors.blue.shade200, size: 24),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            "Chọn chơi lại hoặc thoát về trang chủ",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
