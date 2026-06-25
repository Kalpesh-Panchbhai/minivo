import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildBlockEscapeLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Block Escape',
      bg: const [Color(0xFF5C3D2E), Color(0xFF3A2415)],
      accent: const Color(0xFFE74C3C),
      art: _blockEscapeArt,
    );

void _blockEscapeArt(Canvas canvas, Rect zone) {
  const grid = 6;
  final cell = zone.width / (grid + 0.6);
  final boardW = cell * grid;
  final boardH = cell * grid;
  final ox = zone.left + (zone.width - boardW) / 2;
  final oy = zone.top + (zone.height - boardH) / 2;
  final gap = cell * 0.06;
  final r = cell * 0.15;
  const exitRow = 2;

  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(ox, oy, boardW, boardH), Radius.circular(r * 1.5)),
    Paint()..color = const Color(0xFF5C3D2E),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(ox, oy, boardW, boardH), Radius.circular(r * 1.5)),
    Paint()..color = const Color(0xFFA67C5B)..style = PaintingStyle.stroke..strokeWidth = cell * 0.06,
  );

  void drawBlock(double col, double row, double w, double h, Color c1, Color c2, {bool showChevron = false}) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(ox + col * cell + gap, oy + row * cell + gap, w * cell - gap * 2, h * cell - gap * 2),
      Radius.circular(r),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.outerRect.topLeft,
          rect.outerRect.bottomRight,
          [c1, c2],
        ),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = c2.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = cell * 0.03,
    );
    if (showChevron) {
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final s = rect.height * 0.25;
      final chevPath = Path()
        ..moveTo(cx - s * 0.3, cy - s)
        ..lineTo(cx + s * 0.5, cy)
        ..lineTo(cx - s * 0.3, cy + s);
      canvas.drawPath(
        chevPath,
        Paint()..color = Colors.white.withValues(alpha: 0.85)..strokeWidth = cell * 0.07..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round,
      );
    }
  }

  const bC1 = Color(0xFFEEC060);
  const bC2 = Color(0xFFE8A838);
  const tC1 = Color(0xFFF07070);
  const tC2 = Color(0xFFE74C3C);

  drawBlock(1, 0, 2, 1, bC1, bC2);
  drawBlock(4, 0, 1, 2, bC1, bC2);
  drawBlock(0, exitRow.toDouble(), 2, 1, tC1, tC2, showChevron: true);
  drawBlock(3, 1, 1, 3, bC1, bC2);
  drawBlock(5, 2, 1, 2, bC1, bC2);
  drawBlock(0, 4, 2, 1, bC1, bC2);
  drawBlock(2, 4, 1, 2, bC1, bC2);
  drawBlock(4, 4, 2, 1, bC1, bC2);

  final gateX = ox + boardW;
  final gateY = oy + exitRow * cell + gap;
  final gateH = cell - gap * 2;
  final gateW = cell * 0.35;
  canvas.drawRRect(
    RRect.fromLTRBAndCorners(gateX - 1, gateY, gateX + gateW, gateY + gateH, topRight: Radius.circular(r * 0.6), bottomRight: Radius.circular(r * 0.6)),
    Paint()..color = const Color(0xFF27AE60),
  );
  final ax = gateX + gateW * 0.6;
  final ay = gateY + gateH / 2;
  final as2 = gateH * 0.2;
  canvas.drawPath(
    Path()..moveTo(ax - as2 * 0.4, ay - as2)..lineTo(ax + as2 * 0.4, ay)..lineTo(ax - as2 * 0.4, ay + as2),
    Paint()..color = Colors.white.withValues(alpha: 0.85)..strokeWidth = cell * 0.06..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round,
  );
}
