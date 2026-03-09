class AvatarData {
  final int color;
  final int eyes;
  final int mouth;

  AvatarData({required this.color, required this.eyes, required this.mouth});

  factory AvatarData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AvatarData(color: 11, eyes: 30, mouth: 23);
    return AvatarData(color: json['color'] ?? 11, eyes: json['eyes'] ?? 30, mouth: json['mouth'] ?? 23);
  }
}

class Player {
  final String id;
  final String nickname;
  final int score;
  final int turnScore;
  final bool isDrawer;
  final bool guessedWord;
  final bool voted;
  final AvatarData avatar;

  Player({
    required this.id,
    required this.nickname,
    required this.score,
    required this.turnScore,
    required this.isDrawer,
    required this.guessedWord,
    required this.voted,
    required this.avatar,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? 'Unknown',
      score: json['score'] ?? 0,
      turnScore: json['turn_score'] ?? 0,
      isDrawer: json['isDrawer'] ?? false,
      guessedWord: json['guessedWord'] ?? false,
      voted: json['voted'] ?? false,
      avatar: AvatarData.fromJson(json['avatar']),
    );
  }
}
