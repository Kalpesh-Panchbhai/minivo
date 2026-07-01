import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildDinoRunLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Dino Run',
      bg: const [Color(0xFF374151), Color(0xFF111827)],
      accent: const Color(0xFF9CA3AF),
      art: _dinoRunArt,
    );

void _dinoRunArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;
  const dino = Color(0xFFE5E7EB);
  const ground = Color(0xFF9CA3AF);

  final groundY = zone.bottom - h * 0.12;
  canvas.drawLine(
    Offset(zone.left, groundY),
    Offset(zone.right, groundY),
    Paint()
      ..color = ground
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round,
  );
  final dashPaint = Paint()
    ..color = ground.withValues(alpha: 0.4)
    ..strokeWidth = w * 0.012;
  for (double x = zone.left + w * 0.05; x < zone.right - w * 0.1; x += w * 0.2) {
    canvas.drawLine(
      Offset(x, groundY + w * 0.05),
      Offset(x + w * 0.08, groundY + w * 0.05),
      dashPaint,
    );
  }

  final dinoX = zone.left + w * 0.08;
  final s = w * 0.034;
  drawPixelDino(canvas, dinoX, groundY, s, dino, const Color(0xFF1F2937));

  final cactusPaint = Paint()..color = ground;
  final cx = zone.right - w * 0.22;
  final trunkW = w * 0.05;
  final trunkH = w * 0.28;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - trunkW / 2, groundY - trunkH, trunkW, trunkH),
      Radius.circular(trunkW * 0.4),
    ),
    cactusPaint,
  );
  final armW = w * 0.04;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
          cx + trunkW / 2, groundY - trunkH * 0.75, armW, trunkH * 0.45),
      Radius.circular(armW * 0.5),
    ),
    cactusPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - trunkW / 2 - armW, groundY - trunkH * 0.6, armW,
          trunkH * 0.35),
      Radius.circular(armW * 0.5),
    ),
    cactusPaint,
  );
}

void drawPixelDino(Canvas canvas, double x, double groundY, double s,
    Color fg, Color bg,
    {bool dead = false,
    bool blink = false,
    double? legPhase,
    bool inAir = false}) {
  const body = [
    8, 0, 9, 0, 10, 0, 11, 0, 12, 0, 13, 0,
    7, 1, 8, 1, 9, 1, 10, 1, 11, 1, 12, 1, 13, 1, 14, 1,
    7, 2, 8, 2, 9, 2, 10, 2, 11, 2, 12, 2, 13, 2, 14, 2,
    7, 3, 8, 3, 9, 3, 10, 3, 11, 3, 12, 3, 13, 3, 14, 3,
    7, 4, 8, 4, 9, 4, 10, 4, 11, 4, 12, 4, 13, 4, 14, 4,
    7, 5, 8, 5, 9, 5, 10, 5, 11, 5, 12, 5, 13, 5, 14, 5,
    7, 6, 8, 6, 9, 6, 10, 6, 11, 6,
    6, 7, 7, 7, 8, 7, 9, 7, 10, 7, 11, 7, 12, 7, 13, 7, 14, 7, 15, 7,
    5, 8, 6, 8, 7, 8, 8, 8, 9, 8, 10, 8,
    4, 9, 5, 9, 6, 9, 7, 9, 8, 9, 9, 9, 10, 9, 13, 9, 14, 9,
    3, 10, 4, 10, 5, 10, 6, 10, 7, 10, 8, 10, 9, 10, 10, 10, 13, 10,
    2, 11, 3, 11, 4, 11, 5, 11, 6, 11, 7, 11, 8, 11, 9, 11, 10, 11, 11, 11,
    1, 12, 2, 12, 3, 12, 4, 12, 5, 12, 6, 12, 7, 12, 8, 12, 9, 12, 10, 12, 11, 12,
    0, 13, 1, 13, 2, 13, 3, 13, 4, 13, 5, 13, 6, 13, 7, 13, 8, 13, 9, 13, 10, 13,
    0, 14, 1, 14, 2, 14, 3, 14, 4, 14, 5, 14, 6, 14, 7, 14, 8, 14, 9, 14, 10, 14, 11, 14,
    1, 15, 2, 15, 3, 15, 4, 15, 5, 15, 6, 15, 7, 15, 8, 15, 9, 15, 10, 15,
    2, 16, 3, 16, 5, 16, 6, 16, 7, 16, 8, 16, 9, 16,
    3, 17, 5, 17, 6, 17, 7, 17, 8, 17,
  ];

  const legsStand = [
    6, 18, 7, 18, 6, 19, 7, 19, 6, 20,
    9, 18, 10, 18, 9, 19, 10, 19, 10, 20,
  ];
  const legsA = [
    6, 18, 7, 18, 6, 19, 7, 19, 6, 20, 7, 20,
    9, 18, 10, 18, 10, 19,
  ];
  const legsB = [
    6, 18, 7, 18, 7, 19,
    9, 18, 10, 18, 9, 19, 10, 19, 9, 20, 10, 20,
  ];

  final path = Path();
  for (int i = 0; i < body.length; i += 2) {
    path.addRect(Rect.fromLTWH(
        x + body[i] * s, groundY - (21 - body[i + 1]) * s, s, s));
  }

  final legs = (inAir || legPhase == null)
      ? legsStand
      : ((legPhase % 6.2832) < 3.1416 ? legsA : legsB);
  for (int i = 0; i < legs.length; i += 2) {
    path.addRect(Rect.fromLTWH(
        x + legs[i] * s, groundY - (21 - legs[i + 1]) * s, s, s));
  }

  canvas.drawPath(path, Paint()..color = fg);

  const eyeX = 13, eyeY = 1;
  final ex = x + eyeX * s;
  final ey = groundY - (21 - eyeY) * s;
  if (dead) {
    final xp = Paint()
      ..color = bg
      ..strokeWidth = s * 0.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(ex, ey), Offset(ex + s, ey + s), xp);
    canvas.drawLine(Offset(ex + s, ey), Offset(ex, ey + s), xp);
  } else if (blink) {
    canvas.drawRect(
        Rect.fromLTWH(ex, ey + s * 0.4, s, s * 0.2), Paint()..color = bg);
  } else {
    canvas.drawRect(Rect.fromLTWH(ex, ey, s, s), Paint()..color = bg);
  }
}
