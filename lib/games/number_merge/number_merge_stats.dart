import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kNumberMergeGameId = 'number_merge';
const String kNumberMergeSubKeyClassic = 'classic';

void registerNumberMergeStats() {
  BestStatsRegistry.register(kNumberMergeGameId, _buildNumberMergeStats);
}

int bestScore() =>
    ScoreService().getHighScore(kNumberMergeGameId, subKey: kNumberMergeSubKeyClassic);

List<BestStat> _buildNumberMergeStats() {
  final score = bestScore();
  if (score == 0) return const [];

  return [
    BestStat(
      label: '🏆  CLASSIC',
      value: '$score',
      sublabel: 'best score',
      icon: Icons.grid_4x4_rounded,
      color: const Color(0xFFEDC22E),
    ),
  ];
}
