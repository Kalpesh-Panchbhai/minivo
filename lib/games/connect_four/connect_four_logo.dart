import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildConnectFourLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Connect Four',
      bg: const [Color(0xFF1E3A8A), Color(0xFF0B1E4D)],
      accent: const Color(0xFFFBBF24),
      art: _connectFourArt,
    );

void _connectFourArt(Canvas canvas, Rect zone) {
  // Blue board panel.
  final boardRR =
      RRect.fromRectAndRadius(zone, Radius.circular(zone.width * 0.1));
  canvas.drawRRect(boardRR.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.25));
  canvas.drawRRect(boardRR, Paint()..color = const Color(0xFF2563EB));
  canvas.drawRRect(
      boardRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = zone.width * 0.025);

  const cols = 4;
  const rows = 3;
  final pad = zone.width * 0.1;
  final inner = zone.width - pad * 2;
  final cellW = inner / cols;
  final cellH = (zone.height - pad * 2) / rows;
  final hole = (cellW < cellH ? cellW : cellH) * 0.34;

  // 0 = empty (dark), 1 = red disc, 2 = yellow disc.
  const grid = [
    [0, 2, 1, 0],
    [0, 1, 2, 1],
    [2, 1, 2, 1],
  ];

  const empty = Color(0xFF0B1E4D);
  const red = Color(0xFFF87171);
  const yellow = Color(0xFFFBBF24);

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final center = Offset(
        zone.left + pad + cellW * (c + 0.5),
        zone.top + pad + cellH * (r + 0.5),
      );
      final v = grid[r][c];
      final color = v == 0
          ? empty
          : v == 1
              ? red
              : yellow;
      canvas.drawCircle(center, hole, Paint()..color = color);
      if (v != 0) {
        // Glossy highlight on filled discs.
        canvas.drawCircle(
          center.translate(-hole * 0.28, -hole * 0.28),
          hole * 0.3,
          Paint()..color = Colors.white.withValues(alpha: 0.45),
        );
      }
    }
  }
}
