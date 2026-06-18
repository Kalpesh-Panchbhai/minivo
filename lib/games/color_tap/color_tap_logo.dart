import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildColorTapLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Color Tap',
      bg: const [Color(0xFF7C2D12), Color(0xFF2A0E04)],
      accent: const Color(0xFFFB923C),
      art: _colorTapArt,
    );

void _colorTapArt(Canvas canvas, Rect zone) {
  final w = zone.width;

  // A few overlapping bright targets (concentric rings) in a cluster.
  // Each entry: center offset (relative to zone, 0..1) and base color.
  final targets = <(double, double, Color)>[
    (0.34, 0.36, const Color(0xFFEF4444)), // red
    (0.66, 0.34, const Color(0xFF3B82F6)), // blue
    (0.52, 0.62, const Color(0xFFFACC15)), // yellow
    (0.30, 0.66, const Color(0xFF22C55E)), // green
  ];

  void target(double fx, double fy, Color color, double r) {
    final c = Offset(zone.left + w * fx, zone.top + w * fy);
    // Shadow.
    canvas.drawCircle(c.translate(0, r * 0.12), r, Paint()..color = Colors.black.withValues(alpha: 0.20));
    // Outer ring.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [Color.lerp(color, Colors.white, 0.35)!, color],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Middle ring (white).
    canvas.drawCircle(c, r * 0.62, Paint()..color = Colors.white.withValues(alpha: 0.92));
    // Inner dot.
    canvas.drawCircle(c, r * 0.30, Paint()..color = color);
    // Specular highlight.
    canvas.drawCircle(
      c.translate(-r * 0.32, -r * 0.32),
      r * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  // Draw larger targets first so smaller ones layer on top for overlap depth.
  target(targets[0].$1, targets[0].$2, targets[0].$3, w * 0.26);
  target(targets[1].$1, targets[1].$2, targets[1].$3, w * 0.22);
  target(targets[3].$1, targets[3].$2, targets[3].$3, w * 0.18);
  target(targets[2].$1, targets[2].$2, targets[2].$3, w * 0.20);

  // Small tap-ripple ring emanating near the cluster.
  final rippleC = Offset(zone.left + w * 0.7, zone.top + w * 0.66);
  for (int j = 1; j <= 2; j++) {
    canvas.drawCircle(
      rippleC,
      w * 0.06 * j,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5 / j)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02 / j,
    );
  }
  canvas.drawCircle(rippleC, w * 0.03, Paint()..color = const Color(0xFFFB923C));
}
