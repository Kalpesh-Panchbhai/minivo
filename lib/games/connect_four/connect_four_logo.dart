import 'package:flutter/material.dart';

Widget buildConnectFourLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _ConnectFourLogoPainter(),
    ),
  );
}

class _ConnectFourLogoPainter extends CustomPainter {
  static const _kBoard = Color(0xFF3366CC);
  static const _kRed = Color(0xFFE85D75);
  static const _kYellow = Color(0xFFF5C542);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1A3A7A), Color(0xFF2952A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bgRect),
    );

    final boardW = w * 0.82;
    final boardH = h * 0.52;
    final bx = (w - boardW) / 2;
    final by = h * 0.18;
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, boardW, boardH),
      const Radius.circular(8),
    );
    canvas.drawRRect(boardRect, Paint()..color = _kBoard);

    const cols = 4;
    const rows = 3;
    final cellW = boardW / cols;
    final cellH = boardH / rows;
    final r = cellW * 0.30;

    final grid = [
      [0, 0, 2, 0],
      [0, 1, 1, 0],
      [1, 2, 1, 2],
    ];

    final holePaint = Paint()..color = const Color(0xFF1A3A7A);

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = bx + col * cellW + cellW / 2;
        final cy = by + row * cellH + cellH / 2;
        final v = grid[row][col];
        if (v == 0) {
          canvas.drawCircle(Offset(cx, cy), r, holePaint);
        } else {
          final color = v == 1 ? _kRed : _kYellow;
          canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
          canvas.drawCircle(
            Offset(cx - r * 0.25, cy - r * 0.25),
            r * 0.18,
            Paint()..color = Colors.white.withValues(alpha: 0.45),
          );
        }
      }
    }

    final textY = h - h * 0.20;
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
          colors: [Color(0xFFE85D75), Color(0xFFF5C542)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(pillRect.outerRect),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'CONNECT 4',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.115,
          letterSpacing: 0.6,
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
  bool shouldRepaint(_ConnectFourLogoPainter old) => false;
}
