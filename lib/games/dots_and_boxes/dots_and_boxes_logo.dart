import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/animated_background.dart';
import '../shared/game_logo_scaffold.dart';

const Color _kP1Color = Color(0xFF4DABF7);
const Color _kP2Color = Color(0xFFFF6B6B);

Widget buildDotsAndBoxesLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Dots & Boxes',
      bg: const [Color(0xFF1E40AF), Color(0xFF0B1E4D)],
      accent: const Color(0xFF60A5FA),
      art: _dotsAndBoxesArt,
    );

void _dotsAndBoxesArt(Canvas canvas, Rect zone) {
  // A 3x3 grid of dots, some connected by colored edges, with one completed
  // square filled with a translucent color.
  const n = 3; // dots per side
  final pad = zone.width * 0.10;
  final inner = zone.width - pad * 2;
  final step = inner / (n - 1);
  final ox = zone.left + pad;
  final oy = zone.top + pad;

  Offset dot(int r, int c) => Offset(ox + c * step, oy + r * step);

  // completed (top-left) square fill
  final fillRect = Rect.fromPoints(dot(0, 0), dot(1, 1));
  canvas.drawRRect(
    RRect.fromRectAndRadius(fillRect, Radius.circular(step * 0.12)),
    Paint()..color = const Color(0xFF60A5FA).withValues(alpha: 0.30),
  );

  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = step * 0.13
    ..strokeCap = StrokeCap.round;

  void line(int r1, int c1, int r2, int c2, Color color) {
    edge.color = color;
    canvas.drawLine(dot(r1, c1), dot(r2, c2), edge);
  }

  // four edges of the completed square (bright)
  const bright = Color(0xFFBFDBFE);
  line(0, 0, 0, 1, bright);
  line(0, 1, 1, 1, bright);
  line(1, 1, 1, 0, bright);
  line(1, 0, 0, 0, bright);

  // a few extra colored segments elsewhere on the grid
  line(0, 1, 0, 2, const Color(0xFFFBBF24));
  line(0, 2, 1, 2, const Color(0xFFFBBF24));
  line(1, 0, 2, 0, const Color(0xFF34D399));
  line(2, 1, 2, 2, const Color(0xFFF472B6));

  // dots on top
  final dotR = step * 0.14;
  final dotPaint = Paint()..color = Colors.white;
  final dotShadow = Paint()..color = Colors.black.withValues(alpha: 0.25);
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final p = dot(r, c);
      canvas.drawCircle(p.translate(0, dotR * 0.5), dotR, dotShadow);
      canvas.drawCircle(p, dotR, dotPaint);
      // specular highlight
      canvas.drawCircle(
        p.translate(-dotR * 0.28, -dotR * 0.30),
        dotR * 0.32,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }
  }
}

// ── Animated background painter for the picker screen ─────────────────────

class DotsAndBoxesBgPainter extends AnimatedBgPainter {
  const DotsAndBoxesBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = const Color(0xFF339AF0).withValues(alpha: 0.09)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF339AF0).withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    final boxPaint1 = Paint()
      ..color = _kP1Color.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final boxPaint2 = Paint()
      ..color = _kP2Color.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final clusters = [
      (0.08, 0.10, 22.0, 0.0, true),
      (0.82, 0.06, 18.0, 0.8, false),
      (0.15, 0.58, 15.0, 1.6, true),
      (0.88, 0.45, 20.0, 2.4, false),
      (0.05, 0.82, 17.0, 3.2, true),
      (0.72, 0.88, 14.0, 4.0, false),
      (0.50, 0.02, 12.0, 4.8, true),
      (0.40, 0.96, 16.0, 5.6, false),
    ];

    for (final (xRel, yRel, step, itemPhase, useP1) in clusters) {
      final bobY = math.sin(phase + itemPhase * 0.5) * (step * 0.20);
      final cx = w * xRel;
      final cy = h * yRel + bobY;
      final rot = math.sin(phase + itemPhase) * 0.10;

      canvas.save();
      canvas.translate(cx + step, cy + step);
      canvas.rotate(rot);
      canvas.translate(-(cx + step), -(cy + step));

      final bx = useP1 ? boxPaint1 : boxPaint2;
      canvas.drawRect(Rect.fromLTWH(cx, cy, step, step), bx);
      canvas.drawLine(Offset(cx, cy), Offset(cx + step, cy), linePaint);
      canvas.drawLine(
          Offset(cx + step, cy), Offset(cx + step, cy + step), linePaint);
      canvas.drawLine(
          Offset(cx + step, cy + step), Offset(cx, cy + step), linePaint);
      canvas.drawLine(Offset(cx, cy + step), Offset(cx, cy), linePaint);

      final dr = step * 0.14;
      for (final (dx, dy) in [
        (0.0, 0.0),
        (step, 0.0),
        (0.0, step),
        (step, step)
      ]) {
        canvas.drawCircle(Offset(cx + dx, cy + dy), dr, dotPaint);
      }

      canvas.restore();
    }
  }
}
