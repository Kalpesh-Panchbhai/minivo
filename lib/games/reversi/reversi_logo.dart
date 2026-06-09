import 'package:flutter/material.dart';

Widget buildReversiLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _ReversiLogoPainter(),
    ),
  );
}

class _ReversiLogoPainter extends CustomPainter {
  static const _kBoard = Color(0xFF2E7D32);
  static const _kBlack = Color(0xFF1A1A1A);
  static const _kWhite = Color(0xFFF5F5F5);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bgRect),
    );

    final boardSize = w * 0.72;
    final bx = (w - boardSize) / 2;
    final by = h * 0.14;
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, boardSize, boardSize),
      const Radius.circular(6),
    );
    canvas.drawRRect(boardRect, Paint()..color = _kBoard);

    const n = 4;
    final cell = boardSize / n;
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..strokeWidth = 1;
    for (int i = 1; i < n; i++) {
      canvas.drawLine(
        Offset(bx + i * cell, by),
        Offset(bx + i * cell, by + boardSize),
        gridPaint,
      );
      canvas.drawLine(
        Offset(bx, by + i * cell),
        Offset(bx + boardSize, by + i * cell),
        gridPaint,
      );
    }

    final pieces = [
      (1, 1, true),
      (2, 2, true),
      (1, 2, false),
      (2, 1, false),
      (0, 2, true),
      (3, 1, false),
      (0, 1, false),
      (3, 2, true),
    ];

    final r = cell * 0.34;
    for (final (col, row, isBlack) in pieces) {
      final cx = bx + col * cell + cell / 2;
      final cy = by + row * cell + cell / 2;
      final color = isBlack ? _kBlack : _kWhite;
      canvas.drawCircle(Offset(cx, cy + 1.5), r,
          Paint()..color = Colors.black.withValues(alpha: 0.25));
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
      canvas.drawCircle(
        Offset(cx - r * 0.25, cy - r * 0.25),
        r * 0.15,
        Paint()..color = Colors.white.withValues(alpha: isBlack ? 0.25 : 0.50),
      );
    }

    final textY = h - h * 0.18;
    final pillH = h * 0.16;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w / 2, textY), width: w * 0.88, height: pillH),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(pillRect.outerRect),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'REVERSI',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.13,
          letterSpacing: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.30),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ReversiLogoPainter old) => false;
}
