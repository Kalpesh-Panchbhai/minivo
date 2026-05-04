import 'package:flutter/material.dart';

/// Tic Tac Toe brand logo. Renders as a [size]×[size] square that fills the
/// host tile (used by mosaic_game_tile, game_card, home_screen, etc).
///
/// Design: a real game-in-progress where X has just won the top row. Three
/// X marks in cyan, two O marks in coral, plus a soft white winning-line
/// highlight running across the top row. Purple gradient background. Game
/// name "TIC TAC TOE" at the bottom.
///
/// Referenced from `GameRegistry`'s `tic_tac_toe` entry as a const tear-off
/// so it can sit inside `const GameInfo(...)`.
Widget buildTicTacToeLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF7B68EE), Color(0xFF6A5ACD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: ClipRect(
      child: CustomPaint(
        size: Size(size, size),
        painter: _TicTacToeLogoPainter(),
      ),
    ),
  );
}

class _TicTacToeLogoPainter extends CustomPainter {
  // X wins the top row.
  static const _xPositions = <(int, int)>[
    (0, 0), (1, 0), (2, 0),
  ];
  static const _oPositions = <(int, int)>[
    (1, 1), (0, 2),
  ];

  static const _xColor = Color(0xFF4FC3F7);
  static const _oColor = Color(0xFFFF8A80);

  @override
  void paint(Canvas canvas, Size size) {
    final boardSize = size.width * 0.70;
    final boardLeft = (size.width - boardSize) / 2;
    final boardTop = size.height * 0.10;
    final cell = boardSize / 3;

    Offset cellCenter(int gx, int gy) {
      return Offset(
        boardLeft + (gx + 0.5) * cell,
        boardTop + (gy + 0.5) * cell,
      );
    }

    // Winning-line highlight (behind everything else): top row.
    final winStart = cellCenter(0, 0);
    final winEnd = cellCenter(2, 0);
    final winPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = cell * 0.55
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(winStart, winEnd, winPaint);

    // Grid lines — thick, rounded, semi-transparent white.
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;

    // Vertical
    for (int i = 1; i <= 2; i++) {
      final x = boardLeft + i * cell;
      canvas.drawLine(
        Offset(x, boardTop + cell * 0.10),
        Offset(x, boardTop + boardSize - cell * 0.10),
        gridPaint,
      );
    }
    // Horizontal
    for (int i = 1; i <= 2; i++) {
      final y = boardTop + i * cell;
      canvas.drawLine(
        Offset(boardLeft + cell * 0.10, y),
        Offset(boardLeft + boardSize - cell * 0.10, y),
        gridPaint,
      );
    }

    // X marks
    final xPaint = Paint()
      ..color = _xColor
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (gx, gy) in _xPositions) {
      final c = cellCenter(gx, gy);
      final off = cell * 0.26;
      canvas.drawLine(
        Offset(c.dx - off, c.dy - off),
        Offset(c.dx + off, c.dy + off),
        xPaint,
      );
      canvas.drawLine(
        Offset(c.dx + off, c.dy - off),
        Offset(c.dx - off, c.dy + off),
        xPaint,
      );
    }

    // O marks
    final oPaint = Paint()
      ..color = _oColor
      ..strokeWidth = size.width * 0.040
      ..style = PaintingStyle.stroke;

    for (final (gx, gy) in _oPositions) {
      final c = cellCenter(gx, gy);
      canvas.drawCircle(c, cell * 0.35, oPaint);
    }

    // Game name at bottom — font scales with canvas so text never overflows.
    final namePainter = TextPainter(
      text: TextSpan(
        text: 'TIC TAC TOE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size.width * 0.13,
          letterSpacing: 0.8,
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
  bool shouldRepaint(_TicTacToeLogoPainter old) => false;
}
