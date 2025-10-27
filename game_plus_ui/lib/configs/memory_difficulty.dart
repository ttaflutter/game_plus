import 'package:flutter/material.dart';

/// Dùng riêng cho game Memory (4 mức), tách khỏi enum Difficulty cũ.
enum MemoryDifficulty { easy, medium, hard, extraHard }

extension MemoryDifficultyX on MemoryDifficulty {
  String get label {
    switch (this) {
      case MemoryDifficulty.easy:
        return 'EASY';
      case MemoryDifficulty.medium:
        return 'MEDIUM';
      case MemoryDifficulty.hard:
        return 'HARD';
      case MemoryDifficulty.extraHard:
        return 'EXTRA HARD';
    }
  }

  Color get color {
    switch (this) {
      case MemoryDifficulty.easy:
        return const Color(0xFF2ECC71); // green
      case MemoryDifficulty.medium:
        return const Color(0xFFF39C12); // orange
      case MemoryDifficulty.hard:
        return const Color(0xFFE74C3C); // red
      case MemoryDifficulty.extraHard:
        return const Color(0xFF6C63FF); // purple
    }
  }

  String get assetPath {
    switch (this) {
      case MemoryDifficulty.easy:
        return 'assets/images/easy.png';
      case MemoryDifficulty.medium:
        return 'assets/images/medium.png';
      case MemoryDifficulty.hard:
        return 'assets/images/hard.png';
      case MemoryDifficulty.extraHard:
        return 'assets/images/extra_hard.png';
    }
  }

  int get idx => MemoryDifficulty.values.indexOf(this);

  static MemoryDifficulty fromIndex(int? i) {
    if (i == null) return MemoryDifficulty.easy;
    return (i >= 0 && i < MemoryDifficulty.values.length)
        ? MemoryDifficulty.values[i]
        : MemoryDifficulty.easy;
  }
}
