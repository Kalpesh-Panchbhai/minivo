import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

// Tutorial demos that mirror the real Zip board: a grid of cells, numbered
// checkpoints drawn as dark circles, and a gradient path drawn cell-to-cell.
const _kPathStart = Color(0xFF22C55E);
const _kPathEnd = Color(0xFF16A34A);
const _kCellBg = Color(0xFFDCFCE7);

// A 4x4 snake solution path (row-by-row boustrophedon) — 16 cells.
const List<List<int>> _solution = [
  [0, 0], [0, 1], [0, 2], [0, 3],
  [1, 3], [1, 2], [1, 1], [1, 0],
  [2, 0], [2, 1], [2, 2], [2, 3],
  [3, 3], [3, 2], [3, 1], [3, 0],
];
// Checkpoints: path index -> number (1 at the start, ascending along the path).
const Map<int, String> _checkpoints = {0: '1', 5: '2', 10: '3', 15: '4'};

List<GameHowToPlayStep> zipSteps() => [
      GameHowToPlayStep(
        text: 'Swipe to draw one path that visits every cell exactly once.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _ZipBoardPainter(t, drawFraction: t),
          canvasSize: const Size(200, 170),
        ),
      ),
      GameHowToPlayStep(
        text: 'Pass through the numbered cells in order: 1 → 2 → 3 → 4.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _ZipBoardPainter(t, drawFraction: t, highlightOrder: true),
          canvasSize: const Size(200, 170),
        ),
      ),
      GameHowToPlayStep(
        text: 'Fill every cell to win. Retrace your path to undo a move.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) {
            double fraction;
            double celebrateT;
            if (t < 0.5) {
              fraction = 1.0;
              celebrateT = t / 0.5;
            } else if (t < 0.75) {
              final retractT = (t - 0.5) / 0.25;
              fraction = 1.0 - retractT * 0.25;
              celebrateT = -1;
            } else {
              final extendT = (t - 0.75) / 0.25;
              fraction = 0.75 + extendT * 0.25;
              celebrateT = extendT;
            }
            return _ZipBoardPainter(t, drawFraction: fraction, celebrate: celebrateT);
          },
          canvasSize: const Size(200, 170),
        ),
      ),
    ];

class _ZipBoardPainter extends CustomPainter {
  final double t;
  final double drawFraction; // 0..1 how much of the path is drawn
  final bool highlightOrder;
  final double celebrate; // 0..1 pulse when complete

  _ZipBoardPainter(this.t,
      {required this.drawFraction, this.highlightOrder = false, this.celebrate = -1});

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 4, rows = 4;
    const cellS = 30.0, gap = 4.0;
    final totalW = cols * cellS + (cols - 1) * gap;
    final totalH = rows * cellS + (rows - 1) * gap;
    final ox = (size.width - totalW) / 2;
    final oy = (size.height - totalH) / 2;

    Offset center(int r, int c) => Offset(
          ox + c * (cellS + gap) + cellS / 2,
          oy + r * (cellS + gap) + cellS / 2,
        );

    // cells
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(ox + c * (cellS + gap), oy + r * (cellS + gap), cellS, cellS),
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, Paint()..color = _kCellBg.withValues(alpha: 0.18));
        canvas.drawRRect(
            rect,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.22)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8);
      }
    }

    // path (gradient, rounded) up to drawFraction
    final drawn = (drawFraction * (_solution.length - 1)).clamp(0.0, (_solution.length - 1).toDouble());
    final fullSegs = drawn.floor();
    if (drawFraction > 0) {
      final path = Path();
      final first = center(_solution[0][0], _solution[0][1]);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i <= fullSegs && i < _solution.length; i++) {
        final p = center(_solution[i][0], _solution[i][1]);
        path.lineTo(p.dx, p.dy);
      }
      if (fullSegs < _solution.length - 1) {
        final frac = drawn - fullSegs;
        final a = center(_solution[fullSegs][0], _solution[fullSegs][1]);
        final b = center(_solution[fullSegs + 1][0], _solution[fullSegs + 1][1]);
        path.lineTo(a.dx + (b.dx - a.dx) * frac, a.dy + (b.dy - a.dy) * frac);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = ui.Gradient.linear(
            Offset(ox, oy),
            Offset(ox + totalW, oy + totalH),
            [_kPathStart, _kPathEnd],
          ),
      );
    }

    // checkpoints (dark circle + white number) — always visible
    final nextNum = highlightOrder ? (1 + (t * 4).floor()).clamp(1, 4) : 0;
    for (final entry in _checkpoints.entries) {
      final cell = _solution[entry.key];
      final ctr = center(cell[0], cell[1]);
      final cr = cellS * 0.34;
      final isNext = highlightOrder && int.parse(entry.value) == nextNum;
      canvas.drawCircle(ctr.translate(0, 1), cr, Paint()..color = Colors.black.withValues(alpha: 0.20));
      canvas.drawCircle(ctr, cr, Paint()..color = const Color(0xFF1F2937));
      if (isNext) {
        canvas.drawCircle(
            ctr,
            cr + 3,
            Paint()
              ..color = _kPathStart
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: cellS * 0.42, height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(ctr.dx - tp.width / 2, ctr.dy - tp.height / 2));
    }

    // complete badge
    if (celebrate >= 0) {
      final scale = 0.85 + 0.15 * math.sin(celebrate * math.pi * 2);
      final bc = Offset(ox + totalW - 6, oy - 2);
      canvas.save();
      canvas.translate(bc.dx, bc.dy);
      canvas.scale(scale);
      canvas.drawCircle(Offset.zero, 13, Paint()..color = const Color(0xFF22C55E));
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

  @override
  bool shouldRepaint(_ZipBoardPainter old) => old.t != t;
}
