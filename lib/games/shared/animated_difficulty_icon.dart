import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Difficulty levels that the icon system understands. Independent of any
/// per-game difficulty enum so it can be reused everywhere.
enum DifficultyKind { easy, medium, hard }

/// A self-animated icon that visually represents a difficulty level.
///
/// We render the actual OS emoji glyph (🌱 / 🔥 / 💀) so the recognisable
/// "real" appearance is preserved, then layer it with kind-specific motion
/// and lighting effects (glow halos, flicker, sway, breathing). Together
/// these read as "alive" without ever leaving the emoji safe zone.
class AnimatedDifficultyIcon extends StatefulWidget {
  final DifficultyKind kind;
  final double size;

  /// When false (e.g. unselected scoreboard tab) the motion is more
  /// subdued — saves CPU and reduces visual noise.
  final bool prominent;

  const AnimatedDifficultyIcon({
    super.key,
    required this.kind,
    this.size = 36,
    this.prominent = true,
  });

  @override
  State<AnimatedDifficultyIcon> createState() => _AnimatedDifficultyIconState();
}

class _AnimatedDifficultyIconState extends State<AnimatedDifficultyIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      // Each kind has a different "natural" period — fire flickers fast,
      // plant sways slowly, skull breathes in between.
      duration: switch (widget.kind) {
        DifficultyKind.easy => const Duration(milliseconds: 2800),
        DifficultyKind.medium => const Duration(milliseconds: 1200),
        DifficultyKind.hard => const Duration(milliseconds: 1600),
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disabled) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        switch (widget.kind) {
          case DifficultyKind.easy:
            return _LeafIcon(t: _ctrl.value, size: widget.size, prominent: widget.prominent);
          case DifficultyKind.medium:
            return _FireIcon(t: _ctrl.value, size: widget.size, prominent: widget.prominent);
          case DifficultyKind.hard:
            return _SkullIcon(t: _ctrl.value, size: widget.size, prominent: widget.prominent);
        }
      },
    );
  }
}

// ── EASY: leaf with smooth wind-driven sway pivoting at the base ──────────

class _LeafIcon extends StatelessWidget {
  final double t;
  final double size;
  final bool prominent;
  const _LeafIcon({required this.t, required this.size, required this.prominent});

  @override
  Widget build(BuildContext context) {
    final phase = t * 2 * math.pi;
    // Compose two sines at different rates — feels like real wind that
    // gusts and lulls instead of a perfect pendulum.
    final swayAmp = prominent ? 0.20 : 0.10;
    final sway = (math.sin(phase) * 0.7 + math.sin(phase * 1.7 + 0.3) * 0.3) * swayAmp;
    final breath = 1.0 + math.sin(phase * 0.5) * 0.025;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.rotate(
          angle: sway,
          // Pivot at the base of the leaf so the whole sprout bends like a
          // stem — not a clock hand spinning around its centre.
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scale: breath,
            child: Text(
              '🌱',
              style: TextStyle(
                fontSize: size * 0.86,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── MEDIUM: real-feeling fire — glow halo + flicker + ghost tongue ────────

class _FireIcon extends StatelessWidget {
  final double t;
  final double size;
  final bool prominent;
  const _FireIcon({required this.t, required this.size, required this.prominent});

  @override
  Widget build(BuildContext context) {
    final phase = t * 2 * math.pi;

    // Layered high-frequency sines + a phase offset = chaotic flame-like
    // flicker without a jarring on/off jump. Every term is normalised so
    // the sum stays in roughly [-1, 1].
    final fast1 = math.sin(phase * 5);
    final fast2 = math.sin(phase * 7.3 + 1.0);
    final fast3 = math.sin(phase * 11 + 2.4);
    final flicker = (fast1 * 0.5 + fast2 * 0.35 + fast3 * 0.15);

    final amp = prominent ? 1.0 : 0.5;

    // Vertical scale emphasises the flame "stretching" upward when it
    // surges; horizontal stays nearly flat so the tongue doesn't squash.
    final scaleY = 1.0 + flicker * 0.14 * amp;
    final scaleX = 1.0 + math.sin(phase * 6 + 0.5) * 0.05 * amp;

    // Tiny lateral wobble as the flame is buffeted by air currents.
    final dx = math.sin(phase * 3.7) * 1.3 * amp;
    final dy = -((flicker + 1) / 2) * 1.5 * amp; // slight upward bias

    // Subtle rotation jitter.
    final rot = math.sin(phase * 2.1 + 0.3) * 0.05 * amp;

    // Glow alpha pulses with the flicker so the halo "breathes" with the
    // flame — strongest on surge frames, dims on lulls.
    final glow = (flicker + 1) / 2; // 0..1
    final glowAlpha = 0.30 + glow * 0.45;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Outer glow halo — radial orange/red, pulses with flicker.
          if (prominent)
            Container(
              width: size * 0.55,
              height: size * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B00).withValues(
                      alpha: glowAlpha * 0.55,
                    ),
                    blurRadius: size * 0.32,
                    spreadRadius: size * 0.06,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFC700).withValues(
                      alpha: glowAlpha * 0.40,
                    ),
                    blurRadius: size * 0.18,
                  ),
                ],
              ),
            ),
          // ── Ghost flame layer — slightly larger, behind the main, with a
          //    different phase so it appears as a second flickering tongue.
          Transform.translate(
            offset: Offset(-dx * 0.6, dy * 1.4),
            child: Opacity(
              opacity: 0.55 * amp.clamp(0.4, 1.0),
              child: Transform.scale(
                scaleX: 1.0 + math.sin(phase * 6.5 + 1.4) * 0.06,
                scaleY: 1.0 + math.sin(phase * 5.5 + 1.4) * 0.18,
                child: Text(
                  '🔥',
                  style: TextStyle(
                    fontSize: size * 0.86,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          // ── Main flame — the prominent flicker.
          Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rot,
              child: Transform.scale(
                scaleX: scaleX,
                scaleY: scaleY,
                alignment: Alignment.bottomCenter,
                child: Text(
                  '🔥',
                  style: TextStyle(
                    fontSize: size * 0.95,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── HARD: skull with ominous red glow + slow breathing + slight head tilt ─

class _SkullIcon extends StatelessWidget {
  final double t;
  final double size;
  final bool prominent;
  const _SkullIcon({required this.t, required this.size, required this.prominent});

  @override
  Widget build(BuildContext context) {
    final phase = t * 2 * math.pi;
    final breath = 1.0 + math.sin(phase) * (prominent ? 0.045 : 0.02);
    // Slow head tilt (different rate than breath) for unsettling drift.
    final tilt = math.sin(phase * 0.7 + 0.5) * (prominent ? 0.04 : 0.02);
    final glow = (math.sin(phase) + 1) / 2; // 0..1
    final glowAlpha = 0.20 + glow * 0.45;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Red eye-glow halo behind the skull.
          if (prominent)
            Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(
                      alpha: glowAlpha,
                    ),
                    blurRadius: size * 0.30,
                    spreadRadius: size * 0.05,
                  ),
                  BoxShadow(
                    color: const Color(0xFFB91C1C).withValues(
                      alpha: glowAlpha * 0.5,
                    ),
                    blurRadius: size * 0.12,
                  ),
                ],
              ),
            ),
          // ── Skull glyph — slow breathe + slight tilt.
          Transform.rotate(
            angle: tilt,
            child: Transform.scale(
              scale: breath,
              child: Text(
                '💀',
                style: TextStyle(
                  fontSize: size * 0.86,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
