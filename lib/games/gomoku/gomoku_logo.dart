import 'package:flutter/material.dart';

Widget buildGomokuLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF4A90D9), Color(0xFF2C5F9E), Color(0xFF1A3A6B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _GomokuLogoPainter(),
    ),
  );
}

class _GomokuLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final boardSize = w * 0.76;
    final left = (w - boardSize) / 2;
    final top = h * 0.06;
    const gridLines = 7;
    final cellSize = boardSize / (gridLines - 1);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    for (int i = 0; i < gridLines; i++) {
      final offset = i * cellSize;
      canvas.drawLine(Offset(left, top + offset), Offset(left + boardSize, top + offset), linePaint);
      canvas.drawLine(Offset(left + offset, top), Offset(left + offset, top + boardSize), linePaint);
    }

    void drawStone(int r, int c, bool isBlack) {
      final cx = left + c * cellSize;
      final cy = top + r * cellSize;
      final radius = cellSize * 0.38;
      canvas.drawCircle(Offset(cx, cy + 1), radius, Paint()..color = Colors.black.withValues(alpha: 0.2));
      canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = isBlack ? const Color(0xFF212121) : Colors.white);
      if (!isBlack) {
        canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = Colors.grey.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      }
    }

    // Diagonal win line for black
    drawStone(1, 1, true);
    drawStone(2, 2, true);
    drawStone(3, 3, true);
    drawStone(4, 4, true);
    drawStone(5, 5, true);

    drawStone(1, 4, false);
    drawStone(2, 5, false);
    drawStone(3, 4, false);
    drawStone(4, 5, false);

    // Win line glow
    final startOff = Offset(left + 1 * cellSize, top + 1 * cellSize);
    final endOff = Offset(left + 5 * cellSize, top + 5 * cellSize);
    canvas.drawLine(startOff, endOff, Paint()
      ..color = Colors.amber.withValues(alpha: 0.4)
      ..strokeWidth = cellSize * 0.15
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawLine(startOff, endOff, Paint()
      ..color = Colors.amber.withValues(alpha: 0.7)
      ..strokeWidth = cellSize * 0.06
      ..strokeCap = StrokeCap.round);

    final fontSize = w * 0.11;
    final tp = TextPainter(
      text: TextSpan(
        text: 'GOMOKU',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 1,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h - tp.height - h * 0.03));
  }

  @override
  bool shouldRepaint(_GomokuLogoPainter old) => false;
}
