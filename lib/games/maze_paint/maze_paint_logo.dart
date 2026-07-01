import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildMazePaintLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Maze Paint',
      bg: const [Color(0xFF831843), Color(0xFF500724)],
      accent: const Color(0xFFF472B6),
      art: _mazePaintArt,
    );

void _mazePaintArt(Canvas canvas, Rect zone) {
  const n = 5;
  final cell = zone.width / n;
  final ox = zone.left;
  final oy = zone.top + (zone.height - zone.width) / 2;
  final inset = cell * 0.06;
  final cr = Radius.circular(cell * 0.22);

  // 1 = floor, 0 = wall
  const maze = [
    [1, 1, 1, 1, 0],
    [0, 0, 1, 0, 0],
    [1, 1, 1, 1, 1],
    [1, 0, 0, 0, 1],
    [1, 1, 1, 0, 1],
  ];

  bool isFloor(int r, int c) =>
      r >= 0 && r < n && c >= 0 && c < n && maze[r][c] == 1;

  // Draw floor as merged contour: each cell expands to meet adjacent cells
  const floorColor = Color(0xFF4F5B6E);
  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      if (!isFloor(r, c)) continue;
      final x = ox + c * cell;
      final y = oy + r * cell;
      // Determine insets per side (0 if neighbor exists, inset if edge)
      final top = isFloor(r - 1, c) ? 0.0 : inset;
      final bot = isFloor(r + 1, c) ? 0.0 : inset;
      final lft = isFloor(r, c - 1) ? 0.0 : inset;
      final rgt = isFloor(r, c + 1) ? 0.0 : inset;
      final rect = Rect.fromLTRB(x + lft, y + top, x + cell - rgt, y + cell - bot);
      // Only round corners that are true outer corners
      final tl = (!isFloor(r - 1, c) && !isFloor(r, c - 1)) ? cr : Radius.zero;
      final tr = (!isFloor(r - 1, c) && !isFloor(r, c + 1)) ? cr : Radius.zero;
      final bl = (!isFloor(r + 1, c) && !isFloor(r, c - 1)) ? cr : Radius.zero;
      final br = (!isFloor(r + 1, c) && !isFloor(r, c + 1)) ? cr : Radius.zero;
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: tl, topRight: tr,
            bottomLeft: bl, bottomRight: br),
        Paint()..color = floorColor,
      );
    }
  }

  // Painted/visited cells as merged contour (same approach)
  const paintColor = Color(0xFF00D4AA);
  const painted = [
    [0, 0], [0, 1], [0, 2], [0, 3],
    [1, 2],
    [2, 2], [2, 1], [2, 0],
    [3, 0],
    [4, 0], [4, 1], [4, 2],
    [2, 3], [2, 4],
    [3, 4],
  ];

  bool isPainted(int r, int c) => painted.any((p) => p[0] == r && p[1] == c);

  for (final p in painted) {
    final r = p[0], c = p[1];
    final x = ox + c * cell;
    final y = oy + r * cell;
    final top = isPainted(r - 1, c) ? 0.0 : (isFloor(r - 1, c) ? 0.0 : inset);
    final bot = isPainted(r + 1, c) ? 0.0 : (isFloor(r + 1, c) ? 0.0 : inset);
    final lft = isPainted(r, c - 1) ? 0.0 : (isFloor(r, c - 1) ? 0.0 : inset);
    final rgt = isPainted(r, c + 1) ? 0.0 : (isFloor(r, c + 1) ? 0.0 : inset);
    final rect = Rect.fromLTRB(x + lft, y + top, x + cell - rgt, y + cell - bot);
    bool adjPainted(int dr, int dc) =>
        isPainted(r + dr, c + dc) || (isFloor(r + dr, c + dc) && !isPainted(r + dr, c + dc));
    final tl = (!adjPainted(-1, 0) && !adjPainted(0, -1)) ? cr : Radius.zero;
    final tr = (!adjPainted(-1, 0) && !adjPainted(0, 1)) ? cr : Radius.zero;
    final bl = (!adjPainted(1, 0) && !adjPainted(0, -1)) ? cr : Radius.zero;
    final br = (!adjPainted(1, 0) && !adjPainted(0, 1)) ? cr : Radius.zero;
    canvas.drawRRect(
      RRect.fromRectAndCorners(rect, topLeft: tl, topRight: tr,
          bottomLeft: bl, bottomRight: br),
      Paint()..color = paintColor,
    );
  }

  // Marble ball at paint trail front
  final ballPos = painted.last;
  final ballCx = ox + ballPos[1] * cell + cell * 0.5;
  final ballCy = oy + ballPos[0] * cell + cell * 0.5;
  final ballR = cell * 0.30;

  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(ballCx, ballCy + ballR * 0.25),
      width: ballR * 2.2,
      height: ballR * 0.6,
    ),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  canvas.drawCircle(
    Offset(ballCx, ballCy),
    ballR,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(ballCx - ballR * 0.3, ballCy - ballR * 0.3),
        ballR * 1.4,
        const [Color(0xFFFFFFFF), Color(0xFFF0F0F0), Color(0xFFD0D0D0), Color(0xFFAAAAAA)],
        [0.0, 0.3, 0.65, 1.0],
      ),
  );

  canvas.drawCircle(
    Offset(ballCx - ballR * 0.25, ballCy - ballR * 0.25),
    ballR * 0.13,
    Paint()..color = Colors.white,
  );
  canvas.drawCircle(
    Offset(ballCx - ballR * 0.05, ballCy - ballR * 0.35),
    ballR * 0.06,
    Paint()..color = Colors.white.withValues(alpha: 0.70),
  );

  // Start marker
  final startC = Offset(ox + cell * 0.5, oy + cell * 0.5);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: startC, width: cell * 0.52, height: cell * 0.52),
      Radius.circular(cell * 0.12),
    ),
    Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.07,
  );
}
