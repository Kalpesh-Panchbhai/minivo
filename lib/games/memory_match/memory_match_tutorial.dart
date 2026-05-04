import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> memoryMatchSteps() => [
      GameHowToPlayStep(
        text: 'Tap any card to flip it over',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2200),
          painter: (t) => _FlipCardPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Find the matching pair!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2600),
          painter: (t) => _MatchFoundPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Remember positions — fewer flips = higher score!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3000),
          painter: (t) => _RememberPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kBlue   = Color(0xFF339AF0);
const _kBlueDk = Color(0xFF1971C2);

void _drawBackground(Canvas canvas, Size size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = const Color(0xFF0A1628),
  );
}

void _drawCard(
  Canvas canvas,
  Rect rect, {
  required bool faceUp,
  String? emoji,
  double scaleX = 1.0,
  double alpha = 1.0,
  bool glow = false,
}) {
  if (scaleX.abs() < 0.02) return; // invisible

  canvas.save();
  // Apply horizontal scale (flip effect)
  final cx = rect.center.dx;
  canvas.translate(cx, 0);
  canvas.scale(scaleX, 1.0);
  canvas.translate(-cx, 0);

  final rr = RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.12));

  if (glow) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(4),
        Radius.circular(rect.width * 0.16),
      ),
      Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: 0.45 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  if (faceUp) {
    canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: alpha));
    if (emoji != null && scaleX > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(fontSize: rect.width * 0.50),
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
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [_kBlue, _kBlueDk],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..color = Colors.white.withValues(alpha: alpha);
    canvas.drawRRect(rr, Paint()..color = _kBlue.withValues(alpha: alpha));

    // Dot pattern
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 * alpha);
    const cols = 3;
    const rows = 3;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final dx = rect.left + rect.width * (c + 1) / (cols + 1);
        final dy = rect.top + rect.height * (r + 1) / (rows + 1);
        canvas.drawCircle(Offset(dx, dy), rect.width * 0.06, dotPaint);
      }
    }
    paint.shader = null;
  }

  // Border
  canvas.drawRRect(
    rr,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.25 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );

  canvas.restore();
}

// Step 1: Single card flips from back to front
class _FlipCardPainter extends CustomPainter {
  final double t;
  const _FlipCardPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    final cx = size.width / 2;
    final cy = size.height / 2;
    final cw = size.width * 0.28;
    final ch = cw * 1.35;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: cw, height: ch);

    // Flip: t 0→0.5 back shrinks to 0, t 0.5→1 front grows from 0
    final flipPhase = (t * 2).clamp(0.0, 2.0);
    final bool showFront = flipPhase >= 1.0;
    final scaleX = showFront
        ? (flipPhase - 1.0).clamp(0.0, 1.0)
        : (1.0 - flipPhase).clamp(0.0, 1.0);

    _drawCard(canvas, rect,
      faceUp: showFront,
      emoji: showFront ? '🐶' : null,
      scaleX: scaleX,
    );

    // "TAP!" prompt at the start
    if (t < 0.35) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'TAP!',
          style: TextStyle(
            color: _kBlue.withValues(alpha: (1 - t / 0.35).clamp(0.0, 1.0) * 0.90),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + ch / 2 + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _FlipCardPainter old) => old.t != t;
}

// Step 2: Two cards flip, match found with glow
class _MatchFoundPainter extends CustomPainter {
  final double t;
  const _MatchFoundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    final cx = size.width / 2;
    final cy = size.height * 0.48;
    final cw = size.width * 0.26;
    final ch = cw * 1.35;
    final gap = cw * 0.25;

    final rect1 = Rect.fromCenter(center: Offset(cx - cw / 2 - gap / 2, cy), width: cw, height: ch);
    final rect2 = Rect.fromCenter(center: Offset(cx + cw / 2 + gap / 2, cy), width: cw, height: ch);

    // Phase 0–0.30: card1 flips
    // Phase 0.30–0.60: card2 flips
    // Phase 0.60–1.0: glow + +20 text
    final bool card1Front = t > 0.15;
    final bool card2Front = t > 0.45;
    final bool showGlow = t > 0.62;

    double card1Scale;
    if (t < 0.15) {
      card1Scale = (1.0 - t / 0.15).clamp(0.0, 1.0);
    } else {
      card1Scale = ((t - 0.15) / 0.15).clamp(0.0, 1.0);
    }

    double card2Scale;
    if (t < 0.45) {
      card2Scale = 1.0;
      if (t > 0.30) card2Scale = (1.0 - (t - 0.30) / 0.15).clamp(0.0, 1.0);
    } else {
      card2Scale = ((t - 0.45) / 0.15).clamp(0.0, 1.0);
    }

    _drawCard(canvas, rect1, faceUp: card1Front, emoji: '🐱', scaleX: card1Scale, glow: showGlow);
    _drawCard(canvas, rect2, faceUp: card2Front, emoji: '🐱', scaleX: card2Scale, glow: showGlow);

    if (showGlow) {
      final glowAlpha = ((t - 0.62) / 0.20).clamp(0.0, 1.0);
      final riseY = (t - 0.62) * size.height * 0.20;
      final tp = TextPainter(
        text: TextSpan(
          text: '+20',
          style: TextStyle(
            color: const Color(0xFF22C55E).withValues(alpha: glowAlpha),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - ch / 2 - 18 - riseY));
    }
  }

  @override
  bool shouldRepaint(covariant _MatchFoundPainter old) => old.t != t;
}

// Step 3: Card flips, flips back, then tap correct card from memory
class _RememberPainter extends CustomPainter {
  final double t;
  const _RememberPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    final cx = size.width / 2;
    final cy = size.height * 0.46;
    final cw = size.width * 0.23;
    final ch = cw * 1.35;
    final gap = cw * 0.18;

    // 3 cards in a row
    final positions = [
      Offset(cx - cw - gap, cy),
      Offset(cx, cy),
      Offset(cx + cw + gap, cy),
    ];
    final emojis = ['🦊', '🐸', '🦊'];

    // Phase 0–0.25: card1 flips open (shows 🦊)
    // Phase 0.25–0.50: card1 flips back down
    // Phase 0.50–0.75: card2 flips open (shows 🐸)
    // Phase 0.75–0.85: card2 flips back
    // Phase 0.85–1.0: card3 tapped → flips → 🦊 (match!)

    for (int i = 0; i < 3; i++) {
      bool faceUp = false;
      double scaleX = 1.0;
      bool glow = false;

      if (i == 0) {
        if (t < 0.125) {
          faceUp = false;
          scaleX = (1.0 - t / 0.125).clamp(0.0, 1.0);
        } else if (t < 0.25) {
          faceUp = true;
          scaleX = ((t - 0.125) / 0.125).clamp(0.0, 1.0);
        } else if (t < 0.375) {
          faceUp = true;
          scaleX = (1.0 - (t - 0.25) / 0.125).clamp(0.0, 1.0);
        } else {
          faceUp = false;
          scaleX = 1.0;
        }
      } else if (i == 1) {
        if (t < 0.50) {
          faceUp = false;
          scaleX = 1.0;
        } else if (t < 0.625) {
          faceUp = false;
          scaleX = (1.0 - (t - 0.50) / 0.125).clamp(0.0, 1.0);
        } else if (t < 0.75) {
          faceUp = true;
          scaleX = ((t - 0.625) / 0.125).clamp(0.0, 1.0);
        } else if (t < 0.875) {
          faceUp = true;
          scaleX = (1.0 - (t - 0.75) / 0.125).clamp(0.0, 1.0);
        } else {
          faceUp = false;
          scaleX = 1.0;
        }
      } else {
        // Card 3 (index 2) — tapped last, matches card 0 (🦊)
        if (t < 0.85) {
          faceUp = false;
          scaleX = 1.0;
        } else if (t < 0.925) {
          faceUp = false;
          scaleX = (1.0 - (t - 0.85) / 0.075).clamp(0.0, 1.0);
        } else {
          faceUp = true;
          scaleX = ((t - 0.925) / 0.075).clamp(0.0, 1.0);
          glow = t > 0.97;
        }
      }

      final rect = Rect.fromCenter(
        center: positions[i],
        width: cw,
        height: ch,
      );
      _drawCard(canvas, rect,
        faceUp: faceUp,
        emoji: emojis[i],
        scaleX: scaleX,
        glow: glow,
      );
    }

    // "REMEMBER!" label
    if (t > 0.38 && t < 0.55) {
      final labelAlpha = math.sin(((t - 0.38) / 0.17) * math.pi).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'REMEMBER!',
          style: TextStyle(
            color: _kBlue.withValues(alpha: labelAlpha * 0.90),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + ch / 2 + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _RememberPainter old) => old.t != t;
}
