import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildChessLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Chess',
      bg: const [Color(0xFF2D3436), Color(0xFF1A1A2E)],
      accent: const Color(0xFFD4AF37),
      art: _chessArt,
    );

void _chessArt(Canvas canvas, Rect zone) {
  final s = zone.width;
  final cx = zone.center.dx;
  final cy = zone.center.dy;

  final cellSize = s * 0.22;
  final boardLeft = cx - cellSize;
  final boardTop = cy + s * 0.08;
  final light = Paint()..color = const Color(0xFFF0D9B5).withValues(alpha: 0.5);
  final dark = Paint()..color = const Color(0xFFB58863).withValues(alpha: 0.5);
  for (int r = 0; r < 2; r++) {
    for (int c = 0; c < 2; c++) {
      final isDark = (r + c) % 2 == 0;
      canvas.drawRect(
        Rect.fromLTWH(boardLeft + c * cellSize, boardTop + r * cellSize,
            cellSize, cellSize),
        isDark ? dark : light,
      );
    }
  }

  final knightPath = Path();
  final kx = cx;
  final ky = cy - s * 0.04;
  final ks = s * 0.38;

  knightPath.moveTo(kx - ks * 0.30, ky + ks * 0.50);
  knightPath.lineTo(kx + ks * 0.30, ky + ks * 0.50);
  knightPath.lineTo(kx + ks * 0.30, ky + ks * 0.38);
  knightPath.quadraticBezierTo(
      kx + ks * 0.32, ky + ks * 0.10, kx + ks * 0.22, ky - ks * 0.10);
  knightPath.quadraticBezierTo(
      kx + ks * 0.18, ky - ks * 0.22, kx + ks * 0.10, ky - ks * 0.30);
  knightPath.quadraticBezierTo(
      kx + ks * 0.05, ky - ks * 0.38, kx - ks * 0.05, ky - ks * 0.50);
  knightPath.quadraticBezierTo(
      kx - ks * 0.12, ky - ks * 0.48, kx - ks * 0.18, ky - ks * 0.38);
  knightPath.lineTo(kx - ks * 0.35, ky - ks * 0.18);
  knightPath.quadraticBezierTo(
      kx - ks * 0.42, ky - ks * 0.08, kx - ks * 0.38, ky + ks * 0.05);
  knightPath.lineTo(kx - ks * 0.22, ky - ks * 0.05);
  knightPath.quadraticBezierTo(
      kx - ks * 0.32, ky + ks * 0.12, kx - ks * 0.30, ky + ks * 0.25);
  knightPath.quadraticBezierTo(
      kx - ks * 0.30, ky + ks * 0.38, kx - ks * 0.30, ky + ks * 0.50);
  knightPath.close();

  canvas.drawPath(
    knightPath.shift(const Offset(1.5, 2)),
    Paint()..color = Colors.black.withValues(alpha: 0.30),
  );

  canvas.drawPath(knightPath, Paint()..color = Colors.white);

  canvas.drawPath(
    knightPath,
    Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.025
      ..strokeJoin = StrokeJoin.round,
  );

  final eyeCenter = Offset(kx + ks * 0.05, ky - ks * 0.20);
  canvas.drawCircle(eyeCenter, ks * 0.04, Paint()..color = const Color(0xFF1A1A2E));

  final basePath = Path();
  basePath.moveTo(kx - ks * 0.38, ky + ks * 0.50);
  basePath.lineTo(kx + ks * 0.38, ky + ks * 0.50);
  basePath.lineTo(kx + ks * 0.38, ky + ks * 0.58);
  basePath.lineTo(kx - ks * 0.38, ky + ks * 0.58);
  basePath.close();
  canvas.drawPath(basePath, Paint()..color = Colors.white);
  canvas.drawPath(
    basePath,
    Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02,
  );
}
