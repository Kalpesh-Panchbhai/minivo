import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildColorTapLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Color Tap',
      bg: const [Color(0xFF7C2D12), Color(0xFF431407)],
      accent: const Color(0xFFFB923C),
      art: _colorTapArt,
    );

void _colorTapArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final cx = zone.center.dx;
  final cy = zone.center.dy;

  final r = w * 0.19;
  final gap = w * 0.04;

  final colors = [
    const Color(0xFFEF4444),
    const Color(0xFF3B82F6),
    const Color(0xFF22C55E),
    const Color(0xFFFACC15),
  ];
  final centers = [
    Offset(cx - r - gap / 2, cy - r - gap / 2),
    Offset(cx + r + gap / 2, cy - r - gap / 2),
    Offset(cx - r - gap / 2, cy + r + gap / 2),
    Offset(cx + r + gap / 2, cy + r + gap / 2),
  ];

  const activeIdx = 1;

  for (int i = 0; i < 4; i++) {
    final c = centers[i];
    final color = colors[i];

    canvas.drawCircle(
      c.translate(0, r * 0.06),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    if (i == activeIdx) {
      for (int ring = 3; ring >= 1; ring--) {
        canvas.drawCircle(
          c,
          r + r * 0.15 * ring,
          Paint()
            ..color = color.withValues(alpha: 0.12 * (4 - ring))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            Color.lerp(color, Colors.white, 0.40)!,
            color,
            Color.lerp(color, Colors.black, 0.20)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.drawCircle(
      c.translate(-r * 0.28, -r * 0.28),
      r * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  final tapC = centers[activeIdx];
  for (int j = 1; j <= 2; j++) {
    canvas.drawCircle(
      tapC,
      r * 0.45 * j,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55 / j)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022 / j,
    );
  }
  canvas.drawCircle(
    tapC,
    w * 0.035,
    Paint()..color = Colors.white.withValues(alpha: 0.70),
  );
}
