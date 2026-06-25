import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/level_progress_service.dart';

const String kBlockEscapeGameId = 'block_escape';

void registerBlockEscapeStats() {
  BestStatsRegistry.register(kBlockEscapeGameId, _buildStats);
}

List<BestStat> _buildStats() {
  final lps = LevelProgressService();
  final easyLevel = lps.getHighestLevel(kBlockEscapeGameId, 'easy');
  final mediumLevel = lps.getHighestLevel(kBlockEscapeGameId, 'medium');
  final hardLevel = lps.getHighestLevel(kBlockEscapeGameId, 'hard');

  if (easyLevel == 0 && mediumLevel == 0 && hardLevel == 0) return const [];

  return [
    if (easyLevel > 0) _row('🌱', 'EASY', easyLevel, lps.getOverallBest(kBlockEscapeGameId, 'easy'), const Color(0xFF22C55E)),
    if (mediumLevel > 0) _row('🔥', 'MEDIUM', mediumLevel, lps.getOverallBest(kBlockEscapeGameId, 'medium'), const Color(0xFFF59E0B)),
    if (hardLevel > 0) _row('💀', 'HARD', hardLevel, lps.getOverallBest(kBlockEscapeGameId, 'hard'), const Color(0xFFEF4444)),
  ];
}

BestStat _row(String emoji, String label, int level, int best, Color color) => BestStat(
      label: '$emoji  $label',
      value: 'Level $level',
      sublabel: best > 0 ? 'Best: $best moves' : null,
      icon: Icons.lock_open_rounded,
      color: color,
    );
