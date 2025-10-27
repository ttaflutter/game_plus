import 'dart:math';

enum Dir { up, down, left, right }

class Game2048 {
  static const int n = 4;
  final Random _rnd = Random();

  /// Xác suất sinh ô 4 (mặc định 10%).
  final double spawn4Prob;

  List<List<int>> grid = List.generate(n, (_) => List.filled(n, 0));
  int score = 0;

  // Undo (1 bước)
  List<List<int>>? _prevGrid;
  int? _prevScore;

  Game2048({this.spawn4Prob = 0.10}) {
    reset();
  }

  void reset() {
    score = 0;
    grid = List.generate(n, (_) => List.filled(n, 0));
    _prevGrid = null;
    _prevScore = null;
    _spawn();
    _spawn();
  }

  bool _spawn() {
    final empties = <Point<int>>[];
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (grid[r][c] == 0) empties.add(Point(r, c));
      }
    }
    if (empties.isEmpty) return false;
    final p = empties[_rnd.nextInt(empties.length)];
    grid[p.x][p.y] = _rnd.nextDouble() < (1 - spawn4Prob) ? 2 : 4;
    return true;
  }

  bool get hasMove {
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final v = grid[r][c];
        if (v == 0) return true;
        if (r + 1 < n && grid[r + 1][c] == v) return true;
        if (c + 1 < n && grid[r][c + 1] == v) return true;
      }
    }
    return false;
  }

  int get maxTile {
    var m = 0;
    for (final row in grid) {
      for (final v in row) {
        if (v > m) m = v;
      }
    }
    return m;
  }

  bool canUndo() => _prevGrid != null;

  void undo() {
    if (!canUndo()) return;
    grid = List.generate(n, (r) => List<int>.from(_prevGrid![r]));
    score = _prevScore!;
    _prevGrid = null;
    _prevScore = null;
  }

  /// Trả về true nếu có thay đổi.
  bool move(Dir dir) {
    // lưu cho undo
    _prevGrid = List.generate(n, (r) => List<int>.from(grid[r]));
    _prevScore = score;

    bool changed = false;
    int gained = 0;

    List<List<int>> work = List.generate(n, (r) => List<int>.from(grid[r]));

    int read(int r, int c) => work[r][c];
    void write(int r, int c, int v) => work[r][c] = v;

    List<int> line = List.filled(n, 0);

    // nén + gộp 1 line (trái -> phải)
    List<int> _compressAndMerge(List<int> a) {
      final b = a.where((e) => e != 0).toList();
      final out = <int>[];
      for (int i = 0; i < b.length; i++) {
        if (i + 1 < b.length && b[i] == b[i + 1]) {
          final merged = b[i] * 2;
          out.add(merged);
          gained += merged;
          i++;
        } else {
          out.add(b[i]);
        }
      }
      while (out.length < n) out.add(0);
      return out;
    }

    for (int i = 0; i < n; i++) {
      // lấy 1 line theo hướng
      for (int j = 0; j < n; j++) {
        switch (dir) {
          case Dir.left:
            line[j] = read(i, j);
            break;
          case Dir.right:
            line[j] = read(i, n - 1 - j);
            break;
          case Dir.up:
            line[j] = read(j, i);
            break;
          case Dir.down:
            line[j] = read(n - 1 - j, i);
            break;
        }
      }

      final merged = _compressAndMerge(line);

      for (int j = 0; j < n; j++) {
        switch (dir) {
          case Dir.left:
            if (read(i, j) != merged[j]) changed = true;
            write(i, j, merged[j]);
            break;
          case Dir.right:
            if (read(i, n - 1 - j) != merged[j]) changed = true;
            write(i, n - 1 - j, merged[j]);
            break;
          case Dir.up:
            if (read(j, i) != merged[j]) changed = true;
            write(j, i, merged[j]);
            break;
          case Dir.down:
            if (read(n - 1 - j, i) != merged[j]) changed = true;
            write(n - 1 - j, i, merged[j]);
            break;
        }
      }
    }

    if (!changed) {
      // không đổi -> huỷ snapshot undo
      _prevGrid = null;
      _prevScore = null;
      return false;
    }

    score += gained;
    grid = work;
    _spawn();
    return true;
  }
}
