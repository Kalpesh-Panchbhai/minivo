import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildFlappyTapLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Flappy Tap',
      bg: const [Color(0xFF0E7490), Color(0xFF083344)],
      accent: const Color(0xFF22D3EE),
      art: _flappyTapArt,
    );

void _flappyTapArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final pipeW = w * 0.2;
  const pipeColor = Color(0xFF34D399);
  const pipeDark = Color(0xFF059669);
  const pipeLight = Color(0xFF6EE7B7);

  void pipe(double left, double top, double height, {required bool capAtTop}) {
    final body = Rect.fromLTWH(left, top, pipeW, height);
    canvas.drawRect(body, Paint()..color = pipeColor);
    // Vertical light edge.
    canvas.drawRect(
      Rect.fromLTWH(left + pipeW * 0.12, top, pipeW * 0.18, height),
      Paint()..color = pipeLight,
    );
    // Cap on the gap-facing end.
    final capH = pipeW * 0.5;
    final capRect = capAtTop
        ? Rect.fromLTWH(left - pipeW * 0.12, top, pipeW * 1.24, capH)
        : Rect.fromLTWH(left - pipeW * 0.12, top + height - capH, pipeW * 1.24, capH);
    canvas.drawRect(capRect, Paint()..color = pipeDark);
    canvas.drawRect(
      Rect.fromLTWH(capRect.left + pipeW * 0.1, capRect.top, pipeW * 0.18, capH),
      Paint()..color = pipeLight,
    );
  }

  // Top pipe hangs from zone top; bottom pipe rises from zone bottom; gap in middle.
  final topPipeH = zone.height * 0.38;
  final bottomPipeTop = zone.top + zone.height * 0.62;
  final bottomPipeH = zone.bottom - bottomPipeTop;

  // Left pipe pair (cap faces the gap).
  final leftPipeX = zone.left + w * 0.08;
  pipe(leftPipeX, zone.top, topPipeH, capAtTop: false);
  pipe(leftPipeX, bottomPipeTop, bottomPipeH, capAtTop: true);

  // Right pipe pair.
  final rightPipeX = zone.right - w * 0.08 - pipeW;
  pipe(rightPipeX, zone.top, topPipeH * 0.85, capAtTop: false);
  pipe(rightPipeX, bottomPipeTop + zone.height * 0.05,
      bottomPipeH - zone.height * 0.05,
      capAtTop: true);

  // Round yellow bird, centred in the gap.
  final birdC = zone.center;
  final birdR = w * 0.16;
  // Body.
  canvas.drawCircle(birdC, birdR, Paint()..color = const Color(0xFFFBBF24));
  // Belly highlight.
  canvas.drawCircle(
    birdC.translate(birdR * 0.18, birdR * 0.18),
    birdR * 0.6,
    Paint()..color = const Color(0xFFFDE68A),
  );
  // Body outline.
  canvas.drawCircle(
    birdC,
    birdR,
    Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012,
  );
  // Wing.
  final wing = Path()
    ..moveTo(birdC.dx - birdR * 0.1, birdC.dy)
    ..quadraticBezierTo(birdC.dx - birdR * 0.9, birdC.dy - birdR * 0.3,
        birdC.dx - birdR * 0.7, birdC.dy + birdR * 0.5)
    ..quadraticBezierTo(birdC.dx - birdR * 0.3, birdC.dy + birdR * 0.3,
        birdC.dx - birdR * 0.1, birdC.dy)
    ..close();
  canvas.drawPath(wing, Paint()..color = const Color(0xFFF59E0B));
  // Beak (small, pointing right).
  final beak = Path()
    ..moveTo(birdC.dx + birdR * 0.8, birdC.dy - birdR * 0.12)
    ..lineTo(birdC.dx + birdR * 1.35, birdC.dy)
    ..lineTo(birdC.dx + birdR * 0.8, birdC.dy + birdR * 0.18)
    ..close();
  canvas.drawPath(beak, Paint()..color = const Color(0xFFF97316));
  // Eye.
  final eyeC = birdC.translate(birdR * 0.35, -birdR * 0.3);
  canvas.drawCircle(eyeC, birdR * 0.28, Paint()..color = Colors.white);
  canvas.drawCircle(eyeC.translate(birdR * 0.06, 0), birdR * 0.14,
      Paint()..color = const Color(0xFF111827));
}
