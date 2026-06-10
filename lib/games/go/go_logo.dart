import 'package:flutter/material.dart';

Widget buildGoLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFD4A76A), Color(0xFFC4944E), Color(0xFFA67C3D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _GoLogoPainter(),
    ),
  );
}

class _GoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final boardSize = w * 0.75;
    final left = (w - boardSize) / 2;
    final top = h * 0.06;
    const gridLines = 5;
    final cellSize = boardSize / (gridLines - 1);

    final linePaint = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: 0.5)
      ..strokeWidth = (w * 0.015).clamp(1.0, 3.0);

    for (int i = 0; i < gridLines; i++) {
      final offset = i * cellSize;
      canvas.drawLine(Offset(left, top + offset), Offset(left + boardSize, top + offset), linePaint);
      canvas.drawLine(Offset(left + offset, top), Offset(left + offset, top + boardSize), linePaint);
    }

    final center = boardSize / 2;
    canvas.drawCircle(Offset(left + center, top + center), w * 0.025, Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.6));

    void drawStone(int r, int c, Color color) {
      final cx = left + c * cellSize;
      final cy = top + r * cellSize;
      final radius = cellSize * 0.38;
      canvas.drawCircle(Offset(cx, cy + 1.5), radius, Paint()..color = Colors.black.withValues(alpha: 0.2));
      canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = color);
      canvas.drawCircle(
        Offset(cx - radius * 0.25, cy - radius * 0.25),
        radius * 0.2,
        Paint()..color = Colors.white.withValues(alpha: color == Colors.black ? 0.25 : 0.45),
      );
    }

    drawStone(1, 1, Colors.black);
    drawStone(1, 3, Colors.black);
    drawStone(2, 2, Colors.black);
    drawStone(3, 1, Colors.black);

    drawStone(1, 2, Colors.white);
    drawStone(2, 3, Colors.white);
    drawStone(3, 2, Colors.white);
    drawStone(3, 3, Colors.white);

    final fontSize = w * 0.18;
    final tp = TextPainter(
      text: TextSpan(
        text: 'GO',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 2,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h - tp.height - h * 0.03));
  }

  @override
  bool shouldRepaint(_GoLogoPainter old) => false;
}
