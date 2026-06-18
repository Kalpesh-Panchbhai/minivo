import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildMancalaLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Mancala',
      bg: const [Color(0xFF5C3A21), Color(0xFF2A1A0F)],
      accent: const Color(0xFFD2A679),
      art: _MancalaArt,
    );

// ignore: non_constant_identifier_names
void _MancalaArt(Canvas canvas, Rect zone) {
  // Wooden board: a horizontal tray with a row of pits and a big store at the end.
  final boardRect = Rect.fromCenter(
    center: zone.center,
    width: zone.width,
    height: zone.height * 0.62,
  );
  final board = RRect.fromRectAndRadius(boardRect, Radius.circular(zone.height * 0.16));
  canvas.drawRRect(
    board,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB87D45), Color(0xFF8A5523)],
      ).createShader(boardRect),
  );
  canvas.drawRRect(
    board,
    Paint()
      ..color = const Color(0xFF6E441C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = zone.width * 0.02,
  );

  // Seed palette.
  const seedColors = [
    Color(0xFF60A5FA),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
    Color(0xFFF87171),
    Color(0xFFC084FC),
  ];

  final pitPaint = Paint()..color = const Color(0xFF5A3413);
  final pitRimPaint = Paint()
    ..color = const Color(0xFF49290E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = zone.width * 0.012;

  void seeds(Offset center, double pitR, int count, int colorSeed) {
    final sr = pitR * 0.30;
    for (int i = 0; i < count; i++) {
      final ang = (i / count) * 2 * math.pi + colorSeed;
      final dist = count == 1 ? 0.0 : pitR * 0.42;
      final p = Offset(center.dx + dist * math.cos(ang), center.dy + dist * math.sin(ang));
      canvas.drawCircle(p, sr, Paint()..color = seedColors[(i + colorSeed) % seedColors.length]);
      canvas.drawCircle(
        p.translate(-sr * 0.3, -sr * 0.3),
        sr * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }
  }

  // Four small round pits.
  const pitCount = 4;
  final pitR = boardRect.height * 0.26;
  final rowLeft = boardRect.left + boardRect.width * 0.10;
  final rowRight = boardRect.left + boardRect.width * 0.70;
  final cy = boardRect.center.dy;
  for (int i = 0; i < pitCount; i++) {
    final t = i / (pitCount - 1);
    final cx = rowLeft + (rowRight - rowLeft) * t;
    final c = Offset(cx, cy);
    canvas.drawCircle(c, pitR, pitPaint);
    canvas.drawCircle(c, pitR, pitRimPaint);
    seeds(c, pitR, 3 + (i % 2), i);
  }

  // Larger store pit at the end (oval).
  final storeRect = Rect.fromCenter(
    center: Offset(boardRect.right - boardRect.width * 0.14, cy),
    width: boardRect.width * 0.18,
    height: boardRect.height * 0.78,
  );
  canvas.drawOval(storeRect, pitPaint);
  canvas.drawOval(storeRect, pitRimPaint);
  // A handful of seeds collected in the store.
  final ssr = storeRect.width * 0.18;
  final storeSeeds = [
    storeRect.center.translate(0, -storeRect.height * 0.22),
    storeRect.center.translate(-storeRect.width * 0.18, 0),
    storeRect.center.translate(storeRect.width * 0.18, storeRect.height * 0.05),
    storeRect.center.translate(0, storeRect.height * 0.24),
  ];
  for (int i = 0; i < storeSeeds.length; i++) {
    canvas.drawCircle(storeSeeds[i], ssr, Paint()..color = seedColors[i % seedColors.length]);
    canvas.drawCircle(
      storeSeeds[i].translate(-ssr * 0.3, -ssr * 0.3),
      ssr * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }
}
