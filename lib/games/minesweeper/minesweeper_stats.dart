import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kMinesweeperGameId = 'minesweeper';

const String kMSSubKeyEasy   = 'easy';
const String kMSSubKeyMedium = 'medium';
const String kMSSubKeyHard   = 'hard';

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerMinesweeperStats() {
  BestStatsRegistry.register(kMinesweeperGameId, _buildStats);
}

int bestMinesweeperScore(String subKey) =>
    ScoreService().getHighScore(kMinesweeperGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy   = bestMinesweeperScore(kMSSubKeyEasy);
  final medium = bestMinesweeperScore(kMSSubKeyMedium);
  final hard   = bestMinesweeperScore(kMSSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   '9×9 · 10 mines'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, '16×16 · 40 mines'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   '16×30 · 99 mines'),
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
