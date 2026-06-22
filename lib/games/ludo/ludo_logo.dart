import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildLudoLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Ludo',
      bg: const [Color(0xFF1A5276), Color(0xFF0E2F44)],
      accent: const Color(0xFFF4D03F),
      art: _ludoArt,
    );

void _ludoArt(Canvas canvas, Rect zone) {
  final half = zone.width / 2;
  final quadrants = [
    (Rect.fromLTWH(zone.left, zone.top, half, half), const Color(0xFFE74C3C)),
    (Rect.fromLTWH(zone.left + half, zone.top, half, half), const Color(0xFF27AE60)),
    (Rect.fromLTWH(zone.left, zone.top + half, half, half), const Color(0xFF2980B9)),
    (Rect.fromLTWH(zone.left + half, zone.top + half, half, half), const Color(0xFFF1C40F)),
  ];

  for (final (rect, color) in quadrants) {
    canvas.drawRect(rect, Paint()..color = color);
  }

  final center = zone.center;
  final triSize = half * 0.55;
  final triColors = [
    const Color(0xFFE74C3C),
    const Color(0xFF27AE60),
    const Color(0xFF2980B9),
    const Color(0xFFF1C40F),
  ];
  final triPoints = [
    [Offset(center.dx - triSize, center.dy - triSize), Offset(center.dx + triSize, center.dy - triSize), center],
    [Offset(center.dx + triSize, center.dy - triSize), Offset(center.dx + triSize, center.dy + triSize), center],
    [Offset(center.dx - triSize, center.dy + triSize), Offset(center.dx + triSize, center.dy + triSize), center],
    [Offset(center.dx - triSize, center.dy - triSize), Offset(center.dx - triSize, center.dy + triSize), center],
  ];
  for (int i = 0; i < 4; i++) {
    final path = Path()
      ..moveTo(triPoints[i][0].dx, triPoints[i][0].dy)
      ..lineTo(triPoints[i][1].dx, triPoints[i][1].dy)
      ..lineTo(triPoints[i][2].dx, triPoints[i][2].dy)
      ..close();
    canvas.drawPath(path, Paint()..color = triColors[i].withValues(alpha: 0.85));
  }

  canvas.drawRect(
    zone,
    Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = half * 0.04,
  );

  void token(double cx, double cy, Color color) {
    final r = half * 0.14;
    canvas.drawCircle(Offset(cx, cy + r * 0.15), r, Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.6,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.15,
    );
    canvas.drawCircle(Offset(cx - r * 0.25, cy - r * 0.25), r * 0.18, Paint()..color = Colors.white.withValues(alpha: 0.4));
  }

  final pad = half * 0.35;
  token(zone.left + pad, zone.top + pad, const Color(0xFFE74C3C));
  token(zone.right - pad, zone.top + pad, const Color(0xFF27AE60));
  token(zone.left + pad, zone.bottom - pad, const Color(0xFF2980B9));
  token(zone.right - pad, zone.bottom - pad, const Color(0xFFF1C40F));
}
