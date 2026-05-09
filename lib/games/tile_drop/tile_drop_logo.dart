import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../shared/animated_background.dart';

Widget buildTileDropLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFF922B), Color(0xFFE8590C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _TileDropLogoPainter(),
    ),
  );
}

class _TileDropLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 3×2 mini grid of tiles
    const cols = 3;
    const rows = 2;
    final gridW  = w * 0.72;
    final gridH  = h * 0.50;
    final left   = (w - gridW) / 2;
    final top    = h * 0.06;
    final cellW  = gridW / cols;
    final cellH  = gridH / rows;
    const pad    = 3.0;
    const radius = Radius.circular(6);

    final tileValues = [
      [2,   4,   8 ],
      [4,   8,  16 ],
    ];

    final tileColors = {
      2:  const Color(0xFFFFF3BF),
      4:  const Color(0xFFFFE066),
      8:  const Color(0xFFFFA94D),
      16: const Color(0xFFFF6B6B),
    };
    final tileTextColors = {
      2:  Colors.black,
      4:  Colors.black,
      8:  Colors.white,
      16: Colors.white,
    };

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final val   = tileValues[r][c];
        final color = tileColors[val] ?? const Color(0xFFFFF3BF);
        final tx    = left + c * cellW + pad;
        final ty    = top  + r * cellH + pad;
        final tw    = cellW - pad * 2;
        final th    = cellH - pad * 2;

        // Subtle shadow
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(tx + 1, ty + 2, tw, th),
            radius,
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.18),
        );

        // Tile body
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(tx, ty, tw, th), radius),
          Paint()..color = color,
        );

        // Specular shine
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(tx + 2, ty + 2, tw * 0.55, th * 0.38), radius),
          Paint()..color = Colors.white.withValues(alpha: 0.28),
        );

        // Number
        final textColor = tileTextColors[val] ?? Colors.black;
        final fontSize  = (tw * 0.38).clamp(7.0, 14.0);
        final tp = TextPainter(
          text: TextSpan(
            text: '$val',
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(tx + tw / 2 - tp.width / 2, ty + th / 2 - tp.height / 2));
      }
    }

    // "TILE DROP" label at bottom
    final fontSize = (w * 0.16).clamp(8.0, 22.0);
    final tp = TextPainter(
      text: TextSpan(
        text: 'TILE DROP',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 0.8,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h - tp.height - h * 0.03));
  }

  @override
  bool shouldRepaint(_TileDropLogoPainter old) => false;
}

// ── Animated background painter ──────────────────────────────────────────────

class TileDropBgPainter extends AnimatedBgPainter {
  const TileDropBgPainter(super.t);

  static const _items = <(double, double, double, double, int)>[
    // (xRel, yRel, size, phase, value)
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
