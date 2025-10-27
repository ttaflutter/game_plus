// lib/core/sudoku/types.dart
enum Difficulty { easy, medium, hard }

class CellCoord {
  final int r, c;
  const CellCoord(this.r, this.c);
}

enum MoveKind { setValue, eraseValue, toggleNote, hintFill }

enum MoveResult { applied, rejectedLocked, rejectedGiven, mistake, solved }
