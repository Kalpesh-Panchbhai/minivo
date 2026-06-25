import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/level_progress_service.dart';

const String kMazePaintGameId = 'maze_paint';

void registerMazePaintStats() {
  BestStatsRegistry.register(kMazePaintGameId, _buildStats);
}

List<BestStat> _buildStats() {
  final lps = LevelProgressService();
  final easyLevel = lps.getHighestLevel(kMazePaintGameId, 'easy');
  final mediumLevel = lps.getHighestLevel(kMazePaintGameId, 'medium');
  final hardLevel = lps.getHighestLevel(kMazePaintGameId, 'hard');

  if (easyLevel == 0 && mediumLevel == 0 && hardLevel == 0) return const [];

  return [
    if (easyLevel > 0) _row('🌱', 'EASY', easyLevel, lps.getOverallBest(kMazePaintGameId, 'easy'), const Color(0xFF22C55E)),
    if (mediumLevel > 0) _row('🔥', 'MEDIUM', mediumLevel, lps.getOverallBest(kMazePaintGameId, 'medium'), const Color(0xFFF59E0B)),
    if (hardLevel > 0) _row('💀', 'HARD', hardLevel, lps.getOverallBest(kMazePaintGameId, 'hard'), const Color(0xFFEF4444)),
  ];
}

BestStat _row(String emoji, String label, int level, int best, Color color) => BestStat(
      label: '$emoji  $label',
      value: 'Level $level',
      sublabel: best > 0 ? 'Best: $best moves' : null,
      icon: Icons.format_paint_rounded,
      color: color,
    );
