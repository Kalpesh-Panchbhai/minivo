import 'package:flutter/material.dart';

Widget buildWaterSortLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _WaterSortLogoPainter(),
    ),
  );
}

class _WaterSortLogoPainter extends CustomPainter {
  static const _kBg1 = Color(0xFF0C4A6E);
  static const _kBg2 = Color(0xFF164E63);
  static const _kAccent = Color(0xFF0EA5E9);

  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_kBg1, _kBg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bgRect),
    );

    canvas.drawCircle(
      Offset(w * 0.5, h * 0.42),
      w * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [_kAccent.withValues(alpha: 0.15), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.42), radius: w * 0.45)),
    );

    final tubeW = w * 0.14;
    final tubeH = h * 0.48;
    final gap = w * 0.04;
    final totalW = tubeW * 4 + gap * 3;
    final startX = (w - totalW) / 2;
    final startY = h * 0.12;

    final fills = [
      [0, 1, 0, 2],
      [1, 2, 3, 0],
      [2, 0, 1, 3],
      [3, 3, 2, 1],
    ];

    for (int t = 0; t < 4; t++) {
      final tx = startX + t * (tubeW + gap);
      final ty = startY;

      final tubeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tx, ty, tubeW, tubeH),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        tubeRect,
        Paint()..color = Colors.white.withValues(alpha: 0.10),
      );
      canvas.drawRRect(
        tubeRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      final segH = tubeH / 4;
      for (int s = 0; s < 4; s++) {
        final sy = ty + tubeH - (s + 1) * segH + 2;
        final colorIdx = fills[t][s];
        final segRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(tx + 2, sy, tubeW - 4, segH - 2),
          s == 0 ? const Radius.circular(4) : Radius.zero,
        );
        canvas.drawRRect(segRect, Paint()..color = _colors[colorIdx]);
      }
    }

    final textY = h - h * 0.15;
    final pillH = h * 0.14;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, textY), width: w * 0.92, height: pillH),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_kAccent, Color(0xFF0284C7)],
        ).createShader(pillRect.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pillRect.left, pillRect.top, pillRect.width, pillH * 0.45),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'WATER SORT',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.095,
          letterSpacing: 0.4,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.30), offset: const Offset(0, 1), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  @override
  bool shouldRepaint(_WaterSortLogoPainter old) => false;
}
