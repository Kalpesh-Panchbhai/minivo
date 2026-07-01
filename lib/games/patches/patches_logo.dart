import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildPatchesLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Patches',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      art: _patchesArt,
    );

void _patchesArt(Canvas canvas, Rect zone) {
  const n = 5;
  final cell = zone.width / n;
  final left = zone.left;
  final top = zone.top + (zone.height - zone.width) * 0.5;
  final gridW = cell * n;

  // Cell backgrounds
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      canvas.drawRect(
        Rect.fromLTWH(left + c * cell, top + r * cell, cell, cell),
        Paint()..color = const Color(0xFFF8FAFC),
      );
    }
  }

  // Grid lines
  final gridLine = Paint()
    ..color = const Color(0xFFCBD5E1)
    ..strokeWidth = cell * 0.03;
  for (int i = 1; i < n; i++) {
    canvas.drawLine(
        Offset(left, top + i * cell), Offset(left + gridW, top + i * cell), gridLine);
    canvas.drawLine(
        Offset(left + i * cell, top), Offset(left + i * cell, top + gridW), gridLine);
  }

  // Outer border
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, gridW, gridW),
      Radius.circular(cell * 0.12),
    ),
    Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.08,
  );

  final bw = cell * 0.10;

  // Draw a patch: fill cells with pastel, draw vivid border on outer edges
  void drawPatch(List<List<int>> cells, Color fill, Color border) {
    for (final rc in cells) {
      canvas.drawRect(
        Rect.fromLTWH(left + rc[1] * cell, top + rc[0] * cell, cell, cell),
        Paint()..color = fill,
      );
    }
    final path = Path();
    for (final rc in cells) {
      final r = rc[0], c = rc[1];
      final x = left + c * cell;
      final y = top + r * cell;
      bool has(int dr, int dc) => cells.any((o) => o[0] == r + dr && o[1] == c + dc);
      if (!has(-1, 0)) { path.moveTo(x, y); path.lineTo(x + cell, y); }
      if (!has(1, 0)) { path.moveTo(x, y + cell); path.lineTo(x + cell, y + cell); }
      if (!has(0, -1)) { path.moveTo(x, y); path.lineTo(x, y + cell); }
      if (!has(0, 1)) { path.moveTo(x + cell, y); path.lineTo(x + cell, y + cell); }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = bw
        ..strokeCap = StrokeCap.round,
    );
  }

  // Patch A: 2x2 blue patch top-left
  drawPatch([[0, 0], [0, 1], [1, 0], [1, 1]],
      const Color(0xFFBFDBFE), const Color(0xFF3B82F6));

  // Patch B: L-shape yellow/green
  drawPatch([[0, 3], [0, 4], [1, 3]],
      const Color(0xFFFDE68A), const Color(0xFF22C55E));

  // Patch C: 2x2 green/purple bottom-right
  drawPatch([[3, 3], [3, 4], [4, 3], [4, 4]],
      const Color(0xFFBBF7D0), const Color(0xFF8B5CF6));

  // Patch D: horizontal bar
  drawPatch([[2, 0], [2, 1], [2, 2]],
      const Color(0xFFFECACA), const Color(0xFFEF4444));

  // Patch E: tall piece
  drawPatch([[3, 1], [4, 1]],
      const Color(0xFFDDD6FE), const Color(0xFFEC4899));

  // Clue numbers
  void drawClue(int r, int c, String text) {
    final cx = left + c * cell + cell / 2;
    final cy = top + r * cell + cell / 2;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF334155),
          fontSize: cell * 0.48,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  drawClue(0, 0, '4');
  drawClue(0, 3, '3');
  drawClue(3, 3, '4');
  drawClue(2, 0, '3');
  drawClue(3, 1, '2');

  // Dashed shape hint in empty cell [1,4]
  final dx = left + 4 * cell + cell * 0.20;
  final dy = top + 1 * cell + cell * 0.20;
  final dw = cell * 0.60;
  final dh = cell * 0.60;
  final dashRRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(dx, dy, dw, dh),
    Radius.circular(cell * 0.08),
  );
  final dashPaint = Paint()
    ..color = const Color(0xFF94A3B8).withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = cell * 0.04;

  final dashPath = Path()..addRRect(dashRRect);
  for (final metric in dashPath.computeMetrics()) {
    final totalLen = metric.length;
    final dashLen = cell * 0.09;
    final gapLen = cell * 0.07;
    double dist = 0;
    while (dist < totalLen) {
      final end = (dist + dashLen).clamp(0.0, totalLen);
      canvas.drawPath(metric.extractPath(dist, end), dashPaint);
      dist += dashLen + gapLen;
    }
  }
}
