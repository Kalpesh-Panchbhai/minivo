import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/animated_background.dart';
import '../shared/living_icons_group4.dart';

Widget buildDotsAndBoxesLogo(double size) =>
    buildDotsAndBoxesLivingLogo(size);

const Color _kP1Color = Color(0xFF4DABF7);
const Color _kP2Color = Color(0xFFFF6B6B);

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
