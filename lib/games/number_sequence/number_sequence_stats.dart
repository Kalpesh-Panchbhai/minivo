import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kNumberSequenceGameId = 'number_sequence';

void registerNumberSequenceStats() {
  BestStatsRegistry.register(kNumberSequenceGameId, _buildStats);
}

String _fmtTime(int s) {
  final m = s ~/ 60;
  final sec = s % 60;
  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

List<BestStat> _buildStats() {
  final easy   = ScoreService().getHighScore(kNumberSequenceGameId, subKey: 'easy');
  final medium = ScoreService().getHighScore(kNumberSequenceGameId, subKey: 'medium');
  final hard   = ScoreService().getHighScore(kNumberSequenceGameId, subKey: 'hard');

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) _row('🌱', 'EASY',   easy,   const Color(0xFF22C55E), '25 numbers'),
    if (medium > 0) _row('🔥', 'MEDIUM', medium, const Color(0xFFF59E0B), '50 numbers'),
    if (hard   > 0) _row('💀', 'HARD',   hard,   const Color(0xFFEF4444), '100 numbers'),
  ];
}

BestStat _row(String emoji, String label, int time, Color color, String sublabel) =>
    BestStat(
      label: '$emoji  $label',
      value: _fmtTime(time),
      sublabel: sublabel,
      icon: Icons.emoji_events_rounded,
      color: color,
    );
