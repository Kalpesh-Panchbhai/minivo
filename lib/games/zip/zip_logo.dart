import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildZipLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Zip',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      art: _zipArt,
    );

void _zipArt(Canvas canvas, Rect zone) {
  const n = 3;
  final gap = zone.width * 0.08;
  final cell = (zone.width - gap * (n - 1)) / n;

  Rect cellRect(int r, int c) => Rect.fromLTWH(
      zone.left + c * (cell + gap), zone.top + r * (cell + gap), cell, cell);
  Offset center(int r, int c) => cellRect(r, c).center;

  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final rr =
          RRect.fromRectAndRadius(cellRect(r, c), Radius.circular(cell * 0.20));
      canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: 0.08));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.04,
      );
    }
  }

  const pathNodes = [
    [0, 0],
    [0, 1],
    [1, 1],
    [1, 2],
    [2, 2],
  ];

  final trailPath = Path()
    ..moveTo(
        center(pathNodes[0][0], pathNodes[0][1]).dx,
        center(pathNodes[0][0], pathNodes[0][1]).dy);
  for (int i = 1; i < pathNodes.length; i++) {
    final ctr = center(pathNodes[i][0], pathNodes[i][1]);
    trailPath.lineTo(ctr.dx, ctr.dy);
  }

  canvas.drawPath(
    trailPath,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.28
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        zone.topLeft,
        zone.bottomRight,
        const [Color(0xFFC4B5FD), Color(0xFF818CF8)],
      ),
  );

  void checkpoint(int r, int c, String num) {
    final ctr = center(r, c);
    final cr = cell * 0.30;
    canvas.drawCircle(
      ctr.translate(0, 1.5),
      cr,
      Paint()..color = Colors.black.withValues(alpha: 0.20),
    );
    canvas.drawCircle(
      ctr,
      cr,
      Paint()..color = const Color(0xFF312E81),
    );
    canvas.drawCircle(
      ctr,
      cr,
      Paint()
        ..color = const Color(0xFF818CF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.06,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: num,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: cell * 0.34,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(ctr.dx - tp.width / 2, ctr.dy - tp.height / 2));
  }

  checkpoint(0, 0, '1');
  checkpoint(1, 1, '2');
  checkpoint(2, 2, '3');
}
