import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildReversiLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Reversi',
      bg: const [Color(0xFF14532D), Color(0xFF052E16)],
      accent: const Color(0xFF4ADE80),
      art: _reversiArt,
    );

void _reversiArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final boardRect = Rect.fromCenter(
    center: zone.center,
    width: w * 0.92,
    height: w * 0.92,
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect, Radius.circular(w * 0.05)),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF22C55E), Color(0xFF15803D)],
      ).createShader(boardRect),
  );

  const n = 3;
  final cell = boardRect.width / n;

  final gridPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.30)
    ..strokeWidth = w * 0.014;
  for (int i = 1; i < n; i++) {
    final x = boardRect.left + i * cell;
    final y = boardRect.top + i * cell;
    canvas.drawLine(Offset(x, boardRect.top), Offset(x, boardRect.bottom), gridPaint);
    canvas.drawLine(Offset(boardRect.left, y), Offset(boardRect.right, y), gridPaint);
  }

  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect, Radius.circular(w * 0.05)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022,
  );

  final r = cell * 0.34;

  void disc(int col, int row, bool isBlack) {
    final c = Offset(
      boardRect.left + col * cell + cell / 2,
      boardRect.top + row * cell + cell / 2,
    );
    canvas.drawCircle(
      c.translate(0, r * 0.12),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: isBlack
              ? const [Color(0xFF4B5563), Color(0xFF1A1A1A)]
              : const [Colors.white, Color(0xFFD1D5DB)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c.translate(-r * 0.28, -r * 0.28),
      r * 0.15,
      Paint()..color = Colors.white.withValues(alpha: isBlack ? 0.28 : 0.55),
    );
  }

  disc(0, 0, true);
  disc(2, 0, false);
  disc(0, 2, false);
  disc(2, 2, true);
  disc(0, 1, false);
  disc(2, 1, true);

  final flipC = Offset(
    boardRect.left + 1 * cell + cell / 2,
    boardRect.top + 1 * cell + cell / 2,
  );
  canvas.drawCircle(
    flipC.translate(0, r * 0.12),
    r,
    Paint()..color = Colors.black.withValues(alpha: 0.25),
  );

  canvas.save();
  canvas.translate(flipC.dx, flipC.dy);
  canvas.transform(Matrix4.identity().storage
    ..[0] = 0.55
    ..[5] = 1.0
    ..[10] = 1.0
    ..[15] = 1.0);

  canvas.drawArc(
    Rect.fromCircle(center: Offset.zero, radius: r),
    -math.pi / 2,
    math.pi,
    true,
    Paint()..color = const Color(0xFF1A1A1A),
  );
  canvas.drawArc(
    Rect.fromCircle(center: Offset.zero, radius: r),
    math.pi / 2,
    math.pi,
    true,
    Paint()..color = const Color(0xFFE5E7EB),
  );

  canvas.drawCircle(
    Offset.zero,
    r,
    Paint()
      ..color = const Color(0xFF6B7280)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012,
  );
  canvas.restore();

  final flipTop = Offset(
    boardRect.left + 1 * cell + cell / 2,
    boardRect.top + 0 * cell + cell / 2,
  );
  canvas.drawCircle(
    flipTop.translate(0, r * 0.12),
    r,
    Paint()..color = Colors.black.withValues(alpha: 0.25),
  );
  canvas.drawCircle(
    flipTop,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: const [Color(0xFF4B5563), Color(0xFF1A1A1A)],
      ).createShader(Rect.fromCircle(center: flipTop, radius: r)),
  );
  canvas.drawCircle(
    flipTop.translate(-r * 0.28, -r * 0.28),
    r * 0.15,
    Paint()..color = Colors.white.withValues(alpha: 0.28),
  );

  final flipBot = Offset(
    boardRect.left + 1 * cell + cell / 2,
    boardRect.top + 2 * cell + cell / 2,
  );
  canvas.drawCircle(
    flipBot.translate(0, r * 0.12),
    r,
    Paint()..color = Colors.black.withValues(alpha: 0.25),
  );
  canvas.drawCircle(
    flipBot,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: const [Colors.white, Color(0xFFD1D5DB)],
      ).createShader(Rect.fromCircle(center: flipBot, radius: r)),
  );
  canvas.drawCircle(
    flipBot.translate(-r * 0.28, -r * 0.28),
    r * 0.15,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
}
