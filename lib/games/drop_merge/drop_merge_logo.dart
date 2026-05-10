import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../shared/animated_background.dart';

Widget buildDropMergeLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFF9A3C), Color(0xFFE8590C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _DropMergeLogoPainter(),
    ),
  );
}

class _DropMergeLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Measure label first so we know how much vertical space it needs ───────
    final labelFs = (w * 0.135).clamp(7.0, 17.0);
    final labelTp = TextPainter(
      text: TextSpan(
        text: 'DROP MERGE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: labelFs,
          letterSpacing: 0.6,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.94);

    const labelBottomGap = 0.045;
    final labelTop = h - labelTp.height - h * labelBottomGap;

    // ── Column layout: 3 tiles stacked, top one "dropping" ───────────────────
    //  Available vertical space for tiles: from top padding to just above label
    const topPad  = 0.06;
    final availH  = labelTop - h * topPad;

    // 3 tiles + a small gap between tile1 and tile2 (the "air" the tile falls through)
    const dropGapFrac = 0.10;  // fraction of availH for the gap
    final dropGap = availH * dropGapFrac;
    final tileH   = (availH - dropGap) / 3;
    final tileW   = w * 0.52;
    final tileX   = (w - tileW) / 2;

    const r = Radius.circular(8);

    // Tile data: [value, color, textColor]
    // Tile 0 = top (dropping), tile 1 = middle, tile 2 = bottom (just merged)
    final tiles = [
      (2,  const Color(0xFFFFF3BF), Colors.black87),   // dropping tile – cream
      (4,  const Color(0xFFFFE066), Colors.black87),   // middle – yellow
      (8,  const Color(0xFFFFA94D), Colors.white),     // merged result – orange
    ];

    // positions: tile0 has extra gap below it (it is mid-fall)
    final y0 = h * topPad;                           // falling tile
    final y1 = y0 + tileH + dropGap;                 // middle tile
    final y2 = y1 + tileH;                           // merged tile

    // ── Draw motion-blur dashes below falling tile ────────────────────────────
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = (w * 0.022).clamp(1.2, 2.5)
      ..strokeCap = StrokeCap.round;
    final dashCX = w / 2;
    double dy = y0 + tileH + 2;
    while (dy < y1 - 2) {
      canvas.drawLine(Offset(dashCX, dy), Offset(dashCX, dy + tileH * 0.09), dashPaint);
      dy += tileH * 0.16;
    }

    // ── Draw each tile ────────────────────────────────────────────────────────
    final ys = [y0, y1, y2];
    for (int i = 0; i < 3; i++) {
      final (val, color, textColor) = tiles[i];
      final ty = ys[i];

      // Shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(tileX + 1, ty + 3, tileW, tileH), r),
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );

      // Body
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(tileX, ty, tileW, tileH), r),
        Paint()..color = color,
      );

      // Shine
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(tileX + 3, ty + 3, tileW * 0.52, tileH * 0.38), r),
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );

      // Number
      final fs = (tileH * 0.44).clamp(8.0, 22.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '$val',
          style: TextStyle(
            color: textColor,
            fontSize: fs,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(
        tileX + tileW / 2 - tp.width / 2,
        ty + tileH / 2 - tp.height / 2,
      ));
    }

    // ── Merge sparkles around the bottom tile ─────────────────────────────────
    final sparkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.80)
      ..strokeWidth = (w * 0.025).clamp(1.2, 2.5)
      ..strokeCap = StrokeCap.round;
    final cx = w / 2;
    final cy = y2 + tileH / 2;
    final sr = tileW * 0.60;
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi - math.pi / 6;
      final inner = sr * 0.55;
      final outer = sr * 0.85;
      canvas.drawLine(
        Offset(cx + math.cos(angle) * inner, cy + math.sin(angle) * inner),
        Offset(cx + math.cos(angle) * outer, cy + math.sin(angle) * outer),
        sparkPaint,
      );
    }

    // ── Label ─────────────────────────────────────────────────────────────────
    labelTp.paint(canvas, Offset((w - labelTp.width) / 2, labelTop));
  }

  @override
  bool shouldRepaint(_DropMergeLogoPainter old) => false;
}

// ── Animated background painter ──────────────────────────────────────────────

class DropMergeBgPainter extends AnimatedBgPainter {
  const DropMergeBgPainter(super.t);

  static const _items = <(double, double, double, double, int)>[
    (0.08, 0.10, 30, 0.0,  2),
    (0.82, 0.06, 24, 0.8,  4),
    (0.15, 0.55, 20, 1.6,  8),
    (0.88, 0.42, 28, 2.4,  16),
    (0.05, 0.80, 22, 3.2,  4),
    (0.74, 0.88, 18, 4.0,  2),
    (0.50, 0.03, 16, 4.8,  8),
    (0.40, 0.94, 22, 5.6,  32),
    (0.92, 0.65, 14, 1.2,  2),
    (0.04, 0.44, 18, 3.7,  16),
  ];

  static const _tileColors = {
    2:  Color(0xFFFFF3BF),
    4:  Color(0xFFFFE066),
    8:  Color(0xFFFFA94D),
    16: Color(0xFFFF6B6B),
    32: Color(0xFFE64980),
  };

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    for (final (xRel, yRel, tileSize, itemPhase, value) in _items) {
      final bobY  = math.sin(phase + itemPhase * 0.6) * (tileSize * 0.25);
      final rot   = math.sin(phase * 0.4 + itemPhase) * 0.12;
      final alpha = 0.05 + (math.sin(phase * 1.2 + itemPhase) + 1) / 2 * 0.06;
      final cx    = w * xRel;
      final cy    = h * yRel + bobY;
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
