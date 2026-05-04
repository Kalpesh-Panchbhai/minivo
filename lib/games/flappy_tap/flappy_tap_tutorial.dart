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
          period: const Duration(seconds: 3),
          painter: (t) => _FlappyGapPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: "Don't touch the pipes or the ground!",
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
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
  canvas.drawCircle(
    Offset(sr * 0.5, -sr * 0.25), sr * 0.32, Paint()..color = Colors.white,
  );
  // Pupil
  canvas.drawCircle(
    Offset(sr * 0.55, -sr * 0.22), sr * 0.16, Paint()..color = const Color(0xFF1A1A2E),
  );
  // Eye shine
  canvas.drawCircle(
    Offset(sr * 0.60, -sr * 0.30), sr * 0.07, Paint()..color = Colors.white,
  );
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

  final bodyRect = Rect.fromLTRB(pipeX, 0, pipeX + pipeW, size.height);
  final bodyPaint = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFF66BB6A), Color(0xFF4CAF50), Color(0xFF2E7D32)],
      stops: [0.0, 0.45, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(bodyRect);

  // Top pipe
  if (gapTop > 0) {
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(pipeX, 0, pipeX + pipeW, gapTop),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(pipeX - capExtra, gapTop - capH, pipeX + pipeW + capExtra, gapTop),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF388E3C),
    );
  }

  // Bottom pipe
  if (gapBottom < size.height - 20) {
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(pipeX, gapBottom, pipeX + pipeW, size.height - 20),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      ),
      bodyPaint,
    );
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

    final cx = size.width * 0.38;
    final baseY = size.height * 0.45;
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

// ── Step 2: Bird flying through gap ────────────────────────────────────────

class _FlappyGapPainter extends CustomPainter {
  final double t;
  const _FlappyGapPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);

    const pipeW = 32.0;
    const gapH = 54.0;
    final gapCenterY = size.height * 0.42;
    final pipeX = size.width * 0.62;

    _drawPipePair(canvas, pipeX, gapCenterY, gapH, size, pipeW);
    _drawGround(canvas, size);

    // Bird moves from left edge to just past pipe then resets
    final birdX = size.width * 0.08 + t * (size.width * 0.72);
    final wingPhase = t * 2 * math.pi * 3;

    // Slight arc through gap
    final birdY = size.height * 0.55 +
        math.sin(t * math.pi) * -(gapCenterY - size.height * 0.55 + 5);

    _drawBird(canvas, birdX, birdY, wingPhase);
  }

  @override
  bool shouldRepaint(covariant _FlappyGapPainter old) => old.t != t;
}

// ── Step 3: Bird hitting pipe — danger flash ────────────────────────────────

class _FlappyDangerPainter extends CustomPainter {
  final double t;
  const _FlappyDangerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);

    const pipeW = 32.0;
    const gapH = 50.0;
    final pipeX = size.width * 0.6;
    final gapCenterY = size.height * 0.30; // gap is high — bird will miss it

    _drawPipePair(canvas, pipeX, gapCenterY, gapH, size, pipeW);
    _drawGround(canvas, size);

    // Bird moves toward pipe then resets
    final birdX = size.width * 0.08 + t * (pipeX - size.width * 0.08 + 10);
    final birdY = size.height * 0.52; // stays mid-height, hits pipe body
    final wingPhase = t * 2 * math.pi * 2;

    _drawBird(canvas, birdX, birdY, wingPhase);

    // Red flash when bird reaches pipe (t > 0.75)
    if (t > 0.72) {
      final flashT = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
      // Peak at 0.5, fade by 1.0
      final alpha = math.sin(flashT * math.pi) * 0.60;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.red.withValues(alpha: alpha),
      );

      // X mark
      if (flashT > 0.2) {
        final xAlpha = ((flashT - 0.2) / 0.8).clamp(0.0, 1.0);
        final xPaint = Paint()
          ..color = Colors.white.withValues(alpha: xAlpha)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        const xSize = 14.0;
        canvas.drawLine(
          Offset(birdX - xSize, birdY - xSize),
          Offset(birdX + xSize, birdY + xSize),
          xPaint,
        );
        canvas.drawLine(
          Offset(birdX + xSize, birdY - xSize),
          Offset(birdX - xSize, birdY + xSize),
          xPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlappyDangerPainter old) => old.t != t;
}
