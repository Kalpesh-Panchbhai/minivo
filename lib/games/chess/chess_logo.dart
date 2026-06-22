import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildChessLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Chess',
      bg: const [Color(0xFF2D3436), Color(0xFF1A1A2E)],
      accent: const Color(0xFFD4AF37),
      art: _chessArt,
    );

void _chessArt(Canvas canvas, Rect zone) {
  const n = 4;
  final cell = zone.width / n;

  final light = Paint()..color = const Color(0xFFF0D9B5);
  final dark = Paint()..color = const Color(0xFFB58863);
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final isDark = (r + c) % 2 == 1;
      final rect = Rect.fromLTWH(
          zone.left + c * cell, zone.top + r * cell, cell, cell);
      canvas.drawRect(rect, isDark ? dark : light);
    }
  }
  canvas.drawRect(
    zone,
    Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.08,
  );

  void piece(int r, int c, String ch, Color fill) {
    final ctr = Offset(zone.left + (c + 0.5) * cell, zone.top + (r + 0.5) * cell);
    canvas.drawCircle(ctr.translate(0, cell * 0.05), cell * 0.34,
        Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawCircle(ctr, cell * 0.34, Paint()..color = fill);
    final tp = TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          fontSize: cell * 0.42,
          color: fill == Colors.white ? const Color(0xFF1A1A2E) : Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(ctr.dx - tp.width / 2, ctr.dy - tp.height / 2));
  }

  piece(0, 1, '♚', const Color(0xFF1A1A2E));
  piece(1, 2, '♛', const Color(0xFF1A1A2E));
  piece(2, 1, '♕', Colors.white);
  piece(3, 2, '♔', Colors.white);
}
