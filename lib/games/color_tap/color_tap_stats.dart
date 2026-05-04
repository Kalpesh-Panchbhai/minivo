import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kColorTapGameId = 'color_tap';

const String kCTSubKeyEasy   = 'easy';
const String kCTSubKeyMedium = 'medium';
const String kCTSubKeyHard   = 'hard';

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerColorTapStats() {
  BestStatsRegistry.register(kColorTapGameId, _buildStats);
}

int bestColorTapScore(String subKey) =>
    ScoreService().getHighScore(kColorTapGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy   = bestColorTapScore(kCTSubKeyEasy);
  final medium = bestColorTapScore(kCTSubKeyMedium);
  final hard   = bestColorTapScore(kCTSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   '10 pts/match'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, '15 pts/match'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   '20 pts/match'),
  ];
}

BestStat _row(String emoji, String label, int score, Color color, String sublabel) =>
    BestStat(
      label: '$emoji  $label',
      value: '$score',
      sublabel: sublabel,
      icon: Icons.emoji_events_rounded,
      color: color,
    );
