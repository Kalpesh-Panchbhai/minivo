import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kTileDropGameId = 'tile_drop';

const String kTileDropSubKeyEasy   = 'easy';
const String kTileDropSubKeyMedium = 'medium';
const String kTileDropSubKeyHard   = 'hard';

const Color _kEasyColor   = Color(0xFF4CB97A);
const Color _kMediumColor = Color(0xFFEFA63A);
const Color _kHardColor   = Color(0xFFE8533D);

void registerTileDropStats() {
  BestStatsRegistry.register(kTileDropGameId, _buildTileDropStats);
}

int bestTileDropScore(String subKey) =>
    ScoreService().getHighScore(kTileDropGameId, subKey: subKey);

List<BestStat> _buildTileDropStats() {
  final easy   = bestTileDropScore(kTileDropSubKeyEasy);
  final medium = bestTileDropScore(kTileDropSubKeyMedium);
  final hard   = bestTileDropScore(kTileDropSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    _row('🌱', 'EASY',   easy,   _kEasyColor),
    _row('🔥', 'MEDIUM', medium, _kMediumColor),
    _row('💀', 'HARD',   hard,   _kHardColor),
  ];
}

BestStat _row(String emoji, String label, int score, Color color) {
  return BestStat(
    label:    '$emoji  $label',
    value:    score == 0 ? '—' : '$score',
    sublabel: 'best score',
    icon:     Icons.view_column_rounded,
    color:    color,
  );
}
