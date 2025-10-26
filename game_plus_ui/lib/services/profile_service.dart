import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../configs/app_config.dart';
import '../models/profile_model.dart';

class ProfileService {
  static String get _baseUrl => AppConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, String>> _getHeadersWithAuth() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await _getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET /api/profile/me - Lấy profile của mình
  static Future<MyProfile> getMyProfile() async {
    final uri = Uri.parse('$_baseUrl/api/profile/me');
    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return MyProfile.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to load profile: ${response.body}');
    }
  }

  /// PUT /api/profile/update - Cập nhật profile
  static Future<MyProfile> updateProfile({
    String? username,
    String? bio,
    String? avatarUrl,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/profile/update');
    final headers = await _getHeadersWithAuth();

    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return MyProfile.fromJson(data);
    } else if (response.statusCode == 400) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['detail'] ?? 'Validation error');
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to update profile: ${response.body}');
    }
  }

  /// PUT /api/profile/avatar - Cập nhật avatar
  static Future<MyProfile> updateAvatar(String avatarUrl) async {
    final uri = Uri.parse('$_baseUrl/api/profile/avatar');
    final headers = await _getHeadersWithAuth();

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode({'avatar_url': avatarUrl}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return MyProfile.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to update avatar: ${response.body}');
    }
  }

  /// POST /api/profile/change-password - Đổi mật khẩu
  static Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/profile/change-password');
    final headers = await _getHeadersWithAuth();

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 400) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['detail'] ?? 'Password change failed');
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to change password: ${response.body}');
    }
  }

  /// DELETE /api/profile/delete-account - Xóa tài khoản
  static Future<void> deleteAccount({String? password}) async {
    final queryParams = <String, String>{};
    if (password != null) {
      queryParams['password'] = password;
    }

    final uri = Uri.parse(
      '$_baseUrl/api/profile/delete-account',
    ).replace(queryParameters: queryParams);
    final headers = await _getHeadersWithAuth();

    final response = await http.delete(uri, headers: headers);

    if (response.statusCode == 200) {
      // Xóa token khỏi storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      return;
    } else if (response.statusCode == 400) {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['detail'] ?? 'Account deletion failed');
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to delete account: ${response.body}');
    }
  }

  /// POST /api/profile/logout - Đăng xuất
  static Future<void> logout() async {
    final uri = Uri.parse('$_baseUrl/api/profile/logout');
    final headers = await _getHeadersWithAuth();

    try {
      await http.post(uri, headers: headers);
    } catch (e) {
      // Ignore errors, just clear token
    }

    // Xóa token khỏi storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  /// GET /api/profile/settings - Lấy cài đặt
  static Future<ProfileSettings> getSettings() async {
    final uri = Uri.parse('$_baseUrl/api/profile/settings');
    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return ProfileSettings.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to load settings: ${response.body}');
    }
  }

  /// PUT /api/profile/settings - Cập nhật cài đặt
  static Future<ProfileSettings> updateSettings(
    ProfileSettings settings,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/profile/settings');
    final headers = await _getHeadersWithAuth();

    final response = await http.put(
      uri,
      headers: headers,
      body: jsonEncode(settings.toJson()),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return ProfileSettings.fromJson(data['settings']);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to update settings: ${response.body}');
    }
  }
}
