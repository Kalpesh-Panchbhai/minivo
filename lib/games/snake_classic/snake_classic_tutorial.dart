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
          period: const Duration(seconds: 3),
          painter: (t) => _SnakeEatPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: "Don't bite yourself or hit the walls!",
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
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

void _drawSnakeSegments(
    Canvas canvas, List<Offset> centers, double segR) {
  if (centers.length < 2) {
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

  final n = centers.length;
  for (int i = 0; i < n - 1; i++) {
    final from = i == 0 ? centers[0] : Offset.lerp(centers[i - 1], centers[i], 0.5)!;
    final to = i == n - 2 ? centers.last : Offset.lerp(centers[i], centers[i + 1], 0.5)!;
    final ctl = centers[i];
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(ctl.dx, ctl.dy, to.dx, to.dy);
    canvas.drawPath(path, outer);
    canvas.drawPath(path, inner);
  }

  // Head
  final head = centers.first;
  canvas.drawCircle(head, segR * 0.95, Paint()..color = _kSnakeDark);
  canvas.drawCircle(head, segR * 0.68, Paint()..color = _kSnakeGreen);
  // Eyes
  final eyePaint = Paint()..color = Colors.white;
  final pupilPaint = Paint()..color = const Color(0xFF1B3A2A);
  canvas.drawCircle(Offset(head.dx - segR * 0.3, head.dy - segR * 0.3),
      segR * 0.22, eyePaint);
  canvas.drawCircle(Offset(head.dx + segR * 0.3, head.dy - segR * 0.3),
      segR * 0.22, eyePaint);
  canvas.drawCircle(Offset(head.dx - segR * 0.3, head.dy - segR * 0.3),
      segR * 0.11, pupilPaint);
  canvas.drawCircle(Offset(head.dx + segR * 0.3, head.dy - segR * 0.3),
      segR * 0.11, pupilPaint);
}

void _drawApple(Canvas canvas, Offset center, double r) {
  canvas.drawCircle(
    center, r * 1.1,
    Paint()
      ..color = _kFoodColor.withValues(alpha: 0.18)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
  );
  canvas.drawCircle(center, r, Paint()..color = _kFoodColor);
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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D2B1E),
    );
    _drawGrid(canvas, size);

    final cx = size.width / 2;
    final cy = size.height / 2;
    const segR = 9.0;

    // Short snake wiggling in centre
    final wiggle = math.sin(t * 2 * math.pi) * 4;
    final segments = [
      Offset(cx, cy),
      Offset(cx - segR * 2 + wiggle, cy),
      Offset(cx - segR * 4, cy - wiggle * 0.5),
      Offset(cx - segR * 6 + wiggle * 0.5, cy),
    ];
    _drawSnakeSegments(canvas, segments, segR);

    // Cycling arrow directions: 0=left 1=up 2=right 3=down
    final arrowIdx = (t * 4).floor() % 4;
    final arrowPhase = (t * 4) % 1.0;
    final arrowFade = arrowPhase < 0.7
        ? (arrowPhase / 0.35).clamp(0.0, 1.0)
        : ((1.0 - arrowPhase) / 0.3).clamp(0.0, 1.0);

    const arrowOffset = 46.0;
    const arrowLabels = ['←', '↑', '→', '↓'];
    final arrowPositions = [
      Offset(cx - arrowOffset, cy),
      Offset(cx, cy - arrowOffset),
      Offset(cx + arrowOffset, cy),
      Offset(cx, cy + arrowOffset),
    ];

    final labelStyle = TextStyle(
      color: _kSnakeGreen.withValues(alpha: arrowFade * 0.9),
      fontSize: 22,
      fontWeight: FontWeight.w900,
    );

    final tp = TextPainter(
      text: TextSpan(text: arrowLabels[arrowIdx], style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final pos = arrowPositions[arrowIdx];
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D2B1E),
    );
    _drawGrid(canvas, size);

    const segR = 9.0;
    final cy = size.height * 0.5;

    // Apple position (fixed right side)
    final appleX = size.width * 0.72;
    final appleOffset = Offset(appleX, cy);

    // Snake head moves from left toward apple
    final headX = size.width * 0.12 + t * (appleX - size.width * 0.12 - segR);
    final ate = headX >= appleX - segR * 1.2;

    // After eating, apple pops (scale 0 → 1.3 → 0 → reappear at new pos)
    if (!ate) {
      _drawApple(canvas, appleOffset, segR * 0.85);
    } else {
      // Pop animation after eating
      final popT = ((headX - (appleX - segR * 1.2)) / (segR * 2)).clamp(0.0, 1.0);
      final popScale = popT < 0.5
          ? (1.0 + popT * 0.6)
          : (1.6 - (popT - 0.5) * 3.2).clamp(0.0, 1.6);
      if (popScale > 0) {
        _drawApple(canvas, appleOffset, segR * 0.85 * popScale);
      }
    }

    // Body grows with 3 + extra segments when ate
    final baseSegments = 3;
    final extraSegments = ate ? 1 : 0;
    final totalSegments = baseSegments + extraSegments;

    final centers = <Offset>[
      for (int i = 0; i < totalSegments; i++)
        Offset(headX - i * segR * 2, cy),
    ];
    _drawSnakeSegments(canvas, centers, segR);
  }

  @override
  bool shouldRepaint(covariant _SnakeEatPainter old) => old.t != t;
}

// ── Step 3: Snake near wall with danger flash ───────────────────────────────

class _SnakeDangerPainter extends CustomPainter {
  final double t;
  const _SnakeDangerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D2B1E),
    );
    _drawGrid(canvas, size);

    const segR = 9.0;
    const padding = 4.0;

    // Snake coiled on left, head moving right toward wall
    final headX = size.width * 0.30 + t * (size.width * 0.62);
    final headY = size.height * 0.45;

    final centers = [
      Offset(headX, headY),
      Offset(headX - segR * 2, headY),
      Offset(headX - segR * 4, headY),
      Offset(headX - segR * 4, headY + segR * 2),
      Offset(headX - segR * 2, headY + segR * 2),
    ];
    _drawSnakeSegments(canvas, centers, segR);

    // Wall highlight (right edge)
    final wallPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.55)
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(size.width - padding, 0),
      Offset(size.width - padding, size.height),
      wallPaint,
    );

    // Flash when reaching wall
    if (t > 0.78) {
      final flashT = ((t - 0.78) / 0.22).clamp(0.0, 1.0);
      final alpha = math.sin(flashT * math.pi) * 0.55;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.red.withValues(alpha: alpha),
      );
    }

    // Warning sign near wall
    final warnAlpha = (math.sin(t * 2 * math.pi * 2) * 0.5 + 0.5) * 0.9;
    final tp = TextPainter(
      text: TextSpan(
        text: '⚠',
        style: TextStyle(
          fontSize: 22,
          color: Colors.orange.withValues(alpha: warnAlpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(size.width - tp.width - 10, size.height * 0.10));
  }

  @override
  bool shouldRepaint(covariant _SnakeDangerPainter old) => old.t != t;
}
