import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildTangoLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Tango',
      bg: const [Color(0xFF7C3500), Color(0xFF3E1A00)],
      accent: const Color(0xFFFFA726),
      art: _tangoArt,
    );

void _tangoArt(Canvas canvas, Rect zone) {
  const n = 4;
  final gap = zone.width * 0.06;
  final cell = (zone.width - gap * (n - 1)) / n;

  Rect cellRect(int r, int c) =>
      Rect.fromLTWH(zone.left + c * (cell + gap), zone.top + r * (cell + gap), cell, cell);

  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final rect = cellRect(r, c);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18));
      canvas.drawRRect(rr, Paint()..color = const Color(0xFFFFF8E7).withValues(alpha: 0.25));
      canvas.drawRRect(rr, Paint()
        ..color = const Color(0xFFD4C5A0).withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.05);
    }
  }

  const suns = [[0, 0], [0, 3], [1, 1], [2, 2], [3, 0], [3, 3]];
  const moons = [[0, 1], [0, 2], [1, 0], [1, 2], [2, 0], [2, 1], [2, 3], [3, 1]];

  for (final pos in suns) {
    final ctr = cellRect(pos[0], pos[1]).center;
    final cr = cell * 0.28;
    canvas.drawCircle(ctr.translate(0, 1), cr, Paint()..color = Colors.black.withValues(alpha: 0.18));
    canvas.drawCircle(ctr, cr, Paint()
      ..shader = ui.Gradient.radial(
        ctr.translate(-cr * 0.2, -cr * 0.3), cr * 1.2,
        [const Color(0xFFFFD54F), const Color(0xFFFFA726)]));
    for (int i = 0; i < 8; i++) {
      final angle = i * 3.14159 / 4;
      final inner = cr * 1.15;
      final outer = cr * 1.45;
      final dx1 = ctr.dx + inner * math.cos(angle);
      final dy1 = ctr.dy + inner * math.sin(angle);
      final dx2 = ctr.dx + outer * math.cos(angle);
      final dy2 = ctr.dy + outer * math.sin(angle);
      canvas.drawLine(Offset(dx1, dy1), Offset(dx2, dy2), Paint()
        ..color = const Color(0xFFFFA726).withValues(alpha: 0.70)
        ..strokeWidth = cell * 0.06
        ..strokeCap = StrokeCap.round);
    }
  }

  for (final pos in moons) {
    final ctr = cellRect(pos[0], pos[1]).center;
    final cr = cell * 0.28;
    canvas.drawCircle(ctr.translate(0, 1), cr, Paint()..color = Colors.black.withValues(alpha: 0.18));
    canvas.drawCircle(ctr, cr, Paint()
      ..shader = ui.Gradient.radial(
        ctr.translate(-cr * 0.2, -cr * 0.3), cr * 1.2,
        [const Color(0xFFB388FF), const Color(0xFF7C4DFF)]));
    canvas.drawCircle(ctr.translate(cr * 0.30, -cr * 0.20), cr * 0.65,
      Paint()..color = const Color(0xFF3E1A00).withValues(alpha: 0.70));
  }

  final eqCtr = Offset(
    (cellRect(0, 0).right + cellRect(0, 1).left) / 2,
    cellRect(0, 0).center.dy,
  );
  final eqR = cell * 0.14;
  canvas.drawCircle(eqCtr, eqR, Paint()..color = Colors.white.withValues(alpha: 0.85));
  final tp = TextPainter(
    text: TextSpan(text: '=', style: TextStyle(fontSize: eqR * 1.4, fontWeight: FontWeight.w900, color: const Color(0xFF8B7355))),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, eqCtr.translate(-tp.width / 2, -tp.height / 2));
}

