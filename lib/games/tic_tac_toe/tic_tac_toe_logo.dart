import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildTicTacToeLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Tic Tac Toe',
      bg: const [Color(0xFF581C87), Color(0xFF3B0764)],
      accent: const Color(0xFFC084FC),
      art: _ticTacToeArt,
    );

void _ticTacToeArt(Canvas canvas, Rect zone) {
  final s = zone.width;
  final cell = s / 3;
  final inset = cell * 0.10;

  final gridPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.90)
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.06
    ..strokeCap = StrokeCap.round;

  for (int i = 1; i < 3; i++) {
    final x = zone.left + i * cell;
    canvas.drawLine(
        Offset(x, zone.top + inset), Offset(x, zone.bottom - inset), gridPaint);
    final y = zone.top + i * cell;
    canvas.drawLine(
        Offset(zone.left + inset, y), Offset(zone.right - inset, y), gridPaint);
  }

  Rect cellRect(int r, int c) =>
      Rect.fromLTWH(zone.left + c * cell, zone.top + r * cell, cell, cell);

  void drawX(int r, int c, Color color) {
    final cr = cellRect(r, c);
    final pad = cell * 0.26;
    final xPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cr.left + pad, cr.top + pad),
        Offset(cr.right - pad, cr.bottom - pad), xPaint);
    canvas.drawLine(Offset(cr.right - pad, cr.top + pad),
        Offset(cr.left + pad, cr.bottom - pad), xPaint);
  }

  void drawO(int r, int c, Color color) {
    final cr = cellRect(r, c);
    canvas.drawCircle(
      cr.center,
      cell * 0.26,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.15,
    );
  }

  drawX(0, 0, const Color(0xFFD946EF));
  drawO(1, 1, const Color(0xFF67E8F9));
  drawX(2, 2, const Color(0xFFD946EF));
}
