import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildGoLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Go',
      bg: const [Color(0xFF5C3A21), Color(0xFF2A1A0F)],
      accent: const Color(0xFFE0B873),
      art: _GoArt,
    );

// ignore: non_constant_identifier_names
void _GoArt(Canvas canvas, Rect zone) {
  // Wooden board panel.
  final board = RRect.fromRectAndRadius(zone, Radius.circular(zone.width * 0.06));
  canvas.drawRRect(
    board,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE7B66E), Color(0xFFD49B4E)],
      ).createShader(zone),
  );
  canvas.drawRRect(
    board,
    Paint()
      ..color = const Color(0xFF7A4F23)
      ..style = PaintingStyle.stroke
      ..strokeWidth = zone.width * 0.02,
  );

  // 5x5 intersection grid.
  const n = 5;
  final margin = zone.width * 0.14;
  final inner = zone.width - margin * 2;
  final step = inner / (n - 1);
  final originX = zone.left + margin;
  final originY = zone.top + margin;

  double gx(int c) => originX + c * step;
  double gy(int r) => originY + r * step;

  final linePaint = Paint()
    ..color = const Color(0xFF5A3A18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = zone.width * 0.012;

  for (int i = 0; i < n; i++) {
    canvas.drawLine(Offset(gx(i), gy(0)), Offset(gx(i), gy(n - 1)), linePaint);
    canvas.drawLine(Offset(gx(0), gy(i)), Offset(gx(n - 1), gy(i)), linePaint);
  }

  // Star points (hoshi): center + two corners.
  final starPaint = Paint()..color = const Color(0xFF4A2E12);
  final starR = zone.width * 0.018;
  for (final sp in const [
    [2, 2],
    [0, 0],
    [4, 4],
  ]) {
    canvas.drawCircle(Offset(gx(sp[1]), gy(sp[0])), starR, starPaint);
  }

  // Stones on intersections.
  final stoneR = step * 0.42;
  void stone(int r, int c, bool black) {
    final ctr = Offset(gx(c), gy(r));
    canvas.drawCircle(ctr.translate(0, stoneR * 0.18), stoneR,
        Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawCircle(
      ctr,
      stoneR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: black
              ? const [Color(0xFF555555), Color(0xFF0A0A0A)]
              : const [Colors.white, Color(0xFFC9C9C9)],
        ).createShader(Rect.fromCircle(center: ctr, radius: stoneR)),
    );
  }

  // A small cluster of black and white stones.
  stone(1, 1, true);
  stone(1, 2, false);
  stone(2, 2, true);
  stone(2, 1, false);
  stone(3, 3, true);
  stone(2, 3, false);
}
