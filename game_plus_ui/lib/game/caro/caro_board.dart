import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:game_plus/game/caro/caro_controller.dart';
import 'package:game_plus/game/caro/caro_cell.dart';

class CaroBoard extends StatelessWidget {
  const CaroBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CaroController>();

    return AspectRatio(
      aspectRatio: controller.cols / controller.rows,
      child: Container(
        color: Colors.white,
        child: GridView.builder(
          padding: const EdgeInsets.all(2),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.rows * controller.cols,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: controller.cols,
          ),
          itemBuilder: (context, index) {
            final x = index ~/ controller.cols;
            final y = index % controller.cols;
            final isWinning = controller.winningLine?.contains(x, y) ?? false;

            return CaroCell(
              x: x,
              y: y,
              value: controller.board[x][y],
              isWinningCell: isWinning,
              onTap: () {
                // Chỉ cho phép đánh nếu chưa kết thúc & là lượt của mình
                if (!controller.isFinished &&
                    controller.mySymbol == controller.currentTurn) {
                  controller.sendMove(x, y);
                }
              },
            );
          },
        ),
      ),
    );
  }
}
