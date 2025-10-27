import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../configs/app_config.dart';
import 'auth_service.dart';

class RoomWebSocketManager {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _channel != null;

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_isConnecting || _channel != null) return;

    _isConnecting = true;
    _shouldReconnect = true;

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }

      // Convert http(s) URL to ws(s)
      final wsUrl = AppConfig.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      final uri = Uri.parse('$wsUrl/ws/rooms?token=$token');

      print('🔌 Connecting to WebSocket: $uri');

      _channel = WebSocketChannel.connect(uri);

      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      // Start heartbeat
      _startPing();

      _reconnectAttempts = 0;
      print('✅ WebSocket connected');
    } catch (e) {
      print('❌ WebSocket connection error: $e');
      _handleConnectionError();
    } finally {
      _isConnecting = false;
    }
  }

  /// Handle incoming messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'pong') {
        // Heartbeat response - no need to broadcast
        print('💓 Pong received');
        return;
      }

      // Broadcast to listeners
      _messageController.add(data);
    } catch (e) {
      print('⚠️ Error parsing message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    print('❌ WebSocket error: $error');
    _handleConnectionError();
  }

  /// Handle WebSocket closure
  void _handleDone() {
    print('🔌 WebSocket connection closed');
    _stopPing();
    _channel = null;

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  /// Handle connection errors
  void _handleConnectionError() {
    _stopPing();
    _channel = null;

    if (_shouldReconnect && _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Max reconnection attempts reached');
      _messageController.add({
        'type': 'error',
        'payload': {'message': 'Không thể kết nối đến server'},
      });
    }
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    _reconnectAttempts++;
    final delay = Duration(seconds: 2 * _reconnectAttempts);

    print(
      '🔄 Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect) {
        connect();
      }
    });
  }

  /// Start heartbeat ping every 25 seconds
  void _startPing() {
    _stopPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      send({'type': 'ping'});
    });
  }

  /// Stop heartbeat
  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Send refresh request to get latest room list
  void refresh() {
    send({'type': 'refresh'});
  }

  /// Send message to server
  void send(Map<String, dynamic> message) {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        print('⚠️ Error sending message: $e');
      }
    } else {
      print('⚠️ Cannot send message: WebSocket not connected');
    }
  }

  /// Disconnect WebSocket
  void disconnect() {
    print('🔌 Disconnecting WebSocket');
    _shouldReconnect = false;
    _reconnectAttempts = 0;

    _stopPing();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _channel?.sink.close();
    _channel = null;
  }

  /// Dispose and clean up
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
