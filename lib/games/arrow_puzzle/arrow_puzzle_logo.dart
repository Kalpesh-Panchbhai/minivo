import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildArrowPuzzleLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Arrow Puzzle',
      bg: const [Color(0xFF4C1D95), Color(0xFF2E1065)],
      accent: const Color(0xFFA855F7),
      art: _arrowArt,
    );

const _kBlue = Color(0xFF3B82F6);
const _kCoral = Color(0xFFF97316);
const _kTeal = Color(0xFF2DD4BF);
const _kPink = Color(0xFFEC4899);

void _arrowArt(Canvas canvas, Rect zone) {
  final sw = zone.width * 0.11;
  Offset at(double fx, double fy) => Offset(zone.left + zone.width * fx, zone.top + zone.height * fy);

  // four straight bars in four directions (the real game: straight arrows)
  _bar(canvas, at(0.10, 0.24), at(0.58, 0.24), const Offset(1, 0), _kBlue, sw);
  _bar(canvas, at(0.78, 0.10), at(0.78, 0.52), const Offset(0, 1), _kCoral, sw);
  _bar(canvas, at(0.92, 0.74), at(0.40, 0.74), const Offset(-1, 0), _kTeal, sw);
  _bar(canvas, at(0.26, 0.92), at(0.26, 0.52), const Offset(0, -1), _kPink, sw);
}

void _bar(Canvas canvas, Offset from, Offset to, Offset dir, Color color, double sw) {
  canvas.drawLine(
    from,
    to,
    Paint()
      ..color = color
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round,
  );

  final headLen = sw * 1.5;
  final headW = sw * 1.0;
  final perpX = -dir.dy, perpY = dir.dx;
  final tipX = to.dx + dir.dx * sw * 0.5;
  final tipY = to.dy + dir.dy * sw * 0.5;
  final baseX = tipX - dir.dx * headLen;
  final baseY = tipY - dir.dy * headLen;
  final head = ui.Path()
    ..moveTo(tipX, tipY)
    ..lineTo(baseX + perpX * headW, baseY + perpY * headW)
    ..lineTo(baseX - perpX * headW, baseY - perpY * headW)
    ..close();
  canvas.drawPath(head, Paint()..color = color);
}
