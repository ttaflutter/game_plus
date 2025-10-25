import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:game_plus/configs/app_config.dart';
import 'package:game_plus/services/auth_service.dart';
import 'package:game_plus/services/caro_service.dart';
import 'package:game_plus/game/caro/winning_line_data.dart';

/// Quản lý logic chơi Caro (board + chat + kết nối WS)
class CaroController extends ChangeNotifier {
  final int rows;
  final int cols;
  final int winLen;
  final int matchId;

  List<List<String>> board = [];
  String currentTurn = "X";
  String? mySymbol;
  String? opponentSymbol;
  int? myUserId;
  int? opponentUserId;
  String? myUsername;
  String? opponentUsername;
  int? myRating; // Rating của mình
  int? opponentRating; // Rating của đối thủ
  int? myRatingChange; // Rating thay đổi sau trận (từ server)
  bool isConnected = false;
  bool isFinished = false;
  int? winnerId;
  int moveCount = 0;
  WinningLineData? winningLine;

  // Rematch
  bool rematchRequested = false;
  bool opponentRematchRequested = false;
  bool opponentLeft = false;
  int rematchRequestCount = 0;
  int? newMatchId;

  // Score tracking across rematches
  int myWins = 0;
  int opponentWins = 0;
  int draws = 0;

  // Timer
  int? timeLeft; // seconds
  int? initialTimeLeft; // giá trị ban đầu khi bắt đầu lượt
  DateTime? turnStartTime;
  bool _isTimerRunning = false; // Flag để track timer state
  CaroService? _service;

  // 🗨️ Chat messages (hiển thị ở panel)
  List<Map<String, dynamic>> chatMessages = [];
  int unreadMessageCount = 0; // Số tin nhắn chưa đọc
  bool isChatOpen = false; // Trạng thái chat panel

  CaroController({
    this.rows = 15,
    this.cols = 19,
    this.winLen = 5,
    required this.matchId,
    int? initialMyRating, // Thêm rating ban đầu
    int? initialOpponentRating, // Thêm rating đối thủ ban đầu
  }) {
    // Set initial ratings nếu có
    myRating = initialMyRating;
    opponentRating = initialOpponentRating;
    print(
      "🎮 CaroController created with ratings: my=$myRating, opponent=$opponentRating",
    );

    // Khởi tạo board ngay trong constructor
    initBoard();
  }

  // ==========================================================
  // 🔧 Setup board
  // ==========================================================
  void initBoard() {
    board = List.generate(rows, (_) => List.filled(cols, ""));
    currentTurn = "X";
    mySymbol = null;
    opponentSymbol = null;
    myUserId = null;
    opponentUserId = null;
    isFinished = false;
    winnerId = null;
    moveCount = 0;
    timeLeft = null;
    initialTimeLeft = null;
    turnStartTime = null;
    chatMessages.clear();
    // Không gọi notifyListeners() trong constructor
  }

  // ==========================================================
  // 🌐 Kết nối WebSocket (dùng matchId đã có)
  // ==========================================================
  Future<void> connectToServer() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception("Missing token");

      final wsUrl = AppConfig.wsMatchUrl(matchId, token);
      _service = CaroService(
        wsUrl: wsUrl,
        onMessage: _handleServerMessage,
        onClose: _handleDisconnect,
      );

      await _service!.connect();
      isConnected = true;
      notifyListeners();

      print("🎮 Connected to Caro match $matchId");
    } catch (e) {
      print("❌ connectToServer error: $e");
    }
  }

  // ==========================================================
  // 🧠 Xử lý message từ server
  // ==========================================================
  void _handleServerMessage(Map<String, dynamic> msg) {
    final type = msg["type"];
    final payload = msg["payload"] ?? {};

    print("📨 Received message: $type"); // DEBUG
    print("   Payload: $payload"); // DEBUG

    switch (type) {
      case "joined":
        // Nhận full snapshot từ server
        mySymbol = payload["you"]?["symbol"];
        myUserId = payload["you"]?["user_id"];
        opponentSymbol = mySymbol == "X" ? "O" : "X";
        currentTurn = payload["turn"] ?? "X";
        moveCount = payload["turn_no"] ?? 0;

        // Parse timeLeft carefully
        final timeLimitRaw = payload["time_left"];
        if (timeLimitRaw != null) {
          if (timeLimitRaw is int) {
            timeLeft = timeLimitRaw;
          } else if (timeLimitRaw is double) {
            timeLeft = timeLimitRaw.toInt();
          } else {
            timeLeft = int.tryParse(timeLimitRaw.toString());
          }
        }
        print("⏰ Time left from server: $timeLimitRaw → $timeLeft");

        // Load players
        final players = payload["players"] as List?;
        print(
          "🔍 DEBUG: Players from server: $players",
        ); // Debug full players data
        if (players != null) {
          for (var p in players) {
            final uid = p["user_id"];
            final username = p["username"];
            final rating = p["rating"]; // Lấy rating từ server

            print(
              "🔍 DEBUG: Player - uid: $uid, username: $username, rating: $rating",
            ); // Debug mỗi player

            if (uid == myUserId) {
              myUsername = username;
              myRating = rating;
              print("✅ Set myRating = $myRating"); // Confirm set
            } else {
              opponentUserId = uid;
              opponentUsername = username;
              opponentRating = rating;
              print("✅ Set opponentRating = $opponentRating"); // Confirm set
            }
          }
        }

        print(
          "👤 FINAL: My username: $myUsername (Rating: $myRating), Opponent: $opponentUsername (Rating: $opponentRating)",
        );

        // Load board từ server
        final boardData = payload["board"] as List?;
        if (boardData != null && boardData.isNotEmpty) {
          for (int i = 0; i < boardData.length && i < rows; i++) {
            final row = boardData[i] as List;
            for (int j = 0; j < row.length && j < cols; j++) {
              board[i][j] = row[j]?.toString() ?? "";
            }
          }
        }

        notifyListeners();
        print("🙋 Joined match as $mySymbol (user_id: $myUserId)");
        _startTimerIfNeeded();
        break;

      case "start":
        currentTurn = payload["turn"];

        final timeLimitStart = payload["time_limit"];
        if (timeLimitStart != null) {
          if (timeLimitStart is int) {
            timeLeft = timeLimitStart;
          } else if (timeLimitStart is double) {
            timeLeft = timeLimitStart.toInt();
          } else {
            timeLeft = int.tryParse(timeLimitStart.toString()) ?? 30;
          }
        } else {
          // Fallback: nếu server không gửi time_limit, dùng 30s mặc định
          timeLeft = 30;
        }
        print("🚀 Game started — turn = $currentTurn, timeLeft = $timeLeft");

        notifyListeners();
        _startTimerIfNeeded();
        break;
      case "move":
        final x = payload["x"];
        final y = payload["y"];
        final symbol = payload["symbol"];
        board[x][y] = symbol;
        currentTurn = payload["next_turn"];
        moveCount = payload["turn_no"] ?? moveCount + 1;

        final timeLimitMove = payload["time_limit"];
        if (timeLimitMove != null) {
          if (timeLimitMove is int) {
            timeLeft = timeLimitMove;
          } else if (timeLimitMove is double) {
            timeLeft = timeLimitMove.toInt();
          } else {
            timeLeft = int.tryParse(timeLimitMove.toString()) ?? 30;
          }
        } else {
          // Fallback: reset về 30s
          timeLeft = 30;
        }

        print(
          "📍 Move: ($x,$y) by $symbol, next turn: $currentTurn, timeLeft = $timeLeft",
        );

        notifyListeners();
        _startTimerIfNeeded();
        break;
      case "win":
        isFinished = true;
        winnerId = payload["winner_user_id"];

        // Update score
        if (winnerId == myUserId) {
          myWins++;
        } else {
          opponentWins++;
        }

        // Parse rating change từ server
        final ratingChanges =
            payload["rating_changes"] as Map<String, dynamic>?;
        if (ratingChanges != null && myUserId != null) {
          myRatingChange = ratingChanges[myUserId.toString()];
          print("💎 Rating change: $myRatingChange");
        }

        // Parse winning line
        final line = payload["line"] as List?;
        if (line != null) {
          winningLine = WinningLineData(
            line.map((p) => Position(p["x"], p["y"])).toList(),
          );
        }

        notifyListeners();
        print("🏆 Winner: user $winnerId (Score: $myWins-$opponentWins)");
        break;

      case "draw":
        isFinished = true;
        winnerId = null;
        draws++;

        // Parse rating change từ server (draw = 0)
        final ratingChanges =
            payload["rating_changes"] as Map<String, dynamic>?;
        if (ratingChanges != null && myUserId != null) {
          myRatingChange = ratingChanges[myUserId.toString()];
          print("💎 Rating change: $myRatingChange");
        }

        notifyListeners();
        print("🤝 Game ended in a draw (Total draws: $draws)");
        break;

      case "timeout":
        isFinished = true;
        winnerId = payload["winner_user_id"];
        timeLeft = 0; // Set về 0 để dừng timer

        // Update score
        if (winnerId == myUserId) {
          myWins++;
        } else {
          opponentWins++;
        }

        // Parse rating change từ server
        final ratingChanges =
            payload["rating_changes"] as Map<String, dynamic>?;
        if (ratingChanges != null && myUserId != null) {
          myRatingChange = ratingChanges[myUserId.toString()];
          print("💎 Rating change: $myRatingChange");
        }

        notifyListeners();
        print(
          "⏰ Timeout! Loser: ${payload["loser_user_id"]}, Winner: user $winnerId (Score: $myWins-$opponentWins)",
        );
        break;

      case "surrender":
        isFinished = true;
        winnerId = payload["winner_user_id"];

        // Update score
        if (winnerId == myUserId) {
          myWins++;
        } else {
          opponentWins++;
        }

        // Parse rating change từ server
        final ratingChanges =
            payload["rating_changes"] as Map<String, dynamic>?;
        if (ratingChanges != null && myUserId != null) {
          myRatingChange = ratingChanges[myUserId.toString()];
          print("💎 Rating change: $myRatingChange");
        }

        notifyListeners();
        print(
          "🏳️ Player ${payload["surrendered_user_id"]} surrendered (Score: $myWins-$opponentWins)",
        );
        break;

      case "disconnect":
        final disconnectedUserId = payload["disconnected_user_id"];

        // Nếu đối thủ disconnect khi đang trong dialog end game hoặc game đang chơi
        if (disconnectedUserId != myUserId) {
          opponentLeft = true;
          print("🔌 Opponent left! User $disconnectedUserId disconnected");
        }

        // Chỉ set winner nếu game chưa finished
        if (!isFinished) {
          isFinished = true;
          winnerId = payload["winner_user_id"];
        }

        notifyListeners();
        break;

      case "player_left":
        // Trường hợp đặc biệt: player rời khi đang trong end game dialog
        final leftUserId = payload["user_id"];
        if (leftUserId != myUserId) {
          opponentLeft = true;
          print("👋 Opponent left the room! User $leftUserId");
          notifyListeners();
        }
        break;

      case "chat":
        chatMessages.add({
          "from": payload["from"],
          "message": payload["message"],
          "time": payload["time"],
        });

        // Tăng unread count nếu chat đang đóng
        if (!isChatOpen) {
          unreadMessageCount++;
        }

        notifyListeners();
        break;

      case "rematch_request":
        // Ai đó yêu cầu chơi lại
        rematchRequestCount = payload["total_requests"] ?? 0;
        final fromUserId = payload["from_user_id"];

        // Nếu là đối thủ yêu cầu rematch
        if (fromUserId != myUserId) {
          opponentRematchRequested = true;
        }

        print(
          "🔄 Rematch request from user $fromUserId ($rematchRequestCount/2)",
        );
        notifyListeners();
        break;

      case "rematch_accepted":
        // Cả 2 đồng ý, có match mới
        newMatchId = payload["new_match_id"];
        print("✅ Rematch accepted! New match: $newMatchId");
        notifyListeners();
        break;

      case "rematch_cancelled":
        // Rematch bị hủy vì 1 player rời
        opponentLeft = true;
        rematchRequested = false;
        opponentRematchRequested = false;
        print("❌ Rematch cancelled! Opponent left");
        notifyListeners();
        break;

      case "pong":
        // Response to ping
        break;

      case "error":
        print("⚠️ Error from server: ${payload}");
        break;

      default:
        print("📩 Unknown message: $msg");
    }
  }

  // Timer countdown
  void _startTimerIfNeeded() {
    if (timeLeft == null || isFinished || _isTimerRunning) return;

    // Lưu giá trị ban đầu và thời điểm bắt đầu
    initialTimeLeft = timeLeft;
    turnStartTime = DateTime.now();
    _isTimerRunning = true;
    _updateTimer();
  }

  void _updateTimer() {
    // CRITICAL: Check if disposed or stopped
    if (!_isTimerRunning ||
        isFinished ||
        turnStartTime == null ||
        initialTimeLeft == null) {
      _isTimerRunning = false;
      return;
    }

    // Tính thời gian còn lại dựa trên elapsed time
    final elapsed = DateTime.now().difference(turnStartTime!).inSeconds;
    final remaining = (initialTimeLeft! - elapsed).clamp(0, 999);

    // Update UI
    if (remaining != timeLeft) {
      timeLeft = remaining;
      notifyListeners();
    }

    if (timeLeft! > 0 && !isFinished && _isTimerRunning) {
      Future.delayed(const Duration(seconds: 1), _updateTimer);
    } else {
      _isTimerRunning = false;
    }
  }

  void _stopTimer() {
    _isTimerRunning = false;
    turnStartTime = null;
  } // ==========================================================

  // ✉️ Gửi chat & move & surrender
  // ==========================================================
  void sendMove(int x, int y) {
    if (isFinished || !isConnected) return;
    final data = jsonEncode({
      "type": "move",
      "payload": {"x": x, "y": y},
    });
    _service?.send(data);
  }

  // ==========================================================
  // 💬 Chat methods
  // ==========================================================

  /// Mở chat panel và reset unread count
  void openChat() {
    isChatOpen = true;
    unreadMessageCount = 0;
    notifyListeners();
  }

  /// Đóng chat panel
  void closeChat() {
    isChatOpen = false;
    notifyListeners();
  }

  void sendChat(String text) {
    if (!isConnected || text.trim().isEmpty) return;
    final data = jsonEncode({
      "type": "chat",
      "payload": {"message": text.trim()},
    });
    _service?.send(data);
  }

  void surrender() {
    if (isFinished || !isConnected) return;
    final data = jsonEncode({"type": "surrender", "payload": {}});
    _service?.send(data);
  }

  void requestRematch() {
    if (!isFinished || !isConnected) return;
    rematchRequested = true;
    notifyListeners();

    final data = jsonEncode({"type": "rematch", "payload": {}});
    _service?.send(data);
    print("🔄 Rematch request sent");
  }

  // ==========================================================
  // 🔌 Disconnect
  // ==========================================================
  void _handleDisconnect() {
    _stopTimer(); // Stop timer khi disconnect
    isConnected = false;
    notifyListeners();
  }

  void disconnect() {
    _stopTimer(); // Stop timer trước khi disconnect
    _service?.disconnect();
    isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer(); // Stop timer khi dispose
    _service?.disconnect();
    super.dispose();
  }
}
