import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildMinesweeperLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Minesweeper',
      bg: const [Color(0xFF1E3A5F), Color(0xFF0C1F3A)],
      accent: const Color(0xFF60A5FA),
      art: _minesweeperArt,
    );

void _minesweeperArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;

  final mineCx = zone.left + w * 0.38;
  final mineCy = zone.top + h * 0.48;
  final mineR = w * 0.20;

  for (int i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    final spikeLen = mineR * 1.55;
    canvas.drawLine(
      Offset(mineCx, mineCy),
      Offset(mineCx + math.cos(angle) * spikeLen,
          mineCy + math.sin(angle) * spikeLen),
      Paint()
        ..color = const Color(0xFF111827)
        ..strokeWidth = w * 0.055
        ..strokeCap = StrokeCap.round,
    );
    final tipR = w * 0.032;
    canvas.drawCircle(
      Offset(mineCx + math.cos(angle) * spikeLen,
          mineCy + math.sin(angle) * spikeLen),
      tipR,
      Paint()..color = const Color(0xFF111827),
    );
  }

  canvas.drawCircle(Offset(mineCx, mineCy + mineR * 0.08), mineR, Paint()..color = Colors.black.withValues(alpha: 0.18));
  canvas.drawCircle(
    Offset(mineCx, mineCy),
    mineR,
    Paint()..color = const Color(0xFF111827),
  );
  canvas.drawCircle(
    Offset(mineCx - mineR * 0.30, mineCy - mineR * 0.30),
    mineR * 0.28,
    Paint()..color = Colors.white.withValues(alpha: 0.70),
  );

  final flagPoleX = zone.left + w * 0.72;
  final flagPoleTop = zone.top + h * 0.22;
  final flagPoleBot = zone.top + h * 0.74;

  canvas.drawLine(
    Offset(flagPoleX - w * 0.12, flagPoleBot),
    Offset(flagPoleX + w * 0.12, flagPoleBot),
    Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(flagPoleX, flagPoleTop),
    Offset(flagPoleX, flagPoleBot),
    Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round,
  );

  final flag = Path()
    ..moveTo(flagPoleX, flagPoleTop)
    ..lineTo(flagPoleX + w * 0.22, flagPoleTop + h * 0.09)
    ..lineTo(flagPoleX, flagPoleTop + h * 0.18)
    ..close();
  canvas.drawPath(flag, Paint()..color = const Color(0xFFEF4444));
  canvas.drawPath(
    flag,
    Paint()
      ..color = const Color(0xFFFCA5A5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012,
  );
}
