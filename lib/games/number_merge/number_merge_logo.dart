import 'package:flutter/material.dart';

/// 2048 Merge brand logo. Renders as a [size]×[size] square that fills the
/// host tile (used by mosaic_game_tile, game_card, home_screen, etc).
///
/// Design: a realistic 4×4 game board mid-play, showing tiles with the
/// authentic 2048 colour palette (2 → 128) on a warm golden gradient. Game
/// name "2048" sits at the bottom.
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

class _FilledTile {
  final int row;
  final int col;
  final int value;
  final Color color;
  final bool whiteText;
  const _FilledTile(this.row, this.col, this.value, this.color, this.whiteText);
}

class _Tile2048LogoPainter extends CustomPainter {
  static const _filled = <_FilledTile>[
    _FilledTile(0, 3, 2, Color(0xFFEEE4DA), false),
    _FilledTile(1, 2, 4, Color(0xFFEDE0C8), false),
    _FilledTile(2, 1, 8, Color(0xFFF2B179), false),
    _FilledTile(3, 0, 16, Color(0xFFF59563), true),
    _FilledTile(0, 1, 32, Color(0xFFF67C5F), true),
    _FilledTile(1, 3, 64, Color(0xFFF65E3B), true),
    _FilledTile(2, 2, 128, Color(0xFFEDCF72), true),
  ];

  static const _darkText = Color(0xFF776E65);

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = size.width * 0.75;
    final boardLeft = (size.width - boardSize) / 2;
    final boardTop = (size.height - boardSize) / 2 - size.height * 0.04;
    final boardRect = Rect.fromLTWH(boardLeft, boardTop, boardSize, boardSize);
    final boardRadius = Radius.circular(boardSize * 0.06);

    // Board background
    final boardPaint = Paint()
      ..color = const Color(0xFFBBADA0).withValues(alpha: 0.6);
    canvas.drawRRect(RRect.fromRectAndRadius(boardRect, boardRadius), boardPaint);

    final gap = boardSize * 0.025;
    final cell = (boardSize - gap * 5) / 4;
    final cellRadius = Radius.circular(cell * 0.12);

    // Empty cells
    final emptyPaint = Paint()
      ..color = const Color(0xFFCDC1B4).withValues(alpha: 0.5);
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final left = boardLeft + gap + c * (cell + gap);
        final top = boardTop + gap + r * (cell + gap);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, cell, cell),
            cellRadius,
          ),
          emptyPaint,
        );
      }
    }

    // Filled tiles
    for (final tile in _filled) {
      final left = boardLeft + gap + tile.col * (cell + gap);
      final top = boardTop + gap + tile.row * (cell + gap);
      final tilePaint = Paint()..color = tile.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cell, cell),
          cellRadius,
        ),
        tilePaint,
      );

      // Number text
      final isSmall = tile.value <= 8;
      final fontSize = cell * (isSmall ? 0.50 : 0.36);
      final tp = TextPainter(
        text: TextSpan(
          text: tile.value.toString(),
          style: TextStyle(
            color: tile.whiteText ? Colors.white : _darkText,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(
          left + (cell - tp.width) / 2,
          top + (cell - tp.height) / 2,
        ),
      );
    }

    // Game name at bottom — font scales with canvas so text never overflows.
    final namePainter = TextPainter(
      text: TextSpan(
        text: '2048',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size.width * 0.18,
          letterSpacing: 1.0,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    namePainter.layout();
    namePainter.paint(
      canvas,
      Offset(
        (size.width - namePainter.width) / 2,
        size.height - namePainter.height - size.height * 0.04,
      ),
    );
  }

  @override
  bool shouldRepaint(_Tile2048LogoPainter old) => false;
}
