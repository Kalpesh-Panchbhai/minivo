import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildTangoLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Tango',
      bg: const [Color(0xFF78350F), Color(0xFF451A03)],
      accent: const Color(0xFFFBBF24),
      art: _tangoArt,
    );

void _tangoArt(Canvas canvas, Rect zone) {
  final cell = zone.width / 4;
  final left = zone.left;
  final top = zone.top + zone.height * 0.05;
  final gridW = cell * 4;
  final gridH = cell * 4;

  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 4; c++) {
      final x = left + c * cell;
      final y = top + r * cell;
      final isPrefilled = (r == 0 && c == 1) || (r == 2 && c == 3);
      canvas.drawRect(
        Rect.fromLTWH(x, y, cell, cell),
        Paint()
          ..color = isPrefilled
              ? const Color(0xFFF5ECD7)
              : const Color(0xFFFFF8E7),
      );
    }
  }

  final gridLine = Paint()
    ..color = const Color(0xFFD4C5A0)
    ..strokeWidth = cell * 0.04;
  for (int i = 1; i < 4; i++) {
    final y = top + i * cell;
    canvas.drawLine(Offset(left, y), Offset(left + gridW, y), gridLine);
    final x = left + i * cell;
    canvas.drawLine(Offset(x, top), Offset(x, top + gridH), gridLine);
  }

  final outerBorder = Paint()
    ..color = const Color(0xFF8B7355)
    ..style = PaintingStyle.stroke
    ..strokeWidth = cell * 0.10;
  canvas.drawRect(Rect.fromLTWH(left, top, gridW, gridH), outerBorder);

  void drawSun(double cx, double cy, double r) {
    const rayCount = 8;
    final rayPaint = Paint()
      ..color = const Color(0xFFFFA726)
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < rayCount; i++) {
      final angle = i * 2 * math.pi / rayCount;
      final x1 = cx + r * 1.15 * math.cos(angle);
      final y1 = cy + r * 1.15 * math.sin(angle);
      final x2 = cx + r * 1.55 * math.cos(angle);
      final y2 = cy + r * 1.55 * math.sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), rayPaint);
    }
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFFFFA726),
    );
    canvas.drawCircle(
      Offset(cx - r * 0.25, cy - r * 0.25),
      r * 0.35,
      Paint()..color = const Color(0xFFFFCC80).withValues(alpha: 0.6),
    );
  }

  void drawMoon(double cx, double cy, double r) {
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFF7C4DFF),
    );
    canvas.drawCircle(
      Offset(cx + r * 0.38, cy - r * 0.22),
      r * 0.68,
      Paint()..color = const Color(0xFFF5ECD7),
    );
  }

  final iconR = cell * 0.26;

  drawSun(left + 1.5 * cell, top + 0.5 * cell, iconR);
  drawSun(left + 0.5 * cell, top + 2.5 * cell, iconR);
  drawSun(left + 3.5 * cell, top + 2.5 * cell, iconR);

  drawMoon(left + 0.5 * cell, top + 0.5 * cell, iconR);
  drawMoon(left + 2.5 * cell, top + 1.5 * cell, iconR);
  drawMoon(left + 1.5 * cell, top + 3.5 * cell, iconR);

  void drawClue(double cx, double cy, String symbol) {
    final clueR = cell * 0.16;
    canvas.drawCircle(
      Offset(cx, cy),
      clueR,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      clueR,
      Paint()
        ..color = const Color(0xFF8B7355)
        ..style = PaintingStyle.stroke
        ..strokeWidth = clueR * 0.22,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: const Color(0xFF8B7355),
          fontSize: clueR * 1.4,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  drawClue(left + 1.0 * cell, top + 0.5 * cell, '=');
  drawClue(left + 2.5 * cell, top + 2.0 * cell, '\u00d7');
}
