import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildColorConnectLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Color Connect',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      art: _colorConnectArt,
    );

void _colorConnectArt(Canvas canvas, Rect zone) {
  final cx = zone.center.dx;
  final cy = zone.center.dy;
  final dotR = zone.width * 0.065;
  final lineW = zone.width * 0.045;
  final gridW = zone.width * 0.72;
  final gridH = zone.height * 0.72;
  final left = cx - gridW / 2;
  final top = cy - gridH / 2;

  final gridPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.06)
    ..strokeWidth = zone.width * 0.008;
  const gridN = 5;
  final stepX = gridW / (gridN - 1);
  final stepY = gridH / (gridN - 1);
  for (int i = 0; i < gridN; i++) {
    canvas.drawLine(
      Offset(left, top + i * stepY),
      Offset(left + gridW, top + i * stepY),
      gridPaint,
    );
    canvas.drawLine(
      Offset(left + i * stepX, top),
      Offset(left + i * stepX, top + gridH),
      gridPaint,
    );
  }

  void drawPair(
    Offset a,
    Offset b,
    Offset ctrlA,
    Offset ctrlB,
    Color color,
  ) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(ctrlA.dx, ctrlA.dy, ctrlB.dx, ctrlB.dy, b.dx, b.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineW
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.70),
    );
    canvas.drawCircle(a, dotR, Paint()..color = color);
    canvas.drawCircle(b, dotR, Paint()..color = color);
    canvas.drawCircle(
      a,
      dotR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = zone.width * 0.012,
    );
    canvas.drawCircle(
      b,
      dotR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = zone.width * 0.012,
    );
  }

  const red = Color(0xFFEF4444);
  const blue = Color(0xFF3B82F6);
  const green = Color(0xFF22C55E);

  final rA = Offset(left + stepX * 0, top + stepY * 0);
  final rB = Offset(left + stepX * 2, top + stepY * 2);
  drawPair(
    rA,
    rB,
    Offset(left + stepX * 0, top + stepY * 2),
    Offset(left + stepX * 2, top + stepY * 0),
    red,
  );

  final bA = Offset(left + stepX * 4, top + stepY * 0);
  final bB = Offset(left + stepX * 4, top + stepY * 3);
  drawPair(
    bA,
    bB,
    Offset(left + stepX * 3, top + stepY * 1),
    Offset(left + stepX * 3, top + stepY * 2),
    blue,
  );

  final gA = Offset(left + stepX * 0, top + stepY * 4);
  final gB = Offset(left + stepX * 3, top + stepY * 4);
  drawPair(
    gA,
    gB,
    Offset(left + stepX * 1, top + stepY * 3),
    Offset(left + stepX * 2, top + stepY * 3),
    green,
  );
}
