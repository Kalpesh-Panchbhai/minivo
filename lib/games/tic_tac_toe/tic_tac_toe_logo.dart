import 'package:flutter/material.dart';

/// Tic Tac Toe brand logo. Renders as a [size]×[size] square that fills the
/// host tile (used by mosaic_game_tile, game_card, home_screen, etc).
///
/// Design: a stylized 3×3 grid showing the classic game layout with X's and O's
/// rendered as rounded lines, capturing the essence of the game on a purple
/// gradient background. Game name "TIC TAC TOE" at the bottom.
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
  // 5×5 grid layout. Show a playful 3×3 game state with some X's and O's.
  // Pattern: X at (0,0), O at (1,1), X at (2,0), empty elsewhere
  static const _xPositions = <(int, int)>[
    (0, 0),
    (2, 0),
    (1, 2),
  ];

  static const _oPositions = <(int, int)>[
    (1, 1),
    (2, 2),
  ];

  static const _xColor = Color(0xFF64B5F6); // blue X
  static const _oColor = Color(0xFFEF9A9A); // red O
  static const _textColor = Color(0xFFFFFFFF); // white for game name
  static const _fontSize = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / 5;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = cs * 0.08
      ..strokeCap = StrokeCap.round;

    // Vertical lines
    for (int i = 1; i <= 2; i++) {
      final x = (i + 1) * cs;
      canvas.drawLine(
        Offset(x, cs * 0.8),
        Offset(x, cs * 3.2),
        gridPaint,
      );
    }

    // Horizontal lines
    for (int i = 1; i <= 2; i++) {
      final y = (i + 1) * cs;
      canvas.drawLine(
        Offset(cs * 1, y),
        Offset(cs * 3, y),
        gridPaint,
      );
    }

    // Draw X's
    final xPaint = Paint()
      ..color = _xColor
      ..strokeWidth = cs * 0.20
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final (gx, gy) in _xPositions) {
      final centerX = (gx + 1.5) * cs;
      final centerY = (gy + 1.5) * cs;
      final offset = cs * 0.25;

      canvas.drawLine(
        Offset(centerX - offset, centerY - offset),
        Offset(centerX + offset, centerY + offset),
        xPaint,
      );
      canvas.drawLine(
        Offset(centerX + offset, centerY - offset),
        Offset(centerX - offset, centerY + offset),
        xPaint,
      );
    }

    // Draw O's
    final oPaint = Paint()
      ..color = _oColor
      ..strokeWidth = cs * 0.20
      ..style = PaintingStyle.stroke;

    for (final (gx, gy) in _oPositions) {
      final centerX = (gx + 1.5) * cs;
      final centerY = (gy + 1.5) * cs;
      canvas.drawCircle(Offset(centerX, centerY), cs * 0.25, oPaint);
    }

    // Game name at bottom
    final namePainter = TextPainter(
      text: const TextSpan(
        text: 'TIC TAC TOE',
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
  bool shouldRepaint(_TicTacToeLogoPainter old) => false;
}
