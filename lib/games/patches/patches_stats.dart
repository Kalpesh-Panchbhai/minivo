import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/level_progress_service.dart';
import 'patches_screen.dart';

void registerPatchesStats() {
  BestStatsRegistry.register(kPatchesGameId, _buildStats);
}

List<BestStat> _buildStats() {
  final lps = LevelProgressService();
  final easyLevel   = lps.getHighestLevel(kPatchesGameId, 'easy');
  final mediumLevel = lps.getHighestLevel(kPatchesGameId, 'medium');
  final hardLevel   = lps.getHighestLevel(kPatchesGameId, 'hard');

  if (easyLevel == 0 && mediumLevel == 0 && hardLevel == 0) return const [];

  return [
    if (easyLevel   > 0) _row('🌱', 'EASY',   easyLevel,   const Color(0xFF22C55E)),
    if (mediumLevel > 0) _row('🔥', 'MEDIUM', mediumLevel, const Color(0xFFF59E0B)),
    if (hardLevel   > 0) _row('💀', 'HARD',   hardLevel,   const Color(0xFFEF4444)),
  ];
}

BestStat _row(String emoji, String label, int level, Color color) =>
    BestStat(
      label: '$emoji  $label',
      value: 'Level $level',
      icon: Icons.emoji_events_rounded,
      color: color,
    );
