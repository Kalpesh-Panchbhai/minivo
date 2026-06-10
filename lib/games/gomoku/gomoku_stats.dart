import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kGomokuGameId = 'gomoku';

const String kGomokuSubKeyEasy = 'ai_easy';
const String kGomokuSubKeyMedium = 'ai_medium';
const String kGomokuSubKeyHard = 'ai_hard';

const Color _kEasyColor = Color(0xFF4CB97A);
const Color _kMediumColor = Color(0xFFEFA63A);
const Color _kHardColor = Color(0xFFE8533D);

void registerGomokuStats() {
  BestStatsRegistry.register(kGomokuGameId, _buildStats);
}

int bestGomokuStreak(String subKey) =>
    ScoreService().getHighScore(kGomokuGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy = bestGomokuStreak(kGomokuSubKeyEasy);
  final medium = bestGomokuStreak(kGomokuSubKeyMedium);
  final hard = bestGomokuStreak(kGomokuSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    _row('🌱', 'EASY', easy, _kEasyColor),
    _row('🔥', 'MEDIUM', medium, _kMediumColor),
    _row('💀', 'HARD', hard, _kHardColor),
  ];
}

BestStat _row(String emoji, String label, int streak, Color color) {
  return BestStat(
    label: '$emoji  $label',
    value: streak == 0 ? '—' : '$streak',
    sublabel: streak == 0 ? 'no wins yet' : 'win streak',
    icon: Icons.local_fire_department_rounded,
    color: color,
  );
}
