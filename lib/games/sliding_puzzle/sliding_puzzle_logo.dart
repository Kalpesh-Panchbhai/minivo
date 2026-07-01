import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildSlidingPuzzleLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Sliding Puzzle',
      bg: const [Color(0xFF4C1D95), Color(0xFF2E1065)],
      accent: const Color(0xFFA78BFA),
      art: _slidingPuzzleArt,
    );

void _slidingPuzzleArt(Canvas canvas, Rect zone) {
  const n = 3;
  final gap = zone.width * 0.05;
  final cell = (zone.width - gap * (n - 1)) / n;

  const layout = [
    ['1', '2', '3'],
    ['', '5', '6'],
    ['7', '8', ''],
  ];

  Rect cellRect(int r, int c) => Rect.fromLTWH(
        zone.left + c * (cell + gap),
        zone.top + r * (cell + gap),
        cell,
        cell,
      );

  void drawTile(Rect rect, String value, {bool sliding = false}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.20));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          rect.translate(0, cell * 0.05), Radius.circular(cell * 0.20)),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: sliding
              ? const [Color(0xFFFDE68A), Color(0xFFFBBF24)]
              : const [Color(0xFFEDE9FE), Color(0xFFC4B5FD)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.42),
        Radius.circular(cell * 0.20),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = sliding
            ? const Color(0xFFD97706).withValues(alpha: 0.5)
            : const Color(0xFF7C3AED).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.04,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: sliding ? const Color(0xFF78350F) : const Color(0xFF4C1D95),
          fontWeight: FontWeight.w900,
          fontSize: cell * 0.48,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2),
    );
  }

  void drawEmpty(Rect rect) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.20));
    canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.05));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.04,
    );
  }

  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final value = layout[r][c];
      final rect = cellRect(r, c);
      if (value.isEmpty) {
        drawEmpty(rect);
        continue;
      }
      if (value == '5' && r == 1 && c == 1) {
        continue;
      }
      drawTile(rect, value);
    }
  }

  final slideRect = cellRect(1, 1);
  final slidingOffset = Offset(-cell * 0.30, 0);
  drawTile(slideRect.shift(slidingOffset), '4', sliding: true);
}
