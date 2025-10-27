import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Một ô trên bàn cờ Caro với animation chuyên nghiệp
class CaroCell extends StatefulWidget {
  final int x;
  final int y;
  final String value;
  final VoidCallback onTap;
  final bool isWinningCell;

  const CaroCell({
    super.key,
    required this.x,
    required this.y,
    required this.value,
    required this.onTap,
    this.isWinningCell = false,
  });

  @override
  State<CaroCell> createState() => _CaroCellState();
}

class _CaroCellState extends State<CaroCell> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _glowController;
  late AnimationController _scaleController;
  late Animation<double> _flipAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;

  bool _isHovered = false;
  String _previousValue = "";

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;

    // Flip animation khi đánh quân cờ
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutBack,
    );

    // Glow animation cho winning cell
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Scale animation khi tap
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));

    if (widget.isWinningCell) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CaroCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger flip animation khi value thay đổi từ empty -> X/O
    if (widget.value != _previousValue &&
        widget.value.isNotEmpty &&
        _previousValue.isEmpty) {
      _flipController.forward(from: 0.0);
      _previousValue = widget.value;
    }

    // Handle winning cell animation
    if (widget.isWinningCell && !oldWidget.isWinningCell) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isWinningCell && oldWidget.isWinningCell) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _glowController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.value.isEmpty) {
      _scaleController.forward().then((_) => _scaleController.reverse());
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    Color symbolColor;
    Color bgColor = Colors.white;

    if (widget.value == "X") {
      symbolColor = Colors.blue.shade700;
      bgColor = widget.isWinningCell
          ? Colors.amber.shade100
          : Colors.blue.shade50;
    } else if (widget.value == "O") {
      symbolColor = Colors.red.shade700;
      bgColor = widget.isWinningCell
          ? Colors.amber.shade100
          : Colors.red.shade50;
    } else {
      symbolColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.value.isEmpty
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: _handleTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(0.5),
                decoration: BoxDecoration(
                  color: _isHovered && widget.value.isEmpty
                      ? Colors.blue.shade50
                      : bgColor,
                  border: Border.all(
                    color: widget.isWinningCell
                        ? Colors.amber.shade700.withOpacity(
                            0.7 + _glowAnimation.value * 0.3,
                          )
                        : (_isHovered && widget.value.isEmpty
                              ? Colors.blue.shade300
                              : Colors.grey.shade400),
                    width: widget.isWinningCell ? 2.5 : 0.8,
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.isWinningCell
                      ? [
                          BoxShadow(
                            color: Colors.amber.shade400.withOpacity(
                              0.5 + _glowAnimation.value * 0.3,
                            ),
                            blurRadius: 8 + _glowAnimation.value * 6,
                            spreadRadius: 1 + _glowAnimation.value * 2,
                          ),
                        ]
                      : (_isHovered && widget.value.isEmpty
                            ? [
                                BoxShadow(
                                  color: Colors.blue.shade200.withOpacity(0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null),
                ),
                child: Center(
                  child: widget.value.isEmpty
                      ? Container()
                      : _buildAnimatedSymbol(symbolColor),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedSymbol(Color symbolColor) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * math.pi;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle);

        final isBackVisible = angle > math.pi / 2;

        return Transform(
          transform: transform,
          alignment: Alignment.center,
          child: isBackVisible
              ? Transform(
                  transform: Matrix4.identity()..rotateY(math.pi),
                  alignment: Alignment.center,
                  child: _buildSymbolText(symbolColor),
                )
              : Container(), // Mặt trước (trống)
        );
      },
    );
  }

  Widget _buildSymbolText(Color symbolColor) {
    final gradientColors = widget.value == 'X'
        ? [Colors.blue.shade700, Colors.blue.shade400]
        : [Colors.red.shade700, Colors.red.shade400];

    return AnimatedScale(
      scale: widget.isWinningCell ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds);
        },
        child: Text(
          widget.value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: widget.isWinningCell ? 16 : 14,
            shadows: [
              Shadow(
                color: symbolColor.withOpacity(0.5),
                blurRadius: 3,
                offset: const Offset(1, 1),
              ),
              if (widget.isWinningCell)
                Shadow(color: Colors.amber.shade400, blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}
