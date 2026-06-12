import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kSlidingPuzzleGameId = 'sliding_puzzle';

const String kSPSubKey3x3    = '3x3';
const String kSPSubKey4x4    = '4x4';
const String kSPSubKey5x5    = '5x5';

const Color _k3x3  = Color(0xFF22C55E);
const Color _k4x4  = Color(0xFFF59E0B);
const Color _k5x5  = Color(0xFFEF4444);

void registerSlidingPuzzleStats() {
  BestStatsRegistry.register(kSlidingPuzzleGameId, _buildStats);
}

int bestSlidingPuzzleScore(String subKey) =>
    ScoreService().getHighScore(kSlidingPuzzleGameId, subKey: subKey);

List<BestStat> _buildStats() {
  final s3  = bestSlidingPuzzleScore(kSPSubKey3x3);
  final s4  = bestSlidingPuzzleScore(kSPSubKey4x4);
  final s5  = bestSlidingPuzzleScore(kSPSubKey5x5);

  if (s3 == 0 && s4 == 0 && s5 == 0) return const [];

  return [
    if (s3  > 0) _row('🟢', '3×3',  s3,  _k3x3,  '8 tiles'),
    if (s4  > 0) _row('🟡', '4×4',  s4,  _k4x4,  '15 tiles'),
    if (s5  > 0) _row('🔴', '5×5',  s5,  _k5x5,  '24 tiles'),
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
