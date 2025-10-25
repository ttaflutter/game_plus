import 'package:flutter/material.dart';

/// Widget hiển thị timer countdown với animation
class CaroTimerDisplay extends StatefulWidget {
  final int timeLeft;

  const CaroTimerDisplay({super.key, required this.timeLeft});

  @override
  State<CaroTimerDisplay> createState() => _CaroTimerDisplayState();
}

class _CaroTimerDisplayState extends State<CaroTimerDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CaroTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.timeLeft <= 10 && widget.timeLeft != oldWidget.timeLeft) {
      _pulseController.forward().then((_) => _pulseController.reverse());
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLowTime = widget.timeLeft <= 10;
    final isCritical = widget.timeLeft <= 5;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isLowTime ? _pulseAnimation.value : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: isLowTime
                  ? LinearGradient(
                      colors: isCritical
                          ? [Colors.red.shade700, Colors.red.shade900]
                          : [Colors.orange.shade600, Colors.red.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: isLowTime
                  ? [
                      BoxShadow(
                        color: (isCritical ? Colors.red : Colors.orange)
                            .withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: isLowTime ? value * 0.1 : 0,
                      child: Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: isLowTime ? Colors.white : Colors.white70,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: isLowTime ? 16 : 14,
                    fontWeight: isLowTime ? FontWeight.bold : FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  child: Text("${widget.timeLeft}s"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
