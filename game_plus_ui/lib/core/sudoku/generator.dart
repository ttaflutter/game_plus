// lib/core/sudoku/generator.dart
import 'dart:math';
import 'solver.dart';

class SudokuGenerator {
  final Random _rnd;
  SudokuGenerator([int? seed]) : _rnd = Random(seed);

  /// Tạo lời giải đầy đủ 9x9 ngẫu nhiên
  List<List<int>> generateFullSolution() {
    final grid = List.generate(9, (_) => List.filled(9, 0));
    // Điền ngẫu nhiên 3 block chéo để tăng random
    for (var b = 0; b < 3; b++) {
      _fillBox(grid, b * 3, b * 3);
    }
    SudokuSolver.solve(grid);
    return grid;
  }

  void _fillBox(List<List<int>> g, int row, int col) {
    final nums = List<int>.generate(9, (i) => i + 1)..shuffle(_rnd);
    var k = 0;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        g[row + i][col + j] = nums[k++];
      }
    }
  }

  /// Khoét clue theo độ khó, vẫn đảm bảo unique
  ///
  /// return puzzle (0 là trống)
  List<List<int>> carvePuzzle(
    List<List<int>> solution, {
    required int cluesTarget, // số ô còn lại (≥ 17)
    int maxAttempts = 20000,
  }) {
    final puzzle = solution.map((r) => List<int>.from(r)).toList();

    // danh sách vị trí (0..80)
    final idxs = List<int>.generate(81, (i) => i)..shuffle(_rnd);
    var removed = 0;

    for (final idx in idxs) {
      if (81 - removed <= cluesTarget) break; // đạt mục tiêu
      final r = idx ~/ 9, c = idx % 9;
      final backup = puzzle[r][c];
      if (backup == 0) continue;
      puzzle[r][c] = 0;

      // check unique
      final g = puzzle.map((e) => List<int>.from(e)).toList();
      if (!SudokuSolver.hasUniqueSolution(g)) {
        puzzle[r][c] = backup; // revert
      } else {
        removed++;
      }
    }

    // fallback đơn giản nếu chưa đủ target (hiếm)
    if (_countClues(puzzle) > cluesTarget) {
      // random remove tiếp nhưng giới hạn attempt
      var attempts = 0;
      while (_countClues(puzzle) > cluesTarget && attempts < maxAttempts) {
        attempts++;
        final r = _rnd.nextInt(9), c = _rnd.nextInt(9);
        if (puzzle[r][c] == 0) continue;
        final backup = puzzle[r][c];
        puzzle[r][c] = 0;
        final g = puzzle.map((e) => List<int>.from(e)).toList();
        if (!SudokuSolver.hasUniqueSolution(g)) {
          puzzle[r][c] = backup;
        }
      }
    }

    return puzzle;
  }

  int _countClues(List<List<int>> p) {
    var cnt = 0;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (p[r][c] != 0) cnt++;
      }
    }
    return cnt;
  }
}

/// Mapping độ khó → số clue còn lại (ít clue hơn = khó hơn).
class SudokuDifficultyPreset {
  static int cluesFor(String difficultyName) {
    switch (difficultyName) {
      case 'easy':
        return 40; // dễ: nhiều clue
      case 'medium':
        return 32;
      case 'hard':
      default:
        return 26; // khó
    }
  }
}
