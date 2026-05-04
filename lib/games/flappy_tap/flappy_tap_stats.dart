import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kFlappyTapGameId = 'flappy_tap';

// Sub-keys match _Difficulty.subKey in flappy_tap_screen.dart
const String kFTSubKeyEasy   = 'easy';
const String kFTSubKeyMedium = 'medium';
const String kFTSubKeyHard   = 'hard';

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerFlappyTapStats() {
  BestStatsRegistry.register(kFlappyTapGameId, _buildStats);
}

int bestScoreForKey(String subKey) =>
    ScoreService().getHighScore(kFlappyTapGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy   = bestScoreForKey(kFTSubKeyEasy);
  final medium = bestScoreForKey(kFTSubKeyMedium);
  final hard   = bestScoreForKey(kFTSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   '5 pts/pipe'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, '10 pts/pipe'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   '20 pts/pipe'),
  ];
}

BestStat _row(
  String emoji,
  String label,
  int score,
  Color color,
  String sublabel,
) =>
    BestStat(
      label: '$emoji  $label',
      value: '$score',
      sublabel: sublabel,
      icon: Icons.emoji_events_rounded,
      color: color,
    );
