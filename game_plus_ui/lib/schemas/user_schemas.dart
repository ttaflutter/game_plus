// lib/schemas/user_schemas.dart

class UserUpdatePayload {
  final String? username;
  final String? bio;
  final String? avatarUrl;

  UserUpdatePayload({this.username, this.bio, this.avatarUrl});

  Map<String, dynamic> toJson() {
    return {
      if (username != null) "username": username,
      if (bio != null) "bio": bio,
      if (avatarUrl != null) "avatar_url": avatarUrl,
    };
  }
}
