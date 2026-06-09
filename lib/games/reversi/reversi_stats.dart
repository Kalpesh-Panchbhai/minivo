import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kReversiGameId = 'reversi';

const String kRvSubKeyEasy = 'ai_easy';
const String kRvSubKeyMedium = 'ai_medium';
const String kRvSubKeyHard = 'ai_hard';

const Color _kEasyColor = Color(0xFF4CB97A);
const Color _kMediumColor = Color(0xFFEFA63A);
const Color _kHardColor = Color(0xFFE8533D);

void registerReversiStats() {
  BestStatsRegistry.register(kReversiGameId, _buildStats);
}

int bestReversiStreak(String subKey) =>
    ScoreService().getHighScore(kReversiGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final easy = bestReversiStreak(kRvSubKeyEasy);
  final medium = bestReversiStreak(kRvSubKeyMedium);
  final hard = bestReversiStreak(kRvSubKeyHard);

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
