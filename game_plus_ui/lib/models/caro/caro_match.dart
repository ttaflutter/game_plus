import 'caro_player.dart';

enum MatchStatus { waiting, playing, finished }

class CaroMatch {
  final int id;
  final List<CaroPlayer> players;
  final String turn;
  final MatchStatus status;

  CaroMatch({
    required this.id,
    required this.players,
    required this.turn,
    required this.status,
  });

  factory CaroMatch.fromJson(Map<String, dynamic> json) {
    final players =
        (json['players'] as List<dynamic>?)
            ?.map((p) => CaroPlayer.fromJson(p))
            .toList() ??
        [];
    return CaroMatch(
      id: json['id'] ?? 0,
      players: players,
      turn: json['turn'] ?? 'X',
      status: _parseStatus(json['status']),
    );
  }

  static MatchStatus _parseStatus(String? value) {
    switch (value) {
      case 'playing':
        return MatchStatus.playing;
      case 'finished':
        return MatchStatus.finished;
      default:
        return MatchStatus.waiting;
    }
  }
}
