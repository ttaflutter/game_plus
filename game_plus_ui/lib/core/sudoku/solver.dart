// lib/core/sudoku/solver.dart
/// Backtracking solver + kiểm tra duy nhất nghiệm.
/// Dùng cho generator và cho validate.

class SudokuSolver {
  /// Giải một board 9x9 (0 là trống). Trả về true nếu giải được.
  static bool solve(List<List<int>> grid) {
    final pos = _findEmpty(grid);
    if (pos == null) return true; // solved

    final r = pos[0], c = pos[1];
    for (var n = 1; n <= 9; n++) {
      if (_isSafe(grid, r, c, n)) {
        grid[r][c] = n;
        if (solve(grid)) return true;
        grid[r][c] = 0;
      }
    }
    return false;
  }

  /// Kiểm tra có đúng **một** nghiệm hay không.
  static bool hasUniqueSolution(List<List<int>> start) {
    var count = 0;
    bool dfs(List<List<int>> g) {
      final pos = _findEmpty(g);
      if (pos == null) {
        count++;
        return count > 1; // stop sớm nếu > 1 nghiệm
      }
      final r = pos[0], c = pos[1];
      for (var n = 1; n <= 9; n++) {
        if (_isSafe(g, r, c, n)) {
          g[r][c] = n;
          if (dfs(g)) return true;
          g[r][c] = 0;
        }
      }
      return false;
    }

    final g = start.map((e) => List<int>.from(e)).toList();
    dfs(g);
    return count == 1;
  }

  static List<int>? _findEmpty(List<List<int>> g) {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (g[r][c] == 0) return [r, c];
      }
    }
    return null;
  }

  static bool _isSafe(List<List<int>> g, int r, int c, int n) {
    for (var i = 0; i < 9; i++) {
      if (g[r][i] == n || g[i][c] == n) return false;
    }
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        if (g[br + i][bc + j] == n) return false;
      }
    }
    return true;
  }
}
