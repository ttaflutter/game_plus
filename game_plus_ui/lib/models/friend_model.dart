/// Model cho User trong search results và friends list
class FriendUser {
  final int id;
  final String username;
  final String? avatarUrl;
  final int rating;
  final bool? isFriend;
  final bool? hasPendingRequest;
  final bool? isOnline;
  final DateTime? createdAt;

  FriendUser({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.rating,
    this.isFriend,
    this.hasPendingRequest,
    this.isOnline,
    this.createdAt,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] ?? json['user_id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      rating: json['rating'] ?? 1000,
      isFriend: json['is_friend'],
      hasPendingRequest: json['has_pending_request'],
      isOnline: json['is_online'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

/// Model cho Friend Request
class FriendRequest {
  final int id;
  final int senderId;
  final int receiverId;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;
  final String senderUsername;
  final String? senderAvatarUrl;
  final String receiverUsername;
  final String? receiverAvatarUrl;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.senderUsername,
    this.senderAvatarUrl,
    required this.receiverUsername,
    this.receiverAvatarUrl,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      senderUsername: json['sender_username'],
      senderAvatarUrl: json['sender_avatar_url'],
      receiverUsername: json['receiver_username'],
      receiverAvatarUrl: json['receiver_avatar_url'],
    );
  }
}
