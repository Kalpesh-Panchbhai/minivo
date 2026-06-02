import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/animated_background.dart';

Widget buildDodgeBallLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F0F23), Color(0xFF1A1A3E)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: ClipRect(
      child: CustomPaint(
        size: Size(size, size),
        painter: _DodgeBallLogoPainter(),
      ),
    ),
  );
}

class _DodgeBallLogoPainter extends CustomPainter {
  static const _obsColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFFFF9FF3),
    Color(0xFF6BCB77),
    Color(0xFFCC8EFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;

    const playerColor = Color(0xFF00D4FF);

    final rng = math.Random(42);
    for (int i = 0; i < 12; i++) {
      final sx = rng.nextDouble() * s;
      final sy = rng.nextDouble() * s * 0.6;
      canvas.drawCircle(
        Offset(sx, sy),
        0.8 + rng.nextDouble() * 0.5,
        Paint()..color = Colors.white.withValues(alpha: 0.15),
      );
    }

    final playerR = s * 0.10;
    final playerY = s * 0.70;
    canvas.drawCircle(
      Offset(cx, playerY),
      playerR + 6,
      Paint()
        ..color = playerColor.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final pGrad = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      colors: [const Color(0xFF66E5FF), playerColor, const Color(0xFF0099CC)],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(
      Offset(cx, playerY),
      playerR,
      Paint()..shader = pGrad.createShader(Rect.fromCircle(center: Offset(cx, playerY), radius: playerR)),
    );
    canvas.drawCircle(
      Offset(cx - playerR * 0.22, playerY - playerR * 0.22),
      playerR * 0.25,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    final positions = [
      Offset(s * 0.22, s * 0.18),
      Offset(s * 0.68, s * 0.13),
      Offset(s * 0.42, s * 0.35),
      Offset(s * 0.80, s * 0.30),
      Offset(s * 0.15, s * 0.45),
    ];
    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final color = _obsColors[i];
      final obsR = s * 0.055;

      canvas.drawCircle(
        pos,
        obsR + 4,
        Paint()
          ..color = color.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(pos, obsR, Paint()..color = color);
      canvas.drawCircle(
        Offset(pos.dx - obsR * 0.25, pos.dy - obsR * 0.25),
        obsR * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.30),
      );
    }

    final fontSize = s * 0.10;
    final tp = TextPainter(
      text: TextSpan(
        text: 'DODGE BALL',
        style: TextStyle(
          color: playerColor,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((s - tp.width) / 2, s - tp.height - s * 0.04),
    );
  }

  @override
  bool shouldRepaint(_DodgeBallLogoPainter old) => false;
}

class DodgeBallBgPainter extends AnimatedBgPainter {
  const DodgeBallBgPainter(super.t);

  static const _colors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFFFF9FF3),
    Color(0xFF6BCB77),
    Color(0xFFCC8EFF),
  ];

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    const fg = Color(0xFF00D4FF);

    final playerR = w * 0.035;
    final playerX = w * 0.5 + math.sin(t * 2 * math.pi) * w * 0.2;
    final playerY = h * 0.82;
    canvas.drawCircle(
      Offset(playerX, playerY),
      playerR,
      Paint()..color = fg.withValues(alpha: 0.06),
    );

    for (int i = 0; i < 5; i++) {
      final ox = w * (0.1 + i * 0.2);
      final oy = ((t + i * 0.2) % 1.0) * h * 0.75;
      canvas.drawCircle(
        Offset(ox, oy),
        w * 0.02,
        Paint()..color = _colors[i].withValues(alpha: 0.06),
      );
    }
  }
}
