import 'dart:math' as math;

import 'package:flutter/material.dart';

Widget buildTapTapDashLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: ClipRect(
      child: CustomPaint(
        size: Size(size, size),
        painter: _TapTapDashLogoPainter(),
      ),
    ),
  );
}

class _TapTapDashLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    _drawPath(canvas, s);
    _drawRunner(canvas, s);
    _drawLabel(canvas, size);
  }

  void _drawPath(Canvas canvas, double s) {
    final pathPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.3)
      ..strokeWidth = s * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.1)
      ..strokeWidth = s * 0.18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final trail = Path();
    trail.moveTo(s * 0.15, s * 0.30);
    trail.lineTo(s * 0.45, s * 0.30);
    trail.lineTo(s * 0.45, s * 0.55);
    trail.lineTo(s * 0.70, s * 0.55);

    canvas.drawPath(trail, glowPaint);
    canvas.drawPath(trail, pathPaint);

    final activePaint = Paint()
      ..color = const Color(0xFF00D4FF)
      ..strokeWidth = s * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final active = Path();
    active.moveTo(s * 0.15, s * 0.30);
    active.lineTo(s * 0.35, s * 0.30);

    canvas.drawPath(active, activePaint);
  }

  void _drawRunner(Canvas canvas, double s) {
    final cx = s * 0.35;
    final cy = s * 0.30;
    final r = s * 0.05;

    canvas.drawCircle(
      Offset(cx, cy),
      r * 2.5,
      Paint()..color = const Color(0xFF00D4FF).withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFF00D4FF),
    );

    final sparkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + math.pi / 4;
      final inner = r * 1.8;
      final outer = r * 2.8;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * inner, cy + math.sin(angle) * inner),
        Offset(cx + math.cos(angle) * outer, cy + math.sin(angle) * outer),
        sparkPaint,
      );
    }
  }

  void _drawLabel(Canvas canvas, Size size) {
    final fontSize = size.width * 0.10;
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'TAP TAP DASH',
        style: TextStyle(
          color: const Color(0xFF00D4FF),
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height - textPainter.height - size.height * 0.04,
      ),
    );
  }

  @override
  bool shouldRepaint(_TapTapDashLogoPainter old) => false;
}
