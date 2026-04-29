import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kNumberMergeGameId = 'number_merge';

// Sub-keys match _Difficulty.subKey in number_merge_screen.dart
const String kNMSubKeyEasy   = 'easy';
const String kNMSubKeyMedium = 'medium';
const String kNMSubKeyHard   = 'hard';

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerNumberMergeStats() {
  BestStatsRegistry.register(kNumberMergeGameId, _buildStats);
}

int bestScoreForKey(String subKey) =>
    ScoreService().getHighScore(kNumberMergeGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy   = bestScoreForKey(kNMSubKeyEasy);
  final medium = bestScoreForKey(kNMSubKeyMedium);
  final hard   = bestScoreForKey(kNMSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   'target 1024'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, 'target 2048'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   'target 4096'),
  ];
}

BestStat _row(String emoji, String label, int score, Color color, String sublabel) =>
    BestStat(
      label: '$emoji  $label',
      value: '$score',
      sublabel: sublabel,
      icon: Icons.grid_4x4_rounded,
      color: color,
    );
