import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kSolitaireGameId = 'solitaire';

const String kSolSubKeyEasy   = 'easy';
const String kSolSubKeyMedium = 'medium';
const String kSolSubKeyHard   = 'hard';

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerSolitaireStats() {
  BestStatsRegistry.register(kSolitaireGameId, _buildStats);
}

int bestSolitaireScore(String subKey) =>
    ScoreService().getHighScore(kSolitaireGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy   = bestSolitaireScore(kSolSubKeyEasy);
  final medium = bestSolitaireScore(kSolSubKeyMedium);
  final hard   = bestSolitaireScore(kSolSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   'Draw 1'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, 'Draw 3'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   'Draw 3 + Timer'),
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
