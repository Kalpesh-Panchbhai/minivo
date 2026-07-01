import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildBlockEscapeLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Block Escape',
      bg: const [Color(0xFF5C3D2E), Color(0xFF3A2518)],
      accent: const Color(0xFFE74C3C),
      art: _blockEscapeArt,
    );

void _blockEscapeArt(Canvas canvas, Rect zone) {
  const n = 5;
  final cell = zone.width / n;
  final ox = zone.left;
  final oy = zone.top + (zone.height - zone.width) / 2;
  final boardSize = zone.width;
  final gap = cell * 0.06;
  final r = cell * 0.18;

  final boardRect = Rect.fromLTWH(ox, oy, boardSize, boardSize);
  final boardR = Radius.circular(r * 1.6);

  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect, boardR),
    Paint()..color = const Color(0xFF5C3D2E),
  );

  final borderPaint = Paint()
    ..color = const Color(0xFFA67C5B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = cell * 0.10;

  final gateRowTop = oy + 2 * cell;
  final gateRowBottom = oy + 3 * cell;

  canvas.drawPath(
    Path()
      ..moveTo(boardRect.topLeft.dx + boardR.x, boardRect.topLeft.dy)
      ..lineTo(boardRect.topRight.dx - boardR.x, boardRect.topRight.dy)
      ..arcToPoint(
          Offset(boardRect.topRight.dx, boardRect.topRight.dy + boardR.x),
          radius: boardR)
      ..lineTo(boardRect.right, gateRowTop)
      ..moveTo(boardRect.right, gateRowBottom)
      ..lineTo(boardRect.right, boardRect.bottom - boardR.x)
      ..arcToPoint(Offset(boardRect.right - boardR.x, boardRect.bottom),
          radius: boardR)
      ..lineTo(boardRect.left + boardR.x, boardRect.bottom)
      ..arcToPoint(Offset(boardRect.left, boardRect.bottom - boardR.x),
          radius: boardR)
      ..lineTo(boardRect.left, boardRect.top + boardR.x)
      ..arcToPoint(Offset(boardRect.left + boardR.x, boardRect.top),
          radius: boardR),
    borderPaint,
  );

  final gateW = cell * 0.18;
  final gateX = boardRect.right - gateW * 0.5;
  final gateRect = Rect.fromLTWH(gateX, gateRowTop, gateW, cell);
  canvas.drawRect(
    gateRect,
    Paint()
      ..shader = ui.Gradient.linear(
        gateRect.topCenter,
        gateRect.bottomCenter,
        const [Color(0xFFE74C3C), Color(0xFFC0392B), Color(0xFF922B21)],
        [0.0, 0.5, 1.0],
      ),
  );
  final hingeR = cell * 0.06;
  final hingeP = Paint()..color = const Color(0xFFD4A017);
  canvas.drawCircle(
      Offset(gateX + gateW * 0.5, gateRowTop + cell * 0.2), hingeR, hingeP);
  canvas.drawCircle(
      Offset(gateX + gateW * 0.5, gateRowBottom - cell * 0.2), hingeR, hingeP);

  void drawBlock(
      double col, double row, double w, double h, Color c1, Color c2) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        ox + col * cell + gap,
        oy + row * cell + gap,
        w * cell - gap * 2,
        h * cell - gap * 2,
      ),
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
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.38),
        Radius.circular(r),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
  }

  const amberC1 = Color(0xFFEEC060);
  const amberC2 = Color(0xFFE8A838);

  drawBlock(0, 0, 1, 2, amberC1, amberC2);
  drawBlock(2, 0, 2, 1, amberC1, amberC2);
  drawBlock(3, 1, 1, 2, amberC1, amberC2);
  drawBlock(1, 3, 1, 2, amberC1, amberC2);
  drawBlock(3, 3, 2, 1, amberC1, amberC2);

  const redC1 = Color(0xFFF07070);
  const redC2 = Color(0xFFE74C3C);
  drawBlock(1, 2, 2, 1, redC1, redC2);

  final chevCx = ox + 2 * cell + cell * 0.15;
  final chevCy = oy + 2.5 * cell;
  final chevS = cell * 0.22;
  canvas.drawPath(
    Path()
      ..moveTo(chevCx - chevS * 0.3, chevCy - chevS)
      ..lineTo(chevCx + chevS * 0.5, chevCy)
      ..lineTo(chevCx - chevS * 0.3, chevCy + chevS),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..strokeWidth = cell * 0.08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}
