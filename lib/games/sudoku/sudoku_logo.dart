import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildSudokuLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Sudoku',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      art: _sudokuArt,
    );

void _sudokuArt(Canvas canvas, Rect zone) {
  const n = 3;
  final inset = zone.width * 0.06;
  final boardSize = zone.width - inset * 2;
  final left = zone.left + inset;
  final top = zone.top + (zone.height - boardSize) / 2;
  final cell = boardSize / n;
  final lineW = boardSize * 0.025;

  final checkerFill = Paint()..color = Colors.white.withValues(alpha: 0.07);
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      if ((r + c).isEven) {
        canvas.drawRect(
          Rect.fromLTWH(left + c * cell, top + r * cell, cell, cell),
          checkerFill,
        );
      }
    }
  }

  final gridPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.55)
    ..strokeWidth = lineW
    ..strokeCap = StrokeCap.round;
  for (int i = 1; i < n; i++) {
    final x = left + i * cell;
    final y = top + i * cell;
    canvas.drawLine(Offset(x, top), Offset(x, top + boardSize), gridPaint);
    canvas.drawLine(Offset(left, y), Offset(left + boardSize, y), gridPaint);
  }

  final outerBorder = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = boardSize * 0.045;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boardSize, boardSize),
      Radius.circular(boardSize * 0.06),
    ),
    outerBorder,
  );

  void digit(int r, int c, String d, {double opacity = 1.0}) {
    final cx = left + c * cell + cell / 2;
    final cy = top + r * cell + cell / 2;
    final tp = TextPainter(
      text: TextSpan(
        text: d,
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontWeight: FontWeight.w900,
          fontSize: cell * 0.58,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  digit(0, 0, '5');
  digit(0, 2, '3');
  digit(1, 1, '7');
  digit(2, 2, '9', opacity: 0.45);
}
