import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../configs/app_config.dart';
import '../models/match_history_model.dart';

class MatchHistoryService {
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

  /// GET /api/match-history/my-matches - Lịch sử đấu của mình
  static Future<List<MatchHistoryItem>> getMyMatches({
    String gameName = 'Caro',
    String? status,
    String? result,
    int limit = 10,
    int offset = 0,
  }) async {
    final queryParams = {
      'game_name': gameName,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null) 'status': status,
      if (result != null) 'result': result,
    };

    final uri = Uri.parse(
      '$_baseUrl/api/match-history/my-matches',
    ).replace(queryParameters: queryParams);

    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => MatchHistoryItem.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to load match history: ${response.body}');
    }
  }

  /// GET /api/match-history/user/{user_id} - Lịch sử đấu của người khác
  static Future<List<MatchHistoryItem>> getUserMatches(
    int userId, {
    String gameName = 'Caro',
    String? status,
    String? result,
    int limit = 10,
    int offset = 0,
  }) async {
    final queryParams = {
      'game_name': gameName,
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (status != null) 'status': status,
      if (result != null) 'result': result,
    };

    final uri = Uri.parse(
      '$_baseUrl/api/match-history/user/$userId',
    ).replace(queryParameters: queryParams);

    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => MatchHistoryItem.fromJson(json)).toList();
    } else if (response.statusCode == 404) {
      throw Exception('User not found');
    } else {
      throw Exception('Failed to load user matches: ${response.body}');
    }
  }

  /// GET /api/match-history/match/{match_id} - Chi tiết trận đấu + replay
  static Future<MatchDetail> getMatchDetail(int matchId) async {
    final uri = Uri.parse('$_baseUrl/api/match-history/match/$matchId');

    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return MatchDetail.fromJson(data);
    } else if (response.statusCode == 404) {
      throw Exception('Match not found');
    } else {
      throw Exception('Failed to load match detail: ${response.body}');
    }
  }

  /// GET /api/match-history/stats/summary - Tổng hợp thống kê
  static Future<MatchStatsResponse> getStats({String gameName = 'Caro'}) async {
    final queryParams = {'game_name': gameName};

    final uri = Uri.parse(
      '$_baseUrl/api/match-history/stats/summary',
    ).replace(queryParameters: queryParams);

    final headers = await _getHeadersWithAuth();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return MatchStatsResponse.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login first');
    } else {
      throw Exception('Failed to load stats: ${response.body}');
    }
  }

  /// Helper: Load more matches for pagination
  static Future<List<MatchHistoryItem>> loadMore({
    required int currentOffset,
    int limit = 10,
    String? result,
  }) async {
    return getMyMatches(offset: currentOffset, limit: limit, result: result);
  }

  /// Helper: Get wins only
  static Future<List<MatchHistoryItem>> getWins({
    int limit = 10,
    int offset = 0,
  }) async {
    return getMyMatches(result: 'win', limit: limit, offset: offset);
  }

  /// Helper: Get losses only
  static Future<List<MatchHistoryItem>> getLosses({
    int limit = 10,
    int offset = 0,
  }) async {
    return getMyMatches(result: 'loss', limit: limit, offset: offset);
  }

  /// Helper: Get draws only
  static Future<List<MatchHistoryItem>> getDraws({
    int limit = 10,
    int offset = 0,
  }) async {
    return getMyMatches(result: 'draw', limit: limit, offset: offset);
  }

  /// Helper: Build board from moves up to specific move index
  static List<List<String?>> buildBoardFromMoves({
    required int rows,
    required int cols,
    required List<MoveDetail> moves,
    required int upToMoveIndex,
  }) {
    final board = List.generate(rows, (_) => List<String?>.filled(cols, null));

    for (int i = 0; i < upToMoveIndex && i < moves.length; i++) {
      final move = moves[i];
      board[move.x][move.y] = move.symbol;
    }

    return board;
  }
}
