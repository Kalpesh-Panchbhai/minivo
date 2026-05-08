import 'package:flutter/material.dart';

import '../../core/models/best_stat.dart';
import '../../core/models/game_info.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import 'game_session.dart';

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

  // ── Phase 2 plug-and-play hooks ────────────────────────────────────────
  //
  // Games that opt into the new framework provide a [boardBuilder] (and
  // optionally a [scoreDisplay] / [resultStatsBuilder] / [bgPainterBuilder])
  // instead of a bespoke [screenBuilder]. The framework's [GameScaffold]
  // wires picker → playing → done together using these hooks. Existing
  // games keep working unchanged because [screenBuilder] is still required.

  /// Builds the playing-state board widget for opted-in games. Receives the
  /// active [GameSession] which the game uses to read difficulty / players
  /// and to emit score / completion events.
  final Widget Function(GameSession session)? boardBuilder;

  /// Optional pre-built HUD score pill. Defaults to
  /// [ScoreDisplay.scoreAndBest] when null and [boardBuilder] is in use.
  final ScoreDisplay? scoreDisplay;

  /// Builds the stats widget shown on the result screen. Defaults to a
  /// simple SCORE / BEST row when null.
  final Widget Function(GameSession session, DifficultyDef difficulty)?
      resultStatsBuilder;

  /// Optional animated picker / playing background painter factory.
  final AnimatedBgPainter Function(double t)? bgPainterBuilder;

  const GameDefinition({
    required this.info,
    this.difficulties = const [],
    this.playerSupport = PlayerSupport.soloOnly,
    required this.screenBuilder,
    required this.logoBuilder,
    this.tutorialSteps,
    this.statsBuilder,
    this.boardBuilder,
    this.scoreDisplay,
    this.resultStatsBuilder,
    this.bgPainterBuilder,
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

// ── ScoreDisplay ────────────────────────────────────────────────────────────

/// Strategy object that builds the HUD score pill for a [GameSession].
///
/// Use the preset factories ([ScoreDisplay.scoreAndBest],
/// [ScoreDisplay.timeAndMistakes]) for the two common shapes, or
/// [ScoreDisplay.custom] to inject a fully bespoke pill.
abstract class ScoreDisplay {
  const ScoreDisplay();

  Widget build(GameSession session, DifficultyDef difficulty);

  static ScoreDisplay scoreAndBest() => const _ScoreAndBest();
  static ScoreDisplay timeAndMistakes({int? maxScore}) =>
      _TimeAndMistakes(maxScore: maxScore);
  static ScoreDisplay custom(
    Widget Function(GameSession, DifficultyDef) builder,
  ) =>
      _CustomDisplay(builder);
}

class _ScoreAndBest extends ScoreDisplay {
  const _ScoreAndBest();

  @override
  Widget build(GameSession session, DifficultyDef difficulty) {
    return _PillFrame(
      difficulty: difficulty,
      columns: [
        _PillColumn(
          label: 'SCORE',
          value: '${session.currentScore}',
          color: difficulty.color,
        ),
        _PillColumn(
          label: 'BEST',
          value: '${session.bestScore}',
          color: const Color(0xFF8B7BA7),
        ),
      ],
    );
  }
}

class _TimeAndMistakes extends ScoreDisplay {
  final int? maxScore;
  const _TimeAndMistakes({this.maxScore});

  @override
  Widget build(GameSession session, DifficultyDef difficulty) {
    final secs = session.elapsedTime.inSeconds;
    final best = session.bestScore;
    final bestSecs = (difficulty.isTimeBased && best > 0)
        ? difficulty.maxScore - best
        : null;
    return _PillFrame(
      difficulty: difficulty,
      columns: [
        _PillColumn(
          label: 'TIME',
          value: _formatTime(secs),
          color: difficulty.color,
        ),
        _PillColumn(
          label: 'MISTAKES',
          value: '${session.mistakes}',
          color: const Color(0xFFEF4444),
        ),
        _PillColumn(
          label: 'BEST',
          value: bestSecs != null ? _formatTime(bestSecs) : '--:--',
          color: const Color(0xFF8B7BA7),
        ),
      ],
    );
  }

  static String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _CustomDisplay extends ScoreDisplay {
  final Widget Function(GameSession, DifficultyDef) builder;
  const _CustomDisplay(this.builder);

  @override
  Widget build(GameSession session, DifficultyDef difficulty) =>
      builder(session, difficulty);
}

// ── Pill internals — match the shared snake/sudoku design ──────────────────

class _PillColumn {
  final String label;
  final String value;
  final Color color;
  const _PillColumn({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _PillFrame extends StatelessWidget {
  final DifficultyDef difficulty;
  final List<_PillColumn> columns;

  const _PillFrame({
    required this.difficulty,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final color = difficulty.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDifficultyIcon(
                kind: difficulty.kind,
                size: 14,
                prominent: false,
              ),
              const SizedBox(width: 6),
              Text(
                difficulty.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < columns.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFFE0E7FF),
                    ),
                  ),
                _buildCol(columns[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCol(_PillColumn c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          c.label,
          style: TextStyle(
            color: c.color.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: Text(
            c.value,
            key: ValueKey(c.value),
            style: TextStyle(
              color: c.color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}
