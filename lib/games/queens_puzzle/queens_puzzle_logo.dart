import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildQueensPuzzleLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Queens',
      bg: const [Color(0xFF581C87), Color(0xFF3B0764)],
      accent: const Color(0xFFC084FC),
      art: _queensArt,
    );

void _queensArt(Canvas canvas, Rect zone) {
  final cell = zone.width / 4;
  final left = zone.left;
  final top = zone.top + zone.height * 0.05;

  final gridW = cell * 4;
  final gridH = cell * 4;

  const regionMap = [
    [0, 0, 1, 1],
    [0, 2, 2, 1],
    [3, 2, 4, 4],
    [3, 3, 4, 4],
  ];

  const regionColors = [
    Color(0xFFFF6B6B),
    Color(0xFF51CF66),
    Color(0xFF339AF0),
    Color(0xFFFFD43B),
    Color(0xFFCC5DE8),
  ];

  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 4; c++) {
      final x = left + c * cell;
      final y = top + r * cell;
      final rect = Rect.fromLTWH(x, y, cell, cell);
      canvas.drawRect(rect, Paint()..color = Colors.white);
      canvas.drawRect(
        rect,
        Paint()..color = regionColors[regionMap[r][c]].withValues(alpha: 0.45),
      );
    }
  }

  final thinLine = Paint()
    ..color = const Color(0xFF2D2D3F).withValues(alpha: 0.55)
    ..strokeWidth = cell * 0.04;

  for (int i = 1; i < 4; i++) {
    final y = top + i * cell;
    canvas.drawLine(Offset(left, y), Offset(left + gridW, y), thinLine);
    final x = left + i * cell;
    canvas.drawLine(Offset(x, top), Offset(x, top + gridH), thinLine);
  }

  final outerBorder = Paint()
    ..color = const Color(0xFF2D2D3F)
    ..style = PaintingStyle.stroke
    ..strokeWidth = cell * 0.10;
  canvas.drawRect(Rect.fromLTWH(left, top, gridW, gridH), outerBorder);

  void drawCrown(double cx, double cy, double w) {
    final h = w * 0.72;
    final crownLeft = cx - w / 2;
    final crownTop = cy - h / 2;
    final crownBottom = crownTop + h;
    final bandY = crownBottom - h * 0.22;
    final peakY = crownTop;
    final dipY = crownTop + h * 0.45;

    final path = Path()
      ..moveTo(crownLeft, crownBottom)
      ..lineTo(crownLeft, bandY)
      ..lineTo(crownLeft, dipY)
      ..lineTo(crownLeft + w * 0.18, peakY + h * 0.05)
      ..lineTo(crownLeft + w * 0.30, dipY)
      ..lineTo(cx, peakY)
      ..lineTo(crownLeft + w * 0.70, dipY)
      ..lineTo(crownLeft + w * 0.82, peakY + h * 0.05)
      ..lineTo(crownLeft + w, dipY)
      ..lineTo(crownLeft + w, bandY)
      ..lineTo(crownLeft + w, crownBottom)
      ..close();

    canvas.drawPath(
      path.shift(const Offset(0, 1)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, peakY),
          Offset(cx, crownBottom),
          [
            const Color(0xFFFFD43B),
            const Color(0xFFE8A817),
            const Color(0xFFB8860B),
          ],
          [0.0, 0.55, 1.0],
        ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB8860B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06,
    );

    final jewels = [
      Offset(crownLeft + w * 0.18, peakY + h * 0.05),
      Offset(cx, peakY),
      Offset(crownLeft + w * 0.82, peakY + h * 0.05),
    ];
    final jr = w * 0.07;
    for (final j in jewels) {
      canvas.drawCircle(j, jr, Paint()..color = const Color(0xFFFFF9E6));
      canvas.drawCircle(
        j,
        jr,
        Paint()
          ..color = const Color(0xFFB8860B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.04,
      );
    }
  }

  final crownSize = cell * 0.62;

  drawCrown(left + 0.5 * cell, top + 0.5 * cell, crownSize);
  drawCrown(left + 2.5 * cell, top + 1.5 * cell, crownSize);
  drawCrown(left + 3.5 * cell, top + 3.5 * cell, crownSize);
}
