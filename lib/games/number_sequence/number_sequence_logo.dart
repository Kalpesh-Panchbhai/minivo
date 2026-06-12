import 'package:flutter/material.dart';

Widget buildNumberSequenceLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _NumberSequenceLogoPainter(),
    ),
  );
}

class _NumberSequenceLogoPainter extends CustomPainter {
  static const _kBg1 = Color(0xFF1E1B4B);
  static const _kBg2 = Color(0xFF312E81);
  static const _kAccent = Color(0xFF6366F1);

  static const _bubbleColors = [
    [Color(0xFF6366F1), Color(0xFF818CF8)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    [Color(0xFF06B6D4), Color(0xFF22D3EE)],
    [Color(0xFF10B981), Color(0xFF34D399)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFFEF4444), Color(0xFFF87171)],
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

    final positions = [
      [0.22, 0.20, 0, '1'],
      [0.65, 0.15, 1, '2'],
      [0.40, 0.38, 2, '3'],
      [0.78, 0.42, 3, '4'],
      [0.20, 0.55, 4, '5'],
      [0.55, 0.58, 5, '6'],
    ];

    for (final p in positions) {
      final cx = w * (p[0] as double);
      final cy = h * (p[1] as double);
      final colorIdx = p[2] as int;
      final label = p[3] as String;
      final r = w * 0.10;
      final colors = _bubbleColors[colorIdx];

      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );

      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = colors[0].withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: r * 0.9,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
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
          colors: [_kAccent, Color(0xFF4F46E5)],
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
        text: 'NUM SEQUENCE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.085,
          letterSpacing: 0.4,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.30), offset: const Offset(0, 1), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  @override
  bool shouldRepaint(_NumberSequenceLogoPainter old) => false;
}
