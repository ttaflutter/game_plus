import 'package:flutter/material.dart';

class CustomSliverAppBar extends StatelessWidget {
  final String title;
  final IconData icon;
  final IconData? backgroundIcon;
  final Animation<double>? animation;
  final PreferredSizeWidget? bottom;
  final double expandedHeight;

  const CustomSliverAppBar({
    super.key,
    required this.title,
    required this.icon,
    this.backgroundIcon,
    this.animation,
    this.bottom,
    this.expandedHeight = 180,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.blue.shade700, Colors.blue.shade900]
                : [Colors.blue.shade600, Colors.blue.shade800],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // Background icon (logo mờ)
            if (backgroundIcon != null)
              Positioned(
                top: 80,
                right: 30,
                child: Icon(
                  backgroundIcon,
                  size: 80,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            // Title with icon
            Positioned(
              left: 20,
              bottom: bottom != null ? 64 : 16,
              child: animation != null
                  ? FadeTransition(opacity: animation!, child: _buildTitleRow())
                  : _buildTitleRow(),
            ),
          ],
        ),
      ),
      bottom: bottom,
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
