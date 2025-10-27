import 'package:flutter/material.dart';
import 'package:game_plus/game/caro/caro_controller.dart';

/// Widget hiển thị thông tin 2 người chơi (không có animation)
class CaroPlayersInfo extends StatefulWidget {
  final CaroController controller;

  const CaroPlayersInfo({super.key, required this.controller});

  @override
  State<CaroPlayersInfo> createState() => _CaroPlayersInfoState();
}

class _CaroPlayersInfoState extends State<CaroPlayersInfo> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Người chơi X
          _PlayerCard(
            symbol: "X",
            username: widget.controller.mySymbol == "X"
                ? widget.controller.myUsername
                : widget.controller.opponentUsername,
            color: Colors.blue.shade700,
            isMe: widget.controller.mySymbol == "X",
            isActive:
                widget.controller.currentTurn == "X" &&
                !widget.controller.isFinished,
          ),

          // VS Divider (static)
          Container(
            width: 2,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.5),
                  Colors.blue.withOpacity(0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Người chơi O
          _PlayerCard(
            symbol: "O",
            username: widget.controller.mySymbol == "O"
                ? widget.controller.myUsername
                : widget.controller.opponentUsername,
            color: Colors.red.shade700,
            isMe: widget.controller.mySymbol == "O",
            isActive:
                widget.controller.currentTurn == "O" &&
                !widget.controller.isFinished,
          ),
        ],
      ),
    );
  }
}

/// Card hiển thị thông tin 1 người chơi (không có animation)
class _PlayerCard extends StatelessWidget {
  final String symbol;
  final String? username;
  final Color color;
  final bool isMe;
  final bool isActive;

  const _PlayerCard({
    required this.symbol,
    this.username,
    required this.color,
    required this.isMe,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive ? null : Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? color.withOpacity(0.8) : Colors.grey.shade300,
          width: isActive ? 3 : 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Row(
        children: [
          // Symbol (không có animation)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: isActive ? 10 : 4,
                  spreadRadius: isActive ? 1 : 0,
                ),
              ],
            ),
            child: Center(
              child: Text(
                symbol,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 3)],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    username ?? (isMe ? "Bạn" : "Đối thủ"),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.person, size: 14, color: color),
                  ],
                ],
              ),
              if (isActive)
                Text(
                  "🎯 Đang đánh",
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
