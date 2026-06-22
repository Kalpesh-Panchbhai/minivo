import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

const _kFlowColors = [
  Color(0xFFFF6B6B),
  Color(0xFF4ECDC4),
  Color(0xFFFFE66D),
  Color(0xFF95E1D3),
];

Widget buildColorConnectLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Color Connect',
      bg: const [Color(0xFF1A1A2E), Color(0xFF0A0A14)],
      accent: const Color(0xFF6C63FF),
      art: _colorConnectArt,
    );

void _colorConnectArt(Canvas canvas, Rect zone) {
  const n = 4;
  final gap = zone.width * 0.08;
  final cell = (zone.width - gap * (n - 1)) / n;

  Rect cellRect(int r, int c) =>
      Rect.fromLTWH(zone.left + c * (cell + gap), zone.top + r * (cell + gap), cell, cell);
  Offset center(int r, int c) => cellRect(r, c).center;

  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final rr = RRect.fromRectAndRadius(cellRect(r, c), Radius.circular(cell * 0.22));
      canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.06));
      canvas.drawRRect(
          rr,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.04);
    }
  }

  void drawFlow(List<List<int>> path, Color color) {
    if (path.length < 2) return;
    final p = Path()..moveTo(center(path[0][0], path[0][1]).dx, center(path[0][0], path[0][1]).dy);
    for (int i = 1; i < path.length; i++) {
      final c = center(path[i][0], path[i][1]);
      p.lineTo(c.dx, c.dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.28
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.85),
    );

    final first = center(path.first[0], path.first[1]);
    final last = center(path.last[0], path.last[1]);
    final dotR = cell * 0.26;
    canvas.drawCircle(first, dotR, Paint()..color = color);
    canvas.drawCircle(last, dotR, Paint()..color = color);
  }

  drawFlow([[0, 0], [0, 1], [1, 1], [2, 1], [2, 0]], _kFlowColors[0]);
  drawFlow([[0, 3], [1, 3], [1, 2], [2, 2], [2, 3]], _kFlowColors[1]);
  drawFlow([[3, 0], [3, 1]], _kFlowColors[2]);
  drawFlow([[3, 2], [3, 3]], _kFlowColors[3]);
}
