/// Model for current user's full profile
class MyProfile {
  final int id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final String provider; // 'local' or 'google'
  final DateTime createdAt;
  final int rating;
  final int totalMatches;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;
  final int totalFriends;

  MyProfile({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.bio,
    required this.provider,
    required this.createdAt,
    required this.rating,
    required this.totalMatches,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.winRate,
    required this.totalFriends,
  });

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    return MyProfile(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      provider: json['provider'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      rating: json['rating'] as int,
      totalMatches: json['total_matches'] as int,
      wins: json['wins'] as int,
      losses: json['losses'] as int,
      draws: json['draws'] as int,
      winRate: (json['win_rate'] as num).toDouble(),
      totalFriends: json['total_friends'] as int,
    );
  }

  bool get isLocalAccount => provider == 'local';
  bool get isGoogleAccount => provider == 'google';
}

/// Model for profile settings
class ProfileSettings {
  final NotificationSettings notifications;
  final String language;
  final String theme;

  ProfileSettings({
    required this.notifications,
    required this.language,
    required this.theme,
  });

  factory ProfileSettings.fromJson(Map<String, dynamic> json) {
    return ProfileSettings(
      notifications: NotificationSettings.fromJson(
        json['notifications'] as Map<String, dynamic>,
      ),
      language: json['language'] as String,
      theme: json['theme'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications': notifications.toJson(),
      'language': language,
      'theme': theme,
    };
  }
}

/// Model for notification settings
class NotificationSettings {
  final bool friendRequests;
  final bool challenges;
  final bool matchUpdates;
  final bool chatMessages;

  NotificationSettings({
    required this.friendRequests,
    required this.challenges,
    required this.matchUpdates,
    required this.chatMessages,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      friendRequests: json['friend_requests'] as bool,
      challenges: json['challenges'] as bool,
      matchUpdates: json['match_updates'] as bool,
      chatMessages: json['chat_messages'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friend_requests': friendRequests,
      'challenges': challenges,
      'match_updates': matchUpdates,
      'chat_messages': chatMessages,
    };
  }

  NotificationSettings copyWith({
    bool? friendRequests,
    bool? challenges,
    bool? matchUpdates,
    bool? chatMessages,
  }) {
    return NotificationSettings(
      friendRequests: friendRequests ?? this.friendRequests,
      challenges: challenges ?? this.challenges,
      matchUpdates: matchUpdates ?? this.matchUpdates,
      chatMessages: chatMessages ?? this.chatMessages,
    );
  }
}
