import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildGomokuLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Gomoku',
      bg: const [Color(0xFF1E3A8A), Color(0xFF0B1E4D)],
      accent: const Color(0xFF60A5FA),
      art: _GomokuArt,
    );

// ignore: non_constant_identifier_names
void _GomokuArt(Canvas canvas, Rect zone) {
  // Board panel.
  final board = RRect.fromRectAndRadius(zone, Radius.circular(zone.width * 0.06));
  canvas.drawRRect(
    board,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3B6BC9), Color(0xFF24477F)],
      ).createShader(zone),
  );
  canvas.drawRRect(
    board,
    Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = zone.width * 0.018,
  );

  // 6x6 intersection grid.
  const n = 6;
  final margin = zone.width * 0.13;
  final inner = zone.width - margin * 2;
  final step = inner / (n - 1);
  final originX = zone.left + margin;
  final originY = zone.top + margin;

  double gx(int c) => originX + c * step;
  double gy(int r) => originY + r * step;

  final linePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.22)
    ..style = PaintingStyle.stroke
    ..strokeWidth = zone.width * 0.008;

  for (int i = 0; i < n; i++) {
    canvas.drawLine(Offset(gx(i), gy(0)), Offset(gx(i), gy(n - 1)), linePaint);
    canvas.drawLine(Offset(gx(0), gy(i)), Offset(gx(n - 1), gy(i)), linePaint);
  }

  final stoneR = step * 0.40;

  // Winning line: five black stones across the middle row.
  const winRow = 2;
  final winStart = Offset(gx(0), gy(winRow));
  final winEnd = Offset(gx(4), gy(winRow));
  // Glow under the winning line.
  canvas.drawLine(
    winStart,
    winEnd,
    Paint()
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.55)
      ..strokeWidth = stoneR * 0.9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawLine(
    winStart,
    winEnd,
    Paint()
      ..color = const Color(0xFFFCD34D).withValues(alpha: 0.85)
      ..strokeWidth = stoneR * 0.30
      ..strokeCap = StrokeCap.round,
  );

  void stone(int r, int c, bool black) {
    final ctr = Offset(gx(c), gy(r));
    canvas.drawCircle(ctr.translate(0, stoneR * 0.18), stoneR,
        Paint()..color = Colors.black.withValues(alpha: 0.30));
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
  }

  // Five black stones in a row (the win).
  for (int c = 0; c < 5; c++) {
    stone(winRow, c, true);
  }

  // A few scattered white stones.
  stone(0, 1, false);
  stone(1, 3, false);
  stone(4, 2, false);
  stone(3, 4, false);
}
