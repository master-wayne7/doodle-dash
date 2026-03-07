class Player {
  final String id;
  final String nickname;
  final int score;
  final int turnScore;
  final bool isDrawer;
  final bool guessedWord;

  Player({
    required this.id,
    required this.nickname,
    required this.score,
    required this.turnScore,
    required this.isDrawer,
    required this.guessedWord,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] ?? '',
      nickname: json['nickname'] ?? 'Unknown',
      score: json['score'] ?? 0,
      turnScore: json['turn_score'] ?? 0,
      isDrawer: json['isDrawer'] ?? false,
      guessedWord: json['guessedWord'] ?? false,
    );
  }
}
