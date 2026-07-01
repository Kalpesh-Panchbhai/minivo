import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/animated_background.dart';
import '../shared/game_logo_scaffold.dart';

Widget buildDropMergeLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Drop Merge',
      bg: const [Color(0xFF7C2D12), Color(0xFF431407)],
      accent: const Color(0xFFFB923C),
      art: _dropMergeArt,
    );

void _dropMergeArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;

  const cols = 3;
  const rows = 3;

  final boardW = w * 0.92;
  final boardH = h * 0.82;
  final boardRect = Rect.fromCenter(
    center: Offset(zone.center.dx, zone.center.dy + h * 0.04),
    width: boardW,
    height: boardH,
  );

  final boardRR =
      RRect.fromRectAndRadius(boardRect, Radius.circular(w * 0.08));
  canvas.drawRRect(
    boardRR.shift(const Offset(0, 2)),
    Paint()..color = Colors.black.withValues(alpha: 0.18),
  );
  canvas.drawRRect(boardRR, Paint()..color = const Color(0xFFFFFBF5));
  canvas.drawRRect(
    boardRR,
    Paint()
      ..color = const Color(0xFFFB923C).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012,
  );

  final cellPadX = boardW * 0.08;
  final cellPadY = boardH * 0.08;
  final innerW = boardW - cellPadX * 2;
  final innerH = boardH - cellPadY * 2;
  final cellW = innerW / cols;
  final cellH = innerH / rows;
  final gap = w * 0.02;

  // (value, isDropping) — 0 means empty cell
  const grid = [
    [(4, false), (0, false), (8, false)],
    [(2, false), (16, false), (4, false)],
    [(8, false), (2, false), (32, false)],
  ];

  const tileColors = <int, (Color, Color)>{
    2: (Color(0xFFFFF3BF), Color(0xFF1A1A1A)),
    4: (Color(0xFFFFE066), Color(0xFF1A1A1A)),
    8: (Color(0xFFFFA94D), Color(0xFFFFFFFF)),
    16: (Color(0xFFFF6B6B), Color(0xFFFFFFFF)),
    32: (Color(0xFFE64980), Color(0xFFFFFFFF)),
  };

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final cellLeft = boardRect.left + cellPadX + cellW * c + gap / 2;
      final cellTop = boardRect.top + cellPadY + cellH * r + gap / 2;
      final tileW = cellW - gap;
      final tileH = cellH - gap;
      final tileRect = Rect.fromLTWH(cellLeft, cellTop, tileW, tileH);
      final tileRR = RRect.fromRectAndRadius(
          tileRect, Radius.circular(tileW * 0.18));

      final (value, _) = grid[r][c];

      if (value == 0) {
        canvas.drawRRect(
            tileRR, Paint()..color = const Color(0xFFEEEEEE));
        continue;
      }

      final (bg, fg) = tileColors[value]!;

      canvas.drawRRect(
        tileRR.shift(const Offset(0, 1.5)),
        Paint()
          ..color = bg.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      canvas.drawRRect(tileRR, Paint()..color = bg);

      final fontSize = tileW * (value >= 10 ? 0.34 : 0.42);
      final tp = TextPainter(
        text: TextSpan(
          text: '$value',
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
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

  final dropCol = 1;
  final dropCellLeft =
      boardRect.left + cellPadX + cellW * dropCol + gap / 2;
  final dropTileW = cellW - gap;
  final dropTileH = cellH - gap;
  final dropTileRect = Rect.fromLTWH(
    dropCellLeft,
    boardRect.top - dropTileH * 0.55,
    dropTileW,
    dropTileH,
  );
  final dropRR = RRect.fromRectAndRadius(
      dropTileRect, Radius.circular(dropTileW * 0.18));

  canvas.drawRRect(
    dropRR.shift(const Offset(0, 1.5)),
    Paint()
      ..color = const Color(0xFFFFA94D).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  canvas.drawRRect(dropRR, Paint()..color = const Color(0xFFFFA94D));

  final dropFontSize = dropTileW * 0.42;
  final dropTp = TextPainter(
    text: TextSpan(
      text: '8',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: dropFontSize,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  dropTp.paint(
    canvas,
    Offset(
      dropTileRect.center.dx - dropTp.width / 2,
      dropTileRect.center.dy - dropTp.height / 2,
    ),
  );

  final arrowCx = dropTileRect.center.dx;
  final arrowTopY = dropTileRect.top - dropTileH * 0.40;
  final arrowBotY = dropTileRect.top - dropTileH * 0.08;
  final arrowPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.85)
    ..strokeWidth = w * 0.035
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
      Offset(arrowCx, arrowTopY), Offset(arrowCx, arrowBotY), arrowPaint);
  final ah = w * 0.05;
  final arrowHead = Path()
    ..moveTo(arrowCx, arrowBotY + ah * 0.5)
    ..lineTo(arrowCx - ah, arrowBotY - ah * 0.3)
    ..lineTo(arrowCx + ah, arrowBotY - ah * 0.3)
    ..close();
  canvas.drawPath(
      arrowHead, Paint()..color = Colors.white.withValues(alpha: 0.85));
}

class DropMergeBgPainter extends AnimatedBgPainter {
  const DropMergeBgPainter(super.t);

  static const _items = <(double, double, double, double, int)>[
    (0.08, 0.10, 30, 0.0, 2),
    (0.82, 0.06, 24, 0.8, 4),
    (0.15, 0.55, 20, 1.6, 8),
    (0.88, 0.42, 28, 2.4, 16),
    (0.05, 0.80, 22, 3.2, 4),
    (0.74, 0.88, 18, 4.0, 2),
    (0.50, 0.03, 16, 4.8, 8),
    (0.40, 0.94, 22, 5.6, 32),
    (0.92, 0.65, 14, 1.2, 2),
    (0.04, 0.44, 18, 3.7, 16),
  ];

  static const _tileColors = {
    2: Color(0xFFFFF3BF),
    4: Color(0xFFFFE066),
    8: Color(0xFFFFA94D),
    16: Color(0xFFFF6B6B),
    32: Color(0xFFE64980),
  };

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    for (final (xRel, yRel, tileSize, itemPhase, value) in _items) {
      final bobY = math.sin(phase + itemPhase * 0.6) * (tileSize * 0.25);
      final rot = math.sin(phase * 0.4 + itemPhase) * 0.12;
      final alpha = 0.05 + (math.sin(phase * 1.2 + itemPhase) + 1) / 2 * 0.06;
      final cx = w * xRel;
      final cy = h * yRel + bobY;
      final color = (_tileColors[value] ?? const Color(0xFFFFF3BF))
          .withValues(alpha: alpha);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-tileSize / 2, -tileSize / 2, tileSize, tileSize),
          const Radius.circular(5),
        ),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }
}
