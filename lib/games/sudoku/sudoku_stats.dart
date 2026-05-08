import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kSudokuGameId = 'sudoku';

const String kSudokuSubKeyEasy   = 'easy';
const String kSudokuSubKeyMedium = 'medium';
const String kSudokuSubKeyHard   = 'hard';

// Score is stored as (kSudokuMaxScore - seconds) so higher stored = faster time
const int kSudokuMaxScore = 100000;

const Color _kEasy   = Color(0xFF22C55E);
const Color _kMedium = Color(0xFFF59E0B);
const Color _kHard   = Color(0xFFEF4444);

void registerSudokuStats() {
  BestStatsRegistry.register(kSudokuGameId, _buildStats);
}

int bestSudokuScore(String subKey) =>
    ScoreService().getHighScore(kSudokuGameId, subKey: subKey);

String _formatTime(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

List<BestStat> _buildStats() {
  final easy   = bestSudokuScore(kSudokuSubKeyEasy);
  final medium = bestSudokuScore(kSudokuSubKeyMedium);
  final hard   = bestSudokuScore(kSudokuSubKeyHard);

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   _kEasy,   'fastest solve • relaxed'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, _kMedium, 'fastest solve • balanced'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   _kHard,   'fastest solve • expert'),
  ];
}

BestStat _row(String emoji, String label, int score, Color color, String sublabel) {
  final secs = kSudokuMaxScore - score;
  return BestStat(
    label: '$emoji  $label',
    value: _formatTime(secs),
    sublabel: sublabel,
    icon: Icons.timer_rounded,
    color: color,
  );
}
