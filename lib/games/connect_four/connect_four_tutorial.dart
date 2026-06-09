import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> connectFourSteps() => [
      GameHowToPlayStep(
        text: 'Tap a column to drop your disc',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _DropPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Connect 4 in a row to win!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3200),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Win horizontally, vertically, or diagonally',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3000),
          painter: (t) => _DirectionsPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kRed = Color(0xFFE85D75);
const _kYellow = Color(0xFFF5C542);
const _kBoard = Color(0xFF3366CC);
const _kBg = Color(0xFFF0F4FF);

(Offset, double, double) _boardMetrics(Size size) {
  const cols = 7;
  const rows = 6;
  const pad = 10.0;
  final w = size.width - pad * 2;
  final h = size.height - pad * 2;
  final cellW = w / cols;
  final cellH = h / rows;
  final cell = math.min(cellW, cellH);
  final bw = cell * cols;
  final bh = cell * rows;
  final ox = (size.width - bw) / 2;
  final oy = (size.height - bh) / 2;
  return (Offset(ox, oy), cell, bw);
}

void _drawBoard(Canvas canvas, Size size, List<List<int>> grid) {
  final (origin, cell, bw) = _boardMetrics(size);
  const rows = 6;
  const cols = 7;

  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _kBg);

  final boardRect =
      Rect.fromLTWH(origin.dx, origin.dy, bw, cell * rows);
  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect, const Radius.circular(6)),
    Paint()..color = _kBoard,
  );

  final holePaint = Paint()..color = _kBg;
  final redPaint = Paint()..color = _kRed;
  final yellowPaint = Paint()..color = _kYellow;

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final cx = origin.dx + c * cell + cell / 2;
      final cy = origin.dy + r * cell + cell / 2;
      final radius = cell * 0.36;
      if (grid[r][c] == 0) {
        canvas.drawCircle(Offset(cx, cy), radius, holePaint);
      } else {
        canvas.drawCircle(
            Offset(cx, cy), radius, grid[r][c] == 1 ? redPaint : yellowPaint);
      }
    }
  }
}

List<List<int>> _emptyGrid() =>
    List.generate(6, (_) => List.filled(7, 0));

class _DropPainter extends CustomPainter {
  final double t;
  const _DropPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _emptyGrid();
    grid[5][3] = 1;
    if (t > 0.4) grid[5][4] = 2;
    if (t > 0.7) grid[4][3] = 1;
    _drawBoard(canvas, size, grid);

    if (t < 0.4) {
      final (origin, cell, _) = _boardMetrics(size);
      final dropT = (t / 0.4).clamp(0.0, 1.0);
      final cx = origin.dx + 3 * cell + cell / 2;
      final startY = origin.dy - cell * 0.5;
      final endY = origin.dy + 5 * cell + cell / 2;
      final cy = startY + (endY - startY) * Curves.bounceOut.transform(dropT);
      canvas.drawCircle(Offset(cx, cy), cell * 0.36, Paint()..color = _kRed);
    }
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _emptyGrid();
    grid[5][1] = 1;
    grid[5][2] = 1;
    grid[5][3] = 1;
    if (t > 0.3) grid[5][4] = 1;
    grid[4][2] = 2;
    grid[4][3] = 2;
    grid[5][5] = 2;
    _drawBoard(canvas, size, grid);

    if (t > 0.5) {
      final (origin, cell, _) = _boardMetrics(size);
      final lineT = ((t - 0.5) / 0.3).clamp(0.0, 1.0);
      final y = origin.dy + 5 * cell + cell / 2;
      final startX = origin.dx + 1 * cell + cell / 2;
      final endX = origin.dx + 4 * cell + cell / 2;
      final curX = startX + (endX - startX) * lineT;
      final paint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(startX, y), Offset(curX, y), paint);
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}

class _DirectionsPainter extends CustomPainter {
  final double t;
  const _DirectionsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _emptyGrid();
    grid[5][0] = 1; grid[4][0] = 1; grid[3][0] = 1; grid[2][0] = 1;
    grid[5][3] = 2; grid[4][4] = 2; grid[3][5] = 2; grid[2][6] = 2;
    _drawBoard(canvas, size, grid);

    final (origin, cell, _) = _boardMetrics(size);
    final phase = (t * 2 * math.pi);
    final alpha = (0.4 + 0.6 * ((math.sin(phase) + 1) / 2));
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final vx = origin.dx + 0 * cell + cell / 2;
    canvas.drawLine(
      Offset(vx, origin.dy + 5 * cell + cell / 2),
      Offset(vx, origin.dy + 2 * cell + cell / 2),
      paint,
    );

    canvas.drawLine(
      Offset(origin.dx + 3 * cell + cell / 2, origin.dy + 5 * cell + cell / 2),
      Offset(origin.dx + 6 * cell + cell / 2, origin.dy + 2 * cell + cell / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DirectionsPainter old) => old.t != t;
}
