import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildWaterSortLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Water Sort',
      bg: const [Color(0xFF155E75), Color(0xFF083344)],
      accent: const Color(0xFF22D3EE),
      art: _waterSortArt,
    );

const _segColors = [
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFF22C55E),
];

// Three tubes with mixed colored segments (the real puzzle look).
const _fills = [
  [0, 1, 2, 3],
  [3, 2, 0, 1],
  [1, 3, 1, 2],
];

void _waterSortArt(Canvas canvas, Rect zone) {
  const cap = 4, tubes = 3;
  final gap = zone.width * 0.10;
  final tubeW = (zone.width - gap * (tubes - 1)) / tubes;
  final tubeH = zone.height * 0.92;
  final segH = (tubeH - tubeW * 0.5) / cap; // leave a rounded bottom
  final top = zone.top + (zone.height - tubeH) / 2;

  for (int t = 0; t < tubes; t++) {
    final x = zone.left + t * (tubeW + gap);
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, top, tubeW, tubeH),
      bottomLeft: Radius.circular(tubeW * 0.45),
      bottomRight: Radius.circular(tubeW * 0.45),
      topLeft: Radius.circular(tubeW * 0.18),
      topRight: Radius.circular(tubeW * 0.18),
    );
    // glass
    canvas.drawRRect(body, Paint()..color = Colors.white.withValues(alpha: 0.12));

    // colored segments (clipped to the tube), bottom-up
    canvas.save();
    canvas.clipRRect(body);
    for (int s = 0; s < cap; s++) {
      final sy = top + tubeH - (s + 1) * segH;
      canvas.drawRect(
        Rect.fromLTWH(x, sy, tubeW, segH + 1),
        Paint()..color = _segColors[_fills[t][s]],
      );
    }
    // glass highlight stripe
    canvas.drawRect(
      Rect.fromLTWH(x + tubeW * 0.16, top, tubeW * 0.14, tubeH),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.restore();

    // rim
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = zone.width * 0.012,
    );
  }
}
