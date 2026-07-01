import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildMemoryMatchLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Memory Match',
      bg: const [Color(0xFF1E3A5F), Color(0xFF0C1F3A)],
      accent: const Color(0xFF60A5FA),
      art: _memoryMatchArt,
    );

void _memoryMatchArt(Canvas canvas, Rect zone) {
  final cx = zone.center.dx;
  final cy = zone.center.dy;
  final cardW = zone.width * 0.36;
  final cardH = zone.height * 0.52;
  final gap = zone.width * 0.06;
  final r = Radius.circular(cardW * 0.12);

  void drawCardShadow(Rect rect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0, 2.5)), r),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  final leftRect = Rect.fromCenter(
    center: Offset(cx - cardW / 2 - gap / 2, cy),
    width: cardW,
    height: cardH,
  );
  drawCardShadow(leftRect);

  final leftRR = RRect.fromRectAndRadius(leftRect, r);
  canvas.drawRRect(leftRR, Paint()..color = const Color(0xFF2563EB));
  canvas.drawRRect(
    leftRR,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cardW * 0.03,
  );

  final innerInset = cardW * 0.10;
  final innerRect = leftRect.deflate(innerInset);
  final innerRR = RRect.fromRectAndRadius(innerRect, Radius.circular(cardW * 0.06));
  canvas.drawRRect(
    innerRR,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cardW * 0.02,
  );

  final diagPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.06)
    ..strokeWidth = cardW * 0.015;
  final diagStep = cardW * 0.14;
  canvas.save();
  canvas.clipRRect(innerRR);
  for (double d = -cardH; d < cardW + cardH; d += diagStep) {
    canvas.drawLine(
      Offset(innerRect.left + d, innerRect.top),
      Offset(innerRect.left + d - cardH, innerRect.bottom),
      diagPaint,
    );
  }
  canvas.restore();

  final qTp = TextPainter(
    text: TextSpan(
      text: '?',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.90),
        fontWeight: FontWeight.w900,
        fontSize: cardH * 0.40,
        height: 1,
      ),
    ),
    textDirection: ui.TextDirection.ltr,
  )..layout();
  qTp.paint(
    canvas,
    Offset(
      leftRect.center.dx - qTp.width / 2,
      leftRect.center.dy - qTp.height / 2,
    ),
  );

  final rightRect = Rect.fromCenter(
    center: Offset(cx + cardW / 2 + gap / 2, cy),
    width: cardW,
    height: cardH,
  );
  drawCardShadow(rightRect);

  final rightRR = RRect.fromRectAndRadius(rightRect, r);
  canvas.drawRRect(rightRR, Paint()..color = const Color(0xFFF0F4FF));
  canvas.drawRRect(
    rightRR,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cardW * 0.03,
  );

  final starCx = rightRect.center.dx;
  final starCy = rightRect.center.dy;
  final starR = cardW * 0.28;
  final starPath = Path();
  for (int i = 0; i < 10; i++) {
    final rad = i.isEven ? starR : starR * 0.42;
    final angle = -math.pi / 2 + i * (math.pi / 5);
    final px = starCx + rad * math.cos(angle);
    final py = starCy + rad * math.sin(angle);
    if (i == 0) {
      starPath.moveTo(px, py);
    } else {
      starPath.lineTo(px, py);
    }
  }
  starPath.close();

  canvas.drawPath(
    starPath,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(starCx - starR * 0.2, starCy - starR * 0.2),
        starR * 1.2,
        [const Color(0xFFFDE68A), const Color(0xFFF59E0B)],
      ),
  );
  canvas.drawPath(
    starPath,
    Paint()
      ..color = const Color(0xFFD97706).withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cardW * 0.02,
  );
}
