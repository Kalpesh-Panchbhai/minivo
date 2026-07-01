import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildGoLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Go',
      bg: const [Color(0xFF44271A), Color(0xFF2A1810)],
      accent: const Color(0xFFCD7F32),
      art: _goArt,
    );

void _goArt(Canvas canvas, Rect zone) {
  final w = zone.width;

  final boardRect = Rect.fromCenter(
    center: zone.center,
    width: w * 0.92,
    height: w * 0.92,
  );
  final board = RRect.fromRectAndRadius(boardRect, Radius.circular(w * 0.05));
  canvas.drawRRect(
    board,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE7B66E), Color(0xFFD49B4E)],
      ).createShader(boardRect),
  );
  canvas.drawRRect(
    board,
    Paint()
      ..color = const Color(0xFF7A4F23)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.02,
  );

  const n = 4;
  final margin = boardRect.width * 0.14;
  final inner = boardRect.width - margin * 2;
  final step = inner / (n - 1);
  final originX = boardRect.left + margin;
  final originY = boardRect.top + margin;

  double gx(int c) => originX + c * step;
  double gy(int r) => originY + r * step;

  final linePaint = Paint()
    ..color = const Color(0xFF5A3A18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.010;

  for (int i = 0; i < n; i++) {
    canvas.drawLine(Offset(gx(i), gy(0)), Offset(gx(i), gy(n - 1)), linePaint);
    canvas.drawLine(Offset(gx(0), gy(i)), Offset(gx(n - 1), gy(i)), linePaint);
  }

  final starPaint = Paint()..color = const Color(0xFF4A2E12);
  final starR = w * 0.016;
  canvas.drawCircle(Offset(gx(1), gy(1)), starR, starPaint);
  canvas.drawCircle(Offset(gx(2), gy(2)), starR, starPaint);

  final stoneR = step * 0.40;

  void stone(int r, int c, bool black, {bool justPlaced = false}) {
    final ctr = Offset(gx(c), gy(r));
    if (justPlaced) {
      canvas.drawCircle(
        ctr.translate(stoneR * 0.06, stoneR * 0.25),
        stoneR * 1.15,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    } else {
      canvas.drawCircle(
        ctr.translate(0, stoneR * 0.15),
        stoneR,
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
    }
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
    canvas.drawCircle(
      ctr.translate(-stoneR * 0.28, -stoneR * 0.28),
      stoneR * 0.14,
      Paint()..color = Colors.white.withValues(alpha: black ? 0.22 : 0.50),
    );
  }

  stone(0, 1, true);
  stone(0, 2, true);
  stone(1, 0, true);
  stone(1, 1, true);
  stone(2, 2, true, justPlaced: true);

  stone(0, 3, false);
  stone(1, 2, false);
  stone(1, 3, false);
  stone(2, 1, false);
  stone(2, 3, false);
}
