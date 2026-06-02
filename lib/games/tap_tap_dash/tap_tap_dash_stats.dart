import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kTapTapDashGameId = 'tap_tap_dash';

const String kTapDashSubKeyEasy   = 'easy';
const String kTapDashSubKeyMedium = 'medium';
const String kTapDashSubKeyHard   = 'hard';

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerTapTapDashStats() {
  BestStatsRegistry.register(kTapTapDashGameId, _buildStats);
}

int bestTapDashScore(String subKey) =>
    ScoreService().getHighScore(kTapTapDashGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy   = bestTapDashScore(kTapDashSubKeyEasy);
  final medium = bestTapDashScore(kTapDashSubKeyMedium);
  final hard   = bestTapDashScore(kTapDashSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   'Gentle pace'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, 'Steady speed'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   'Blazing fast'),
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
