import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/animated_background.dart';
import '../shared/game_logo_scaffold.dart';

Widget buildDodgeBallLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Dodge Ball',
      bg: const [Color(0xFF0E4D64), Color(0xFF062C3A)],
      accent: const Color(0xFF22D3EE),
      art: _dodgeBallArt,
    );

void _dodgeBallArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;
  final cx = zone.center.dx;
  final cy = zone.center.dy;

  final playerR = w * 0.10;
  final playerC = Offset(cx - w * 0.06, cy + h * 0.04);

  canvas.drawCircle(
    playerC,
    playerR * 1.8,
    Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawCircle(
    playerC,
    playerR,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          const Color(0xFFCFFAFE),
          const Color(0xFF22D3EE),
          const Color(0xFF0E7490),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: playerC, radius: playerR)),
  );
  canvas.drawCircle(
    playerC.translate(-playerR * 0.25, -playerR * 0.25),
    playerR * 0.22,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );

  const ballColor = Color(0xFFEF4444);
  final balls = <(Offset, double, Offset)>[
    (Offset(cx + w * 0.32, cy - h * 0.30), w * 0.07, Offset(-1.0, 1.0)),
    (Offset(cx - w * 0.30, cy - h * 0.22), w * 0.06, Offset(1.0, 0.8)),
    (Offset(cx + w * 0.22, cy + h * 0.32), w * 0.055, Offset(-0.8, -1.0)),
  ];

  for (final (center, r, dir) in balls) {
    final linePaint = Paint()
      ..color = ballColor.withValues(alpha: 0.25)
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;
    for (int i = 1; i <= 3; i++) {
      final off = Offset(dir.dx * r * 0.5 * i, dir.dy * r * 0.5 * i);
      canvas.drawLine(
        center + off,
        center + off + Offset(dir.dx * r * 0.4, dir.dy * r * 0.4),
        linePaint..color = ballColor.withValues(alpha: 0.3 / i),
      );
    }

    canvas.drawCircle(
      center,
      r * 1.5,
      Paint()
        ..color = ballColor.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            const Color(0xFFFCA5A5),
            ballColor,
            const Color(0xFFB91C1C),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center.translate(-r * 0.28, -r * 0.28),
      r * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.50),
    );
  }
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
