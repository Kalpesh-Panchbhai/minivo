import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'animated_difficulty_icon.dart';
import 'game_picker_button.dart';
import 'spinning_slider.dart';

// ════════════════════════════════════════════════════════════════
// DATA MODEL
// ════════════════════════════════════════════════════════════════

/// Data describing one difficulty option shown in the picker card.
class GameDifficultyData {
  final String label;
  final Color color;
  final DifficultyKind kind;
  final String hint;
  final int bestScore;
  final String Function(int score) bestLabel;

  const GameDifficultyData({
    required this.label,
    required this.color,
    required this.kind,
    required this.hint,
    required this.bestScore,
    required this.bestLabel,
  });
}

// ════════════════════════════════════════════════════════════════
// INTERNAL HELPERS
// ════════════════════════════════════════════════════════════════

/// Animated colored box showing the currently selected difficulty name + icon.
class GameDifficultyLabel extends StatelessWidget {
  final GameDifficultyData data;
  const GameDifficultyLabel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Container(
        key: ValueKey(data.label),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: data.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: data.color.withValues(alpha: 0.30),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDifficultyIcon(kind: data.kind, size: 32),
            const SizedBox(width: 12),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: data.color,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Personal-best pill displayed under the difficulty selector.
class GameBestPill extends StatelessWidget {
  final GameDifficultyData data;
  const GameBestPill({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final best = data.bestScore;
    final color = data.color;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey('best_${data.label}_$best'),
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
                best > 0 ? data.bestLabel(best) : 'Set your first best!',
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

// ════════════════════════════════════════════════════════════════
// SHARED CARD
// ════════════════════════════════════════════════════════════════

/// The white rounded-top card containing the eyebrow, difficulty label,
/// spinning slider, hint text, and best-score pill.
class GameDifficultyCard extends StatelessWidget {
  final List<GameDifficultyData> difficulties;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final IconData eyebrowIcon;
  final String eyebrowLabel;
  final Color accentColor;

  const GameDifficultyCard({
    super.key,
    required this.difficulties,
    required this.activeIndex,
    required this.onChanged,
    required this.eyebrowIcon,
    required this.eyebrowLabel,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = difficulties[activeIndex];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
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
            // Eyebrow row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(eyebrowIcon, size: 16, color: accentColor),
                ),
                const SizedBox(width: 8),
                Text(
                  eyebrowLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GameDifficultyLabel(data: active),
            const SizedBox(height: 14),
            SpinningSlider(
              stopCount: difficulties.length,
              activeIndex: activeIndex,
              activeColor: active.color,
              stopColors: difficulties.map((d) => d.color).toList(),
              onChanged: onChanged,
            ),
            const SizedBox(height: 8),
            // Hint text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Padding(
                key: ValueKey(activeIndex),
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  active.hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6B5E7E),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GameBestPill(data: active),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COMPOSED PICKER BODIES
// ════════════════════════════════════════════════════════════════

/// Picker body for multiplayer games (Tic Tac Toe, Memory Match).
/// Shows the difficulty card + "Play vs. AI" button + "Play with a Friend" button.
class GameAiPickerBody extends StatelessWidget {
  final List<GameDifficultyData> difficulties;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onPlayAi;
  final VoidCallback onPlayFriend;
  final List<Color> aiGradient;
  final List<Color> friendGradient;
  final String difficultyLabel;

  const GameAiPickerBody({
    super.key,
    required this.difficulties,
    required this.activeIndex,
    required this.onChanged,
    required this.onPlayAi,
    required this.onPlayFriend,
    this.aiGradient = const [Color(0xFF6C4EF3), Color(0xFF8B72F8)],
    this.friendGradient = const [Color(0xFFFF5A5F), Color(0xFFFF8E53)],
    this.difficultyLabel = 'AI DIFFICULTY',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameDifficultyCard(
          difficulties: difficulties,
          activeIndex: activeIndex,
          onChanged: onChanged,
          eyebrowIcon: Icons.tune_rounded,
          eyebrowLabel: difficultyLabel,
          accentColor: aiGradient.first,
        ),
        GamePickerButton(
          label: 'Play vs. AI',
          sublabel: 'Single player',
          icon: Icons.smart_toy_rounded,
          gradientColors: aiGradient,
          onTap: onPlayAi,
          topRadius: 0,
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 320.ms)
            .slideY(begin: 0.08, end: 0, duration: 320.ms),
        const SizedBox(height: 12),
        GamePickerButton(
          label: 'Play with a Friend',
          sublabel: 'Pass & play on one device',
          icon: Icons.people_alt_rounded,
          gradientColors: friendGradient,
          onTap: onPlayFriend,
        )
            .animate()
            .fadeIn(delay: 260.ms, duration: 320.ms)
            .slideY(begin: 0.08, end: 0, duration: 320.ms),
      ],
    );
  }
}

/// Picker body for single-player games (Snake, ColorTap, NumberMerge, FlappyTap).
/// Shows the difficulty card + a single play button whose gradient follows the active difficulty.
class GameSinglePickerBody extends StatelessWidget {
  final List<GameDifficultyData> difficulties;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final String playLabel;
  final String playSubLabel;
  final VoidCallback onPlay;
  final Color accentColor;

  const GameSinglePickerBody({
    super.key,
    required this.difficulties,
    required this.activeIndex,
    required this.onChanged,
    required this.playLabel,
    required this.playSubLabel,
    required this.onPlay,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = difficulties[activeIndex].color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameDifficultyCard(
          difficulties: difficulties,
          activeIndex: activeIndex,
          onChanged: onChanged,
          eyebrowIcon: Icons.tune_rounded,
          eyebrowLabel: 'DIFFICULTY',
          accentColor: accentColor,
        ),
        GamePickerButton(
          label: playLabel,
          sublabel: playSubLabel,
          icon: Icons.play_arrow_rounded,
          gradientColors: [
            activeColor,
            Color.lerp(activeColor, Colors.white, 0.22)!,
          ],
          onTap: onPlay,
          topRadius: 0,
        )
            .animate()
            .fadeIn(delay: 220.ms, duration: 320.ms)
            .slideY(begin: 0.08, end: 0, duration: 320.ms),
      ],
    );
  }
}
