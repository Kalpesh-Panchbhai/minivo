import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/animated_background.dart';
import '../shared/living_icons_group4.dart';

Widget buildDodgeBallLogo(double size) => buildDodgeBallLivingLogo(size);

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
