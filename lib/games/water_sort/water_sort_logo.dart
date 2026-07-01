import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildWaterSortLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Water Sort',
      bg: const [Color(0xFF155E75), Color(0xFF083344)],
      accent: const Color(0xFF22D3EE),
      art: _waterSortArt,
    );

void _waterSortArt(Canvas canvas, Rect zone) {
  const cap = 4;
  final spacing = zone.width * 0.12;
  final tubeW = (zone.width - spacing) / 2;
  final tubeH = zone.height * 0.92;
  final segH = (tubeH - tubeW * 0.5) / cap;
  final top = zone.top + (zone.height - tubeH) / 2;

  const mixedColors = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
  ];

  const sortedColors = [
    Color(0xFF3B82F6),
    Color(0xFF3B82F6),
    Color(0xFF3B82F6),
    Color(0xFF3B82F6),
  ];

  final tubes = [mixedColors, sortedColors];

  for (int t = 0; t < 2; t++) {
    final x = zone.left + t * (tubeW + spacing);
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, top, tubeW, tubeH),
      bottomLeft: Radius.circular(tubeW * 0.45),
      bottomRight: Radius.circular(tubeW * 0.45),
      topLeft: Radius.circular(tubeW * 0.12),
      topRight: Radius.circular(tubeW * 0.12),
    );

    canvas.drawRRect(
        body, Paint()..color = Colors.white.withValues(alpha: 0.10));

    canvas.save();
    canvas.clipRRect(body);
    for (int s = 0; s < cap; s++) {
      final sy = top + tubeH - (s + 1) * segH;
      canvas.drawRect(
        Rect.fromLTWH(x, sy, tubeW, segH + 1),
        Paint()..color = tubes[t][s],
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(x + tubeW * 0.15, top, tubeW * 0.15, tubeH),
      Paint()..color = Colors.white.withValues(alpha: 0.20),
    );
    canvas.restore();

    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = zone.width * 0.015,
    );
  }
}
