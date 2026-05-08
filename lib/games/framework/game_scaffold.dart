import 'package:flutter/material.dart';

import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../shared/animated_background.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart';
import 'game_definition.dart';
import 'game_session.dart';

/// A drop-in scaffold for plug-and-play games. Handles the picker → playing
/// → result lifecycle, score persistence, favorites, restart dialog wiring,
/// and pause-on-dialog. Games provide a [GameDefinition] with a
/// [GameDefinition.boardBuilder] and the framework does the rest.
class GameScaffold extends StatefulWidget {
  final GameDefinition definition;

  const GameScaffold({super.key, required this.definition});

  @override
  State<GameScaffold> createState() => _GameScaffoldState();
}

enum _Mode { picker, playing, done }

class _GameScaffoldState extends State<GameScaffold> {
  _Mode _mode = _Mode.picker;
  late DifficultyDef _pickerDifficulty;
  DifficultyDef? _activeDifficulty;
  PlayerConfig _activePlayers = PlayerConfig.solo;
  GameSessionImpl? _session;
  bool _isFavorite = false;

  static final DifficultyDef _fallbackDifficulty = DifficultyDef(
    key: 'default',
    label: 'PLAY',
    kind: DifficultyKind.medium,
    color: const Color(0xFF6C4EF3),
    hint: '',
    scoreLabel: (s) => '$s pts',
  );

  @override
  void initState() {
    super.initState();
    _pickerDifficulty = widget.definition.difficulties.isNotEmpty
        ? widget.definition.difficulties.first
        : _fallbackDifficulty;
    _isFavorite = ScoreService().isFavorite(widget.definition.info.id);
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  void _startGame(
    DifficultyDef diff, {
    PlayerMode mode = PlayerMode.solo,
    int count = 1,
    List<String> names = const [],
  }) {
    _session?.dispose();

    final players = PlayerConfig(
      mode: mode,
      playerCount: count,
      playerNames: names,
    );

    final initialBest = ScoreService()
        .getHighScore(widget.definition.info.id, subKey: diff.key);

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _activePlayers = players;
      _session = GameSessionImpl(
        definition: widget.definition,
        difficulty: diff,
        players: players,
        onComplete: _onGameComplete,
        onFail: _onGameFail,
        initialBest: initialBest,
      );
      _mode = _Mode.playing;
    });

    ScoreService().incrementGamePlayCount(widget.definition.info.id);
  }

  Future<void> _onGameComplete() async {
    final session = _session;
    if (session == null) return;
    final scoreToSave = session.currentScore;
    final isNew = await ScoreService().saveScore(
      widget.definition.info.id,
      scoreToSave,
      subKey: _activeDifficulty!.key,
    );
    if (!mounted) return;
    session.markNewBest(isNew);
    setState(() => _mode = _Mode.done);
  }

  void _onGameFail() {
    _onGameComplete();
  }

  void _backToPicker() {
    _session?.dispose();
    setState(() {
      _mode = _Mode.picker;
      _session = null;
      _activeDifficulty = null;
    });
  }

  void _playAgain() {
    final diff = _activeDifficulty ?? _pickerDifficulty;
    _startGame(
      diff,
      mode: _activePlayers.mode,
      count: _activePlayers.playerCount,
      names: _activePlayers.playerNames,
    );
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(widget.definition.info.id);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = widget.definition.info;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: info.color,
      steps: widget.definition.tutorialSteps?.call(),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case _Mode.picker:
        return _buildPicker();
      case _Mode.playing:
        return _buildPlaying();
      case _Mode.done:
        return _buildResult();
    }
  }

  // ── Picker ───────────────────────────────────────────────────────────────

  Widget _buildPicker() {
    final def = widget.definition;
    final info = def.info;
    final bgFactory = def.bgPainterBuilder;

    return GamePickerScaffold(
      bgColorTop: info.bgColor,
      bgColorBottom: Color.lerp(info.bgColor, info.color, 0.10) ?? info.bgColor,
      animatedBg: bgFactory != null
          ? AnimatedBackground(
              factory: bgFactory,
              period: const Duration(seconds: 10),
            )
          : null,
      iconRingColors: [info.color, info.color, info.color],
      iconChild: ClipOval(child: def.logoBuilder(90)),
      title: info.name,
      subtitle: info.description,
      onBack: () => Navigator.of(context).pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      body: _buildPickerBody(),
    );
  }

  Widget _buildPickerBody() {
    final def = widget.definition;
    final diffs = def.difficulties.isNotEmpty
        ? def.difficulties
        : <DifficultyDef>[_fallbackDifficulty];
    final activeIndex = diffs.indexOf(_pickerDifficulty).clamp(0, diffs.length - 1);

    final pickerData = diffs
        .map((d) => GameDifficultyData(
              label: d.label,
              color: d.color,
              kind: d.kind,
              hint: d.hint,
              bestScore: ScoreService()
                  .getHighScore(def.info.id, subKey: d.key),
              bestLabel: (s) => d.scoreLabel(s),
            ))
        .toList();

    final modes = def.playerSupport.modes;
    final showAi = modes.length > 1 || def.playerSupport.playerCounts.isNotEmpty;

    if (showAi) {
      return GameAiPickerBody(
        difficulties: pickerData,
        activeIndex: activeIndex,
        onChanged: (i) => setState(() => _pickerDifficulty = diffs[i]),
        onPlayAi: () => _startGame(diffs[activeIndex], mode: PlayerMode.vsAI),
        onPlayFriend: () => _startGame(
          diffs[activeIndex],
          mode: PlayerMode.localCoop,
          count: def.playerSupport.playerCounts.isNotEmpty
              ? def.playerSupport.playerCounts.first
              : 2,
        ),
      );
    }

    return GameSinglePickerBody(
      difficulties: pickerData,
      activeIndex: activeIndex,
      onChanged: (i) => setState(() => _pickerDifficulty = diffs[i]),
      playLabel: 'Play ${def.info.name}',
      playSubLabel: diffs[activeIndex].hint,
      onPlay: () => _startGame(diffs[activeIndex]),
      accentColor: def.info.color,
    );
  }

  // ── Playing ──────────────────────────────────────────────────────────────

  Widget _buildPlaying() {
    final def = widget.definition;
    final info = def.info;
    final session = _session!;
    final diff = _activeDifficulty!;
    final scoreDisplay = def.scoreDisplay ?? ScoreDisplay.scoreAndBest();

    final topColor = Color.lerp(info.bgColor, diff.color, 0.06) ?? info.bgColor;
    final bottomColor =
        Color.lerp(info.bgColor, diff.color, 0.04) ?? info.bgColor;

    final board = def.boardBuilder != null
        ? def.boardBuilder!(session)
        : const Center(
            child: Text('No boardBuilder configured'),
          );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [topColor, bottomColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          if (def.bgPainterBuilder != null)
            Positioned.fill(
              child: AnimatedBackground(
                factory: def.bgPainterBuilder!,
                period: const Duration(seconds: 10),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 4),
                GameHudBar(
                  leading: GameBackButton(onTap: _backToPicker),
                  centerContent: scoreDisplay.build(session, diff),
                  trailing: GameRestartButton(
                    gameName: info.name,
                    accentColor: info.color,
                    onRestart: _playAgain,
                    onDialogOpened: session.pauseTimer,
                    onDialogDismissed: session.resumeTimer,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: board),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Result ───────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final def = widget.definition;
    final session = _session!;
    final diff = _activeDifficulty!;

    final headline = session.resultHeadline ??
        (session.isNewBest ? 'New Best! 🎉' : 'Game Over');
    final subtitle = session.resultSubtitle ??
        '${diff.label} • ${diff.scoreLabel(session.currentScore)}';

    final stats = def.resultStatsBuilder?.call(session, diff) ??
        GameResultStatsRow(
          stats: [
            StatItem(
              label: 'SCORE',
              value: session.currentScore,
              color: diff.color,
            ),
            StatItem(
              label: 'BEST',
              value: session.bestScore,
              color: const Color(0xFF8B7BA7),
            ),
          ],
        );

    return GenericGameResultScreen(
      headline: headline,
      subtitle: subtitle,
      badgeContent: '',
      badgeColor: diff.color,
      badgeChild: ClipOval(child: widget.definition.logoBuilder(120)),
      showNewBestBadge: session.isNewBest,
      statsWidget: stats,
      actions: [
        GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _playAgain,
          filled: true,
          color: diff.color,
        ),
        GameResultAction(
          label: 'Menu',
          icon: Icons.tune_rounded,
          onTap: _backToPicker,
          filled: false,
        ),
      ],
    );
  }
}
