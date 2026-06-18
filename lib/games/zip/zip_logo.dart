import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildZipLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Zip',
      bg: const [Color(0xFF0F3D24), Color(0xFF03130A)],
      accent: const Color(0xFF4ADE80),
      art: _zipArt,
    );

void _zipArt(Canvas canvas, Rect zone) {
  const n = 3;
  final gap = zone.width * 0.07;
  final cell = (zone.width - gap * (n - 1)) / n;

  Rect cellRect(int r, int c) =>
      Rect.fromLTWH(zone.left + c * (cell + gap), zone.top + r * (cell + gap), cell, cell);
  Offset center(int r, int c) => cellRect(r, c).center;

  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final rr = RRect.fromRectAndRadius(cellRect(r, c), Radius.circular(cell * 0.22));
      canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.10));
      canvas.drawRRect(
          rr,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.05);
    }
  }

  const path = [
    [0, 0], [0, 1], [0, 2],
    [1, 2], [1, 1], [1, 0],
    [2, 0], [2, 1], [2, 2],
  ];
  final p = Path()
    ..moveTo(center(path[0][0], path[0][1]).dx, center(path[0][0], path[0][1]).dy);
  for (int i = 1; i < path.length; i++) {
    final ctr = center(path[i][0], path[i][1]);
    p.lineTo(ctr.dx, ctr.dy);
  }
  canvas.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.34
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        zone.topLeft,
        zone.bottomRight,
        const [Color(0xFFBBF7D0), Color(0xFF4ADE80)],
      ),
  );

  void checkpoint(int r, int c, String num) {
    final ctr = center(r, c);
    final cr = cell * 0.32;
    canvas.drawCircle(ctr.translate(0, 1.5), cr, Paint()..color = Colors.black.withValues(alpha: 0.22));
    canvas.drawCircle(ctr, cr, Paint()..color = const Color(0xFF0B3D1E));
    final tp = TextPainter(
      text: TextSpan(
          text: num,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: cell * 0.42, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(ctr.dx - tp.width / 2, ctr.dy - tp.height / 2));
  }

  checkpoint(0, 0, '1');
  checkpoint(2, 2, '2');
}
