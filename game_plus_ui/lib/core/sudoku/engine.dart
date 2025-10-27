// lib/core/sudoku/engine.dart
import 'dart:math';
import 'board.dart';
import 'generator.dart';
import 'solver.dart';
import 'types.dart';

class Move {
  final MoveKind kind;
  final int r, c;
  final int? prevValue;
  final int? newValue;
  final Set<int>? prevNotes;
  final int? toggledNote;

  Move({
    required this.kind,
    required this.r,
    required this.c,
    this.prevValue,
    this.newValue,
    this.prevNotes,
    this.toggledNote,
  });
}

class SudokuEngine {
  Board board;
  int mistakes; // số lần điền sai
  final int maxLives;
  final List<Move> _undo = [];
  final List<Move> _redo = [];

  SudokuEngine({required this.board, this.mistakes = 0, this.maxLives = 3});

  /// Tạo game mới theo độ khó
  static SudokuEngine newGame(String difficultyName, {int? seed}) {
    final gen = SudokuGenerator(seed);
    final solution = gen.generateFullSolution();
    final clues = SudokuDifficultyPreset.cluesFor(difficultyName);
    final puzzle = gen.carvePuzzle(solution, cluesTarget: clues);

    // dựng cells
    final cells = List.generate(9, (r) {
      return List.generate(9, (c) {
        final v = puzzle[r][c];
        return CellState(
          value: v,
          given: v != 0,
          userLocked: v != 0, // clue mặc định đã locked
        );
      });
    });

    return SudokuEngine(
      board: Board(cells: cells, solution: solution),
    );
  }

  /// Các ứng viên hợp lệ tại (r,c) dựa trên trạng thái hiện tại
  Set<int> candidatesAt(int r, int c) {
    if (board.get(r, c) != 0) return {};
    final used = <int>{};

    for (var i = 0; i < 9; i++) {
      used.add(board.get(r, i));
      used.add(board.get(i, c));
    }
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        used.add(board.get(br + i, bc + j));
      }
    }
    final poss = <int>{};
    for (var n = 1; n <= 9; n++) {
      if (!used.contains(n)) poss.add(n);
    }
    return poss;
  }

  bool get isSolved => board.isSolved;
  int get livesLeft => maxLives - mistakes;

  /// Điền số. Trả về kết quả để UI xử lý (sparkle, trừ tim, v.v.)
  MoveResult setNumber(int r, int c, int value) {
    final cell = board.cells[r][c];
    if (cell.given) return MoveResult.rejectedGiven;
    if (cell.userLocked) return MoveResult.rejectedLocked;
    if (value < 1 || value > 9) return MoveResult.applied;

    final prev = cell.value;
    final prevNotes = {...cell.notes};

    if (board.solution[r][c] == value) {
      // đúng → điền và lock
      board.set(r, c, value);
      board.setUserLocked(r, c, true);
      cell.notes.clear();
      _undo.add(
        Move(
          kind: MoveKind.setValue,
          r: r,
          c: c,
          prevValue: prev,
          newValue: value,
          prevNotes: prevNotes,
        ),
      );
      _redo.clear();
      return isSolved ? MoveResult.solved : MoveResult.applied;
    } else {
      // sai → tăng mistakes
      mistakes = min(maxLives, mistakes + 1);
      return MoveResult.mistake;
    }
  }

  /// Erase: chỉ xóa nếu ô không phải given và không bị userLocked
  MoveResult eraseCell(int r, int c) {
    final cell = board.cells[r][c];
    if (cell.given) return MoveResult.rejectedGiven;
    if (cell.userLocked) return MoveResult.rejectedLocked;
    if (cell.value == 0 && cell.notes.isEmpty) return MoveResult.applied;

    final prev = cell.value;
    final prevNotes = {...cell.notes};

    cell.value = 0;
    cell.notes.clear();

    _undo.add(
      Move(
        kind: MoveKind.eraseValue,
        r: r,
        c: c,
        prevValue: prev,
        prevNotes: prevNotes,
      ),
    );
    _redo.clear();
    return MoveResult.applied;
  }

  /// Toggle một note tại (r,c)
  MoveResult toggleNote(int r, int c, int note) {
    final cell = board.cells[r][c];
    if (cell.given || cell.userLocked) return MoveResult.rejectedLocked;
    if (cell.value != 0) return MoveResult.rejectedLocked;
    if (note < 1 || note > 9) return MoveResult.applied;

    final prevNotes = {...cell.notes};
    if (cell.notes.contains(note)) {
      cell.notes.remove(note);
    } else {
      cell.notes.add(note);
    }
    _undo.add(
      Move(
        kind: MoveKind.toggleNote,
        r: r,
        c: c,
        prevNotes: prevNotes,
        toggledNote: note,
      ),
    );
    _redo.clear();
    return MoveResult.applied;
  }

  /// Hint: điền đúng một ô rỗng (random hoặc ưu tiên single-candidate)
  MoveResult hintFill() {
    // ưu tiên ô có 1 candidates
    final singles = <CellCoord>[];
    final empties = <CellCoord>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (board.get(r, c) == 0) {
          final cand = candidatesAt(r, c);
          if (cand.length == 1) {
            singles.add(CellCoord(r, c));
          } else {
            empties.add(CellCoord(r, c));
          }
        }
      }
    }
    CellCoord? pick;
    if (singles.isNotEmpty) {
      singles.shuffle();
      pick = singles.first;
    } else if (empties.isNotEmpty) {
      empties.shuffle();
      pick = empties.first;
    }
    if (pick == null) return MoveResult.applied;

    final r = pick.r, c = pick.c;
    final correct = board.solution[r][c];
    final cell = board.cells[r][c];
    final prevNotes = {...cell.notes};

    board.set(r, c, correct);
    board.setUserLocked(r, c, true);
    cell.notes.clear();

    _undo.add(
      Move(
        kind: MoveKind.hintFill,
        r: r,
        c: c,
        prevValue: 0,
        newValue: correct,
        prevNotes: prevNotes,
      ),
    );
    _redo.clear();

    return isSolved ? MoveResult.solved : MoveResult.applied;
  }

  bool canUndo() => _undo.isNotEmpty;
  bool canRedo() => _redo.isNotEmpty;

  void undo() {
    if (_undo.isEmpty) return;
    final m = _undo.removeLast();
    final cell = board.cells[m.r][m.c];

    switch (m.kind) {
      case MoveKind.setValue:
      case MoveKind.hintFill:
        cell.value = m.prevValue ?? 0;
        cell.userLocked = false;
        cell.notes
          ..clear()
          ..addAll(m.prevNotes ?? const <int>{});
        break;
      case MoveKind.eraseValue:
        cell.value = m.prevValue ?? 0;
        cell.userLocked = (cell.value != 0);
        cell.notes
          ..clear()
          ..addAll(m.prevNotes ?? const <int>{});
        break;
      case MoveKind.toggleNote:
        cell.notes
          ..clear()
          ..addAll(m.prevNotes ?? const <int>{});
        break;
    }
    _redo.add(m);
  }

  void redo() {
    if (_redo.isEmpty) return;
    final m = _redo.removeLast();
    switch (m.kind) {
      case MoveKind.setValue:
      case MoveKind.hintFill:
        setNumber(m.r, m.c, m.newValue ?? 0);
        break;
      case MoveKind.eraseValue:
        eraseCell(m.r, m.c);
        break;
      case MoveKind.toggleNote:
        toggleNote(m.r, m.c, m.toggledNote ?? 0);
        break;
    }
  }

  /// Xuất JSON để lưu
  String toJsonString() => board.toJsonString();

  /// Khôi phục từ JSON
  static SudokuEngine fromJsonString(String s, {int maxLives = 3}) {
    return SudokuEngine(board: Board.fromJsonString(s), maxLives: maxLives);
  }
}
