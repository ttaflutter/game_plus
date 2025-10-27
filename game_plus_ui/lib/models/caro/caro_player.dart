class CaroPlayer {
  final int userId;
  final String symbol;

  CaroPlayer({required this.userId, required this.symbol});

  factory CaroPlayer.fromJson(Map<String, dynamic> json) =>
      CaroPlayer(userId: json['user_id'] ?? 0, symbol: json['symbol'] ?? '');

  Map<String, dynamic> toJson() => {'user_id': userId, 'symbol': symbol};
}
