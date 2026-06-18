import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildReversiLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Reversi',
      bg: const [Color(0xFF14532D), Color(0xFF052E16)],
      accent: const Color(0xFF4ADE80),
      art: _reversiArt,
    );

void _reversiArt(Canvas canvas, Rect zone) {
  final boardSize = zone.width;
  final boardRect = Rect.fromLTWH(zone.left, zone.top, boardSize, boardSize);

  // Green board.
  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect, Radius.circular(boardSize * 0.06)),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF22C55E), Color(0xFF15803D)],
      ).createShader(boardRect),
  );

  const n = 4;
  final cell = boardSize / n;

  // Grid lines.
  final gridPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.30)
    ..strokeWidth = boardSize * 0.012;
  for (int i = 1; i < n; i++) {
    canvas.drawLine(
      Offset(zone.left + i * cell, zone.top),
      Offset(zone.left + i * cell, zone.top + boardSize),
      gridPaint,
    );
    canvas.drawLine(
      Offset(zone.left, zone.top + i * cell),
      Offset(zone.left + boardSize, zone.top + i * cell),
      gridPaint,
    );
  }
  // Board border.
  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect, Radius.circular(boardSize * 0.06)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = boardSize * 0.02,
  );

  // Discs: (col, row, isBlack) — Othello-style mix of black and white.
  const pieces = [
    (1, 1, true),
    (2, 2, true),
    (1, 2, false),
    (2, 1, false),
    (0, 2, true),
    (3, 1, false),
    (0, 1, false),
    (3, 2, true),
  ];

  const black = Color(0xFF1A1A1A);
  final r = cell * 0.36;

  for (final (col, row, isBlack) in pieces) {
    final c = Offset(
      zone.left + col * cell + cell / 2,
      zone.top + row * cell + cell / 2,
    );
    // Drop shadow.
    canvas.drawCircle(c.translate(0, r * 0.12), r, Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: isBlack
              ? const [Color(0xFF4B5563), black]
              : const [Colors.white, Color(0xFFD1D5DB)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Highlight.
    canvas.drawCircle(
      c.translate(-r * 0.28, -r * 0.28),
      r * 0.16,
      Paint()..color = Colors.white.withValues(alpha: isBlack ? 0.30 : 0.6),
    );
  }
}
