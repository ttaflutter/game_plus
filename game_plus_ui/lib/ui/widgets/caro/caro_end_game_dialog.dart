import 'package:flutter/material.dart';
import 'package:game_plus/game/caro/caro_controller.dart';

/// Dialog hiển thị kết quả trận đấu
class CaroEndGameDialog extends StatelessWidget {
  final CaroController controller;
  final VoidCallback onPlayAgain;
  final VoidCallback onGoHome;

  const CaroEndGameDialog({
    super.key,
    required this.controller,
    required this.onPlayAgain,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final dialogData = _getDialogData();

    return AlertDialog(
      title: Row(
        children: [
          Icon(dialogData.icon, color: dialogData.color, size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(dialogData.title)),
        ],
      ),
      content: Text(dialogData.message),
      actions: [
        TextButton.icon(
          onPressed: onPlayAgain,
          icon: const Icon(Icons.replay),
          label: const Text("Chơi lại"),
          style: TextButton.styleFrom(foregroundColor: Colors.deepPurple),
        ),
        TextButton(onPressed: onGoHome, child: const Text("Về trang chủ")),
      ],
    );
  }

  _DialogData _getDialogData() {
    final bool iAmWinner = controller.winnerId == controller.myUserId;

    if (controller.winnerId != null) {
      // Có người thắng
      if (iAmWinner) {
        // Check if it's timeout win
        if (controller.timeLeft != null && controller.timeLeft! <= 0) {
          return _DialogData(
            title: "⏰ Thắng do Timeout!",
            message:
                "Đối thủ đã hết thời gian!\nTổng số nước: ${controller.moveCount}",
            icon: Icons.emoji_events,
            color: Colors.amber,
          );
        } else {
          return _DialogData(
            title: "🎉 Chiến thắng!",
            message:
                "Chúc mừng bạn đã thắng!\nTổng số nước: ${controller.moveCount}",
            icon: Icons.emoji_events,
            color: Colors.amber,
          );
        }
      } else {
        // I lost
        if (controller.timeLeft != null && controller.timeLeft! <= 0) {
          return _DialogData(
            title: "⏰ Thua do Timeout!",
            message:
                "Bạn đã hết thời gian!\nTổng số nước: ${controller.moveCount}",
            icon: Icons.sentiment_dissatisfied,
            color: Colors.red,
          );
        } else {
          return _DialogData(
            title: "😔 Thua cuộc",
            message: "Đối thủ đã thắng.\nTổng số nước: ${controller.moveCount}",
            icon: Icons.sentiment_dissatisfied,
            color: Colors.red,
          );
        }
      }
    } else {
      // Hòa
      return _DialogData(
        title: "🤝 Hòa!",
        message:
            "Trận đấu kết thúc với tỷ số hòa.\nTổng số nước: ${controller.moveCount}",
        icon: Icons.handshake,
        color: Colors.grey,
      );
    }
  }
}

class _DialogData {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  _DialogData({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}
