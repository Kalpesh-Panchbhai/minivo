import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildHangmanLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Hangman',
      bg: const [Color(0xFF3730A3), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      art: _hangmanArt,
    );

void _hangmanArt(Canvas canvas, Rect zone) {
  final w = zone.width;

  // Gallows frame.
  final framePaint = Paint()
    ..color = const Color(0xFFC7D2FE)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.05
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final baseY = zone.top + zone.height * 0.74;
  final topY = zone.top + zone.height * 0.06;
  final postX = zone.left + w * 0.22;
  final beamEndX = zone.left + w * 0.62;

  canvas.drawLine(Offset(zone.left + w * 0.1, baseY),
      Offset(zone.left + w * 0.5, baseY), framePaint); // base
  canvas.drawLine(Offset(postX, baseY), Offset(postX, topY), framePaint); // post
  canvas.drawLine(Offset(postX, topY), Offset(beamEndX, topY), framePaint); // beam

  // Rope.
  final ropeTop = Offset(beamEndX, topY);
  final ropeBot = Offset(beamEndX, topY + zone.height * 0.14);
  canvas.drawLine(
      ropeTop,
      ropeBot,
      Paint()
        ..color = const Color(0xFFFCD34D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round);

  // Small round head.
  final headR = zone.height * 0.07;
  canvas.drawCircle(
    Offset(beamEndX, ropeBot.dy + headR),
    headR,
    Paint()
      ..color = const Color(0xFFE0E7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04,
  );

  // Blanks with letters "_ _ A _" below.
  const slots = ['', '', 'A', ''];
  final slotW = w * 0.16;
  final slotGap = w * 0.05;
  final totalW = slots.length * slotW + (slots.length - 1) * slotGap;
  final startX = zone.center.dx - totalW / 2;
  final lineY = zone.bottom - zone.height * 0.02;

  final underline = Paint()
    ..color = Colors.white.withValues(alpha: 0.9)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.03
    ..strokeCap = StrokeCap.round;

  for (int i = 0; i < slots.length; i++) {
    final sx = startX + i * (slotW + slotGap);
    canvas.drawLine(Offset(sx, lineY), Offset(sx + slotW, lineY), underline);
    if (slots[i].isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: slots[i],
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: slotW * 1.0,
              height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(sx + slotW / 2 - tp.width / 2, lineY - tp.height - w * 0.02),
      );
    }
  }
}
