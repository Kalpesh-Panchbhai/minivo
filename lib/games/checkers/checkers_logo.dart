import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildCheckersLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Checkers',
      bg: const [Color(0xFF5C3A21), Color(0xFF2A1A0F)],
      accent: const Color(0xFFD2A679),
      art: _checkersArt,
    );

void _checkersArt(Canvas canvas, Rect zone) {
  const n = 4;
  final cell = zone.width / n;

  // 4x4 checkerboard with alternating light/dark squares.
  final light = Paint()..color = const Color(0xFFF5DEB3);
  final dark = Paint()..color = const Color(0xFF6B4226);
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final isDark = (r + c) % 2 == 1;
      final rect = Rect.fromLTWH(
          zone.left + c * cell, zone.top + r * cell, cell, cell);
      canvas.drawRect(rect, isDark ? dark : light);
    }
  }
  // Board border.
  canvas.drawRect(
    zone,
    Paint()
      ..color = const Color(0xFF3E2015)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.08,
  );

  void disc(int r, int c, Color fill, Color rim) {
    final ctr = Offset(zone.left + (c + 0.5) * cell, zone.top + (r + 0.5) * cell);
    final radius = cell * 0.36;
    // Contact shadow.
    canvas.drawCircle(ctr.translate(0, cell * 0.05), radius,
        Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawCircle(ctr, radius, Paint()..color = fill);
    // Inner ring detail.
    canvas.drawCircle(
      ctr,
      radius * 0.62,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06,
    );
    // Top highlight.
    canvas.drawCircle(ctr.translate(-radius * 0.3, -radius * 0.3), radius * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.4));
  }

  // Two red discs and one dark disc on dark squares.
  disc(0, 1, const Color(0xFFE53935), const Color(0xFFFF8A80));
  disc(3, 2, const Color(0xFFE53935), const Color(0xFFFF8A80));
  disc(2, 1, const Color(0xFF1F2937), const Color(0xFF6B7280));
}
