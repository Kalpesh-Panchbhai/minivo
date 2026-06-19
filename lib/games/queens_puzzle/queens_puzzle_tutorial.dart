import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

const _kAccent = Color(0xFFD4A0FF);

const _regionColors = [
  Color(0xFFFF6B6B),
  Color(0xFF51CF66),
  Color(0xFF339AF0),
  Color(0xFFFFD43B),
];

const _regions = [
  [0, 1, 4, 5],
  [2, 3, 6, 7],
  [8, 9, 12, 13],
  [10, 11, 14, 15],
];

const _solution = [
  [0, 2],
  [1, 0],
  [2, 3],
  [3, 1],
];

List<GameHowToPlayStep> queensPuzzleSteps() => [
      GameHowToPlayStep(
        text: 'Place one queen in each colored region. Tap a cell to place.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _QueensBoardPainter(t, placeFraction: t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Each row and column must have exactly one queen.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _QueensBoardPainter(t, placeFraction: 1.0, highlightRowCol: true),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Queens cannot touch — not even diagonally!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _QueensBoardPainter(t, placeFraction: 1.0, highlightAdjacent: true),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Long press to mark cells with X. Solve all regions to win!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _QueensBoardPainter(1.0, placeFraction: 1.0, celebrate: t),
          canvasSize: const Size(200, 180),
        ),
      ),
    ];

class _QueensBoardPainter extends CustomPainter {
  final double t;
  final double placeFraction;
  final bool highlightRowCol;
  final bool highlightAdjacent;
  final double celebrate;

  _QueensBoardPainter(this.t,
      {required this.placeFraction,
      this.highlightRowCol = false,
      this.highlightAdjacent = false,
      this.celebrate = -1});

  @override
  void paint(Canvas canvas, Size size) {
    const n = 4;
    const cellS = 34.0, gap = 3.0;
    final totalW = n * cellS + (n - 1) * gap;
    final totalH = n * cellS + (n - 1) * gap;
    final ox = (size.width - totalW) / 2;
    final oy = (size.height - totalH) / 2;

    Rect cellRect(int r, int c) => Rect.fromLTWH(
          ox + c * (cellS + gap),
          oy + r * (cellS + gap),
          cellS,
          cellS,
        );

    for (int reg = 0; reg < n; reg++) {
      for (final idx in _regions[reg]) {
        final r = idx ~/ n, c = idx % n;
        final rect = cellRect(r, c);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
        canvas.drawRRect(rr, Paint()..color = _regionColors[reg].withValues(alpha: 0.25));
        canvas.drawRRect(
            rr,
            Paint()
              ..color = _regionColors[reg].withValues(alpha: 0.50)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0);
      }
    }

    if (highlightRowCol) {
      final idx = (t * 4).floor().clamp(0, 3);
      final qr = _solution[idx][0], qc = _solution[idx][1];
      for (int c = 0; c < n; c++) {
        final rect = cellRect(qr, c);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(5)),
            Paint()..color = _kAccent.withValues(alpha: 0.18));
      }
      for (int r = 0; r < n; r++) {
        final rect = cellRect(r, qc);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(5)),
            Paint()..color = _kAccent.withValues(alpha: 0.18));
      }
    }

    if (highlightAdjacent) {
      final idx = (t * 4).floor().clamp(0, 3);
      final qr = _solution[idx][0], qc = _solution[idx][1];
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nr = qr + dr, nc = qc + dc;
          if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
          final rect = cellRect(nr, nc);
          canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(5)),
              Paint()..color = Colors.red.withValues(alpha: 0.20));
          final ctr = rect.center;
          final xSize = cellS * 0.18;
          final xPaint = Paint()
            ..color = Colors.red.withValues(alpha: 0.55)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(ctr.dx - xSize, ctr.dy - xSize),
              Offset(ctr.dx + xSize, ctr.dy + xSize), xPaint);
          canvas.drawLine(Offset(ctr.dx + xSize, ctr.dy - xSize),
              Offset(ctr.dx - xSize, ctr.dy + xSize), xPaint);
        }
      }
    }

    final queensToShow = (placeFraction * 4).ceil().clamp(0, 4);
    for (int i = 0; i < queensToShow; i++) {
      final qr = _solution[i][0], qc = _solution[i][1];
      final ctr = cellRect(qr, qc).center;
      final cr = cellS * 0.30;
      canvas.drawCircle(ctr, cr, Paint()..color = const Color(0xFFFFD43B));
      _drawCrown(canvas, ctr, cr * 0.7);
    }

    if (celebrate >= 0) {
      final scale = 0.85 + 0.15 * math.sin(celebrate * math.pi * 2);
      final bc = Offset(ox + totalW - 6, oy - 2);
      canvas.save();
      canvas.translate(bc.dx, bc.dy);
      canvas.scale(scale);
      canvas.drawCircle(Offset.zero, 13, Paint()..color = const Color(0xFF51CF66));
      final check = Path()
        ..moveTo(-5, 0)
        ..lineTo(-1.5, 4)
        ..lineTo(6, -4);
      canvas.drawPath(
          check,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
      canvas.restore();
    }
  }

  void _drawCrown(Canvas canvas, Offset ctr, double s) {
    final path = Path();
    final cx = ctr.dx, cy = ctr.dy;
    path.moveTo(cx - s, cy + s * 0.35);
    path.lineTo(cx - s, cy - s * 0.2);
    path.lineTo(cx - s * 0.5, cy + s * 0.1);
    path.lineTo(cx, cy - s * 0.55);
    path.lineTo(cx + s * 0.5, cy + s * 0.1);
    path.lineTo(cx + s, cy - s * 0.2);
    path.lineTo(cx + s, cy + s * 0.35);
    path.close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_QueensBoardPainter old) => true;
}
