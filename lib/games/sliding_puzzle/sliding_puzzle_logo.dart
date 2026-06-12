import 'package:flutter/material.dart';

Widget buildSlidingPuzzleLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _SlidingPuzzleLogoPainter(),
    ),
  );
}

class _SlidingPuzzleLogoPainter extends CustomPainter {
  static const _kBg1 = Color(0xFF1A0F2E);
  static const _kBg2 = Color(0xFF2D1B4E);
  static const _kAccent = Color(0xFF8B5CF6);

  static const _tileColors = [
    Color(0xFF8B5CF6),
    Color(0xFFA78BFA),
    Color(0xFF7C3AED),
    Color(0xFF6D28D9),
    Color(0xFF9333EA),
    Color(0xFFC084FC),
    Color(0xFFD946EF),
    Color(0xFF7E22CE),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()
      ..shader = const LinearGradient(colors: [_kBg1, _kBg2], begin: Alignment.topLeft, end: Alignment.bottomRight)
          .createShader(Rect.fromLTWH(0, 0, w, h)));

    canvas.drawCircle(Offset(w * 0.5, h * 0.42), w * 0.4,
      Paint()..shader = RadialGradient(colors: [_kAccent.withValues(alpha: 0.15), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.42), radius: w * 0.4)));

    final gridSize = w * 0.68;
    final cellSize = gridSize / 3;
    final startX = (w - gridSize) / 2;
    final startY = h * 0.12;
    final nums = [1, 2, 3, 4, 5, 6, 7, 8, 0];

    for (int i = 0; i < 9; i++) {
      final r = i ~/ 3;
      final c = i % 3;
      final x = startX + c * cellSize;
      final y = startY + r * cellSize;
      final num = nums[i];

      if (num == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, y + 2, cellSize - 4, cellSize - 4), Radius.circular(cellSize * 0.15)),
          Paint()..color = Colors.white.withValues(alpha: 0.04),
        );
        continue;
      }

      final color = _tileColors[(num - 1) % _tileColors.length];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 2, y + 2, cellSize - 4, cellSize - 4),
        Radius.circular(cellSize * 0.15),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, y + 3.5, cellSize - 4, cellSize - 4), Radius.circular(cellSize * 0.15)),
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );

      canvas.drawRRect(rect, Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(color, Colors.white, 0.2)!, color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect.outerRect));

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, y + 2, cellSize - 4, (cellSize - 4) * 0.4), Radius.circular(cellSize * 0.15)),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '$num',
          style: TextStyle(
            color: Colors.white,
            fontSize: cellSize * 0.45,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(0, 1), blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + cellSize / 2 - tp.width / 2, y + cellSize / 2 - tp.height / 2));
    }

    final textY = h - h * 0.18;
    final pillH = h * 0.16;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, textY), width: w * 0.92, height: pillH),
      const Radius.circular(8),
    );
    canvas.drawRRect(pillRect, Paint()
      ..shader = LinearGradient(colors: [_kAccent, const Color(0xFFD946EF)])
          .createShader(pillRect.outerRect));

    final tp = TextPainter(
      text: TextSpan(
        text: 'SLIDE PUZZLE',
        style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900, fontSize: w * 0.10, letterSpacing: 0.5,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.30), offset: const Offset(0, 1), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SlidingPuzzleLogoPainter old) => false;
}
