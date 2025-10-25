import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:game_plus/configs/app_config.dart';
import 'package:game_plus/services/auth_service.dart';
import 'package:game_plus/models/friend_model.dart';

class FriendService {
  static String get baseUrl => AppConfig.baseUrl;

  /// Tìm kiếm users theo username
  static Future<List<FriendUser>> searchUsers(String query) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception("Not authenticated");

    final url = Uri.parse('$baseUrl/api/friends/search?query=$query');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => FriendUser.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search users: ${response.body}');
    }
  }

  /// Gửi lời mời kết bạn
  static Future<FriendRequest> sendFriendRequest(String username) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception("Not authenticated");

    final url = Uri.parse('$baseUrl/api/friends/requests');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'receiver_username': username}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      return FriendRequest.fromJson(data);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to send friend request');
    }
  }

  /// Lấy danh sách lời mời nhận được
  static Future<List<FriendRequest>> getReceivedRequests() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception("Not authenticated");

    final url = Uri.parse('$baseUrl/api/friends/requests/received');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => FriendRequest.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get received requests: ${response.body}');
    }
  }

  /// Lấy danh sách lời mời đã gửi
  static Future<List<FriendRequest>> getSentRequests() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception("Not authenticated");

    final url = Uri.parse('$baseUrl/api/friends/requests/sent');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => FriendRequest.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get sent requests: ${response.body}');
    }
  }

  /// Chấp nhận hoặc từ chối lời mời
  static Future<FriendRequest> respondToRequest(
    int requestId,
    String action,
  ) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception("Not authenticated");

    final url = Uri.parse('$baseUrl/api/friends/requests/$requestId');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'action': action}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return FriendRequest.fromJson(data);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to respond to request');
    }
  }

  /// Hủy lời mời đã gửi
  static Future<void> cancelFriendRequest(int requestId) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception("Not authenticated");

    final url = Uri.parse('$baseUrl/api/friends/requests/$requestId');
    final response = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to cancel request');
    }
  }

  /// Lấy danh sách bạn bè
  static Future<List<FriendUser>> getFriends() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception("Not authenticated");

    final url = Uri.parse('$baseUrl/api/friends');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => FriendUser.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get friends: ${response.body}');
    }
  }

  /// Hủy kết bạn
  static Future<void> removeFriend(int friendId) async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception("Not authenticated");

    final url = Uri.parse('$baseUrl/api/friends/$friendId');
    final response = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['detail'] ?? 'Failed to remove friend');
    }
  }
}
