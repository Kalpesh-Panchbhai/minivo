import 'dart:math' as math;

import 'package:flutter/material.dart';

Widget buildColorTapLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFF6B35), Color(0xFFFF922B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _ColorTapLogoPainter(),
    ),
  );
}

class _ColorTapLogoPainter extends CustomPainter {
  static const _orbitColors = [
    Color(0xFFEF4444), // red
    Color(0xFF3B82F6), // blue
    Color(0xFF22C55E), // green
    Color(0xFFEAB308), // yellow
    Color(0xFF8B5CF6), // purple
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.44;
    final r = size.width * 0.28;

    // Main circle — white gradient fill
    final mainGrad = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.70)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, mainGrad);

    // Tap icon in center (finger/hand icon drawn as a simplified shape)
    final tapPaint = Paint()
      ..color = const Color(0xFFFF6B35)
      ..style = PaintingStyle.fill;
    // Draw a simple tap circle + ripple
    canvas.drawCircle(Offset(cx, cy), r * 0.30, tapPaint);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.50,
      Paint()
        ..color = const Color(0xFFFF6B35).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06,
    );

    // Orbiting color dots
    final orbitR = r * 1.55;
    for (int i = 0; i < _orbitColors.length; i++) {
      final angle = (i / _orbitColors.length) * 2 * math.pi - math.pi / 2;
      final dx = cx + math.cos(angle) * orbitR;
      final dy = cy + math.sin(angle) * orbitR;
      final dotR = r * 0.18;
      // Shadow
      canvas.drawCircle(
        Offset(dx, dy + 1.5),
        dotR,
        Paint()..color = Colors.black.withValues(alpha: 0.15),
      );
      canvas.drawCircle(Offset(dx, dy), dotR, Paint()..color = _orbitColors[i]);
      // Highlight
      canvas.drawCircle(
        Offset(dx - dotR * 0.25, dy - dotR * 0.25),
        dotR * 0.30,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // "COLOR TAP" text at bottom
    final tp = TextPainter(
      text: TextSpan(
        text: 'COLOR TAP',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size.width * 0.13,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, size.height - tp.height - size.height * 0.04),
    );
  }

  @override
  bool shouldRepaint(_ColorTapLogoPainter old) => false;
}
