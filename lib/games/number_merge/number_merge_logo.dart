import 'package:flutter/material.dart';

/// 2048 Merge brand logo. Renders as a [size]×[size] square that fills the
/// host tile (used by mosaic_game_tile, game_card, home_screen, etc).
///
/// Design: stylized merge tiles with bezier-rounded corners showing the iconic
/// 2048 progression (2 → 4 → 8 → 16), rendered on a golden gradient background
/// matching the in-game palette. Game name "2048" at the bottom.
///
/// Referenced from `GameRegistry`'s `number_merge` entry as a const tear-off
/// so it can sit inside `const GameInfo(...)`.
Widget build2048Logo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFEDC22E), Color(0xFFF67C5F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: ClipRect(
      child: CustomPaint(
        size: Size(size, size),
        painter: _Tile2048LogoPainter(),
      ),
    ),
  );
}

class _Tile2048LogoPainter extends CustomPainter {
  // Layout: three tiles arranged diagonally showing 2→4→8 progression.
  // Logical 5×5 grid for consistent sizing.
  static const _tileCoords = <(int, int)>[
    (1, 2), // 2
    (2, 1), // 4
    (3, 2), // 8
  ];

  static const _tileValues = ['2', '4', '8'];

  // Tile palette — vibrant colors from 2048 theme
  static const _tileColors = <Color>[
    Color(0xFFEEEEEE), // 2 — light gray
    Color(0xFFEDDECC), // 4 — cream
    Color(0xFFF2B179), // 8 — orange-gold
  ];

  static const _tileTextColor = Color(0xFF776E65); // dark brown
  static const _textColor = Color(0xFFFFFFFF); // white for game name
  static const _fontSize = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / 5;

    // Draw tiles with rounded corners
    for (int i = 0; i < _tileCoords.length; i++) {
      final (x, y) = _tileCoords[i];
      final tileSize = cs * 0.8;
      final centerX = (x + 0.5) * cs;
      final centerY = (y + 0.5) * cs;
      final left = centerX - tileSize / 2;
      final top = centerY - tileSize / 2;

      // Tile background with rounded corners
      final tilePaint = Paint()..color = _tileColors[i];
      final tileRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, tileSize, tileSize),
        Radius.circular(tileSize * 0.15),
      );
      canvas.drawRRect(tileRect, tilePaint);

      // Tile number text
      final textPainter = TextPainter(
        text: TextSpan(
          text: _tileValues[i],
          style: const TextStyle(
            color: _tileTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 28,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          centerX - textPainter.width / 2,
          centerY - textPainter.height / 2,
        ),
      );
    }

    // Game name at bottom
    final namePainter = TextPainter(
      text: const TextSpan(
        text: '2048',
        style: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.w900,
          fontSize: _fontSize,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    namePainter.layout();
    namePainter.paint(
      canvas,
      Offset((size.width - namePainter.width) / 2, size.height - cs * 0.7),
    );
  }

  @override
  bool shouldRepaint(_Tile2048LogoPainter old) => false;
}
