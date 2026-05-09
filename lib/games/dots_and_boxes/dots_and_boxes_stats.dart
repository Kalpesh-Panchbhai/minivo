import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kDotsAndBoxesGameId = 'dots_and_boxes';

const String kDotsAndBoxesSubKeyEasy = 'ai_easy';
const String kDotsAndBoxesSubKeyMedium = 'ai_medium';
const String kDotsAndBoxesSubKeyHard = 'ai_hard';

const Color _kEasyColor = Color(0xFF4CB97A);
const Color _kMediumColor = Color(0xFFEFA63A);
const Color _kHardColor = Color(0xFFE8533D);

void registerDotsAndBoxesStats() {
  BestStatsRegistry.register(kDotsAndBoxesGameId, _buildDotsAndBoxesStats);
}

int bestBoxes(String subKey) =>
    ScoreService().getHighScore(kDotsAndBoxesGameId, subKey: subKey);

List<BestStat> _buildDotsAndBoxesStats() {
  final easy = bestBoxes(kDotsAndBoxesSubKeyEasy);
  final medium = bestBoxes(kDotsAndBoxesSubKeyMedium);
  final hard = bestBoxes(kDotsAndBoxesSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    _row('🌱', 'EASY', easy, _kEasyColor),
    _row('🔥', 'MEDIUM', medium, _kMediumColor),
    _row('💀', 'HARD', hard, _kHardColor),
  ];
}

BestStat _row(String emoji, String label, int boxes, Color color) {
  return BestStat(
    label: '$emoji  $label',
    value: boxes == 0 ? '—' : '$boxes',
    sublabel: boxes == 0 ? 'no wins yet' : 'boxes claimed',
    icon: Icons.grid_4x4_rounded,
    color: color,
  );
}
