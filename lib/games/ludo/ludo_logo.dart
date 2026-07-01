import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildLudoLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Ludo',
      bg: const [Color(0xFF3B1F6E), Color(0xFF1E1048)],
      accent: const Color(0xFFA78BFA),
      art: _ludoArt,
    );

void _ludoArt(Canvas canvas, Rect zone) {
  const red = Color(0xFFE74C3C);
  const green = Color(0xFF27AE60);
  const yellow = Color(0xFFF1C40F);
  const blue = Color(0xFF2980B9);
  const boardBg = Color(0xFFF5F0E1);
  const borderC = Color(0xFF2C3E50);
  const trackStroke = Color(0xFF90A4AE);

  final s = zone.width;
  final cell = s / 15;
  final ox = zone.left;
  final oy = zone.top + (zone.height - s) / 2;

  // Board background
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(ox, oy, s, s),
      Radius.circular(cell * 0.6),
    ),
    Paint()..color = boardBg,
  );

  // Home areas (6x6 corners)
  void drawHome(int r0, int c0, Color color) {
    final x = ox + c0 * cell;
    final y = oy + r0 * cell;
    final w = cell * 6;
    canvas.drawRect(Rect.fromLTWH(x, y, w, w), Paint()..color = color);
    final pad = w * 0.15;
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + pad, y + pad, w - pad * 2, w - pad * 2),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(inner, Paint()..color = Colors.white);
    canvas.drawRRect(
      inner,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.12,
    );
    // Token circles in home
    final tokenR = cell * 0.42;
    final cx1 = x + w * 0.35;
    final cx2 = x + w * 0.65;
    final cy1 = y + w * 0.35;
    final cy2 = y + w * 0.65;
    for (final pos in [Offset(cx1, cy1), Offset(cx2, cy1), Offset(cx1, cy2), Offset(cx2, cy2)]) {
      canvas.drawCircle(pos, tokenR, Paint()..color = color.withValues(alpha: 0.35));
      canvas.drawCircle(
        pos,
        tokenR,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.06,
      );
    }
  }

  drawHome(0, 0, green);
  drawHome(0, 9, yellow);
  drawHome(9, 0, red);
  drawHome(9, 9, blue);

  // Track cells grid lines (the cross area)
  final gridPaint = Paint()
    ..color = trackStroke
    ..strokeWidth = cell * 0.04;
  // Vertical arm (columns 6-8, rows 0-14)
  for (int r = 0; r <= 15; r++) {
    final y = oy + r * cell;
    if (r <= 6 || r >= 9) {
      canvas.drawLine(Offset(ox + 6 * cell, y), Offset(ox + 9 * cell, y), gridPaint);
    }
  }
  for (int c = 6; c <= 9; c++) {
    final x = ox + c * cell;
    canvas.drawLine(Offset(x, oy), Offset(x, oy + 6 * cell), gridPaint);
    canvas.drawLine(Offset(x, oy + 9 * cell), Offset(x, oy + 15 * cell), gridPaint);
  }
  // Horizontal arm (rows 6-8, columns 0-14)
  for (int c = 0; c <= 15; c++) {
    final x = ox + c * cell;
    if (c <= 6 || c >= 9) {
      canvas.drawLine(Offset(x, oy + 6 * cell), Offset(x, oy + 9 * cell), gridPaint);
    }
  }
  for (int r = 6; r <= 9; r++) {
    final y = oy + r * cell;
    canvas.drawLine(Offset(ox, y), Offset(ox + 6 * cell, y), gridPaint);
    canvas.drawLine(Offset(ox + 9 * cell, y), Offset(ox + 15 * cell, y), gridPaint);
  }

  // Colored home lanes
  void drawLane(List<Offset> cells, Color color) {
    for (final c in cells) {
      canvas.drawRect(
        Rect.fromLTWH(ox + c.dx * cell, oy + c.dy * cell, cell, cell),
        Paint()..color = color.withValues(alpha: 0.45),
      );
    }
  }

  // Green lane: row 7, cols 1-5
  drawLane([for (int c = 1; c <= 5; c++) Offset(c.toDouble(), 7)], green);
  // Yellow lane: col 7, rows 1-5
  drawLane([for (int r = 1; r <= 5; r++) Offset(7, r.toDouble())], yellow);
  // Blue lane: row 7, cols 9-13
  drawLane([for (int c = 9; c <= 13; c++) Offset(c.toDouble(), 7)], blue);
  // Red lane: col 7, rows 9-13
  drawLane([for (int r = 9; r <= 13; r++) Offset(7, r.toDouble())], red);

  // Center finish area — 4 colored triangles
  final centerX = ox + 6 * cell;
  final centerY = oy + 6 * cell;
  final cSize = cell * 3;
  final mid = Offset(centerX + cSize / 2, centerY + cSize / 2);

  void drawCenterTri(Offset p1, Offset p2, Color color) {
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(mid.dx, mid.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderC
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06,
    );
  }

  drawCenterTri(Offset(centerX, centerY), Offset(centerX + cSize, centerY), yellow);
  drawCenterTri(Offset(centerX + cSize, centerY), Offset(centerX + cSize, centerY + cSize), blue);
  drawCenterTri(Offset(centerX + cSize, centerY + cSize), Offset(centerX, centerY + cSize), red);
  drawCenterTri(Offset(centerX, centerY + cSize), Offset(centerX, centerY), green);

  // Board outer border
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(ox, oy, s, s),
      Radius.circular(cell * 0.6),
    ),
    Paint()
      ..color = borderC
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.14,
  );
}
