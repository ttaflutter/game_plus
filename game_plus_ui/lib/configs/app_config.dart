import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Cấu hình chung của app, load từ .env
class AppConfig {
  /// Base HTTP URL cho REST API
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:8000';

  /// Base WebSocket URL cho realtime (tự động chuyển http ↔ ws)
  static String get wsBaseUrl {
    final url = baseUrl;
    if (url.startsWith('https')) {
      return url.replaceFirst('https', 'wss');
    } else {
      return url.replaceFirst('http', 'ws');
    }
  }

  /// Sinh URL WebSocket match hoàn chỉnh
  static String wsMatchUrl(int matchId, String token) {
    return "$wsBaseUrl/ws/match/$matchId?token=$token";
  }

  /// Sinh URL WebSocket matchmaking hoàn chỉnh
  static String wsMatchmakingUrl(String token) {
    // Ensure proper WebSocket path with /ws/ prefix
    final baseWs = wsBaseUrl;
    // Remove trailing slash if exists
    final cleanBase = baseWs.endsWith('/')
        ? baseWs.substring(0, baseWs.length - 1)
        : baseWs;
    return "$cleanBase/ws/matchmaking?token=$token";
  }
}
