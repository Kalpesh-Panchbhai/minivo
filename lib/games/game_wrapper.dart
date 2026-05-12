import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/services/analytics_service.dart';
import '../core/services/audio_service.dart';
import '../core/services/crash_reporter.dart';
import '../core/services/ads_service.dart';
import '../core/services/score_service.dart';

enum GameState { ready, playing, paused, gameOver }

class GameWrapper extends StatefulWidget {
  final String gameId;
  final Widget child;
  final bool customOverlays;

  const GameWrapper({
    super.key,
    required this.gameId,
    required this.child,
    this.customOverlays = false,
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

  GameState get state => _state;
  int get score => _score;
  int get highScore => _highScore;

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService().getHighScore(widget.gameId);
  }

  void startGame() {
    _startedAt = DateTime.now();
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
    final wasAlreadyOver = _state == GameState.gameOver;
    AudioService().playGameOver();
    final isNew = _score > _highScore;
    if (isNew) {
      _highScore = _score;
      ScoreService().saveScore(widget.gameId, _score);
    }
    // Per-session bookkeeping (counts, coins, recents, analytics) only fires
    // on the FIRST death of a session. A continued run that ends again still
    // updates the high score above but does not double-count.
    if (!wasAlreadyOver) {
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
    if (wasAlreadyOver) return;

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

          // Default HUD — skipped when the game uses a fully custom overlay
          // and renders its own scoreboard / controls.
          if (_state == GameState.playing && !widget.customOverlays)
            _buildHUD(context),

          // Ready overlay
          if (!widget.customOverlays && _state == GameState.ready)
            _buildReadyOverlay(context),

          // Pause overlay
          if (_state == GameState.paused) _buildPauseOverlay(context),

          // Game over overlay
          if (!widget.customOverlays && _state == GameState.gameOver)
            _buildGameOverOverlay(context),
        ],
      ),
    );
  }

  Widget _buildHUD(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SlideFadeIn(
              child: _ScoreChip(score: _score, bestScore: _highScore),
            ),
            const _SlideFadeIn(child: GamePauseButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyOverlay(BuildContext context) {
    return GestureDetector(
      onTap: startGame,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 64,
                color: Colors.white,
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                    duration: 800.ms,
                  ),
              const SizedBox(height: 20),
              const Text(
                AppStrings.tapToStart,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(duration: 500.ms),
            ],
          ),
        ),
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

  Widget _buildGameOverOverlay(BuildContext context) {
    final stars = _getStars();
    final isNew = _score == _highScore && _score > 0;

    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.gameOver,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.star_rounded,
                        size: 32,
                        color: i < stars
                            ? AppColors.starFilled
                            : AppColors.starEmpty,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  '${AppStrings.score}: $_score',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppStrings.bestScore}: $_highScore',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (isNew) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.starFilled.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '🎉 New High Score!',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.categoryAction,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _overlayButton(
                  AppStrings.playAgain,
                  Icons.refresh_rounded,
                  AppColors.primary,
                  () {
                    AnalyticsService().resultAction(
                      gameId: widget.gameId,
                      action: 'play_again',
                    );
                    restartGame();
                  },
                ),
                const SizedBox(height: 8),
                _overlayButton(
                  AppStrings.home,
                  Icons.home_rounded,
                  AppColors.textSecondary,
                  () {
                    AnalyticsService().resultAction(
                      gameId: widget.gameId,
                      action: 'home',
                    );
                    context.go('/home');
                  },
                ),
              ],
            ),
          )
            .animate()
            .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 300.ms),
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

// ════════════════════════════════════════════════════════════════
// REUSABLE HUD COMPONENTS (used by every game via GameWrapper)
// ════════════════════════════════════════════════════════════════

/// One-shot slide-down + fade-in entrance using TweenAnimationBuilder.
/// Self-disposing — leaves no pending timers when the widget is unmounted.
class _SlideFadeIn extends StatelessWidget {
  final Widget child;
  const _SlideFadeIn({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, ch) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -16),
            child: ch,
          ),
        );
      },
      child: child,
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final int score;
  final int bestScore;

  const _ScoreChip({required this.score, required this.bestScore});

  @override
  Widget build(BuildContext context) {
    final showBest = bestScore > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, showBest ? 14 : 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trophy badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC233), Color(0xFFFF8A00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Score label
              Text(
                'SCORE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              // Animated score number
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutBack,
                  ),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  '$score',
                  key: ValueKey<int>(score),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          if (showBest) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 1,
              height: 26,
              color: AppColors.textPrimary.withValues(alpha: 0.10),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BEST',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$bestScore',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary.withValues(alpha: 0.7),
                    height: 1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
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
