/// Room list item model
///
/// Supports 2 formats:
/// 1. REST API: room_name, room_code, is_public, has_password
/// 2. WebSocket: name, is_private (no room_code, auto-generated fallback)
class RoomListItem {
  final int id;
  final String roomCode;
  final String roomName;
  final String hostUsername;
  final String status; // waiting, playing, finished
  final bool isPublic;
  final bool hasPassword;
  final int currentPlayers;
  final int maxPlayers;
  final DateTime createdAt;

  RoomListItem({
    required this.id,
    required this.roomCode,
    required this.roomName,
    required this.hostUsername,
    required this.status,
    required this.isPublic,
    required this.hasPassword,
    required this.currentPlayers,
    required this.maxPlayers,
    required this.createdAt,
  });

  factory RoomListItem.fromJson(Map<String, dynamic> json) {
    // WebSocket format: "name", "is_private" (no room_code, has_password)
    // REST API format: "room_name", "room_code", "is_public", "has_password"

    final isWebSocketFormat =
        json.containsKey('name') && !json.containsKey('room_name');

    // Try multiple field names for room code
    String getRoomCode() {
      if (json['room_code'] != null) return json['room_code'];
      if (json['code'] != null) return json['code'];
      // Fallback: generate from ID (only for display, not for joining)
      return 'ID:${json['id']}';
    }

    return RoomListItem(
      id: json['id'],
      roomCode: getRoomCode(),
      roomName: json['room_name'] ?? json['name'], // Support both formats
      hostUsername: json['host_username'],
      status: json['status'],
      isPublic: isWebSocketFormat
          ? !(json['is_private'] ?? false) // WebSocket: is_private
          : (json['is_public'] ?? true), // REST API: is_public
      hasPassword: json['has_password'] ?? false,
      currentPlayers: json['current_players'],
      maxPlayers: json['max_players'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class RoomPlayer {
  final int userId;
  final String username;
  final String? avatarUrl;
  final int rating;
  final bool isReady;
  final bool isHost;
  final DateTime joinedAt;

  RoomPlayer({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.rating,
    required this.isReady,
    required this.isHost,
    required this.joinedAt,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      userId: json['user_id'],
      username: json['username'],
      avatarUrl: json['avatar_url'],
      rating: json['rating'],
      isReady: json['is_ready'],
      isHost: json['is_host'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}

class RoomDetail {
  final int id;
  final String roomCode;
  final String roomName;
  final int hostId;
  final String status;
  final bool isPublic;
  final bool hasPassword;
  final int maxPlayers;
  final int currentPlayers;
  final int boardRows;
  final int boardCols;
  final int winLen;
  final DateTime createdAt;
  final List<RoomPlayer> players;
  final int? matchId;

  RoomDetail({
    required this.id,
    required this.roomCode,
    required this.roomName,
    required this.hostId,
    required this.status,
    required this.isPublic,
    required this.hasPassword,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.boardRows,
    required this.boardCols,
    required this.winLen,
    required this.createdAt,
    required this.players,
    this.matchId,
  });

  factory RoomDetail.fromJson(Map<String, dynamic> json) {
    return RoomDetail(
      id: json['id'],
      roomCode: json['room_code'],
      roomName: json['room_name'],
      hostId: json['host_id'],
      status: json['status'],
      isPublic: json['is_public'] ?? true,
      hasPassword: json['has_password'] ?? false,
      maxPlayers: json['max_players'],
      currentPlayers: json['current_players'],
      boardRows: json['board_rows'],
      boardCols: json['board_cols'],
      winLen: json['win_len'],
      createdAt: DateTime.parse(json['created_at']),
      players: (json['players'] as List)
          .map((p) => RoomPlayer.fromJson(p))
          .toList(),
      matchId: json['match_id'],
    );
  }
}

class CreateRoomRequest {
  final String roomName;
  final String? password;
  final int maxPlayers;
  final int boardRows;
  final int boardCols;
  final int winLen;
  final bool isPublic;

  CreateRoomRequest({
    required this.roomName,
    this.password,
    this.maxPlayers = 2,
    this.boardRows = 15,
    this.boardCols = 19,
    this.winLen = 5,
    this.isPublic = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'room_name': roomName,
      if (password != null && password!.isNotEmpty) 'password': password,
      'max_players': maxPlayers,
      'board_rows': boardRows,
      'board_cols': boardCols,
      'win_len': winLen,
      'is_public': isPublic,
    };
  }
}
