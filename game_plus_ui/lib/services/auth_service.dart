// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../schemas/auth_schemas.dart';
import '../models/user_model.dart';
import '../configs/app_config.dart';

class AuthService {
  String get _baseUrl => AppConfig.baseUrl;

  Future<TokenResponse> register(RegisterRequest req) async {
    final url = Uri.parse('$_baseUrl/api/auth/register');
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(req.toJson()),
    );

    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      final tokenRes = TokenResponse.fromJson(data);
      await _saveToken(tokenRes.accessToken);
      return tokenRes;
    } else {
      throw Exception('Register failed: ${res.body}');
    }
  }

  Future<TokenResponse> login(LoginRequest req) async {
    final url = Uri.parse('$_baseUrl/api/auth/login');
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(req.toJson()),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final tokenRes = TokenResponse.fromJson(data);
      await _saveToken(tokenRes.accessToken);
      return tokenRes;
    } else {
      throw Exception('Login failed: ${res.body}');
    }
  }

  Future<TokenResponse> loginWithGoogle({
    required String email,
    required String name,
    required String sub,
    String? avatarUrl,
  }) async {
    final url = Uri.parse('$_baseUrl/api/auth/google-login');
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'email': email,
        'name': name,
        'sub': sub,
        'avatar_url': avatarUrl,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final tokenRes = TokenResponse.fromJson(data);
      await _saveToken(tokenRes.accessToken);
      return tokenRes;
    } else {
      throw Exception('Google login failed: ${res.body}');
    }
  }

  Future<UserModel> getCurrentUser() async {
    final token = await getToken();
    if (token == null) throw Exception("No token found");

    final url = Uri.parse('$_baseUrl/api/auth/me');
    final res = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return UserModel.fromJson(data);
    } else {
      throw Exception('Failed to get current user: ${res.body}');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  // Helpers
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
}
