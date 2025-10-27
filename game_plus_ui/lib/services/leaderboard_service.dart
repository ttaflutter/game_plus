import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../configs/app_config.dart';
import '../models/leaderboard_model.dart';

class LeaderboardService {
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

  /// GET /api/leaderboard/ - Lấy bảng xếp hạng
  static Future<List<LeaderboardEntry>> getLeaderboard({
    String gameName = 'Caro',
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    final queryParams = {
      'game_name': gameName,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final uri = Uri.parse(
      '$_baseUrl/api/leaderboard/',
    ).replace(queryParameters: queryParams);

    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => LeaderboardEntry.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load leaderboard: ${response.body}');
    }
  }

  /// GET /api/leaderboard/user/{user_id} - Xem chi tiết người chơi
  static Future<UserProfileDetail> getUserProfile(
    int userId, {
    String gameName = 'Caro',
  }) async {
    final queryParams = {'game_name': gameName};
    final uri = Uri.parse(
      '$_baseUrl/api/leaderboard/user/$userId',
    ).replace(queryParameters: queryParams);

    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return UserProfileDetail.fromJson(data);
    } else if (response.statusCode == 404) {
      throw Exception('User not found');
    } else {
      throw Exception('Failed to load user profile: ${response.body}');
    }
  }

  /// GET /api/leaderboard/my-stats - Xem stats của chính mình
  static Future<UserProfileDetail> getMyStats({
    String gameName = 'Caro',
  }) async {
    final queryParams = {'game_name': gameName};
    final uri = Uri.parse(
      '$_baseUrl/api/leaderboard/my-stats',
    ).replace(queryParameters: queryParams);

    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return UserProfileDetail.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to load my stats: ${response.body}');
    }
  }

  /// GET /api/leaderboard/top/{top_n} - Lấy top N người chơi
  static Future<List<LeaderboardEntry>> getTopPlayers(
    int topN, {
    String gameName = 'Caro',
  }) async {
    if (topN < 1 || topN > 100) {
      throw ArgumentError('topN must be between 1 and 100');
    }

    final queryParams = {'game_name': gameName};
    final uri = Uri.parse(
      '$_baseUrl/api/leaderboard/top/$topN',
    ).replace(queryParameters: queryParams);

    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => LeaderboardEntry.fromJson(json)).toList();
    } else if (response.statusCode == 400) {
      throw Exception('Invalid topN value - must be between 1 and 100');
    } else {
      throw Exception('Failed to load top players: ${response.body}');
    }
  }

  /// Helper: Load more data for pagination
  static Future<List<LeaderboardEntry>> loadMore({
    required int currentOffset,
    int limit = 20,
    String? search,
  }) async {
    return getLeaderboard(offset: currentOffset, limit: limit, search: search);
  }
}
