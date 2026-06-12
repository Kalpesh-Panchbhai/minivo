import 'package:flutter/material.dart';

Widget buildNutsAndBoltsLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _NutsAndBoltsLogoPainter(),
    ),
  );
}

class _NutsAndBoltsLogoPainter extends CustomPainter {
  static const _kBg1 = Color(0xFF292524);
  static const _kBg2 = Color(0xFF44403C);
  static const _kAccent = Color(0xFF78716C);

  static const _colors = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
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

    final boltW = w * 0.12;
    final nutH = h * 0.065;
    final gap = w * 0.08;
    final totalW = boltW * 3 + gap * 2;
    final startX = (w - totalW) / 2 + boltW / 2;
    final baseY = h * 0.65;

    final fills = [
      [0, 0, 1],
      [1, 2, 0],
      [2, 1, 2],
    ];

    for (int b = 0; b < 3; b++) {
      final cx = startX + b * (boltW + gap);
      final shaftH = h * 0.32;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, baseY), width: boltW + 6, height: 6),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF78716C),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, baseY - shaftH / 2 - 3), width: 4, height: shaftH),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFA8A29E),
      );

      for (int n = 0; n < 3; n++) {
        final ny = baseY - 8 - n * (nutH + 3);
        final colorIdx = fills[b][n];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, ny), width: boltW, height: nutH),
            const Radius.circular(4),
          ),
          Paint()..color = _colors[colorIdx],
        );
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
          colors: [Color(0xFF78716C), Color(0xFF57534E)],
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
        text: 'NUTS & BOLTS',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.09,
          letterSpacing: 0.4,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.30), offset: const Offset(0, 1), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  @override
  bool shouldRepaint(_NutsAndBoltsLogoPainter old) => false;
}
