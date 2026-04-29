import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

/// Game id for Tic Tac Toe — kept here so the registration site doesn't need
/// to depend on the screen file just to know the id.
const String kTicTacToeGameId = 'tic_tac_toe';

/// Sub-keys for the per-difficulty best-streak buckets. We never persist
/// scores for "Pass & Play" two-player rounds (per product rule: "best is
/// always against AI for all levels").
const String kTicTacToeSubKeyEasy = 'ai_easy';
const String kTicTacToeSubKeyMedium = 'ai_medium';
const String kTicTacToeSubKeyHard = 'ai_hard';

// Difficulty palette — must mirror tic_tac_toe_screen.dart so the stats panel
// reads as part of the same visual system. Kept here too (not imported) so
// the screen file remains the single source of truth and we don't create a
// circular dependency through GameRegistry / app initialisation.
const Color _kEasyColor = Color(0xFF4CB97A);
const Color _kMediumColor = Color(0xFFEFA63A);
const Color _kHardColor = Color(0xFFE8533D);

/// Register the Tic Tac Toe stats builder. Call once at app start (see
/// [registerAllGameStats]).
void registerTicTacToeStats() {
  BestStatsRegistry.register(kTicTacToeGameId, _buildTicTacToeStats);
}

/// Best win-streak achieved by the player against the AI at [subKey].
/// Convenience wrapper used by the gameplay screen and the registry builder.
int bestStreak(String subKey) =>
    ScoreService().getHighScore(kTicTacToeGameId, subKey: subKey);

List<BestStat> _buildTicTacToeStats() {
  final easy = bestStreak(kTicTacToeSubKeyEasy);
  final medium = bestStreak(kTicTacToeSubKeyMedium);
  final hard = bestStreak(kTicTacToeSubKeyHard);

  // Hide the panel entirely until the player has won at least one round on
  // some difficulty — otherwise it shows three empty "0 wins" rows on first
  // visit, which feels punishing rather than aspirational.
  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    _row('🌱', 'EASY', easy, _kEasyColor),
    _row('🔥', 'MEDIUM', medium, _kMediumColor),
    _row('💀', 'HARD', hard, _kHardColor),
  ];
}

BestStat _row(String emoji, String label, int streak, Color color) {
  // Big number ("12") with a quiet sublabel ("win streak") — matches the
  // Wordle / Microsoft Solitaire "Best: <N> <unit>" pattern but keeps the
  // number itself as the visual anchor.
  return BestStat(
    label: '$emoji  $label',
    value: streak == 0 ? '—' : '$streak',
    sublabel: streak == 0 ? 'no wins yet' : 'win streak',
    icon: Icons.local_fire_department_rounded,
    color: color,
  );
}
