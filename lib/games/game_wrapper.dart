import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/services/analytics_service.dart';
import '../core/services/audio_service.dart';
import '../core/services/crash_reporter.dart';
import '../core/services/review_service.dart';
import '../core/services/ads_service.dart';
import '../core/services/score_service.dart';

enum GameState { ready, playing, paused, gameOver }

class GameWrapper extends StatefulWidget {
  final String gameId;
  final Widget child;

  const GameWrapper({
    super.key,
    required this.gameId,
    required this.child,
  });

  static GameWrapperState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_GameStateScope>();
    if (scope != null) return scope._wrapper;
    return context.findAncestorStateOfType<GameWrapperState>()!;
  }

  @override
  State<GameWrapper> createState() => GameWrapperState();
}

class GameWrapperState extends State<GameWrapper> {
  GameState _state = GameState.ready;
  int _score = 0;
  int _highScore = 0;
  DateTime? _startedAt;
  // True after [endGame] has counted the current session (one fresh
  // start → final death). [continueAfterGameOver] does NOT reset this,
  // so a continued run that ends again won't double-count games-played
  // or re-fire `game_end` analytics. Only [startGame]/[restartGame]
  // begin a new session by clearing the flag.
  bool _sessionCounted = false;
  bool _hasContinued = false;

  GameState get state => _state;
  int get score => _score;
  int get highScore => _highScore;
  bool get hasContinued => _hasContinued;

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService().getHighScore(widget.gameId);
  }

  void startGame() {
    _startedAt = DateTime.now();
    _sessionCounted = false;
    _hasContinued = false;
    setState(() {
      _state = GameState.playing;
      _score = 0;
    });
    AnalyticsService().gameStart(gameId: widget.gameId);
    CrashReporter().log('game_start', {'game_id': widget.gameId});
  }

  void updateScore(int newScore) {
    setState(() => _score = newScore);
  }

  void incrementScore([int amount = 1]) {
    _score += amount;
    AudioService().playScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void pauseGame() {
    if (_state == GameState.playing) {
      setState(() => _state = GameState.paused);
    }
  }

  void resumeGame() {
    if (_state == GameState.paused) {
      setState(() => _state = GameState.playing);
    }
  }

  void endGame() {
    AudioService().playGameOver();
    final isNew = _score > _highScore;
    if (isNew) {
      _highScore = _score;
      ScoreService().saveScore(widget.gameId, _score);
      ReviewService().maybeRequestReview();
    }
    // Per-session bookkeeping (counts, coins, recents, analytics) fires
    // ONCE per session. After `continueAfterGameOver`, _state flips back
    // to playing — we use [_sessionCounted] instead of state inspection
    // so a continued run that ends again doesn't double-count.
    if (!_sessionCounted) {
      _sessionCounted = true;
      ScoreService().incrementGamesPlayed();
      ScoreService().incrementGamePlayCount(widget.gameId);
      ScoreService().addRecentlyPlayed(widget.gameId);

      int coins = 5;
      if (isNew) coins += 10;
      if (_getStars() == 3) coins += 15;
      ScoreService().addCoins(coins);

      final duration = _startedAt == null
          ? 0
          : DateTime.now().difference(_startedAt!).inSeconds;
      AnalyticsService().gameEnd(
        gameId: widget.gameId,
        result: 'loss',
        score: _score,
        durationSec: duration,
        isHighScore: isNew,
      );
      CrashReporter().log('game_end', {
        'game_id': widget.gameId,
        'score': _score,
        'duration_sec': duration,
        'is_high_score': isNew,
      });
    }

    // Idempotent: if state is already gameOver, skip the interstitial flow
    // and state-change (game-over UI is already showing).
    if (_state == GameState.gameOver) return;
    AdsService().notifyGameOver();
    AdsService().showInterstitial(onComplete: () {
      _setGameOverState();
    });
  }

  void _setGameOverState() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      if (mounted) setState(() => _state = GameState.gameOver);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _state = GameState.gameOver);
      });
    }
  }

  /// Resume a session that already ended (typical use: after a rewarded
  /// "Watch ad to continue" button). Flips state from gameOver → playing
  /// without resetting score. Counters and analytics for this session
  /// already fired on the first death — see [endGame].
  void continueAfterGameOver() {
    if (_state != GameState.gameOver) return;
    _hasContinued = true;
    setState(() => _state = GameState.playing);
    AnalyticsService().gameRestart(
      gameId: widget.gameId,
      from: 'rewarded_continue',
    );
    CrashReporter().log('game_continue', {'game_id': widget.gameId});
  }

  void restartGame() {
    final from = _state == GameState.gameOver
        ? 'result_screen'
        : (_state == GameState.paused ? 'pause' : 'mode_change');
    AnalyticsService().gameRestart(gameId: widget.gameId, from: from);
    _startedAt = null;
    _sessionCounted = false;
    _hasContinued = false;
    setState(() {
      _state = GameState.ready;
      _score = 0;
    });
  }

  int _getStars() {
    if (_score >= 75) return 3;
    if (_score >= 30) return 2;
    if (_score >= 10) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Game canvas — wrapped in InheritedWidget so descendants rebuild on state change
          Positioned.fill(
            child: _GameStateScope(
              wrapper: this,
              state: _state,
              score: _score,
              highScore: _highScore,
              child: widget.child,
            ),
          ),

          // Pause overlay
          if (_state == GameState.paused) _buildPauseOverlay(context),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pause_circle_filled_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.paused,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 20),
                _overlayButton(
                  AppStrings.resume,
                  Icons.play_arrow_rounded,
                  AppColors.primary,
                  resumeGame,
                ),
                const SizedBox(height: 8),
                _overlayButton(
                  AppStrings.restart,
                  Icons.refresh_rounded,
                  AppColors.categoryAction,
                  restartGame,
                ),
                const SizedBox(height: 8),
                _overlayButton(
                  AppStrings.quit,
                  Icons.home_rounded,
                  AppColors.textSecondary,
                  () => context.go('/home'),
                ),
              ],
            ),
          ).animate().scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: 300.ms,
                curve: Curves.easeOutBack,
              ),
        ),
      ),
    );
  }

  Widget _overlayButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

class _GameStateScope extends InheritedWidget {
  final GameState state;
  final int score;
  final int highScore;
  final GameWrapperState _wrapper;

  const _GameStateScope({
    required this.state,
    required this.score,
    required this.highScore,
    required GameWrapperState wrapper,
    required super.child,
  }) : _wrapper = wrapper;

  @override
  bool updateShouldNotify(_GameStateScope old) =>
      state != old.state ||
      score != old.score ||
      highScore != old.highScore;
}

/// Reusable, design-consistent pause button — same look across every game.
/// If [onTap] is omitted, calls `GameWrapper.of(context).pauseGame()`.
class GamePauseButton extends StatefulWidget {
  final VoidCallback? onTap;

  const GamePauseButton({super.key, this.onTap});

  @override
  State<GamePauseButton> createState() => _GamePauseButtonState();
}

class _GamePauseButtonState extends State<GamePauseButton> {
  bool _pressed = false;

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      GameWrapper.of(context).pauseGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.pause_rounded,
            size: 26,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
