class CaroMessage {
  final String type;
  final Map<String, dynamic> payload;

  CaroMessage({required this.type, required this.payload});

  factory CaroMessage.fromJson(Map<String, dynamic> json) {
    return CaroMessage(
      type: json['type'] ?? '',
      payload: json['payload'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};
}

class MoveMessage {
  final int x;
  final int y;
  final String symbol;
  final String nextTurn;

  MoveMessage({
    required this.x,
    required this.y,
    required this.symbol,
    required this.nextTurn,
  });

  factory MoveMessage.fromJson(Map<String, dynamic> json) => MoveMessage(
    x: json['x'] ?? 0,
    y: json['y'] ?? 0,
    symbol: json['symbol'] ?? '',
    nextTurn: json['next_turn'] ?? '',
  );
}

class ChatMessage {
  final int from;
  final String message;
  final String time;

  ChatMessage({required this.from, required this.message, required this.time});

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    from: json['from'] ?? 0,
    message: json['message'] ?? '',
    time: json['time'] ?? '',
  );
}
