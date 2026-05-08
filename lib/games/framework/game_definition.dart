import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/models/game_info.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../shared/animated_difficulty_icon.dart';

export '../../core/models/game_info.dart' show GameCategory;
export '../shared/animated_difficulty_icon.dart' show DifficultyKind;

// ── DifficultyDef ──────────────────────────────────────────────────────────

/// Describes one difficulty level for a game.
///
/// [key] matches the sub-key used by [ScoreService] (e.g. 'easy', 'medium').
/// [maxScore] = 0 means score-based (higher is better); > 0 means time-based
/// (score is stored as `maxScore - seconds` so higher stored = faster time).
class DifficultyDef {
  final String key;
  final String label;
  final String hint;
  final DifficultyKind kind;
  final Color color;

  /// 0 = score-based (higher is better).
  /// > 0 = time-based: score stored as `maxScore - seconds`.
  final int maxScore;

  /// Formats the best score for display, e.g. '4820 pts' or '1:23'.
  final String Function(int score) scoreLabel;

  /// Optional emoji prefix for the stats row, e.g. '🌱'. Falls back to the
  /// difficulty kind if null.
  final String? emoji;

  /// Optional sub-label for stats rows, e.g. '5 pts/apple'.
  final String? statSublabel;

  /// Optional icon for stats rows. Defaults to [Icons.emoji_events_rounded]
  /// for score-based and [Icons.timer_rounded] for time-based.
  final IconData? statIcon;

  const DifficultyDef({
    required this.key,
    required this.label,
    required this.kind,
    required this.color,
    required this.hint,
    this.maxScore = 0,
    required this.scoreLabel,
    this.emoji,
    this.statSublabel,
    this.statIcon,
  });

  bool get isTimeBased => maxScore > 0;

  String get _defaultEmoji => switch (kind) {
        DifficultyKind.easy => '🌱',
        DifficultyKind.medium => '🔥',
        DifficultyKind.hard => '💀',
      };

  String get resolvedEmoji => emoji ?? _defaultEmoji;

  IconData get resolvedStatIcon =>
      statIcon ??
      (isTimeBased ? Icons.timer_rounded : Icons.emoji_events_rounded);
}

// ── PlayerSupport ──────────────────────────────────────────────────────────

enum PlayerMode { solo, vsAI, localCoop }

class PlayerSupport {
  final List<PlayerMode> modes;

  /// Non-empty only for localCoop — the allowed player counts.
  final List<int> playerCounts;

  const PlayerSupport({
    this.modes = const [PlayerMode.solo],
    this.playerCounts = const [],
  });

  static const soloOnly = PlayerSupport(modes: [PlayerMode.solo]);
}

// ── GameDefinition ─────────────────────────────────────────────────────────

/// The complete, self-contained description of a single game.
///
/// Pass this to [allGameDefinitions] in `all_games.dart`. The framework
/// derives everything else (registry entries, stats builders, etc.) from it
/// automatically.
class GameDefinition {
  final GameInfo info;

  /// Empty list = no difficulty picker shown.
  final List<DifficultyDef> difficulties;

  final PlayerSupport playerSupport;

  /// Builds the game's root widget.
  final Widget Function() screenBuilder;

  /// Builds the [size]×[size] branded logo tile.
  final Widget Function(double size) logoBuilder;

  /// Animated how-to-play steps. Null = sheet falls back to [info.howToPlay].
  final List<GameHowToPlayStep> Function()? tutorialSteps;

  /// Custom stats builder. When provided it completely overrides the
  /// framework's auto-generated stats (which are derived from [difficulties]).
  final List<BestStat> Function()? statsBuilder;

  const GameDefinition({
    required this.info,
    this.difficulties = const [],
    this.playerSupport = PlayerSupport.soloOnly,
    required this.screenBuilder,
    required this.logoBuilder,
    this.tutorialSteps,
    this.statsBuilder,
  });

  bool get hasDifficulties => difficulties.isNotEmpty;

  /// Returns the stats rows to show in the "Your best" panel.
  ///
  /// If [statsBuilder] is set, delegates to it. Otherwise auto-generates
  /// one row per difficulty that has a non-zero high score.
  List<BestStat> buildBestStats() {
    if (statsBuilder != null) return statsBuilder!();
    if (difficulties.isEmpty) return _defaultStats();
    return _autoStats();
  }

  List<BestStat> _autoStats() {
    final rows = <BestStat>[];
    for (final d in difficulties) {
      final score =
          ScoreService().getHighScore(info.id, subKey: d.key);
      if (score <= 0) continue;
      rows.add(BestStat(
        label: '${d.resolvedEmoji}  ${d.label}',
        value: d.scoreLabel(score),
        sublabel: d.statSublabel,
        icon: d.resolvedStatIcon,
        color: d.color,
      ));
    }
    return rows;
  }

  List<BestStat> _defaultStats() {
    final hs = ScoreService().getHighScore(info.id);
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
