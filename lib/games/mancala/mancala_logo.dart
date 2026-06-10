import 'package:flutter/material.dart';

Widget buildMancalaLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF7B5B3A), Color(0xFF5C3D24), Color(0xFF3E2713)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _MancalaLogoPainter(),
    ),
  );
}

class _MancalaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final boardW = w * 0.88;
    final boardH = h * 0.42;
    final boardLeft = (w - boardW) / 2;
    final boardTop = h * 0.14;

    final boardPaint = Paint()..color = const Color(0xFF8B6914).withValues(alpha: 0.4);
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boardLeft, boardTop, boardW, boardH),
      const Radius.circular(20),
    );
    canvas.drawRRect(boardRect, boardPaint);

    final storeW = boardW * 0.12;
    final storeH = boardH * 0.8;
    final storeTop = boardTop + (boardH - storeH) / 2;
    final storePaint = Paint()..color = const Color(0xFF5C3D24).withValues(alpha: 0.5);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(boardLeft + boardW * 0.03, storeTop, storeW, storeH), const Radius.circular(10)),
      storePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(boardLeft + boardW - boardW * 0.03 - storeW, storeTop, storeW, storeH), const Radius.circular(10)),
      storePaint,
    );

    final pitRadius = boardH * 0.14;
    final pitY1 = boardTop + boardH * 0.3;
    final pitY2 = boardTop + boardH * 0.7;
    final pitPaint = Paint()..color = const Color(0xFF5C3D24).withValues(alpha: 0.4);
    final seedPaint = Paint()..color = const Color(0xFFD4A76A);

    for (int i = 0; i < 6; i++) {
      final x = boardLeft + boardW * 0.22 + i * (boardW * 0.56 / 5);
      canvas.drawCircle(Offset(x, pitY1), pitRadius, pitPaint);
      canvas.drawCircle(Offset(x, pitY2), pitRadius, pitPaint);
      if (i < 4) {
        canvas.drawCircle(Offset(x, pitY1), pitRadius * 0.35, seedPaint);
        canvas.drawCircle(Offset(x, pitY2), pitRadius * 0.35, seedPaint);
      }
    }

    final fontSize = w * 0.10;
    final tp = TextPainter(
      text: TextSpan(
        text: 'MANCALA',
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
  bool shouldRepaint(_MancalaLogoPainter old) => false;
}
