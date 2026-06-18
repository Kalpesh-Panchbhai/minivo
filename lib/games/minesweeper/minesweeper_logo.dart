import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildMinesweeperLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Minesweeper',
      bg: const [Color(0xFF1E3A8A), Color(0xFF0B1E4D)],
      accent: const Color(0xFF60A5FA),
      art: _minesweeperArt,
    );

void _minesweeperArt(Canvas canvas, Rect zone) {
  const n = 3;
  final gap = zone.width * 0.06;
  final cell = (zone.width - gap * (n - 1)) / n;

  Rect cellRect(int r, int c) => Rect.fromLTWH(
      zone.left + c * (cell + gap), zone.top + r * (cell + gap), cell, cell);
  Offset center(int r, int c) => cellRect(r, c).center;

  // Raised tile look helper.
  void raisedTile(int r, int c) {
    final rr = RRect.fromRectAndRadius(cellRect(r, c), Radius.circular(cell * 0.18));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFCBD5E1));
    // Top-left highlight bevel.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cellRect(r, c).left, cellRect(r, c).top, cell, cell * 0.42),
        Radius.circular(cell * 0.18),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFF64748B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.05,
    );
  }

  void revealedTile(int r, int c) {
    final rr = RRect.fromRectAndRadius(cellRect(r, c), Radius.circular(cell * 0.18));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFEFF4FA));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFB6C2D4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.04,
    );
  }

  // All tiles raised by default.
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      raisedTile(r, c);
    }
  }

  // Number "2" on a revealed tile (top-left).
  revealedTile(0, 0);
  final numCtr = center(0, 0);
  final numTp = TextPainter(
    text: TextSpan(
      text: '2',
      style: TextStyle(
        color: const Color(0xFF2563EB),
        fontWeight: FontWeight.w900,
        fontSize: cell * 0.6,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  numTp.paint(canvas, Offset(numCtr.dx - numTp.width / 2, numCtr.dy - numTp.height / 2));

  // Black mine with spikes (centre).
  final mineCtr = center(1, 1);
  final mr = cell * 0.26;
  for (int i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    canvas.drawLine(
      mineCtr,
      Offset(mineCtr.dx + math.cos(angle) * mr * 1.5,
          mineCtr.dy + math.sin(angle) * mr * 1.5),
      Paint()
        ..color = const Color(0xFF111827)
        ..strokeWidth = cell * 0.07
        ..strokeCap = StrokeCap.round,
    );
  }
  canvas.drawCircle(mineCtr, mr, Paint()..color = const Color(0xFF111827));
  canvas.drawCircle(
    mineCtr.translate(-mr * 0.3, -mr * 0.3),
    mr * 0.3,
    Paint()..color = Colors.white.withValues(alpha: 0.7),
  );

  // Red flag (bottom-right).
  final flagCtr = center(2, 2);
  final poleTop = Offset(flagCtr.dx - cell * 0.05, flagCtr.dy - cell * 0.28);
  final poleBottom = Offset(flagCtr.dx - cell * 0.05, flagCtr.dy + cell * 0.28);
  // Base.
  canvas.drawLine(
    Offset(flagCtr.dx - cell * 0.22, poleBottom.dy),
    Offset(flagCtr.dx + cell * 0.22, poleBottom.dy),
    Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = cell * 0.07
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    poleTop,
    poleBottom,
    Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = cell * 0.06
      ..strokeCap = StrokeCap.round,
  );
  final flag = Path()
    ..moveTo(poleTop.dx, poleTop.dy)
    ..lineTo(poleTop.dx + cell * 0.3, poleTop.dy + cell * 0.12)
    ..lineTo(poleTop.dx, poleTop.dy + cell * 0.24)
    ..close();
  canvas.drawPath(flag, Paint()..color = const Color(0xFFEF4444));
}
