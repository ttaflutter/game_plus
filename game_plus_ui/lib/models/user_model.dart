// lib/models/user_model.dart
class UserModel {
  final int id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? provider;
  final int? rating; // Thêm trường rating/elo

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.provider,
    this.rating,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      avatarUrl: json['avatar_url'],
      provider: json['provider'],
      rating:
          json['rating'] ?? json['elo'], // Support both 'rating' and 'elo' keys
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "username": username,
    "email": email,
    "avatar_url": avatarUrl,
    "provider": provider,
    "rating": rating,
  };
}
