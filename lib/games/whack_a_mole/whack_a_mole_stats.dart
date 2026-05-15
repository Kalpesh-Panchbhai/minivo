import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kWhackAMoleGameId = 'whack_a_mole';

const String kWAMSubKeyEasy   = 'easy';
const String kWAMSubKeyMedium = 'medium';
const String kWAMSubKeyHard   = 'hard';

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerWhackAMoleStats() {
  BestStatsRegistry.register(kWhackAMoleGameId, _buildStats);
}

int bestWhackAMoleScore(String subKey) =>
    ScoreService().getHighScore(kWhackAMoleGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy   = bestWhackAMoleScore(kWAMSubKeyEasy);
  final medium = bestWhackAMoleScore(kWAMSubKeyMedium);
  final hard   = bestWhackAMoleScore(kWAMSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   '45 sec'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, '35 sec'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   '25 sec'),
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
