/// Model để lưu thông tin winning line
class WinningLineData {
  final List<Position> positions;

  WinningLineData(this.positions);

  bool contains(int x, int y) {
    return positions.any((pos) => pos.x == x && pos.y == y);
  }
}

class Position {
  final int x;
  final int y;

  Position(this.x, this.y);
}
