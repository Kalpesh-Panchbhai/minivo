import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/animated_background.dart';
import '../shared/living_icons_group3.dart';

Widget buildDropMergeLogo(double size) => buildDropMergeLivingLogo(size);

class DropMergeBgPainter extends AnimatedBgPainter {
  const DropMergeBgPainter(super.t);

  static const _items = <(double, double, double, double, int)>[
    (0.08, 0.10, 30, 0.0, 2),
    (0.82, 0.06, 24, 0.8, 4),
    (0.15, 0.55, 20, 1.6, 8),
    (0.88, 0.42, 28, 2.4, 16),
    (0.05, 0.80, 22, 3.2, 4),
    (0.74, 0.88, 18, 4.0, 2),
    (0.50, 0.03, 16, 4.8, 8),
    (0.40, 0.94, 22, 5.6, 32),
    (0.92, 0.65, 14, 1.2, 2),
    (0.04, 0.44, 18, 3.7, 16),
  ];

  static const _tileColors = {
    2: Color(0xFFFFF3BF),
    4: Color(0xFFFFE066),
    8: Color(0xFFFFA94D),
    16: Color(0xFFFF6B6B),
    32: Color(0xFFE64980),
  };

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    for (final (xRel, yRel, tileSize, itemPhase, value) in _items) {
      final bobY = math.sin(phase + itemPhase * 0.6) * (tileSize * 0.25);
      final rot = math.sin(phase * 0.4 + itemPhase) * 0.12;
      final alpha = 0.05 + (math.sin(phase * 1.2 + itemPhase) + 1) / 2 * 0.06;
      final cx = w * xRel;
      final cy = h * yRel + bobY;
      final color = (_tileColors[value] ?? const Color(0xFFFFF3BF))
          .withValues(alpha: alpha);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-tileSize / 2, -tileSize / 2, tileSize, tileSize),
          const Radius.circular(5),
        ),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }
}
