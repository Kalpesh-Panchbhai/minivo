import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget build2048Logo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: '2048 Merge',
      bg: const [Color(0xFF7F1D1D), Color(0xFF2D0A0A)],
      accent: const Color(0xFFFB7185),
      art: _mergeArt,
    );

class _Tile {
  final int row;
  final int col;
  final int value;
  final Color color;
  const _Tile(this.row, this.col, this.value, this.color);
}

const _tiles = <_Tile>[
  _Tile(0, 0, 2, Color(0xFFFBBF24)), // amber
  _Tile(0, 1, 4, Color(0xFFF59E0B)), // orange-amber
  _Tile(1, 0, 8, Color(0xFFF97316)), // orange
  _Tile(1, 1, 16, Color(0xFFEF4444)), // red
];

void _mergeArt(Canvas canvas, Rect zone) {
  const n = 2;
  final gap = zone.width * 0.07;
  final cell = (zone.width - gap * (n + 1)) / n;
  final cellRadius = Radius.circular(cell * 0.16);

  Rect cellRect(int r, int c) => Rect.fromLTWH(
        zone.left + gap + c * (cell + gap),
        zone.top + gap + r * (cell + gap),
        cell,
        cell,
      );

  for (final tile in _tiles) {
    final rect = cellRect(tile.row, tile.col);
    final rr = RRect.fromRectAndRadius(rect, cellRadius);
    // drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, cell * 0.03), cellRadius),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.drawRRect(rr, Paint()..color = tile.color);
    // top sheen
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.46),
        cellRadius,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );

    final fontSize = tile.value < 10 ? cell * 0.52 : cell * 0.40;
    final tp = TextPainter(
      text: TextSpan(
        text: tile.value.toString(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        rect.left + (cell - tp.width) / 2,
        rect.top + (cell - tp.height) / 2,
      ),
    );
  }
}
