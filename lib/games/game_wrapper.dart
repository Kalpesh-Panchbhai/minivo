import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/services/audio_service.dart';
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
    return context.findAncestorStateOfType<GameWrapperState>()!;
  }

  @override
  State<GameWrapper> createState() => GameWrapperState();
}

class GameWrapperState extends State<GameWrapper> {
  GameState _state = GameState.ready;
  int _score = 0;
  int _highScore = 0;

  GameState get state => _state;
  int get score => _score;
  int get highScore => _highScore;

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService().getHighScore(widget.gameId);
  }

  void startGame() {
    setState(() {
      _state = GameState.playing;
      _score = 0;
    });
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
    if (_state == GameState.gameOver) return;
    AudioService().playGameOver();
    final isNew = _score > _highScore;
    if (isNew) {
      _highScore = _score;
      ScoreService().saveScore(widget.gameId, _score);
    }
    ScoreService().incrementGamesPlayed();
    ScoreService().incrementGamePlayCount(widget.gameId);
    ScoreService().addRecentlyPlayed(widget.gameId);

    int coins = 5;
    if (isNew) coins += 10;
    if (_getStars() == 3) coins += 15;
    ScoreService().addCoins(coins);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _state = GameState.gameOver);
    });
  }

  void restartGame() {
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
        children: [
          // Game canvas
          Positioned.fill(child: widget.child),

          // HUD
          if (_state == GameState.playing) _buildHUD(context),

          // Ready overlay
          if (_state == GameState.ready) _buildReadyOverlay(context),

          // Pause overlay
          if (_state == GameState.paused) _buildPauseOverlay(context),

          // Game over overlay
          if (_state == GameState.gameOver) _buildGameOverOverlay(context),
        ],
      ),
    );
  }

  Widget _buildHUD(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${AppStrings.bestScore}: $_highScore',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: pauseGame,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
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
                  restartGame,
                ),
                const SizedBox(height: 8),
                _overlayButton(
                  AppStrings.home,
                  Icons.home_rounded,
                  AppColors.textSecondary,
                  () => context.go('/home'),
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
