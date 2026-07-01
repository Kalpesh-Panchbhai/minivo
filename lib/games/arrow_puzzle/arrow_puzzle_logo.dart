import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildArrowPuzzleLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Arrow Puzzle',
      bg: const [Color(0xFF4C1D95), Color(0xFF2E1065)],
      accent: const Color(0xFFA78BFA),
      art: _arrowArt,
    );

void _arrowArt(Canvas canvas, Rect zone) {
  final cx = zone.center.dx;
  final cy = zone.center.dy;
  final unit = zone.width * 0.16;
  final sw = unit * 0.30;

  void drawArrow(Offset from, Offset to, Color color, {bool glow = false}) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return;
    final ux = dx / len;
    final uy = dy / len;

    final headLen = unit * 0.36;
    final headW = unit * 0.24;
    final shaftEnd = Offset(to.dx - ux * headLen * 0.4, to.dy - uy * headLen * 0.4);

    if (glow) {
      canvas.drawCircle(
        Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2),
        unit * 0.7,
        Paint()
          ..color = const Color(0xFF22C55E).withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.5),
      );
    }

    canvas.drawLine(
      from,
      shaftEnd,
      Paint()
        ..color = color
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final px = -uy;
    final py = ux;
    final bx = to.dx - ux * headLen;
    final by = to.dy - uy * headLen;
    final cp1x = bx + px * headW + ux * headLen * 0.3;
    final cp1y = by + py * headW + uy * headLen * 0.3;
    final cp2x = bx - px * headW + ux * headLen * 0.3;
    final cp2y = by - py * headW + uy * headLen * 0.3;

    canvas.drawPath(
      Path()
        ..moveTo(to.dx, to.dy)
        ..quadraticBezierTo(cp1x, cp1y, bx + px * headW, by + py * headW)
        ..lineTo(bx - px * headW, by - py * headW)
        ..quadraticBezierTo(cp2x, cp2y, to.dx, to.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  const blue = Color(0xFF3B82F6);
  const orange = Color(0xFFF97316);
  const teal = Color(0xFF0D9488);
  const purple = Color(0xFF7C3AED);

  final al = unit * 1.6;

  // Row 1: two arrows
  drawArrow(
    Offset(cx - unit * 1.3, cy - unit * 1.2),
    Offset(cx + unit * 0.5, cy - unit * 1.2),
    purple,
  );
  drawArrow(
    Offset(cx + unit * 1.1, cy - unit * 0.6),
    Offset(cx + unit * 1.1, cy - unit * 0.6 - al * 0.75),
    blue,
  );

  // Row 2: two arrows crossing
  drawArrow(
    Offset(cx + unit * 0.8, cy - unit * 0.15),
    Offset(cx - unit * 1.0, cy - unit * 0.15),
    teal,
    glow: true,
  );
  drawArrow(
    Offset(cx - unit * 0.5, cy - unit * 0.5),
    Offset(cx - unit * 0.5, cy + unit * 0.6),
    orange,
  );

  // Row 3: three arrows
  drawArrow(
    Offset(cx - unit * 1.2, cy + unit * 0.55),
    Offset(cx + unit * 0.6, cy + unit * 0.55),
    purple,
  );
  drawArrow(
    Offset(cx + unit * 1.2, cy + unit * 0.3),
    Offset(cx + unit * 1.2, cy + unit * 1.4),
    orange,
  );
  drawArrow(
    Offset(cx + unit * 0.4, cy + unit * 1.2),
    Offset(cx - unit * 1.3, cy + unit * 1.2),
    blue,
  );
}
