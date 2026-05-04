import 'package:flutter/material.dart';

Widget buildTicTacToeLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF9775FA), Color(0xFF6C4EF3), Color(0xFF4C3BC7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _TicTacToeLogoPainter(),
    ),
  );
}

class _TicTacToeLogoPainter extends CustomPainter {
  // Board state: X wins top-left diagonal (0,4,8)
  static const _xCells = {0, 4, 8};
  static const _oCells = {1, 5};

  static const _xColor = Color(0xFFE85D75);
  static const _oColor = Color(0xFF5BC0DE);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Board occupies top 72% of the logo, bottom 25% for text
    final boardSize = w * 0.78;
    final boardLeft = (w - boardSize) / 2;
    final boardTop = h * 0.04;
    final cell = boardSize / 3;

    // ── Grid lines (matches gameplay: mauve, inset, rounded) ──────────────
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = (w * 0.035).clamp(2.5, 7.0)
      ..strokeCap = StrokeCap.round;

    final inset = cell * 0.10;
    // Vertical
    for (int i = 1; i <= 2; i++) {
      final x = boardLeft + i * cell;
      canvas.drawLine(
        Offset(x, boardTop + inset),
        Offset(x, boardTop + boardSize - inset),
        gridPaint,
      );
    }
    // Horizontal
    for (int i = 1; i <= 2; i++) {
      final y = boardTop + i * cell;
      canvas.drawLine(
        Offset(boardLeft + inset, y),
        Offset(boardLeft + boardSize - inset, y),
        gridPaint,
      );
    }

    // ── Marks ──────────────────────────────────────────────────────────────
    final markStroke = cell * 0.16;

    Offset cellCenter(int idx) => Offset(
          boardLeft + (idx % 3 + 0.5) * cell,
          boardTop + (idx ~/ 3 + 0.5) * cell,
        );

    // X marks
    final xPaint = Paint()
      ..color = _xColor
      ..strokeWidth = markStroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final idx in _xCells) {
      final c = cellCenter(idx);
      final pad = cell * 0.16;
      canvas.drawLine(Offset(c.dx - pad, c.dy - pad), Offset(c.dx + pad, c.dy + pad), xPaint);
      canvas.drawLine(Offset(c.dx + pad, c.dy - pad), Offset(c.dx - pad, c.dy + pad), xPaint);
    }

    // O marks
    final oPaint = Paint()
      ..color = _oColor
      ..strokeWidth = markStroke
      ..style = PaintingStyle.stroke;

    for (final idx in _oCells) {
      final c = cellCenter(idx);
      canvas.drawCircle(c, cell * 0.30, oPaint);
    }

    // ── Win line: diagonal 0→8 (matches WinLinePainter exactly) ──────────
    final start = cellCenter(0);
    final end = cellCenter(8);

    // Glow pass
    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = cell * 0.18
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawLine(start, end, glowPaint);

    // Solid white line on top
    final winPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = cell * 0.10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, end, winPaint);

    // ── "TIC TAC TOE" text at bottom ──────────────────────────────────────
    final fontSize = w * 0.115;
    final tp = TextPainter(
      text: TextSpan(
        text: 'TIC TAC TOE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 0.5,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((w - tp.width) / 2, h - tp.height - h * 0.03),
    );
  }

  @override
  bool shouldRepaint(_TicTacToeLogoPainter old) => false;
}
