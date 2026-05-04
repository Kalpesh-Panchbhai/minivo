import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

// ── Public API ──────────────────────────────────────────────────────────────

List<GameHowToPlayStep> flappyTapSteps() => [
      GameHowToPlayStep(
        text: 'Tap the screen to flap upward',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _FlappyBobPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Fly through the gap between the pipes',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _FlappyGapPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: "Don't touch the pipes or the ground!",
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _FlappyDangerPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

// ── Shared drawing helpers ──────────────────────────────────────────────────

void _drawSky(Canvas canvas, Size size) {
  final rect = Rect.fromLTWH(0, 0, size.width, size.height);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4A9FD4), Color(0xFF71B9E8), Color(0xFFADD8F0)],
        stops: [0.0, 0.5, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect),
  );
}

void _drawGround(Canvas canvas, Size size) {
  final groundTop = size.height - 20;
  canvas.drawRect(
    Rect.fromLTRB(0, groundTop, size.width, size.height),
    Paint()..color = const Color(0xFF8B6914),
  );
  canvas.drawRect(
    Rect.fromLTRB(0, groundTop, size.width, groundTop + 6),
    Paint()..color = const Color(0xFF5CB85C),
  );
}

void _drawBird(Canvas canvas, double cx, double cy, double wingPhase,
    {double scale = 1.0}) {
  const r = 14.0;
  final sr = r * scale;

  canvas.save();
  canvas.translate(cx, cy);

  // Body
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: sr * 2.2, height: sr * 2.0),
    Paint()..color = const Color(0xFFFFD700),
  );
  // Belly
  canvas.drawOval(
    Rect.fromCenter(center: Offset(sr * 0.15, sr * 0.2), width: sr * 1.4, height: sr * 1.2),
    Paint()..color = const Color(0xFFFFF0A0),
  );
  // Wing
  final wingY = -sr * 0.28 - sr * 0.55 * math.sin(wingPhase);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(-sr * 0.28, wingY), width: sr * 1.4, height: sr * 0.7),
    Paint()..color = const Color(0xFFE6B800),
  );
  // Eye white
  canvas.drawCircle(Offset(sr * 0.5, -sr * 0.25), sr * 0.32, Paint()..color = Colors.white);
  // Pupil
  canvas.drawCircle(Offset(sr * 0.55, -sr * 0.22), sr * 0.16, Paint()..color = const Color(0xFF1A1A2E));
  // Eye shine
  canvas.drawCircle(Offset(sr * 0.60, -sr * 0.30), sr * 0.07, Paint()..color = Colors.white);
  // Beak
  final beak = Path()
    ..moveTo(sr * 0.7, 0)
    ..lineTo(sr * 1.3, -sr * 0.12)
    ..lineTo(sr * 1.3, sr * 0.18)
    ..close();
  canvas.drawPath(beak, Paint()..color = const Color(0xFFFF8C00));

  canvas.restore();
}

void _drawPipePair(Canvas canvas, double pipeX, double gapCenterY,
    double gapHeight, Size size, double pipeW) {
  final gapTop = gapCenterY - gapHeight / 2;
  final gapBottom = gapCenterY + gapHeight / 2;
  const capExtra = 5.0;
  const capH = 14.0;
  final groundTop = size.height - 20;

  final bodyRect = Rect.fromLTRB(pipeX, 0, pipeX + pipeW, size.height);
  final bodyPaint = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFF66BB6A), Color(0xFF4CAF50), Color(0xFF2E7D32)],
      stops: [0.0, 0.45, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(bodyRect);

  // Top pipe body
  if (gapTop > 0) {
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(pipeX, 0, pipeX + pipeW, gapTop),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      ),
      bodyPaint,
    );
    // Top pipe cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(pipeX - capExtra, gapTop - capH, pipeX + pipeW + capExtra, gapTop),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF388E3C),
    );
  }

  // Bottom pipe body
  if (gapBottom < groundTop) {
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(pipeX, gapBottom, pipeX + pipeW, groundTop),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      ),
      bodyPaint,
    );
    // Bottom pipe cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(pipeX - capExtra, gapBottom, pipeX + pipeW + capExtra, gapBottom + capH),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF388E3C),
    );
  }
}

// ── Step 1: Bird bobbing with TAP ripple ────────────────────────────────────

class _FlappyBobPainter extends CustomPainter {
  final double t;
  const _FlappyBobPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawGround(canvas, size);

    final cx = size.width * 0.40;
    final baseY = size.height * 0.42;
    final bobY = baseY + math.sin(t * 2 * math.pi) * 10;
    final wingPhase = t * 2 * math.pi * 2;

    // TAP ripple: expands and fades over 1 cycle
    final rippleRadius = 14 + t * 36;
    final rippleAlpha = (1 - t).clamp(0.0, 1.0) * 0.55;
    canvas.drawCircle(
      Offset(cx, bobY),
      rippleRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: rippleAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    _drawBird(canvas, cx, bobY, wingPhase);

    // "TAP" text label
    final fadeIn = (math.sin(t * 2 * math.pi * 0.5) + 1) / 2;
    final tp = TextPainter(
      text: TextSpan(
        text: 'TAP',
        style: TextStyle(
          color: Colors.white.withValues(alpha: fadeIn * 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, bobY + 26));
  }

  @override
  bool shouldRepaint(covariant _FlappyBobPainter old) => old.t != t;
}

// ── Step 2: Bird flying cleanly through the pipe gap ───────────────────────
//
// Key constraint: bird must be at gapCenterY exactly when birdX == pipeX.
// We place the pipe at the t=0.50 x-position so the sine arc peak aligns.

class _FlappyGapPainter extends CustomPainter {
  final double t;
  const _FlappyGapPainter(this.t);

  static const _gapH = 58.0;
  static const _pipeW = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);

    // Pipe is centred horizontally (at x = 0.50 * width).
    // Bird travels from left edge (x≈10) to right edge (x≈170).
    // At t=0.50 the bird's x == pipe centre — the sine arc also peaks there.
    final pipeX = size.width * 0.50 - _pipeW / 2;
    final gapCenterY = size.height * 0.40;

    _drawPipePair(canvas, pipeX, gapCenterY, _gapH, size, _pipeW);
    _drawGround(canvas, size);

    // Bird x: left edge → right edge
    final startX = size.width * 0.06;
    final birdX = startX + t * (size.width * 0.88);

    // Bird y: starts below gap, rises to gapCenterY at t=0.5, then descends.
    // sin(t * π) peaks at t=0.5 → birdY = gapCenterY at pipe centre.
    final startY = size.height * 0.68;
    final birdY = startY - (startY - gapCenterY) * math.sin(t * math.pi);

    final wingPhase = t * 2 * math.pi * 3;
    _drawBird(canvas, birdX, birdY, wingPhase);

    // Green tick when bird has passed through the gap (t 0.55 → 0.80)
    if (t > 0.55 && t < 0.85) {
      final fadeT = (t - 0.55) / 0.30;
      final alpha = math.sin(fadeT * math.pi).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '✓',
          style: TextStyle(
            color: const Color(0xFF4CAF50).withValues(alpha: alpha),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(pipeX + _pipeW + 6, gapCenterY - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlappyGapPainter old) => old.t != t;
}

// ── Step 3: Bird flying into pipe — danger flash + game over ────────────────

class _FlappyDangerPainter extends CustomPainter {
  final double t;
  const _FlappyDangerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);

    const pipeW = 34.0;
    const gapH = 52.0;
    // Gap is deliberately HIGH so the bird (flying mid-height) misses it.
    final pipeX = size.width * 0.62;
    final gapCenterY = size.height * 0.18; // gap near top — bird will hit body

    _drawPipePair(canvas, pipeX, gapCenterY, gapH, size, pipeW);
    _drawGround(canvas, size);

    // Bird moves from left toward the pipe, stops at impact (t > 0.72).
    final rawX = size.width * 0.08 + t * (pipeX - size.width * 0.08 + pipeW * 0.5);
    final birdX = t < 0.72 ? rawX : (pipeX - 14.0); // clamp at pipe face
    final birdY = size.height * 0.48; // stays mid-height — hits pipe body
    final wingPhase = t * 2 * math.pi * 2;

    _drawBird(canvas, birdX, birdY, wingPhase);

    // Impact effects after t=0.72
    if (t > 0.72) {
      final flashT = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
      // Screen flash
      final flashAlpha = math.sin(flashT * math.pi) * 0.55;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.red.withValues(alpha: flashAlpha),
      );

      // X mark over the bird
      if (flashT > 0.15) {
        final xAlpha = ((flashT - 0.15) / 0.45).clamp(0.0, 1.0);
        final xPaint = Paint()
          ..color = Colors.white.withValues(alpha: xAlpha * 0.95)
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round;
        const xSize = 13.0;
        canvas.drawLine(Offset(birdX - xSize, birdY - xSize), Offset(birdX + xSize, birdY + xSize), xPaint);
        canvas.drawLine(Offset(birdX + xSize, birdY - xSize), Offset(birdX - xSize, birdY + xSize), xPaint);
      }

      // "GAME OVER" text
      if (flashT > 0.40) {
        final textAlpha = ((flashT - 0.40) / 0.40).clamp(0.0, 1.0);
        final tp = TextPainter(
          text: TextSpan(
            text: 'GAME OVER',
            style: TextStyle(
              color: Colors.white.withValues(alpha: textAlpha),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height * 0.72));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlappyDangerPainter old) => old.t != t;
}
