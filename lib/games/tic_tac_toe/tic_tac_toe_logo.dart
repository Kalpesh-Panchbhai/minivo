import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildTicTacToeLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Tic Tac Toe',
      bg: const [Color(0xFF6B21A8), Color(0xFF3B0764)],
      accent: const Color(0xFFD946EF),
      art: _ticTacToeArt,
    );

void _ticTacToeArt(Canvas canvas, Rect zone) {
  const n = 3;
  final cell = zone.width / n;

  Rect cellRect(int r, int c) =>
      Rect.fromLTWH(zone.left + c * cell, zone.top + r * cell, cell, cell);

  // Hash (#) grid: 2 vertical + 2 horizontal strokes, inset from the edges.
  final inset = cell * 0.12;
  final gridPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = zone.width * 0.045
    ..strokeCap = StrokeCap.round;

  for (int i = 1; i < n; i++) {
    final x = zone.left + i * cell;
    canvas.drawLine(
        Offset(x, zone.top + inset), Offset(x, zone.bottom - inset), gridPaint);
    final y = zone.top + i * cell;
    canvas.drawLine(
        Offset(zone.left + inset, y), Offset(zone.right - inset, y), gridPaint);
  }

  // X (two crossed strokes) in the top-left cell — pink/white.
  final xCell = cellRect(0, 0);
  final xPad = cell * 0.27;
  final xPaint = Paint()
    ..color = const Color(0xFFF9A8D4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = cell * 0.16
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
      Offset(xCell.left + xPad, xCell.top + xPad),
      Offset(xCell.right - xPad, xCell.bottom - xPad),
      xPaint);
  canvas.drawLine(
      Offset(xCell.right - xPad, xCell.top + xPad),
      Offset(xCell.left + xPad, xCell.bottom - xPad),
      xPaint);

  // O (ring) in the bottom-right cell — cyan.
  final oCell = cellRect(2, 2);
  canvas.drawCircle(
      oCell.center,
      cell * 0.27,
      Paint()
        ..color = const Color(0xFF67E8F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.15);
}
