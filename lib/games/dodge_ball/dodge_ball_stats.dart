import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kDodgeBallGameId = 'dodge_ball';

const String kDodgeSubKeyEasy   = 'easy';
const String kDodgeSubKeyMedium = 'medium';
const String kDodgeSubKeyHard   = 'hard';

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerDodgeBallStats() {
  BestStatsRegistry.register(kDodgeBallGameId, _buildStats);
}

int bestDodgeScore(String subKey) =>
    ScoreService().getHighScore(kDodgeBallGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy   = bestDodgeScore(kDodgeSubKeyEasy);
  final medium = bestDodgeScore(kDodgeSubKeyMedium);
  final hard   = bestDodgeScore(kDodgeSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   'Gentle pace'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, 'Classic speed'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   'Pure reflexes'),
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
