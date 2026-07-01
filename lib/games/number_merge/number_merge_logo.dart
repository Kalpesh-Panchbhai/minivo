import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget build2048Logo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: '2048 Merge',
      bg: const [Color(0xFF92400E), Color(0xFF451A03)],
      accent: const Color(0xFFFBBF24),
      art: _mergeArt,
    );

void _mergeArt(Canvas canvas, Rect zone) {
  const n = 3;
  final boardSide = zone.width;
  final boardR = boardSide * 0.08;
  final ox = zone.left;
  final oy = zone.top + (zone.height - boardSide) / 2;
  final boardRect = Rect.fromLTWH(ox, oy, boardSide, boardSide);
  final gap = boardSide * 0.05;
  final cellSize = (boardSide - gap * (n + 1)) / n;
  final tileR = cellSize * 0.16;

  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect, Radius.circular(boardR)),
    Paint()..color = const Color(0xFFBBADA0),
  );

  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      final tx = ox + gap + c * (cellSize + gap);
      final ty = oy + gap + r * (cellSize + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(tx, ty, cellSize, cellSize),
          Radius.circular(tileR),
        ),
        Paint()..color = const Color(0xFFCDC1B4),
      );
    }
  }

  final tiles = [
    [0, 0, 2],
    [0, 1, 64],
    [0, 2, 8],
    [1, 0, 8],
    [1, 1, 128],
    [1, 2, 2],
    [2, 0, 4],
    [2, 2, 2048],
  ];

  Color tileBg(int v) {
    switch (v) {
      case 2:
        return const Color(0xFFEEE4DA);
      case 4:
        return const Color(0xFFEDE0C8);
      case 8:
        return const Color(0xFFF2B179);
      case 64:
        return const Color(0xFFF65E3B);
      case 128:
        return const Color(0xFFEDCF72);
      case 2048:
        return const Color(0xFFEDC22E);
      default:
        return const Color(0xFFCDC1B4);
    }
  }

  Color tileFg(int v) {
    if (v >= 8) return const Color(0xFFF9F6F2);
    return const Color(0xFF776E65);
  }

  for (final t in tiles) {
    final r = t[0], c = t[1], v = t[2];
    final tx = ox + gap + c * (cellSize + gap);
    final ty = oy + gap + r * (cellSize + gap);
    final tileRect = Rect.fromLTWH(tx, ty, cellSize, cellSize);

    if (v >= 8) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          tileRect.inflate(cellSize * 0.04),
          Radius.circular(tileR * 1.2),
        ),
        Paint()
          ..color = tileBg(v).withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(tileRect, Radius.circular(tileR)),
      Paint()..color = tileBg(v),
    );

    final label = v.toString();
    double fontSize = cellSize * 0.42;
    if (label.length >= 4) {
      fontSize = cellSize * 0.26;
    } else if (label.length == 3) {
      fontSize = cellSize * 0.30;
    } else if (label.length == 2) {
      fontSize = cellSize * 0.36;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: tileFg(v),
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
        tileRect.center.dx - tp.width / 2,
        tileRect.center.dy - tp.height / 2,
      ),
    );
  }
}
