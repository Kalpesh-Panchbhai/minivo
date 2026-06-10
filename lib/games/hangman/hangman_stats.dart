import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kHangmanGameId = 'hangman';

const String kHangmanSubKeyEasy = 'easy';
const String kHangmanSubKeyMedium = 'medium';
const String kHangmanSubKeyHard = 'hard';

const Color _kEasyColor = Color(0xFF4CB97A);
const Color _kMediumColor = Color(0xFFEFA63A);
const Color _kHardColor = Color(0xFFE8533D);

void registerHangmanStats() {
  BestStatsRegistry.register(kHangmanGameId, _buildStats);
}

int bestHangmanScore(String subKey) =>
    ScoreService().getHighScore(kHangmanGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy = bestHangmanScore(kHangmanSubKeyEasy);
  final medium = bestHangmanScore(kHangmanSubKeyMedium);
  final hard = bestHangmanScore(kHangmanSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    _row('🌱', 'EASY', easy, _kEasyColor),
    _row('🔥', 'MEDIUM', medium, _kMediumColor),
    _row('💀', 'HARD', hard, _kHardColor),
  ];
}

BestStat _row(String emoji, String label, int score, Color color) {
  return BestStat(
    label: '$emoji  $label',
    value: score == 0 ? '—' : '$score',
    sublabel: score == 0 ? 'no wins yet' : 'win streak',
    icon: Icons.local_fire_department_rounded,
    color: color,
  );
}
