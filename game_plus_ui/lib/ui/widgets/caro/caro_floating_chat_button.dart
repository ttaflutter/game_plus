import 'package:flutter/material.dart';
import 'package:game_plus/game/caro/caro_controller.dart';

/// Floating chat button với badge notification như Messenger
class CaroFloatingChatButton extends StatefulWidget {
  final CaroController controller;
  final VoidCallback onPressed;
  final int unreadCount;

  const CaroFloatingChatButton({
    super.key,
    required this.controller,
    required this.onPressed,
    required this.unreadCount,
  });

  @override
  State<CaroFloatingChatButton> createState() => _CaroFloatingChatButtonState();
}

class _CaroFloatingChatButtonState extends State<CaroFloatingChatButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.unreadCount > 0;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: hasUnread ? _scaleAnimation.value : 1.0,
          child: GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade400.withOpacity(0.5),
                    blurRadius: hasUnread ? 16 : 12,
                    spreadRadius: hasUnread ? 2 : 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Icon chat
                  const Center(
                    child: Icon(
                      Icons.chat_bubble,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),

                  // Badge notification
                  if (hasUnread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade600,
                                Colors.red.shade400,
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              widget.unreadCount > 99
                                  ? '99+'
                                  : '${widget.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
