import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildGomokuLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Gomoku',
      bg: const [Color(0xFF1E3A5F), Color(0xFF0C1F3A)],
      accent: const Color(0xFF60A5FA),
      art: _gomokuArt,
    );

void _gomokuArt(Canvas canvas, Rect zone) {
  final w = zone.width;

  const n = 7;
  final margin = w * 0.08;
  final inner = w - margin * 2;
  final step = inner / (n - 1);
  final originX = zone.left + margin;
  final originY = zone.top + margin;

  double gx(int c) => originX + c * step;
  double gy(int r) => originY + r * step;

  final linePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.007;

  for (int i = 0; i < n; i++) {
    canvas.drawLine(Offset(gx(i), gy(0)), Offset(gx(i), gy(n - 1)), linePaint);
    canvas.drawLine(Offset(gx(0), gy(i)), Offset(gx(n - 1), gy(i)), linePaint);
  }

  final stoneR = step * 0.38;

  void stone(int r, int c, bool black, {bool glow = false}) {
    final ctr = Offset(gx(c), gy(r));
    canvas.drawCircle(
      ctr.translate(0, stoneR * 0.15),
      stoneR,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    if (glow) {
      canvas.drawCircle(
        ctr,
        stoneR * 1.6,
        Paint()
          ..color = const Color(0xFFFBBF24).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawCircle(
      ctr,
      stoneR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: black
              ? const [Color(0xFF4B4B4B), Color(0xFF0A0A0A)]
              : const [Colors.white, Color(0xFFCBD5E1)],
        ).createShader(Rect.fromCircle(center: ctr, radius: stoneR)),
    );
    canvas.drawCircle(
      ctr.translate(-stoneR * 0.3, -stoneR * 0.3),
      stoneR * 0.15,
      Paint()..color = Colors.white.withValues(alpha: black ? 0.25 : 0.50),
    );
  }

  final winStart = Offset(gx(1), gy(1));
  final winEnd = Offset(gx(5), gy(5));
  canvas.drawLine(
    winStart,
    winEnd,
    Paint()
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.45)
      ..strokeWidth = stoneR * 0.8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );
  canvas.drawLine(
    winStart,
    winEnd,
    Paint()
      ..color = const Color(0xFFFCD34D).withValues(alpha: 0.70)
      ..strokeWidth = stoneR * 0.25
      ..strokeCap = StrokeCap.round,
  );

  for (int i = 0; i < 5; i++) {
    stone(1 + i, 1 + i, true, glow: i == 2);
  }

  stone(2, 4, false);
  stone(4, 2, false);
  stone(1, 4, false);
  stone(5, 3, false);
}
