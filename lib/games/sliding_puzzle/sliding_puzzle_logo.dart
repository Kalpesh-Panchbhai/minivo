import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildSlidingPuzzleLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Sliding Puzzle',
      bg: const [Color(0xFF5B21B6), Color(0xFF2E1065)],
      accent: const Color(0xFFA78BFA),
      art: _slidingPuzzleArt,
    );

void _slidingPuzzleArt(Canvas canvas, Rect zone) {
  const n = 3;
  final gap = zone.width * 0.06;
  final cell = (zone.width - gap * (n - 1)) / n;

  // Classic 15-puzzle layout: tiles 1..8 with one empty gap slot.
  const layout = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', ''],
  ];

  Rect cellRect(int r, int c) => Rect.fromLTWH(
        zone.left + c * (cell + gap),
        zone.top + r * (cell + gap),
        cell,
        cell,
      );

  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final value = layout[r][c];
      final rect = cellRect(r, c);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.22));

      if (value.isEmpty) {
        // Empty gap slot: recessed, faint outline.
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.05));
        canvas.drawRRect(
          rr,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.05,
        );
        continue;
      }

      // Tile shadow.
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.translate(0, cell * 0.05), Radius.circular(cell * 0.22)),
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );
      // Tile face.
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [Color(0xFFEDE9FE), Color(0xFFC4B5FD)],
          ).createShader(rect),
      );
      // Top sheen.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.45),
          Radius.circular(cell * 0.22),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.30),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: const Color(0xFF4C1D95),
            fontWeight: FontWeight.w900,
            fontSize: cell * 0.5,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
    }
  }
}
