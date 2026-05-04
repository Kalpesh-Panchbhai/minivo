import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> memoryMatchSteps() => [
      GameHowToPlayStep(
        text: 'Tap any card to flip it over',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2400),
          painter: (t) => _FlipCardPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Find the matching pair!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _MatchFoundPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Remember positions — fewer flips = higher score!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3200),
          painter: (t) => _RememberPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kBlue  = Color(0xFF339AF0);
const _kGreen = Color(0xFF22C55E);
const _kRed   = Color(0xFFEF4444);

// ── Shared background ──────────────────────────────────────────────────────

void _drawBackground(Canvas canvas, Size size) {
  // Dark blue-purple gradient bg
  final paint = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFF0F1A3A), Color(0xFF0A1628)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

  // Subtle dot grid overlay
  final dotPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.04);
  const spacing = 18.0;
  for (double x = spacing / 2; x < size.width; x += spacing) {
    for (double y = spacing / 2; y < size.height; y += spacing) {
      canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
    }
  }
}

// ── Shared card renderer ───────────────────────────────────────────────────

void _drawCard(
  Canvas canvas,
  Rect rect, {
  required bool faceUp,
  String? emoji,
  double scaleX = 1.0,
  double alpha = 1.0,
  bool glow = false,
  bool mismatch = false,
  Color? borderColor,
}) {
  if (scaleX.abs() < 0.02) return;

  canvas.save();
  final cx = rect.center.dx;
  canvas.translate(cx, 0);
  canvas.scale(scaleX, 1.0);
  canvas.translate(-cx, 0);

  final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.13));

  // Glow / shadow
  if (glow) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(5),
        Radius.circular(rect.width * 0.18),
      ),
      Paint()
        ..color = _kGreen.withValues(alpha: 0.50 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  } else if (mismatch) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(4),
        Radius.circular(rect.width * 0.16),
      ),
      Paint()
        ..color = _kRed.withValues(alpha: 0.45 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  } else {
    // Depth shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(1.5, 3),
        Radius.circular(rect.width * 0.13),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  if (faceUp) {
    // Cream white card
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF0F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect)
        ..color = Colors.white.withValues(alpha: alpha),
    );

    // Colored border (pair tint)
    final bColor = borderColor ?? (glow ? _kGreen : _kBlue);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = bColor.withValues(alpha: (glow ? 0.90 : 0.45) * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow ? 1.8 : 1.4,
    );

    // Emoji
    if (emoji != null && scaleX > 0.1) {
      final tp = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(fontSize: rect.width * 0.52),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          rect.left + (rect.width - tp.width) / 2,
          rect.top + (rect.height - tp.height) / 2,
        ),
      );
    }
  } else {
    // Back: deep purple-blue gradient
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF5C6BC0).withValues(alpha: alpha),
            const Color(0xFF3949AB).withValues(alpha: alpha),
            const Color(0xFF1A237E).withValues(alpha: alpha),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );

    // Dot pattern
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22 * alpha);
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        final dx = rect.left + rect.width * (c + 1) / 4;
        final dy = rect.top + rect.height * (r + 1) / 4;
        canvas.drawCircle(Offset(dx, dy), rect.width * 0.055, dotPaint);
      }
    }

    // Question mark
    final qp = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.58 * alpha),
          fontSize: rect.width * 0.40,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    qp.paint(
      canvas,
      Offset(
        rect.left + (rect.width - qp.width) / 2,
        rect.top + (rect.height - qp.height) / 2,
      ),
    );

    // Highlight edge
    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.20 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  canvas.restore();
}

// ── Floating score text helper ─────────────────────────────────────────────

void _drawFloatingScore(
  Canvas canvas,
  String text,
  Offset pos,
  double alpha, {
  Color color = _kGreen,
  double fontSize = 15,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(
            color: color.withValues(alpha: alpha * 0.50),
            blurRadius: 6,
          ),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy));
}

// ─────────────────────────────────────────────────────────────────────────
// Step 1: Single card flips from back to front with TAP indicator
// ─────────────────────────────────────────────────────────────────────────

class _FlipCardPainter extends CustomPainter {
  final double t;
  const _FlipCardPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    final cx = size.width / 2;
    final cy = size.height / 2 - 8;
    final cw = size.width * 0.30;
    final ch = cw * 1.40;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch);

    // Phase: 0–0.1 idle, 0.1–0.55 flip, 0.55–0.85 face-up hold, 0.85–1.0 fade
    final flipPhase = ((t - 0.10) / 0.45).clamp(0.0, 1.0);
    final bool showFront = flipPhase >= 0.5;
    double scaleX;
    if (flipPhase < 0.5) {
      scaleX = 1.0 - flipPhase * 2.0;
    } else {
      scaleX = (flipPhase - 0.5) * 2.0;
    }
    // Ease the scale
    scaleX = Curves.easeInOut.transform(scaleX.clamp(0.0, 1.0));

    _drawCard(canvas, rect,
      faceUp: showFront,
      emoji: showFront ? '🐶' : null,
      scaleX: scaleX.clamp(0.01, 1.0),
      borderColor: _kBlue,
    );

    // "TAP!" prompt — pulsing before the flip
    if (t < 0.12) {
      final pulse = math.sin(t / 0.12 * math.pi * 2);
      final labelAlpha = (1.0 - t / 0.12).clamp(0.0, 1.0) * 0.90;
      _drawLabel(
        canvas,
        'TAP!',
        Offset(cx, cy + ch / 2 + 12),
        labelAlpha * (0.75 + pulse * 0.25),
        color: _kBlue,
        fontSize: 12,
      );
    }

    // Tap ripple at start of flip
    if (t > 0.08 && t < 0.22) {
      final rippleT = (t - 0.08) / 0.14;
      final rippleR = cw * 0.5 * rippleT;
      canvas.drawCircle(
        Offset(cx, cy),
        rippleR,
        Paint()
          ..color = _kBlue.withValues(alpha: (1.0 - rippleT) * 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // "FLIPPED!" label after flip completes
    if (t > 0.58 && t < 0.90) {
      final labelAlpha = math.sin(((t - 0.58) / 0.32) * math.pi).clamp(0.0, 1.0);
      _drawLabel(
        canvas,
        'FLIPPED!',
        Offset(cx, cy + ch / 2 + 12),
        labelAlpha * 0.90,
        color: _kGreen,
        fontSize: 11,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlipCardPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────
// Step 2: Two cards flip sequentially, match found with glow + score
// ─────────────────────────────────────────────────────────────────────────

class _MatchFoundPainter extends CustomPainter {
  final double t;
  const _MatchFoundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    final cx = size.width / 2;
    final cy = size.height * 0.46;
    final cw = size.width * 0.27;
    final ch = cw * 1.38;
    final gap = cw * 0.22;

    final rect1 = Rect.fromCenter(center: Offset(cx - cw / 2 - gap / 2, cy), width: cw, height: ch);
    final rect2 = Rect.fromCenter(center: Offset(cx + cw / 2 + gap / 2, cy), width: cw, height: ch);

    // Timeline:
    // 0.00–0.18: card1 back→front flip
    // 0.22–0.40: card2 back→front flip
    // 0.42–0.55: brief pause showing both face-up
    // 0.55–1.00: glow + +20 score rises + sparkles

    final bool card1Front = t > 0.09;
    final bool card2Front = t > 0.31;
    final bool showGlow = t > 0.55;

    double flipScale(double start, double end) {
      final phase = ((t - start) / (end - start)).clamp(0.0, 1.0);
      final s = phase < 0.5 ? 1.0 - phase * 2 : (phase - 0.5) * 2;
      return Curves.easeInOut.transform(s.clamp(0.0, 1.0)).clamp(0.01, 1.0);
    }

    final c1Scale = flipScale(0.0, 0.18);
    final c2Scale = t < 0.22 ? 1.0 : flipScale(0.22, 0.40);

    _drawCard(canvas, rect1,
      faceUp: card1Front,
      emoji: '🐱',
      scaleX: c1Scale,
      glow: showGlow,
      borderColor: const Color(0xFF4DABF7),
    );
    _drawCard(canvas, rect2,
      faceUp: card2Front,
      emoji: '🐱',
      scaleX: c2Scale,
      glow: showGlow,
      borderColor: const Color(0xFF4DABF7),
    );

    if (showGlow) {
      final glowProgress = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
      final scoreAlpha = (glowProgress < 0.15
          ? glowProgress / 0.15
          : glowProgress > 0.85
              ? (1.0 - glowProgress) / 0.15
              : 1.0)
          .clamp(0.0, 1.0);
      final riseY = glowProgress * size.height * 0.18;

      _drawFloatingScore(
        canvas,
        '+20',
        Offset(cx, cy - ch / 2 - 14 - riseY),
        scoreAlpha,
        fontSize: 16,
      );

      // "MATCH!" label
      if (glowProgress > 0.25) {
        final labelAlpha = ((glowProgress - 0.25) / 0.75).clamp(0.0, 1.0);
        _drawLabel(
          canvas,
          'MATCH!',
          Offset(cx, cy + ch / 2 + 12),
          labelAlpha * 0.95,
          color: _kGreen,
          fontSize: 12,
        );
      }

      // Sparkle dots
      if (glowProgress > 0.10) {
        _drawSparkles(canvas, rect1.center, glowProgress, size.width * 0.12);
        _drawSparkles(canvas, rect2.center, glowProgress, size.width * 0.12);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MatchFoundPainter old) => old.t != t;
}

void _drawSparkles(Canvas canvas, Offset center, double t, double radius) {
  const count = 6;
  for (int i = 0; i < count; i++) {
    final angle = (i / count) * 2 * math.pi + t * 2;
    final r = radius * (0.4 + t * 0.6);
    final x = center.dx + math.cos(angle) * r;
    final y = center.dy + math.sin(angle) * r;
    final alpha = (1.0 - t).clamp(0.0, 1.0) * 0.80;
    canvas.drawCircle(
      Offset(x, y),
      2.5,
      Paint()..color = _kGreen.withValues(alpha: alpha),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step 3: Cards flip and flip back — remember positions
// ─────────────────────────────────────────────────────────────────────────

class _RememberPainter extends CustomPainter {
  final double t;
  const _RememberPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    final cx = size.width / 2;
    final cy = size.height * 0.44;
    final cw = size.width * 0.24;
    final ch = cw * 1.38;
    final gap = cw * 0.16;

    // 3 cards in a row
    final centers = [
      Offset(cx - cw - gap, cy),
      Offset(cx, cy),
      Offset(cx + cw + gap, cy),
    ];
    final emojis = ['🦊', '🐸', '🦊'];
    final pairColors = [const Color(0xFFFF922B), const Color(0xFF51CF66), const Color(0xFFFF922B)];

    // Timeline (3 acts):
    // Act 1 (0.00–0.35): card[0] flips open → shows 🦊 → flips back
    // Act 2 (0.38–0.72): card[1] flips open → shows 🐸 → flips back
    // Act 3 (0.78–1.00): card[2] tapped → flips → 🦊 MATCH!

    for (int i = 0; i < 3; i++) {
      bool faceUp = false;
      double scaleX = 1.0;
      bool glow = false;

      double flipScaleThree(double start, double mid, double end) {
        if (t < start) return 1.0;
        if (t < mid) {
          final phase = (t - start) / (mid - start);
          return Curves.easeInOut.transform((1.0 - phase).clamp(0.0, 1.0)).clamp(0.01, 1.0);
        }
        if (t < end) {
          final phase = (t - mid) / (end - mid);
          return Curves.easeInOut.transform(phase.clamp(0.0, 1.0)).clamp(0.01, 1.0);
        }
        return 1.0;
      }

      if (i == 0) {
        // Flip open 0.00→0.12, face-up 0.12→0.22, flip close 0.22→0.34
        if (t < 0.12) {
          scaleX = flipScaleThree(0.0, 0.06, 0.12);
          faceUp = t >= 0.06;
        } else if (t < 0.22) {
          faceUp = true;
          scaleX = 1.0;
        } else if (t < 0.34) {
          faceUp = t < 0.28;
          scaleX = flipScaleThree(0.22, 0.28, 0.34);
        } else {
          faceUp = false;
          scaleX = 1.0;
        }
      } else if (i == 1) {
        // Flip open 0.38→0.50, face-up 0.50→0.60, flip close 0.60→0.72
        if (t < 0.38) {
          faceUp = false;
          scaleX = 1.0;
        } else if (t < 0.50) {
          scaleX = flipScaleThree(0.38, 0.44, 0.50);
          faceUp = t >= 0.44;
        } else if (t < 0.60) {
          faceUp = true;
          scaleX = 1.0;
        } else if (t < 0.72) {
          faceUp = t < 0.66;
          scaleX = flipScaleThree(0.60, 0.66, 0.72);
        } else {
          faceUp = false;
          scaleX = 1.0;
        }
      } else {
        // Card[2] tapped at 0.78, flips open 0.78→0.90, glow 0.90–1.0
        if (t < 0.78) {
          faceUp = false;
          scaleX = 1.0;
        } else if (t < 0.90) {
          scaleX = flipScaleThree(0.78, 0.84, 0.90);
          faceUp = t >= 0.84;
        } else {
          faceUp = true;
          scaleX = 1.0;
          glow = t > 0.92;
        }
      }

      final rect = Rect.fromCenter(center: centers[i], width: cw, height: ch);
      _drawCard(
        canvas,
        rect,
        faceUp: faceUp,
        emoji: emojis[i],
        scaleX: scaleX,
        glow: glow,
        borderColor: pairColors[i],
      );
    }

    // "REMEMBER!" label between acts 1 and 2
    if (t > 0.35 && t < 0.54) {
      final labelAlpha = math.sin(((t - 0.35) / 0.19) * math.pi).clamp(0.0, 1.0);
      _drawLabel(
        canvas,
        'REMEMBER!',
        Offset(cx, cy + ch / 2 + 12),
        labelAlpha * 0.92,
        color: _kBlue,
        fontSize: 11,
      );
    }

    // Score indicator on final match
    if (t > 0.92) {
      final scoreAlpha = ((t - 0.92) / 0.08).clamp(0.0, 1.0);
      final riseY = (t - 0.92) * size.height * 0.15;
      _drawFloatingScore(
        canvas,
        '+20',
        Offset(centers[2].dx, centers[2].dy - ch / 2 - 12 - riseY),
        scoreAlpha,
        fontSize: 14,
      );
      _drawSparkles(canvas, centers[2], (t - 0.92) / 0.08, cw * 0.55);
    }

    // Tap indicator above card[2] before it flips
    if (t > 0.72 && t < 0.82) {
      final tapAlpha = math.sin(((t - 0.72) / 0.10) * math.pi).clamp(0.0, 1.0);
      // Ripple
      final rippleT = ((t - 0.72) / 0.10).clamp(0.0, 1.0);
      canvas.drawCircle(
        centers[2],
        cw * 0.45 * rippleT,
        Paint()
          ..color = _kBlue.withValues(alpha: (1.0 - rippleT) * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      _drawLabel(
        canvas,
        'TAP!',
        Offset(centers[2].dx, centers[2].dy + ch / 2 + 12),
        tapAlpha * 0.90,
        color: _kBlue,
        fontSize: 11,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RememberPainter old) => old.t != t;
}

// ── Shared label helper ────────────────────────────────────────────────────

void _drawLabel(
  Canvas canvas,
  String text,
  Offset center,
  double alpha, {
  Color color = _kBlue,
  double fontSize = 12,
}) {
  if (alpha <= 0.01) return;

  // Background pill
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final pillRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(center.dx, center.dy + tp.height / 2),
      width: tp.width + 12,
      height: tp.height + 6,
    ),
    const Radius.circular(6),
  );
  canvas.drawRRect(
    pillRect,
    Paint()..color = color.withValues(alpha: alpha * 0.15),
  );

  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
}
