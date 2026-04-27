class GameScore {
  final String gameId;
  final int score;
  final int stars;
  final int coinsEarned;
  final Duration playTime;
  final DateTime playedAt;
  final bool isHighScore;

  const GameScore({
    required this.gameId,
    required this.score,
    required this.stars,
    required this.coinsEarned,
    required this.playTime,
    required this.playedAt,
    this.isHighScore = false,
  });
}

class LeaderboardEntry {
  final String userId;
  final String displayName;
  final int score;
  final DateTime timestamp;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.score,
    required this.timestamp,
    required this.rank,
  });
}
