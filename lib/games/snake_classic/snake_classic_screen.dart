import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/spinning_slider.dart';
import 'snake_classic_stats.dart';

// ── Picker palette ─────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFEAFBF5);
const Color _kBgBot    = Color(0xFFD7F5E8);
const Color _kCardBg   = Colors.white;
const Color _kHintText = Color(0xFF386641);

// ── Snake brand colors ─────────────────────────────────────────────────────
const Color _kSnakeGreen = Color(0xFF20C997);
const Color _kSnakeDark  = Color(0xFF099268);

// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

// ── Game constants ─────────────────────────────────────────────────────────
const int _kBoardN = 15;
const int _kInitialLen = 3;
const Color _kBoardBg   = Color(0xFFE6FCF5);
const Color _kFoodColor = Color(0xFFEF4444);
const Color _kFoodGlow  = Color(0xFFFFB4B4);

// ── Difficulty enum ────────────────────────────────────────────────────────
enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label   => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color   => [_kEasyColor, _kMediumColor, _kHardColor][index];
  // Speed model: snake starts at [startMs] and gets [deltaPerApple] ms
  // faster per apple eaten, capped at [floorMs]. Easy stays constant
  // (delta = 0), so casual players never feel chased.
  int    get startMs        => [280, 220, 170][index];
  int    get deltaPerApple  => [0,   1,   2  ][index];
  int    get floorMs        => [280, 190, 130][index];
  int    get pointsPerFood  => [5, 10, 20][index];
  String get subKey         => ['easy', 'medium', 'hard'][index];
  String get hint => [
        'Slow & gentle — perfect for first-timers.',
        'Steady classic pace, gradual ramp.',
        'Starts brisk, ramps to fast.',
      ][index];
  DifficultyKind get kind => [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard,
      ][index];

  int tickMsForApples(int apples) {
    final raw = startMs - deltaPerApple * apples;
    return raw < floorMs ? floorMs : raw;
  }
}

// ── Direction enum ─────────────────────────────────────────────────────────
enum _Dir { up, down, left, right }

extension _DirX on _Dir {
  int get dx => switch (this) {
        _Dir.left  => -1,
        _Dir.right => 1,
        _ => 0,
      };
  int get dy => switch (this) {
        _Dir.up   => -1,
        _Dir.down => 1,
        _ => 0,
      };
  bool isOpposite(_Dir other) => switch (this) {
        _Dir.up    => other == _Dir.down,
        _Dir.down  => other == _Dir.up,
        _Dir.left  => other == _Dir.right,
        _Dir.right => other == _Dir.left,
      };
}

// ════════════════════════════════════════════════════════════════
// Root screen — picker → game transition
// ════════════════════════════════════════════════════════════════

class SnakeClassicScreen extends StatefulWidget {
  const SnakeClassicScreen({super.key});

  @override
  State<SnakeClassicScreen> createState() => _SnakeClassicScreenState();
}

class _SnakeClassicScreenState extends State<SnakeClassicScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.medium;

  bool _isFavorite = false;

  // Snake state
  final _rng = math.Random();
  List<math.Point<int>> _snake = const [];
  List<math.Point<int>> _prevSnake = const [];
  _Dir _dir = _Dir.right;
  _Dir? _pendingDir;
  List<math.Point<int>> _foods = const [];

  int _score = 0;
  int _bestScore = 0;
  bool _isNewBestScore = false;
  bool _gameOver = false;

  // Apples eaten this run — drives speed progression. Reset on every
  // game start (NOT on every tick).
  int _applesEaten = 0;

  // Eat-animation state. Each entry lasts ~700ms after spawn; the painter
  // fades them out. Cleared on game start / back-to-picker.
  final List<_EatEffect> _eatEffects = [];
  int? _lastEatTimeMs;

  // Swipe gesture state — mirrors the dual-signal pattern from 2048.
  double _dragDx = 0;
  double _dragDy = 0;

  late final AnimationController _tickCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFavorite = ScoreService().isFavorite(kSnakeClassicGameId);
    _tickCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..addStatusListener(_onTickComplete);
  }

  @override
  void dispose() {
    _tickCtrl.removeStatusListener(_onTickComplete);
    _tickCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_activeDifficulty == null || _gameOver) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_tickCtrl.isAnimating) _tickCtrl.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_tickCtrl.isAnimating && !_gameOver) {
        _tickCtrl.forward(from: _tickCtrl.value);
      }
    }
  }

  void _onTickComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted || _gameOver) return;
    // Don't tick when paused — the restart dialog or pause overlay is open.
    if (GameWrapper.of(context).state == GameState.paused) return;
    _tick();
    if (mounted && !_gameOver) {
      _tickCtrl.forward(from: 0);
    }
  }

  int _bestFor(_Difficulty d) =>
      ScoreService().getHighScore(kSnakeClassicGameId, subKey: d.subKey);

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kSnakeClassicGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kSnakeClassicGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kSnakeGreen,
    );
  }

  // ── Game start / restart ─────────────────────────────────────────────────

  void _startGame(_Difficulty diff) {
    final mid = _kBoardN ~/ 2;
    final initial = <math.Point<int>>[
      for (int i = 0; i < _kInitialLen; i++)
        math.Point(mid + (_kInitialLen - 1 - i), mid),
    ];

    setState(() {
      _activeDifficulty = diff;
      _pickerDifficulty = diff;
      _snake = initial;
      _prevSnake = List<math.Point<int>>.from(initial);
      _dir = _Dir.right;
      _pendingDir = null;
      _foods = _spawnFoods(initial, []);
      _score = 0;
      _bestScore = _bestFor(diff);
      _isNewBestScore = false;
      _gameOver = false;
      _applesEaten = 0;
      _eatEffects.clear();
      _lastEatTimeMs = null;
    });

    _tickCtrl.duration = Duration(milliseconds: diff.tickMsForApples(0));
    _tickCtrl.forward(from: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameWrapper.of(context).startGame();
        GameWrapper.of(context).updateScore(0);
      }
    });
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  void _backToPicker() {
    _tickCtrl.stop();
    GameWrapper.of(context).restartGame();
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
      _isNewBestScore = false;
      _score = 0;
      _snake = const [];
      _prevSnake = const [];
      _applesEaten = 0;
      _eatEffects.clear();
      _lastEatTimeMs = null;
    });
  }

  // ── Food spawning ────────────────────────────────────────────────────────

  List<math.Point<int>> _spawnFoods(
    List<math.Point<int>> snake,
    List<math.Point<int>> existingFoods,
  ) {
    final occupied = {...snake.toSet(), ...existingFoods.toSet()};
    final empties = <math.Point<int>>[];
    for (int x = 0; x < _kBoardN; x++) {
      for (int y = 0; y < _kBoardN; y++) {
        final p = math.Point(x, y);
        if (!occupied.contains(p)) empties.add(p);
      }
    }
    final result = List<math.Point<int>>.from(existingFoods);
    while (result.length < 3 && empties.isNotEmpty) {
      final idx = _rng.nextInt(empties.length);
      result.add(empties[idx]);
      empties.removeAt(idx);
    }
    return result;
  }

  // ── Tick / collision logic ───────────────────────────────────────────────

  void _tick() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver) return;

    // Apply pending direction iff it isn't a 180° reversal.
    if (_pendingDir != null && !_dir.isOpposite(_pendingDir!)) {
      _dir = _pendingDir!;
    }
    _pendingDir = null;

    final head = _snake.first;
    final next = math.Point(head.x + _dir.dx, head.y + _dir.dy);

    // Wall collision — solid walls in every mode.
    if (next.x < 0 || next.x >= _kBoardN ||
        next.y < 0 || next.y >= _kBoardN) {
      _endGame();
      return;
    }

    // Self collision. The tail vacates this tick unless we grow,
    // so the last segment is excluded only when not eating.
    final ateIdx = _foods.indexWhere((f) => f == next);
    final ate = ateIdx >= 0;
    final lastIndex = ate ? _snake.length : _snake.length - 1;
    for (int i = 0; i < lastIndex; i++) {
      if (_snake[i] == next) {
        _endGame();
        return;
      }
    }

    final newSnake = <math.Point<int>>[next, ..._snake];
    if (!ate) newSnake.removeLast();

    final eatenPos = ate ? _foods[ateIdx] : null;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      _prevSnake = _snake;
      _snake = newSnake;
      if (ate) {
        final newScore = _score + diff.pointsPerFood;
        if (newScore > _bestScore) {
          _bestScore = newScore;
          _isNewBestScore = true;
        }
        _score = newScore;
        _applesEaten += 1;
        ScoreService().saveScore(
          kSnakeClassicGameId, newScore, subKey: diff.subKey,
        );
        AudioService().playScore();
        // Remove eaten apple and spawn a replacement to keep count at 3.
        final remaining = List<math.Point<int>>.from(_foods)
          ..removeAt(ateIdx);
        _foods = _spawnFoods(newSnake, remaining);

        // Spawn an eat-effect for the apple that was just consumed and
        // remember the moment for the head-pulse animation. Prune any
        // expired effects while we're here so the list stays bounded.
        _eatEffects.add(_EatEffect(
          cellPos: eatenPos!,
          points: diff.pointsPerFood,
          color: diff.color,
          startTimeMs: nowMs,
        ));
        _lastEatTimeMs = nowMs;
        _eatEffects.removeWhere((e) => nowMs - e.startTimeMs > 700);
      }
    });

    if (ate) {
      GameWrapper.of(context).updateScore(_score);
      // Speed progression — applies on the next forward(from: 0) call,
      // so the apple-eating tick keeps its existing duration and the
      // ramp kicks in cleanly on the following move.
      _tickCtrl.duration = Duration(
        milliseconds: diff.tickMsForApples(_applesEaten),
      );
    }
  }

  void _endGame() {
    _tickCtrl.stop();
    AudioService().playGameOver();
    setState(() => _gameOver = true);
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      if (mounted) GameWrapper.of(context).endGame();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GameWrapper.of(context).endGame();
      });
    }
  }

  void _handleSwipeDirection(_Dir d) {
    if (_activeDifficulty == null || _gameOver) return;
    if (d.isOpposite(_dir)) return;
    _pendingDir = d;

    // Snappy turn — without this, a swipe taken early in a tick has to
    // wait up to one full tick (260 ms on Easy!) before the new
    // direction takes effect. We fast-forward the in-flight animation
    // so the next tick (which applies _pendingDir) starts almost
    // immediately. Skip when there's <50 ms left — the natural finish
    // is faster than the fast-forward window anyway.
    if (_tickCtrl.isAnimating && _tickCtrl.duration != null) {
      final remainingMs =
          (1.0 - _tickCtrl.value) * _tickCtrl.duration!.inMilliseconds;
      if (remainingMs > 50) {
        _tickCtrl.animateTo(
          1.0,
          duration: const Duration(milliseconds: 40),
          curve: Curves.linear,
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    return _buildGame();
  }

  // ════════════════════════════════════════════════════════════════
  // PICKER
  // ════════════════════════════════════════════════════════════════

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => _SnakeBgPainter(t),
        period: const Duration(seconds: 10),
      ),
      iconRingColors: const [_kSnakeGreen, _kSnakeDark, _kSnakeGreen],
      iconChild: ClipOval(
        child: GameRegistry.getById(kSnakeClassicGameId)
                ?.buildBrandedLogo(size: 84) ??
            const SizedBox.shrink(),
      ),
      title: 'Snake Classic',
      subtitle: 'Slither • Eat • Survive',
      onBack: () => context.pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      tallThreshold: 860,
      body: _PickerSection(
        difficulty: _pickerDifficulty,
        onDifficultyChanged: (d) => setState(() => _pickerDifficulty = d),
        onPlay: () => _startGame(_pickerDifficulty),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAME VIEW
  // ════════════════════════════════════════════════════════════════

  Widget _buildGame() {
    if (_gameOver) return _buildGameOverScreen();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBgTop, _kBgBot],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBackground(
              factory: (t) => _SnakeBgPainter(t),
              period: const Duration(seconds: 10),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 4),
                _buildGameHud(),
                const SizedBox(height: 12),
                Expanded(child: Center(child: _buildBoard())),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameHud() {
    return GameHudBar(
      leading: GameBackButton(onTap: _backToPicker),
      centerContent: _ScoreBoardPill(
        difficulty: _activeDifficulty!,
        score: _score,
        best: _bestScore,
      ),
      trailing: GameRestartButton(
        gameName: 'Snake',
        accentColor: _kSnakeGreen,
        onRestart: _newGame,
        onDialogOpened: _tickCtrl.stop,
        onDialogDismissed: () {
          if (!_gameOver) _tickCtrl.forward(from: _tickCtrl.value);
        },
      ),
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, c) {
        final side = math.min(c.maxWidth - 24, c.maxHeight);
        return SizedBox(
          width: side,
          height: side,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              _dragDx = 0;
              _dragDy = 0;
            },
            onPanUpdate: (d) {
              _dragDx += d.delta.dx;
              _dragDy += d.delta.dy;
            },
            onPanEnd: (d) {
              final v = d.velocity.pixelsPerSecond;
              final dx = math.max(v.dx.abs() / 4, _dragDx.abs());
              final dy = math.max(v.dy.abs() / 4, _dragDy.abs());
              if (dx < 24 && dy < 24) return;

              if (dx > dy) {
                final velSignal = v.dx.abs() / 4;
                final distSignal = _dragDx.abs();
                final goRight =
                    (velSignal > distSignal) ? (v.dx > 0) : (_dragDx > 0);
                _handleSwipeDirection(goRight ? _Dir.right : _Dir.left);
              } else {
                final velSignal = v.dy.abs() / 4;
                final distSignal = _dragDy.abs();
                final goDown =
                    (velSignal > distSignal) ? (v.dy > 0) : (_dragDy > 0);
                _handleSwipeDirection(goDown ? _Dir.down : _Dir.up);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: _kBoardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _kSnakeGreen.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AnimatedBuilder(
                  animation: _tickCtrl,
                  builder: (_, _) => CustomPaint(
                    size: Size.square(side),
                    painter: _SnakePainter(
                      snake: _snake,
                      prevSnake: _prevSnake,
                      foods: _foods,
                      dir: _dir,
                      t: _tickCtrl.value,
                      eatEffects: _eatEffects,
                      lastEatTimeMs: _lastEatTimeMs,
                      nowMs: DateTime.now().millisecondsSinceEpoch,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameOverScreen() {
    final difficulty = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: 'Game Over',
      badgeContent: '🐍',
      badgeColor: difficulty.color,
      showNewBestBadge: _isNewBestScore,
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
          filled: true,
          color: difficulty.color,
        ),
        game_result.GameResultAction(
          label: 'Change Mode',
          icon: Icons.tune_rounded,
          onTap: _backToPicker,
          filled: false,
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: () => context.go('/home'),
          filled: false,
        ),
      ],
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(
            label: 'SCORE',
            value: _score,
            color: difficulty.color,
          ),
          game_result.StatItem(
            label: 'BEST',
            value: _bestScore,
            color: const Color(0xFF8B7BA7),
          ),
          game_result.StatItem(
            label: 'LENGTH',
            value: _snake.length,
            color: _kSnakeDark,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PICKER — Difficulty card + attached play button
// ════════════════════════════════════════════════════════════════

class _PickerSection extends StatelessWidget {
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final VoidCallback onPlay;

  const _PickerSection({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: _kSnakeGreen.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _kSnakeGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        size: 16,
                        color: _kSnakeGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'DIFFICULTY',
                      style: TextStyle(
                        color: _kSnakeGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DifficultyLabel(difficulty: difficulty),
                const SizedBox(height: 14),
                _DifficultyTrack(
                  difficulty: difficulty,
                  onChanged: onDifficultyChanged,
                ),
                const SizedBox(height: 6),
                _DifficultyHint(difficulty: difficulty),
                const SizedBox(height: 12),
                _BestScorePill(difficulty: difficulty),
              ],
            ),
          ),
        ),
        _PlayButton(difficulty: difficulty, onTap: onPlay)
            .animate()
            .fadeIn(delay: 220.ms, duration: 320.ms)
            .slideY(begin: 0.08, end: 0, duration: 320.ms),
      ],
    );
  }
}

class _DifficultyLabel extends StatelessWidget {
  final _Difficulty difficulty;
  const _DifficultyLabel({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Container(
        key: ValueKey(difficulty.label),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: difficulty.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: difficulty.color.withValues(alpha: 0.30),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDifficultyIcon(kind: difficulty.kind, size: 32),
            const SizedBox(width: 12),
            Text(
              difficulty.label,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: difficulty.color,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyTrack extends StatelessWidget {
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onChanged;

  const _DifficultyTrack({required this.difficulty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const values = _Difficulty.values;
    return SpinningSlider(
      stopCount: values.length,
      activeIndex: values.indexOf(difficulty),
      activeColor: difficulty.color,
      stopColors: const [_kEasyColor, _kMediumColor, _kHardColor],
      onChanged: (i) => onChanged(values[i]),
    );
  }
}

class _DifficultyHint extends StatelessWidget {
  final _Difficulty difficulty;
  const _DifficultyHint({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Padding(
        key: ValueKey(difficulty),
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          difficulty.hint,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kHintText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _BestScorePill extends StatelessWidget {
  final _Difficulty difficulty;
  const _BestScorePill({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final best = ScoreService().getHighScore(
      kSnakeClassicGameId,
      subKey: difficulty.subKey,
    );
    final color = difficulty.color;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey('best_${difficulty.label}_$best'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: best > 0
              ? color.withValues(alpha: 0.14)
              : const Color(0xFF8B7BA7).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: best > 0
                ? color.withValues(alpha: 0.40)
                : const Color(0xFF8B7BA7).withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              best > 0 ? Icons.emoji_events_rounded : Icons.flag_outlined,
              size: 14,
              color: best > 0 ? color : const Color(0xFF8B7BA7),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                best > 0 ? 'Best $best' : 'Set your first best!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: best > 0 ? color : const Color(0xFF6B5E7E),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  final _Difficulty difficulty;
  final VoidCallback onTap;
  const _PlayButton({required this.difficulty, required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.difficulty.color;
    final lighter = Color.lerp(color, Colors.white, 0.22)!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, lighter],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.36),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Play Snake',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      '${widget.difficulty.pointsPerFood} pts per apple',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// GAME — HUD widgets
// ════════════════════════════════════════════════════════════════

class _ScoreBoardPill extends StatelessWidget {
  final _Difficulty difficulty;
  final int score;
  final int best;
  const _ScoreBoardPill({
    required this.difficulty,
    required this.score,
    required this.best,
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
                color: _kSnakeGreen.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _scoreColumn('SCORE', score, color),
              const SizedBox(width: 18),
              Container(width: 1, height: 28, color: const Color(0xFFD7F0E5)),
              const SizedBox(width: 18),
              _scoreColumn('BEST', best, _kSnakeDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreColumn(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '$value',
            key: ValueKey<int>(value),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}


// ════════════════════════════════════════════════════════════════
// Eat-effect data — passed through to the painter so it can render
// the apple flash + floating "+N" score popup independent of game
// state. Cleared on game start / back-to-picker.
// ════════════════════════════════════════════════════════════════

class _EatEffect {
  final math.Point<int> cellPos;
  final int points;
  final Color color;
  final int startTimeMs;

  const _EatEffect({
    required this.cellPos,
    required this.points,
    required this.color,
    required this.startTimeMs,
  });
}

// ════════════════════════════════════════════════════════════════
// CUSTOM PAINTER — snake board (snake + food + grid + eat effects)
// ════════════════════════════════════════════════════════════════

class _SnakePainter extends CustomPainter {
  final List<math.Point<int>> snake;
  final List<math.Point<int>> prevSnake;
  final List<math.Point<int>> foods;
  final _Dir dir;
  final double t;
  final List<_EatEffect> eatEffects;
  final int? lastEatTimeMs;
  final int nowMs;

  _SnakePainter({
    required this.snake,
    required this.prevSnake,
    required this.foods,
    required this.dir,
    required this.t,
    required this.eatEffects,
    required this.lastEatTimeMs,
    required this.nowMs,
  });

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / _kBoardN;

    // Subtle grid lines so the cells read clearly without dominating.
    final gridPaint = Paint()
      ..color = _kSnakeGreen.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (int i = 1; i < _kBoardN; i++) {
      canvas.drawLine(
        Offset(i * cs, 0), Offset(i * cs, size.height), gridPaint,
      );
      canvas.drawLine(
        Offset(0, i * cs), Offset(size.width, i * cs), gridPaint,
      );
    }

    // Food (apple) — drawn before the snake so head occlusion reads as "eaten".
    _drawFood(canvas, cs);

    if (snake.isNotEmpty) {
      _drawSnake(canvas, cs);
    }

    // Eat effects (apple flash + score popup) layered above the snake so
    // the floating "+N" never gets occluded by the body.
    _drawEatEffects(canvas, cs);
  }

  // ── Snake body ───────────────────────────────────────────────────────────

  void _drawSnake(Canvas canvas, double cs) {
    // Interpolated segment centers.
    final centers = <Offset>[
      for (int i = 0; i < snake.length; i++)
        () {
          final to = snake[i];
          final from = (i < prevSnake.length) ? prevSnake[i] : to;
          final px = from.x + (to.x - from.x) * t;
          final py = from.y + (to.y - from.y) * t;
          return Offset((px + 0.5) * cs, (py + 0.5) * cs);
        }(),
    ];

    if (centers.length < 2) {
      // Single-segment fallback — only hit during init/race conditions.
      canvas.drawCircle(centers.first, cs * 0.47,
          Paint()..color = _kSnakeDark);
      canvas.drawCircle(centers.first, cs * 0.32,
          Paint()..color = _kSnakeGreen);
      _drawHead(canvas, centers.first, cs);
      return;
    }

    // Build the body as N-1 sub-paths. Each sub-path runs from the
    // midpoint of (i-1, i) through centers[i] (control point) to the
    // midpoint of (i, i+1). Endpoints clamp to centers[0] / centers.last.
    //
    // Two passes:
    //   1. Outer dark stroke, tapering 0.94 → 0.55 of cs (head→tail).
    //   2. Inner mint highlight, tapering 0.66 → 0.30 of cs.
    //
    // The quadratic-Bezier-per-segment approach makes corners curve
    // smoothly while straight runs collapse to lines (3 collinear
    // points → degenerate quadratic = line).

    final segs = <(Offset, Offset, Offset, double)>[];
    final n = centers.length;
    for (int i = 0; i < n - 1; i++) {
      final from = i == 0
          ? centers[0]
          : Offset.lerp(centers[i - 1], centers[i], 0.5)!;
      final to = i == n - 2
          ? centers.last
          : Offset.lerp(centers[i], centers[i + 1], 0.5)!;
      final ctl = centers[i];
      // tFromHead: 0 at head, 1 at tail. Used for both strokes' taper.
      final tFromHead = i / (n - 1);
      segs.add((from, ctl, to, tFromHead));
    }

    final outer = Paint()
      ..color = _kSnakeDark
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (from, ctl, to, p) in segs) {
      outer.strokeWidth = _lerp(cs * 0.94, cs * 0.55, p);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctl.dx, ctl.dy, to.dx, to.dy);
      canvas.drawPath(path, outer);
    }

    final inner = Paint()
      ..color = _kSnakeGreen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (from, ctl, to, p) in segs) {
      inner.strokeWidth = _lerp(cs * 0.66, cs * 0.30, p);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctl.dx, ctl.dy, to.dx, to.dy);
      canvas.drawPath(path, inner);
    }

    _drawHead(canvas, centers.first, cs);
  }

  void _drawHead(Canvas canvas, Offset head, double cs) {
    // Head pulse on eat: scale 1.0 → 1.18 → 1.0 over 180 ms.
    var headScale = 1.0;
    if (lastEatTimeMs != null) {
      final age = nowMs - lastEatTimeMs!;
      if (age >= 0 && age < 180) {
        final pulseT = age / 180.0;
        headScale = 1.0 + 0.18 * math.sin(pulseT * math.pi);
      }
    }

    canvas.drawCircle(
      head, cs * 0.48 * headScale, Paint()..color = _kSnakeDark,
    );
    canvas.drawCircle(
      Offset(head.dx - cs * 0.10, head.dy - cs * 0.10),
      cs * 0.14 * headScale,
      Paint()..color = _kSnakeGreen.withValues(alpha: 0.45),
    );
    _drawEyesAt(canvas, head, cs);
  }

  // ── Food ─────────────────────────────────────────────────────────────────

  void _drawFood(Canvas canvas, double cs) {
    for (final food in foods) {
      final cx = (food.x + 0.5) * cs;
      final cy = (food.y + 0.5) * cs;
      canvas.drawCircle(
        Offset(cx, cy), cs * 0.50,
        Paint()
          ..color = _kFoodColor.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.30),
      );
      canvas.drawCircle(
        Offset(cx, cy), cs * 0.34, Paint()..color = _kFoodColor,
      );
      canvas.drawCircle(
        Offset(cx - cs * 0.10, cy - cs * 0.10), cs * 0.10,
        Paint()..color = _kFoodGlow.withValues(alpha: 0.85),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + cs * 0.08, cy - cs * 0.32),
          width: cs * 0.20, height: cs * 0.10,
        ),
        Paint()..color = const Color(0xFF22C55E),
      );
    }
  }

  // ── Eat effects (apple flash + floating score popup) ────────────────────

  void _drawEatEffects(Canvas canvas, double cs) {
    for (final e in eatEffects) {
      final age = nowMs - e.startTimeMs;
      if (age < 0 || age > 700) continue;

      final cx = (e.cellPos.x + 0.5) * cs;
      final cy = (e.cellPos.y + 0.5) * cs;

      // Apple flash — scale up + fade out over 220 ms. Reads as the
      // apple "popping" the moment it's eaten.
      if (age < 220) {
        final flashT = age / 220.0;
        final scale = 1.0 + flashT * 0.55;
        final alpha = 1.0 - flashT;
        canvas.drawCircle(
          Offset(cx, cy), cs * 0.50 * scale,
          Paint()
            ..color = _kFoodColor.withValues(alpha: 0.30 * alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.25),
        );
        canvas.drawCircle(
          Offset(cx, cy), cs * 0.34 * scale,
          Paint()..color = _kFoodColor.withValues(alpha: alpha),
        );
      }

      // Score popup — "+N" floats up ~1.5 cells over 600 ms while
      // fading. Coloured by difficulty so the player learns which
      // tier is paying out.
      if (age < 600) {
        final popT = age / 600.0;
        final yOffset = -popT * cs * 1.5;
        final alpha = (1.0 - popT).clamp(0.0, 1.0);
        final scale = 0.85 + (1 - popT) * 0.20;
        final tp = TextPainter(
          text: TextSpan(
            text: '+${e.points}',
            style: TextStyle(
              color: e.color.withValues(alpha: alpha),
              fontSize: cs * 0.62 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: alpha * 0.7),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(cx - tp.width / 2, cy + yOffset - tp.height / 2),
        );
      }
    }
  }

  // ── Eyes (head, oriented to direction) ──────────────────────────────────

  void _drawEyesAt(Canvas canvas, Offset center, double cs) {
    final cx = center.dx;
    final cy = center.dy;
    final off = cs * 0.18;
    final Offset e1, e2;
    switch (dir) {
      case _Dir.right:
        e1 = Offset(cx + cs * 0.12, cy - off);
        e2 = Offset(cx + cs * 0.12, cy + off);
        break;
      case _Dir.left:
        e1 = Offset(cx - cs * 0.12, cy - off);
        e2 = Offset(cx - cs * 0.12, cy + off);
        break;
      case _Dir.up:
        e1 = Offset(cx - off, cy - cs * 0.12);
        e2 = Offset(cx + off, cy - cs * 0.12);
        break;
      case _Dir.down:
        e1 = Offset(cx - off, cy + cs * 0.12);
        e2 = Offset(cx + off, cy + cs * 0.12);
        break;
    }
    final whitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF1B3A2A);
    canvas.drawCircle(e1, cs * 0.10, whitePaint);
    canvas.drawCircle(e2, cs * 0.10, whitePaint);
    canvas.drawCircle(e1, cs * 0.05, pupilPaint);
    canvas.drawCircle(e2, cs * 0.05, pupilPaint);
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) =>
      old.snake != snake ||
      old.prevSnake != prevSnake ||
      old.foods != foods ||
      old.dir != dir ||
      old.t != t ||
      old.eatEffects != eatEffects ||
      old.lastEatTimeMs != lastEatTimeMs ||
      old.nowMs != nowMs;
}

// ════════════════════════════════════════════════════════════════
// Decorative background — floating snake icons + apple dots
// ════════════════════════════════════════════════════════════════

class _SnakeBgPainter extends AnimatedBgPainter {
  const _SnakeBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final items = <(IconData, Color, double, double, double, double)>[
      // (icon, color, xRel, yRel, sizePx, phase)
      (Icons.pest_control_rounded, _kSnakeGreen, 0.10, 0.12,  90, 0.0),
      (Icons.circle_rounded,       _kFoodColor,  0.86, 0.18,  44, 0.7),
      (Icons.pest_control_rounded, _kSnakeGreen, 0.18, 0.78,  76, 1.4),
      (Icons.circle_rounded,       _kFoodColor,  0.78, 0.84,  36, 2.1),
      (Icons.pest_control_rounded, _kSnakeGreen, 0.50, 0.50,  64, 4.7),
      (Icons.circle_rounded,       _kFoodColor,  0.06, 0.42,  28, 3.5),
    ];

    for (final (icon, color, xRel, yRel, fontSize, p) in items) {
      final wave = math.sin(phase + p);
      final yBob = wave * 6;
      final rot = math.sin(phase * 0.7 + p) * 0.10;
      final alpha = 0.05 + (math.sin(phase * 1.3 + p) + 1) / 2 * 0.05;

      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: fontSize,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}
