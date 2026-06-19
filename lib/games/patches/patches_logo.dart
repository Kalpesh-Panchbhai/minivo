import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildPatchesLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Patches',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      art: _patchesArt,
    );

void _patchesArt(Canvas canvas, Rect zone) {
  const n = 5;
  final gap = zone.width * 0.04;
  final cell = (zone.width - gap * (n - 1)) / n;

  Rect cellRect(int r, int c) =>
      Rect.fromLTWH(zone.left + c * (cell + gap), zone.top + r * (cell + gap), cell, cell);

  final patches = [
    [0, 0, 2, 2, const Color(0xFFBFDBFE)],
    [0, 2, 1, 3, const Color(0xFFFDE68A)],
    [1, 0, 2, 1, const Color(0xFFBBF7D0)],
    [1, 1, 1, 1, const Color(0xFFFECACA)],
    [2, 0, 1, 2, const Color(0xFFDDD6FE)],
    [2, 2, 1, 1, const Color(0xFFFBCFE8)],
    [3, 0, 2, 1, const Color(0xFFCFFAFE)],
    [3, 1, 1, 2, const Color(0xFFFED7AA)],
    [4, 1, 1, 2, const Color(0xFFE9D5FF)],
    [3, 3, 2, 2, const Color(0xFFA7F3D0)],
    [0, 3, 1, 2, const Color(0xFFFCA5A5)],
    [1, 3, 2, 2, const Color(0xFF93C5FD)],
    [4, 0, 1, 1, const Color(0xFFFCD34D)],
  ];

  for (final p in patches) {
    final r = p[0] as int, c = p[1] as int;
    final h = p[2] as int, w = p[3] as int;
    final color = p[4] as Color;
    final tl = cellRect(r, c);
    final br = cellRect(r + h - 1, c + w - 1);
    final rect = Rect.fromLTRB(tl.left, tl.top, br.right, br.bottom);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18));
    canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.55));
    canvas.drawRRect(rr, Paint()
      ..color = color.withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.06);
  }

  final clues = [
    [0, 0, '4'],
    [0, 3, '3'],
    [1, 0, '2'],
    [2, 1, '2'],
    [3, 2, '2'],
    [4, 0, '1'],
  ];
  for (final cl in clues) {
    final r = cl[0] as int, c = cl[1] as int;
    final text = cl[2] as String;
    final ctr = cellRect(r, c).center;
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        fontSize: cell * 0.55, fontWeight: FontWeight.w900,
        color: Colors.white.withValues(alpha: 0.90),
        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.30), blurRadius: 2)],
      )),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, ctr.translate(-tp.width / 2, -tp.height / 2));
  }
}
