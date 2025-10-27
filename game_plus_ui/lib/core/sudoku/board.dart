// lib/core/sudoku/board.dart
import 'dart:convert';

class CellState {
  /// 0 = empty; 1..9 = value
  int value;

  /// Là ô đề bài (clue) hay không
  final bool given;

  /// Nếu người chơi đã điền ĐÚNG số (khớp solution) thì khóa
  /// không cho Erase (chỉ undo mới gỡ được)
  bool userLocked;

  /// Notes: tập số nhỏ đang ghi chú
  final Set<int> notes;

  CellState({
    required this.value,
    required this.given,
    this.userLocked = false,
    Set<int>? notes,
  }) : notes = notes ?? <int>{};

  CellState copy() => CellState(
    value: value,
    given: given,
    userLocked: userLocked,
    notes: {...notes},
  );

  Map<String, dynamic> toJson() => {
    'v': value,
    'g': given,
    'l': userLocked,
    'n': notes.toList(),
  };

  static CellState fromJson(Map<String, dynamic> m) => CellState(
    value: m['v'] as int,
    given: m['g'] as bool,
    userLocked: m['l'] as bool? ?? false,
    notes: (m['n'] as List?)?.cast<int>().toSet() ?? <int>{},
  );
}

class Board {
  /// 9x9 grid
  final List<List<CellState>> cells;

  /// Lời giải 9x9, mỗi phần tử 1..9
  final List<List<int>> solution;

  Board({required this.cells, required this.solution})
    : assert(cells.length == 9 && cells.every((r) => r.length == 9));

  /// Giá trị tại (r,c)
  int get(int r, int c) => cells[r][c].value;

  /// Set giá trị (không tự kiểm tra hợp lệ)
  void set(int r, int c, int v) {
    cells[r][c].value = v;
  }

  bool isGiven(int r, int c) => cells[r][c].given;
  bool isUserLocked(int r, int c) => cells[r][c].userLocked;

  void setUserLocked(int r, int c, bool locked) {
    cells[r][c].userLocked = locked;
  }

  Set<int> notesOf(int r, int c) => cells[r][c].notes;

  bool get isSolved {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (cells[r][c].value != solution[r][c]) return false;
      }
    }
    return true;
  }

  /// Deep copy (để dùng trong undo/redo)
  Board copy() {
    final newCells = List.generate(
      9,
      (r) => List.generate(9, (c) => cells[r][c].copy()),
    );
    final newSol = List.generate(9, (r) => List<int>.from(solution[r]));
    return Board(cells: newCells, solution: newSol);
  }

  /// JSON để lưu game
  String toJsonString() {
    final data = {
      'cells': cells.map((row) => row.map((c) => c.toJson()).toList()).toList(),
      'solution': solution,
    };
    return jsonEncode(data);
  }

  static Board fromJsonString(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    final cells = (m['cells'] as List)
        .map<List<CellState>>(
          (row) => (row as List).map((e) => CellState.fromJson(e)).toList(),
        )
        .toList();
    final solution = (m['solution'] as List)
        .map<List<int>>((row) => (row as List).cast<int>().toList())
        .toList();
    return Board(cells: cells, solution: solution);
  }
}
