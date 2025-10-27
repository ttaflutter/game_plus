import 'package:flutter/material.dart';
import 'package:game_plus/game/caro/caro_controller.dart';

/// Widget hiển thị trạng thái game với animation chuyên nghiệp
class CaroGameStatus extends StatefulWidget {
  final CaroController controller;

  const CaroGameStatus({super.key, required this.controller});

  @override
  State<CaroGameStatus> createState() => _CaroGameStatusState();
}

class _CaroGameStatusState extends State<CaroGameStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String statusText;
    List<Color> gradientColors;
    IconData statusIcon;
    bool shouldPulse = false;

    if (!widget.controller.isConnected) {
      statusText = "🔌 Đang kết nối...";
      gradientColors = [Colors.orange.shade700, Colors.orange.shade400];
      statusIcon = Icons.sync;
      shouldPulse = true;
    } else if (widget.controller.mySymbol == null) {
      statusText = "⏳ Đang chờ đối thủ...";
      gradientColors = [Colors.blue.shade700, Colors.blue.shade400];
      statusIcon = Icons.hourglass_empty;
      shouldPulse = true;
    } else if (widget.controller.isFinished) {
      if (widget.controller.winnerId != null) {
        statusText = "🏆 Trận đấu kết thúc!";
        gradientColors = [Colors.green.shade700, Colors.green.shade400];
        statusIcon = Icons.emoji_events;
      } else {
        statusText = "🤝 Hòa!";
        gradientColors = [Colors.grey.shade700, Colors.grey.shade400];
        statusIcon = Icons.handshake;
      }
    } else {
      final isMyTurn =
          widget.controller.currentTurn == widget.controller.mySymbol;
      if (isMyTurn) {
        final myName = widget.controller.myUsername ?? "Bạn";
        statusText = "🎯 Lượt của $myName (${widget.controller.mySymbol})";
        gradientColors = [Colors.green.shade700, Colors.teal.shade500];
        statusIcon = Icons.touch_app;
        shouldPulse = true;
      } else {
        final opponentName = widget.controller.opponentUsername ?? "Đối thủ";
        statusText = "⏳ Đợi $opponentName (${widget.controller.currentTurn})";
        gradientColors = [Colors.orange.shade700, Colors.deepOrange.shade400];
        statusIcon = Icons.hourglass_empty;
      }
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: shouldPulse ? _pulseAnimation.value : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Shimmer effect khi đang chờ
                if (shouldPulse)
                  Positioned.fill(
                    child: ClipRect(
                      child: Transform.translate(
                        offset: Offset(
                          _shimmerAnimation.value *
                              MediaQuery.of(context).size.width,
                          0,
                        ),
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Nội dung chính
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.rotate(
                          angle: shouldPulse
                              ? _animationController.value * 2 * 3.14159
                              : 0,
                          child: Opacity(
                            opacity: value,
                            child: Icon(
                              statusIcon,
                              color: Colors.white,
                              size: 24,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
