import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildHangmanLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Hangman',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      art: _hangmanArt,
    );

void _hangmanArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;

  final framePaint = Paint()
    ..color = const Color(0xFFC7D2FE)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.05
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final baseY = zone.top + h * 0.78;
  final topY = zone.top + h * 0.06;
  final postX = zone.left + w * 0.24;
  final beamEndX = zone.left + w * 0.60;

  canvas.drawLine(
    Offset(zone.left + w * 0.08, baseY),
    Offset(zone.left + w * 0.48, baseY),
    framePaint,
  );
  canvas.drawLine(Offset(postX, baseY), Offset(postX, topY), framePaint);
  canvas.drawLine(Offset(postX, topY), Offset(beamEndX, topY), framePaint);

  final ropeTop = Offset(beamEndX, topY);
  final ropeLen = h * 0.12;
  final ropeBot = Offset(beamEndX, topY + ropeLen);
  canvas.drawLine(
    ropeTop,
    ropeBot,
    Paint()
      ..color = const Color(0xFFFCD34D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.032
      ..strokeCap = StrokeCap.round,
  );

  final headR = h * 0.065;
  final headC = Offset(beamEndX, ropeBot.dy + headR);
  canvas.drawCircle(
    headC,
    headR,
    Paint()
      ..color = const Color(0xFFE0E7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04,
  );

  final bodyPaint = Paint()
    ..color = const Color(0xFFE0E7FF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.035
    ..strokeCap = StrokeCap.round;

  final neckY = headC.dy + headR;
  final bodyBotY = neckY + h * 0.18;
  canvas.drawLine(Offset(beamEndX, neckY), Offset(beamEndX, bodyBotY), bodyPaint);

  final armY = neckY + h * 0.06;
  final armSpan = w * 0.12;
  canvas.drawLine(
    Offset(beamEndX - armSpan, armY + h * 0.06),
    Offset(beamEndX + armSpan, armY + h * 0.06),
    bodyPaint,
  );
  canvas.drawLine(
    Offset(beamEndX, armY),
    Offset(beamEndX - armSpan, armY + h * 0.06),
    bodyPaint,
  );
  canvas.drawLine(
    Offset(beamEndX, armY),
    Offset(beamEndX + armSpan, armY + h * 0.06),
    bodyPaint,
  );

  final legSpan = w * 0.10;
  final legLen = h * 0.12;
  canvas.drawLine(
    Offset(beamEndX, bodyBotY),
    Offset(beamEndX - legSpan, bodyBotY + legLen),
    bodyPaint,
  );
  canvas.drawLine(
    Offset(beamEndX, bodyBotY),
    Offset(beamEndX + legSpan, bodyBotY + legLen),
    bodyPaint,
  );

  const slots = ['_', '_', '_', '_'];
  final slotW = w * 0.12;
  final slotGap = w * 0.04;
  final totalW = slots.length * slotW + (slots.length - 1) * slotGap;
  final startX = zone.center.dx - totalW / 2;
  final lineY = zone.bottom - h * 0.02;

  final underline = Paint()
    ..color = Colors.white.withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.03
    ..strokeCap = StrokeCap.round;

  for (int i = 0; i < slots.length; i++) {
    final sx = startX + i * (slotW + slotGap);
    canvas.drawLine(Offset(sx, lineY), Offset(sx + slotW, lineY), underline);
  }
}
