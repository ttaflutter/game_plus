import 'package:flutter/material.dart';

/// Dialog xác nhận đầu hàng
class CaroSurrenderDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const CaroSurrenderDialog({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.flag, color: Colors.red),
          SizedBox(width: 12),
          Text("Đầu hàng?"),
        ],
      ),
      content: const Text("Bạn có chắc chắn muốn đầu hàng không?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Hủy"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text("Đầu hàng"),
        ),
      ],
    );
  }

  /// Helper method để show dialog
  static Future<void> show(BuildContext context, VoidCallback onConfirm) {
    return showDialog(
      context: context,
      builder: (context) => CaroSurrenderDialog(onConfirm: onConfirm),
    );
  }
}
