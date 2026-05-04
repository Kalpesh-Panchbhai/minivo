import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kMemoryMatchGameId = 'memory_match';

const String kMMSubKeyEasy   = 'easy';
const String kMMSubKeyMedium = 'medium';
const String kMMSubKeyHard   = 'hard';

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerMemoryMatchStats() {
  BestStatsRegistry.register(kMemoryMatchGameId, _buildStats);
}

int bestMemoryScore(String subKey) =>
    ScoreService().getHighScore(kMemoryMatchGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy   = bestMemoryScore(kMMSubKeyEasy);
  final medium = bestMemoryScore(kMMSubKeyMedium);
  final hard   = bestMemoryScore(kMMSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   '4×3 grid'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, '4×4 grid'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   '6×4 grid'),
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
