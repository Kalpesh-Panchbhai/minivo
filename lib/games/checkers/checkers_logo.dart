import 'package:flutter/material.dart';

Widget buildCheckersLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF8B5E3C), Color(0xFF6D4227), Color(0xFF4A2C17)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _CheckersLogoPainter(),
    ),
  );
}

class _CheckersLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final boardSize = w * 0.78;
    final boardLeft = (w - boardSize) / 2;
    final boardTop = h * 0.06;
    final cell = boardSize / 4;

    final lightPaint = Paint()..color = const Color(0xFFF5DEB3).withValues(alpha: 0.30);
    final darkPaint = Paint()..color = const Color(0xFF3E2015).withValues(alpha: 0.40);

    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final isDark = (r + c) % 2 == 1;
        final rect = Rect.fromLTWH(boardLeft + c * cell, boardTop + r * cell, cell, cell);
        canvas.drawRect(rect, isDark ? darkPaint : lightPaint);
      }
    }

    final redPaint = Paint()..color = const Color(0xFFE53935);
    final redBorder = Paint()
      ..color = const Color(0xFFFF6F61)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.02).clamp(1.0, 4.0);

    void drawPiece(int r, int c, Paint fill, Paint border) {
      final cx = boardLeft + (c + 0.5) * cell;
      final cy = boardTop + (r + 0.5) * cell;
      final radius = cell * 0.34;
      canvas.drawCircle(Offset(cx, cy), radius, fill);
      canvas.drawCircle(Offset(cx, cy), radius, border);
    }

    final blackPaint = Paint()..color = const Color(0xFF212121);
    final blackBorder = Paint()
      ..color = const Color(0xFF616161)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.02).clamp(1.0, 4.0);

    drawPiece(0, 1, blackPaint, blackBorder);
    drawPiece(0, 3, blackPaint, blackBorder);
    drawPiece(1, 0, blackPaint, blackBorder);

    drawPiece(2, 3, redPaint, redBorder);
    drawPiece(3, 0, redPaint, redBorder);
    drawPiece(3, 2, redPaint, redBorder);

    final fontSize = w * 0.12;
    final tp = TextPainter(
      text: TextSpan(
        text: 'CHECKERS',
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
    tp.paint(canvas, Offset((w - tp.width) / 2, h - tp.height - h * 0.03));
  }

  @override
  bool shouldRepaint(_CheckersLogoPainter old) => false;
}
