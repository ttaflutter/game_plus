// lib/schemas/auth_schemas.dart
import '../models/user_model.dart';

class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final String provider;
  final String? avatarUrl;
  final String? bio;
  final String? providerId;

  RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    this.provider = "local",
    this.avatarUrl,
    this.bio,
    this.providerId,
  });

  Map<String, dynamic> toJson() => {
    "username": username,
    "email": email,
    "password": password,
    "provider": provider,
    if (avatarUrl != null) "avatar_url": avatarUrl,
    if (bio != null) "bio": bio,
    if (providerId != null) "provider_id": providerId,
  };
}

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {"email": email, "password": password};
}

class TokenResponse {
  final String accessToken;
  final int expiresIn;
  final UserModel user;

  TokenResponse({
    required this.accessToken,
    required this.expiresIn,
    required this.user,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'],
      expiresIn: json['expires_in'],
      user: UserModel.fromJson(json['user']),
    );
  }
}
