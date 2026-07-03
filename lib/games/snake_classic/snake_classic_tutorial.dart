import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

// ── Public API ──────────────────────────────────────────────────────────────

List<GameHowToPlayStep> snakeClassicSteps() => [
      GameHowToPlayStep(
        text: 'Swipe left, right, up or down to steer',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _SnakeSteerPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Eat the apples to grow and score',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2500),
          painter: (t) => _SnakeEatPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: "Don't hit the walls or yourself — game over!",
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _SnakeDangerPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

// ── Shared drawing helpers ──────────────────────────────────────────────────

const _kSnakeGreen = Color(0xFF20C997);
const _kSnakeDark = Color(0xFF099268);
const _kFoodColor = Color(0xFFEF4444);

void _drawGrid(Canvas canvas, Size size) {
  final paint = Paint()
    ..color = _kSnakeGreen.withValues(alpha: 0.06)
    ..strokeWidth = 1;
  const cells = 8;
  final cw = size.width / cells;
  final ch = size.height / cells;
  for (int i = 1; i < cells; i++) {
    canvas.drawLine(Offset(i * cw, 0), Offset(i * cw, size.height), paint);
    canvas.drawLine(Offset(0, i * ch), Offset(size.width, i * ch), paint);
  }
}

/// Draws the snake as a smooth pill/tube along [centers].
/// All centers must lie in a straight line for a straight snake.
void _drawSnakeSegments(Canvas canvas, List<Offset> centers, double segR) {
  if (centers.isEmpty) return;
  if (centers.length == 1) {
    canvas.drawCircle(centers.first, segR, Paint()..color = _kSnakeDark);
    return;
  }

  final outer = Paint()
    ..color = _kSnakeDark
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = segR * 1.85;
  final inner = Paint()
    ..color = _kSnakeGreen
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = segR * 1.3;

  // Draw as a single polyline so straight segments look perfectly straight.
  final path = Path()..moveTo(centers.last.dx, centers.last.dy);
  for (int i = centers.length - 2; i >= 0; i--) {
    path.lineTo(centers[i].dx, centers[i].dy);
  }
  canvas.drawPath(path, outer);
  canvas.drawPath(path, inner);

  // Head
  final head = centers.first;
  canvas.drawCircle(head, segR * 0.95, Paint()..color = _kSnakeDark);
  canvas.drawCircle(head, segR * 0.68, Paint()..color = _kSnakeGreen);
  // Eyes (offset upward from head centre for horizontal snake)
  _drawEyes(canvas, head, segR, horizontal: true);
}

void _drawEyes(Canvas canvas, Offset head, double segR, {bool horizontal = true}) {
  final eyePaint = Paint()..color = Colors.white;
  final pupilPaint = Paint()..color = const Color(0xFF1B3A2A);
  final dy = horizontal ? -segR * 0.30 : 0.0;
  final dx = horizontal ? 0.0 : -segR * 0.30;
  canvas.drawCircle(Offset(head.dx - segR * 0.30 + dx, head.dy + dy - segR * 0.0), segR * 0.24, eyePaint);
  canvas.drawCircle(Offset(head.dx + segR * 0.30 + dx, head.dy + dy + segR * 0.0), segR * 0.24, eyePaint);
  canvas.drawCircle(Offset(head.dx - segR * 0.30 + dx, head.dy + dy - segR * 0.0), segR * 0.12, pupilPaint);
  canvas.drawCircle(Offset(head.dx + segR * 0.30 + dx, head.dy + dy + segR * 0.0), segR * 0.12, pupilPaint);
}

void _drawApple(Canvas canvas, Offset center, double r) {
  // Glow
  canvas.drawCircle(
    center, r * 1.2,
    Paint()
      ..color = _kFoodColor.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
  );
  canvas.drawCircle(center, r, Paint()..color = _kFoodColor);
  // Highlight
  canvas.drawCircle(
    Offset(center.dx - r * 0.28, center.dy - r * 0.28),
    r * 0.28,
    Paint()..color = const Color(0xFFFFB4B4).withValues(alpha: 0.85),
  );
  // Leaf
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(center.dx + r * 0.22, center.dy - r * 0.88),
      width: r * 0.50,
      height: r * 0.25,
    ),
    Paint()..color = const Color(0xFF22C55E),
  );
}

// ── Step 1: Steer — directional arrows cycle around the snake ───────────────

class _SnakeSteerPainter extends CustomPainter {
  final double t;
  const _SnakeSteerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0D2B1E));
    _drawGrid(canvas, size);

    final cx = size.width / 2;
    final cy = size.height / 2;
    const segR = 9.0;

    // Short snake — 4 segments in a straight horizontal line with a tiny head bob
    final bob = math.sin(t * 2 * math.pi) * 2;
    final segments = [
      Offset(cx, cy + bob),
      Offset(cx - segR * 2, cy + bob),
      Offset(cx - segR * 4, cy + bob),
      Offset(cx - segR * 6, cy + bob),
    ];
    _drawSnakeSegments(canvas, segments, segR);

    // Arrow cycles ← ↑ → ↓ one at a time with fade in/out
    final arrowIdx = (t * 4).floor() % 4;
    final arrowPhase = (t * 4) % 1.0;
    final arrowAlpha = arrowPhase < 0.15
        ? arrowPhase / 0.15
        : arrowPhase > 0.75
            ? (1 - (arrowPhase - 0.75) / 0.25).clamp(0.0, 1.0)
            : 1.0;

    const arrowOffset = 48.0;
    const arrowLabels = ['←', '↑', '→', '↓'];
    const arrowPositions = [
      Offset(-arrowOffset, 0),
      Offset(0, -arrowOffset),
      Offset(arrowOffset, 0),
      Offset(0, arrowOffset),
    ];

    final aPos = Offset(cx, cy) + arrowPositions[arrowIdx];
    final tp = TextPainter(
      text: TextSpan(
        text: arrowLabels[arrowIdx],
        style: TextStyle(
          color: _kSnakeGreen.withValues(alpha: arrowAlpha * 0.95),
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(aPos.dx - tp.width / 2, aPos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _SnakeSteerPainter old) => old.t != t;
}

// ── Step 2: Snake eats apple and grows ─────────────────────────────────────

class _SnakeEatPainter extends CustomPainter {
  final double t;
  const _SnakeEatPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0D2B1E));
    _drawGrid(canvas, size);

    const segR = 9.0;
    final cy = size.height * 0.50;
    final appleX = size.width * 0.76;

    // Phase 0–0.55: snake moves right toward apple
    // Phase 0.55–0.75: eat pop + score
    // Phase 0.75–1.0: snake shown longer, fades
    final phase = t;

    if (phase < 0.55) {
      // Snake moves from left toward apple
      final headX = size.width * 0.12 + (phase / 0.55) * (appleX - size.width * 0.12 - segR * 1.2);
      final bodyCount = 3;
      final centers = List.generate(
        bodyCount,
        (i) => Offset(headX - i * segR * 2, cy),
      );
      _drawSnakeSegments(canvas, centers, segR);
      _drawApple(canvas, Offset(appleX, cy), segR * 0.9);
    } else if (phase < 0.75) {
      // Eat animation: apple pops, score +1
      final popT = (phase - 0.55) / 0.20;
      final headX = appleX - segR * 0.8;
      final bodyCount = 3;
      final centers = List.generate(
        bodyCount,
        (i) => Offset(headX - i * segR * 2, cy),
      );
      _drawSnakeSegments(canvas, centers, segR);

      // Apple pop (scale then vanish)
      final popScale = math.sin(popT * math.pi);
      if (popScale > 0) {
        _drawApple(canvas, Offset(appleX, cy), segR * 0.9 * popScale);
      }

      // Particle burst
      if (popT > 0.1) {
        for (int i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          final dist = popT * segR * 2.5;
          canvas.drawCircle(
            Offset(appleX + math.cos(angle) * dist, cy + math.sin(angle) * dist),
            3.5 * (1 - popT).clamp(0.0, 1.0),
            Paint()..color = _kFoodColor.withValues(alpha: (1 - popT).clamp(0.0, 1.0)),
          );
        }
      }

      // +1 score
      final scoreAlpha = math.sin(popT * math.pi).clamp(0.0, 1.0);
      final scoreRise = popT * 14;
      final tp = TextPainter(
        text: TextSpan(
          text: '+5',
          style: TextStyle(
            color: Colors.white.withValues(alpha: scoreAlpha),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(appleX - tp.width / 2, cy - 20 - scoreRise));
    } else {
      // Show grown snake + new apple spawning
      final fadeT = (phase - 0.75) / 0.25;
      final alpha = (1 - fadeT * 0.5).clamp(0.0, 1.0);
      final headX = appleX;
      final bodyCount = 5; // grown by 2
      final centers = List.generate(
        bodyCount,
        (i) => Offset(headX - i * segR * 2, cy),
      );
      // Draw with opacity fade
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: alpha));
      _drawSnakeSegments(canvas, centers, segR);
      canvas.restore();

      // New apple appears further right
      final newAppleX = math.min(size.width * 0.92, appleX + segR * 4);
      final newAppleAlpha = (fadeT * 2).clamp(0.0, 1.0);
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: newAppleAlpha));
      _drawApple(canvas, Offset(newAppleX, cy), segR * 0.9);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SnakeEatPainter old) => old.t != t;
}

// ── Step 3: Snake hits the right wall — straight line, clear crash ──────────
//
// The snake is a perfectly straight horizontal line of segments moving right.
// When the head reaches the right wall it stops, flashes red, and shows GAME OVER.

class _SnakeDangerPainter extends CustomPainter {
  final double t;
  const _SnakeDangerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0D2B1E));
    _drawGrid(canvas, size);

    const segR = 9.0;
    const segSpacing = segR * 2.2; // gap between segment centres
    const numSegs = 5;
    const wallPad = 4.0;
    final wallX = size.width - wallPad;
    final cy = size.height * 0.50;

    // Head travels from left into the wall; clamp at wallX - segR
    final startX = size.width * 0.28;
    final rawHeadX = startX + t * (wallX - startX);
    final impactX = wallX - segR * 1.05; // where head stops
    final crashed = rawHeadX >= impactX;
    final headX = crashed ? impactX : rawHeadX;

    // All body segments behind the head in a perfectly straight horizontal line
    final centers = List.generate(
      numSegs,
      (i) => Offset(headX - i * segSpacing, cy),
    );
    _drawSnakeSegments(canvas, centers, segR);

    // Right wall — red line
    canvas.drawLine(
      Offset(wallX, 0),
      Offset(wallX, size.height),
      Paint()
        ..color = Colors.red.withValues(alpha: 0.70)
        ..strokeWidth = 3.5,
    );

    // Crash effects
    if (crashed) {
      final tImpact = (impactX - startX) / (wallX - startX);
      final localT = ((t - tImpact) / (1 - tImpact)).clamp(0.0, 1.0);

      // Screen flash
      final flashAlpha = math.sin(localT * math.pi) * 0.60;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.red.withValues(alpha: flashAlpha),
      );

      // X mark at impact point
      if (localT > 0.05) {
        final xAlpha = math.sin(localT * math.pi).clamp(0.0, 1.0);
        final xPaint = Paint()
          ..color = Colors.white.withValues(alpha: xAlpha)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        const xSz = 12.0;
        canvas.drawLine(Offset(headX - xSz, cy - xSz), Offset(headX + xSz, cy + xSz), xPaint);
        canvas.drawLine(Offset(headX + xSz, cy - xSz), Offset(headX - xSz, cy + xSz), xPaint);
      }

      // GAME OVER label
      if (localT > 0.35) {
        final textAlpha = ((localT - 0.35) / 0.35).clamp(0.0, 1.0);
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
  bool shouldRepaint(covariant _SnakeDangerPainter old) => old.t != t;
}
