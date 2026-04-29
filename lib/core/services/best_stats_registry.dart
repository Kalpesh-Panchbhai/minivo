import 'package:flutter/material.dart';

import '../models/best_stat.dart';
import 'score_service.dart';

/// Builder signature: pure function that produces the rows shown in the
/// "Your best" panel for a given game. Builders read from [ScoreService] so
/// the panel always reflects persisted state.
typedef BestStatsBuilder = List<BestStat> Function();

/// Central registry mapping `gameId` → custom stats builder.
///
/// Games can opt in to a richer stats panel by calling
/// [BestStatsRegistry.register]. Anything not registered falls back to the
/// default high-score builder, which renders a single "BEST" row when the
/// game has a non-zero high score.
class BestStatsRegistry {
  BestStatsRegistry._();

  static final Map<String, BestStatsBuilder> _builders = {};

  /// Register a custom stats builder for the given [gameId]. Subsequent
  /// calls overwrite the previous registration.
  static void register(String gameId, BestStatsBuilder builder) {
    _builders[gameId] = builder;
  }

  /// Remove a previous registration. Mostly useful for tests.
  static void unregister(String gameId) {
    _builders.remove(gameId);
  }

  /// Returns the rows to show for [gameId]. Empty list means "nothing to
  /// show yet" (caller should hide the panel).
  static List<BestStat> statsFor(String gameId) {
    final custom = _builders[gameId];
    if (custom != null) return custom();
    return _defaultBuilder(gameId);
  }

  /// Default: render one row with the high score, if > 0.
  static List<BestStat> _defaultBuilder(String gameId) {
    final hs = ScoreService().getHighScore(gameId);
    if (hs <= 0) return const [];
    return [
      BestStat(
        label: 'BEST',
        value: '$hs',
        icon: Icons.emoji_events_rounded,
      ),
    ];
  }
}
