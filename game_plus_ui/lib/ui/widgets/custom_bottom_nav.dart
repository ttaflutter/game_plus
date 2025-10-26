import 'package:flutter/material.dart';
import 'package:game_plus/ui/screens/profile/profile_screen.dart';
import 'package:game_plus/ui/screens/caro/caro_home_screen.dart';
import 'package:game_plus/ui/screens/leaderboard/leaderboard_screen.dart';
import 'package:game_plus/ui/widgets/page_transition.dart';
import 'package:game_plus/ui/screens/friends/friends_screen.dart';
import 'package:game_plus/ui/screens/history/match_history_screen.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;

  const CustomBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(
        icon: Icons.emoji_events,
        label: "Xếp Hạng",
        isActive: currentIndex == 0,
        onTap: () {
          Navigator.pushReplacement(
            context,
            pageTransition(const LeaderboardScreen()),
          );
        },
      ),
      _NavItem(
        icon: Icons.people,
        label: "Bàn Bè",
        isActive: currentIndex == 1,
        onTap: () {
          Navigator.pushReplacement(
            context,
            pageTransition(const FriendsScreen()),
          );
        },
      ),
      _NavItem(
        icon: Icons.extension,
        label: "Chơi Ngay",
        isActive: currentIndex == 2,
        onTap: () {
          Navigator.pushReplacement(
            context,
            pageTransition(const CaroHomeScreen()),
          );
        },
      ),
      _NavItem(
        icon: Icons.history,
        label: "Lịch Sử",
        isActive: currentIndex == 3,
        onTap: () {
          Navigator.pushReplacement(
            context,
            pageTransition(const MatchHistoryScreen()),
          );
        },
      ),
      _NavItem(
        icon: Icons.person,
        label: "Cá Nhân",
        isActive: currentIndex == 4,
        onTap: () {
          Navigator.pushReplacement(
            context,
            pageTransition(const ProfileScreen()),
          );
        },
      ),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.blue.shade600.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              scale: isActive ? 1.2 : 1.0,
              child: Icon(
                icon,
                size: 22,
                color: isActive ? Colors.blue.shade600 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.blue.shade600 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
