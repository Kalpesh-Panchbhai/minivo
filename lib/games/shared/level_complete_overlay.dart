import 'dart:math' as math;
import 'package:flutter/material.dart';

const _appreciations = [
  'Amazing! 🎉',
  'Brilliant! ✨',
  'Superb! 🌟',
  'Fantastic! 🔥',
  'Well Done! 👏',
  'Awesome! 💫',
  'Incredible! 🏆',
  'Perfect! 💎',
  'Outstanding! 🥇',
  'Magnificent! 🎯',
  'Splendid! 🌈',
  'Marvelous! ⚡',
  'Excellent! 🎊',
  'Wonderful! 💪',
  'Genius! 🧠',
];

class LevelCompleteOverlay extends StatefulWidget {
  final int level;
  final Color accentColor;
  final VoidCallback onComplete;

  const LevelCompleteOverlay({
    super.key,
    required this.level,
    required this.accentColor,
    required this.onComplete,
  });

  @override
  State<LevelCompleteOverlay> createState() => _LevelCompleteOverlayState();
}

class _LevelCompleteOverlayState extends State<LevelCompleteOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final String _text;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _text = _appreciations[rng.nextInt(_appreciations.length)];
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete();
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final fadeIn = (t * 5).clamp(0.0, 1.0);
        final fadeOut = t > 0.75 ? ((1.0 - t) / 0.25).clamp(0.0, 1.0) : 1.0;
        final opacity = fadeIn * fadeOut;
        final scale = 0.5 + fadeIn * 0.5;
        final bgOpacity = opacity * 0.55;

        return Material(
          color: Colors.transparent,
          child: Container(
            color: Colors.black.withValues(alpha: bgOpacity),
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: widget.accentColor.withValues(alpha: 0.6), blurRadius: 20),
                            Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Level ${widget.level} Complete',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
