/// Model for match history list item
class MatchHistoryItem {
  final int matchId;
  final String gameName;
  final String status; // waiting, playing, finished, abandoned
  final String? result; // win, loss, draw
  final String opponentUsername;
  final String? opponentAvatarUrl;
  final String opponentSymbol;
  final String mySymbol;
  final int boardRows;
  final int boardCols;
  final int totalMoves;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? durationSeconds;

  MatchHistoryItem({
    required this.matchId,
    required this.gameName,
    required this.status,
    this.result,
    required this.opponentUsername,
    this.opponentAvatarUrl,
    required this.opponentSymbol,
    required this.mySymbol,
    required this.boardRows,
    required this.boardCols,
    required this.totalMoves,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.durationSeconds,
  });

  factory MatchHistoryItem.fromJson(Map<String, dynamic> json) {
    return MatchHistoryItem(
      matchId: json['match_id'] as int,
      gameName: json['game_name'] as String,
      status: json['status'] as String,
      result: json['result'] as String?,
      opponentUsername: json['opponent_username'] as String,
      opponentAvatarUrl: json['opponent_avatar_url'] as String?,
      opponentSymbol: json['opponent_symbol'] as String,
      mySymbol: json['my_symbol'] as String,
      boardRows: json['board_rows'] as int,
      boardCols: json['board_cols'] as int,
      totalMoves: json['total_moves'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }
}

/// Model for player info in match detail
class PlayerInfo {
  final int userId;
  final String username;
  final String? avatarUrl;
  final String symbol;
  final bool? isWinner;
  final int? ratingBefore;
  final int? ratingAfter;

  PlayerInfo({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.symbol,
    this.isWinner,
    this.ratingBefore,
    this.ratingAfter,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) {
    return PlayerInfo(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      symbol: json['symbol'] as String,
      isWinner: json['is_winner'] as bool?,
      ratingBefore: json['rating_before'] as int?,
      ratingAfter: json['rating_after'] as int?,
    );
  }

  int? get ratingChange {
    if (ratingBefore == null || ratingAfter == null) return null;
    return ratingAfter! - ratingBefore!;
  }
}

/// Model for individual move detail
class MoveDetail {
  final int turnNo;
  final int userId;
  final String username;
  final int x;
  final int y;
  final String symbol;
  final DateTime madeAt;

  MoveDetail({
    required this.turnNo,
    required this.userId,
    required this.username,
    required this.x,
    required this.y,
    required this.symbol,
    required this.madeAt,
  });

  factory MoveDetail.fromJson(Map<String, dynamic> json) {
    return MoveDetail(
      turnNo: json['turn_no'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String,
      x: json['x'] as int,
      y: json['y'] as int,
      symbol: json['symbol'] as String,
      madeAt: DateTime.parse(json['made_at'] as String),
    );
  }
}

/// Model for winning line coordinate
class WinningCell {
  final int x;
  final int y;

  WinningCell({required this.x, required this.y});

  factory WinningCell.fromJson(Map<String, dynamic> json) {
    return WinningCell(x: json['x'] as int, y: json['y'] as int);
  }
}

/// Model for complete match detail with replay data
class MatchDetail {
  final int matchId;
  final String gameName;
  final String status;
  final int boardRows;
  final int boardCols;
  final int winLen;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? durationSeconds;
  final List<PlayerInfo> players;
  final List<MoveDetail> moves;
  final List<List<String?>> board;
  final List<WinningCell>? winningLine;

  MatchDetail({
    required this.matchId,
    required this.gameName,
    required this.status,
    required this.boardRows,
    required this.boardCols,
    required this.winLen,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.durationSeconds,
    required this.players,
    required this.moves,
    required this.board,
    this.winningLine,
  });

  factory MatchDetail.fromJson(Map<String, dynamic> json) {
    // Parse board (2D array)
    final boardData = json['board'] as List;
    final board = boardData.map((row) {
      return (row as List).map((cell) => cell as String?).toList();
    }).toList();

    // Parse winning line
    List<WinningCell>? winningLine;
    if (json['winning_line'] != null) {
      winningLine = (json['winning_line'] as List)
          .map((cell) => WinningCell.fromJson(cell as Map<String, dynamic>))
          .toList();
    }

    return MatchDetail(
      matchId: json['match_id'] as int,
      gameName: json['game_name'] as String,
      status: json['status'] as String,
      boardRows: json['board_rows'] as int,
      boardCols: json['board_cols'] as int,
      winLen: json['win_len'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      players: (json['players'] as List)
          .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
          .toList(),
      moves: (json['moves'] as List)
          .map((m) => MoveDetail.fromJson(m as Map<String, dynamic>))
          .toList(),
      board: board,
      winningLine: winningLine,
    );
  }

  PlayerInfo? get winner =>
      players.firstWhere((p) => p.isWinner == true, orElse: () => players[0]);

  bool get isDraw => players.every((p) => p.isWinner == null);
}

/// Model for stats summary
class MatchStatsResponse {
  final int totalMatches;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final int? latestMatchId;
  final DateTime? latestMatchDate;

  MatchStatsResponse({
    required this.totalMatches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    this.latestMatchId,
    this.latestMatchDate,
  });

  factory MatchStatsResponse.fromJson(Map<String, dynamic> json) {
    return MatchStatsResponse(
      totalMatches: json['total_matches'] as int,
      wins: json['wins'] as int,
      losses: json['losses'] as int,
      draws: json['draws'] as int,
      winRate: (json['win_rate'] as num).toDouble(),
      latestMatchId: json['latest_match_id'] as int?,
      latestMatchDate: json['latest_match_date'] != null
          ? DateTime.parse(json['latest_match_date'] as String)
          : null,
    );
  }
}
