class LeaderboardEntry {
  final int rank;
  final int userId;
  final String username;
  final String? avatarUrl;
  final int rating;
  final int wins;
  final int losses;
  final int draws;
  final int totalGames;
  final double winRate;
  final bool isOnline;
  final bool isFriend;
  final bool hasPendingRequest;
  final bool isCurrentUser; // Indicate if this is the current logged-in user

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.rating,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.totalGames,
    required this.winRate,
    required this.isOnline,
    required this.isFriend,
    required this.hasPendingRequest,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      rating: json['rating'] as int,
      wins: json['wins'] as int,
      losses: json['losses'] as int,
      draws: json['draws'] as int,
      totalGames: json['total_games'] as int,
      winRate: (json['win_rate'] as num).toDouble(),
      isOnline: json['is_online'] as bool? ?? false,
      isFriend: json['is_friend'] as bool? ?? false,
      hasPendingRequest: json['has_pending_request'] as bool? ?? false,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'rating': rating,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'total_games': totalGames,
      'win_rate': winRate,
      'is_online': isOnline,
      'is_friend': isFriend,
      'has_pending_request': hasPendingRequest,
      'is_current_user': isCurrentUser,
    };
  }
}

class RecentMatch {
  final int matchId;
  final String opponentUsername;
  final String result; // "win", "loss", "draw"
  final DateTime finishedAt;
  final String symbol; // "X" or "O"

  RecentMatch({
    required this.matchId,
    required this.opponentUsername,
    required this.result,
    required this.finishedAt,
    required this.symbol,
  });

  factory RecentMatch.fromJson(Map<String, dynamic> json) {
    return RecentMatch(
      matchId: json['match_id'] as int,
      opponentUsername: json['opponent_username'] as String,
      result: json['result'] as String,
      finishedAt: DateTime.parse(json['finished_at'] as String),
      symbol: json['symbol'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'match_id': matchId,
      'opponent_username': opponentUsername,
      'result': result,
      'finished_at': finishedAt.toIso8601String(),
      'symbol': symbol,
    };
  }
}

class UserProfileDetail {
  final int userId;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final int rating;
  final int rank;
  final int wins;
  final int losses;
  final int draws;
  final int totalGames;
  final double winRate;
  final DateTime createdAt;
  final bool isFriend;
  final bool hasPendingRequest;
  final bool isOnline;
  final List<RecentMatch> recentMatches;

  UserProfileDetail({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.bio,
    required this.rating,
    required this.rank,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.totalGames,
    required this.winRate,
    required this.createdAt,
    required this.isFriend,
    required this.hasPendingRequest,
    required this.isOnline,
    required this.recentMatches,
  });

  factory UserProfileDetail.fromJson(Map<String, dynamic> json) {
    return UserProfileDetail(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      rating: json['rating'] as int,
      rank: json['rank'] as int,
      wins: json['wins'] as int,
      losses: json['losses'] as int,
      draws: json['draws'] as int,
      totalGames: json['total_games'] as int,
      winRate: (json['win_rate'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      isFriend: json['is_friend'] as bool? ?? false,
      hasPendingRequest: json['has_pending_request'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? false,
      recentMatches:
          (json['recent_matches'] as List?)
              ?.map((e) => RecentMatch.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'bio': bio,
      'rating': rating,
      'rank': rank,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'total_games': totalGames,
      'win_rate': winRate,
      'created_at': createdAt.toIso8601String(),
      'is_friend': isFriend,
      'has_pending_request': hasPendingRequest,
      'is_online': isOnline,
      'recent_matches': recentMatches.map((e) => e.toJson()).toList(),
    };
  }
}
