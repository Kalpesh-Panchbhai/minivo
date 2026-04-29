import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Base class for animated background painters used by game picker / detail
/// screens. Subclasses implement [paintAt] receiving a normalised time value
/// `t ∈ [0, 1)` that loops continuously.
///
/// Each painter instance is recreated every animation frame (cheap — they're
/// just thin objects holding `t`), and Flutter only repaints when `t` changes
/// thanks to [shouldRepaint] comparing the time field.
abstract class AnimatedBgPainter extends CustomPainter {
  final double t;
  const AnimatedBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) => paintAt(canvas, size, t);

  void paintAt(Canvas canvas, Size size, double t);

  @override
  bool shouldRepaint(covariant AnimatedBgPainter old) => old.t != t;
}

/// A widget that drives an [AnimatedBgPainter] at a given period.
///
/// Use a top-level / static factory function so the painter can be const-like
/// (cheap to allocate per frame). Wrap a `Stack` of game-themed decorative
/// shapes that gently bob, rotate, and fade — they should feel alive without
/// distracting from the foreground content.
class AnimatedBackground extends StatefulWidget {
  final AnimatedBgPainter Function(double t) factory;
  final Duration period;

  const AnimatedBackground({
    super.key,
    required this.factory,
    this.period = const Duration(seconds: 8),
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the OS / test "disable animations" flag — without this,
    // `pumpAndSettle` in widget tests times out forever waiting for the
    // perpetual repeat() to drain.
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: widget.factory(_ctrl.value),
        ),
      ),
    );
  }
}

/// Generic animated painter — renders coloured floating circles and a
/// scattered cluster of the game's icon at low alpha. Used by
/// [SingleModeGameScreen] so every game's detail surface feels alive without
/// each one having to ship a bespoke painter.
class GenericAnimatedBgPainter extends AnimatedBgPainter {
  final Color accent;
  final IconData icon;
  final Color iconColor;
  GenericAnimatedBgPainter(super.t, {
    required this.accent,
    required this.icon,
    Color? iconColor,
  }) : iconColor = iconColor ?? accent;

  static const _items = <(double, double, double, double)>[
    // (xRel, yRel, radiusBase, phase)
    (0.10, 0.12, 26, 0.0),
    (0.86, 0.08, 18, 0.7),
    (0.18, 0.55, 14, 1.4),
    (0.92, 0.40, 22, 2.1),
    (0.06, 0.78, 20, 2.8),
    (0.78, 0.88, 16, 3.5),
    (0.50, 0.02, 12, 4.2),
    (0.32, 0.95, 18, 4.9),
    (0.95, 0.66, 14, 0.3),
    (0.04, 0.42, 16, 5.6),
  ];

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    // Floating colour bubbles — accented with the game's colour, alpha pulse.
    for (final (xRel, yRel, r, p) in _items) {
      final wave = math.sin(phase + p);
      final yBob = wave * (r * 0.25);
      final alpha = 0.06 + (math.sin(phase * 1.3 + p) + 1) / 2 * 0.06;
      final radius = r + math.sin(phase * 0.7 + p) * (r * 0.10);

      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(w * xRel, h * yRel + yBob),
          radius * 1.2,
          [
            accent.withValues(alpha: alpha),
            accent.withValues(alpha: 0),
          ],
        );
      canvas.drawCircle(Offset(w * xRel, h * yRel + yBob), radius * 1.2, paint);
    }

    // Two larger ghost glyphs of the game icon, drawn via TextPainter using
    // the icon font. Subtle and corner-anchored so they don't crowd content.
    void drawIcon(double xRel, double yRel, double size, double opacity, double itemPhase) {
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: size,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: iconColor.withValues(alpha: opacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = w * xRel;
      final cy = h * yRel + math.sin(phase + itemPhase) * 5;
      final rot = math.sin(phase * 0.5 + itemPhase) * 0.06;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    drawIcon(0.85, 0.18, 110, 0.06, 0.0);
    drawIcon(0.18, 0.78, 90, 0.05, 2.4);
    drawIcon(0.50, 0.48, 70, 0.04, 4.7);
  }
}
