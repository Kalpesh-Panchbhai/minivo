import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildQueensPuzzleLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Queens',
      bg: const [Color(0xFF3B1F6E), Color(0xFF1A0A3E)],
      accent: const Color(0xFFD4A0FF),
      art: _queensArt,
    );

void _queensArt(Canvas canvas, Rect zone) {
  const n = 4;
  final gap = zone.width * 0.06;
  final cell = (zone.width - gap * (n - 1)) / n;

  final regionColors = [
    const Color(0xFFFF6B6B),
    const Color(0xFF51CF66),
    const Color(0xFF339AF0),
    const Color(0xFFFFD43B),
  ];

  const regions = [
    [0, 1, 4, 5],
    [2, 3, 6, 7],
    [8, 9, 12, 13],
    [10, 11, 14, 15],
  ];

  const queenPositions = [
    [0, 2],
    [1, 0],
    [2, 3],
    [3, 1],
  ];

  Rect cellRect(int r, int c) =>
      Rect.fromLTWH(zone.left + c * (cell + gap), zone.top + r * (cell + gap), cell, cell);

  for (int reg = 0; reg < n; reg++) {
    for (final idx in regions[reg]) {
      final r = idx ~/ n, c = idx % n;
      final rect = cellRect(r, c);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18));
      canvas.drawRRect(rr, Paint()..color = regionColors[reg].withValues(alpha: 0.35));
      canvas.drawRRect(
          rr,
          Paint()
            ..color = regionColors[reg].withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.06);
    }
  }

  for (final pos in queenPositions) {
    final ctr = cellRect(pos[0], pos[1]).center;
    final cr = cell * 0.30;
    canvas.drawCircle(ctr.translate(0, 1.5), cr, Paint()..color = Colors.black.withValues(alpha: 0.22));
    canvas.drawCircle(
        ctr,
        cr,
        Paint()
          ..shader = ui.Gradient.radial(
            ctr.translate(-cr * 0.2, -cr * 0.3),
            cr * 1.2,
            [const Color(0xFFFFD43B), const Color(0xFFF59F00)],
          ));

    final crownSize = cr * 0.75;
    final crownPath = Path();
    final cx = ctr.dx, cy = ctr.dy;
    crownPath.moveTo(cx - crownSize, cy + crownSize * 0.3);
    crownPath.lineTo(cx - crownSize, cy - crownSize * 0.2);
    crownPath.lineTo(cx - crownSize * 0.5, cy + crownSize * 0.1);
    crownPath.lineTo(cx, cy - crownSize * 0.5);
    crownPath.lineTo(cx + crownSize * 0.5, cy + crownSize * 0.1);
    crownPath.lineTo(cx + crownSize, cy - crownSize * 0.2);
    crownPath.lineTo(cx + crownSize, cy + crownSize * 0.3);
    crownPath.close();

    canvas.drawPath(
        crownPath,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
  }
}
