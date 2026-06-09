import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> reversiSteps() => [
      GameHowToPlayStep(
        text: 'Place a disc to sandwich opponent pieces',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3000),
          painter: (t) => _PlacePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Sandwiched pieces flip to your color',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3200),
          painter: (t) => _FlipPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Most discs when the board fills wins!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3000),
          painter: (t) => _CountPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kBlack = Color(0xFF1A1A1A);
const _kWhite = Color(0xFFF5F5F5);
const _kBoard = Color(0xFF2E7D32);
const _kBg = Color(0xFFF0F8F0);

(Offset, double) _boardMetrics(Size size) {
  const n = 4;
  const pad = 14.0;
  final s = math.min(size.width, size.height) - pad * 2;
  final cell = s / n;
  final ox = (size.width - s) / 2;
  final oy = (size.height - s) / 2;
  return (Offset(ox, oy), cell);
}

void _drawBoardBase(Canvas canvas, Size size) {
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _kBg);
  final (origin, cell) = _boardMetrics(size);
  const n = 4;
  final s = cell * n;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, s, s), const Radius.circular(4)),
    Paint()..color = _kBoard,
  );
  final gridPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.15)
    ..strokeWidth = 0.8;
  for (int i = 1; i < n; i++) {
    canvas.drawLine(
        Offset(origin.dx + i * cell, origin.dy),
        Offset(origin.dx + i * cell, origin.dy + s),
        gridPaint);
    canvas.drawLine(
        Offset(origin.dx, origin.dy + i * cell),
        Offset(origin.dx + s, origin.dy + i * cell),
        gridPaint);
  }
}

void _drawDisc(Canvas canvas, double cx, double cy, double r, bool isBlack) {
  final color = isBlack ? _kBlack : _kWhite;
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
}

class _PlacePainter extends CustomPainter {
  final double t;
  const _PlacePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBoardBase(canvas, size);
    final (origin, cell) = _boardMetrics(size);
    final r = cell * 0.34;

    _drawDisc(canvas, origin.dx + 1 * cell + cell / 2, origin.dy + 1 * cell + cell / 2, r, false);
    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2, origin.dy + 2 * cell + cell / 2, r, false);
    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2, origin.dy + 1 * cell + cell / 2, r, true);
    _drawDisc(canvas, origin.dx + 1 * cell + cell / 2, origin.dy + 2 * cell + cell / 2, r, true);

    if (t > 0.4) {
      final cx = origin.dx + 0 * cell + cell / 2;
      final cy = origin.dy + 1 * cell + cell / 2;
      final alpha = ((t - 0.4) / 0.2).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _kBlack.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_PlacePainter old) => old.t != t;
}

class _FlipPainter extends CustomPainter {
  final double t;
  const _FlipPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBoardBase(canvas, size);
    final (origin, cell) = _boardMetrics(size);
    final r = cell * 0.34;

    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2, origin.dy + 2 * cell + cell / 2, r, false);
    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2, origin.dy + 1 * cell + cell / 2, r, true);
    _drawDisc(canvas, origin.dx + 1 * cell + cell / 2, origin.dy + 2 * cell + cell / 2, r, true);

    final flipped = t > 0.5;
    _drawDisc(canvas, origin.dx + 1 * cell + cell / 2, origin.dy + 1 * cell + cell / 2, r, flipped ? true : false);

    _drawDisc(canvas, origin.dx + 0 * cell + cell / 2, origin.dy + 1 * cell + cell / 2, r, true);
  }

  @override
  bool shouldRepaint(_FlipPainter old) => old.t != t;
}

class _CountPainter extends CustomPainter {
  final double t;
  const _CountPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBoardBase(canvas, size);
    final (origin, cell) = _boardMetrics(size);
    final r = cell * 0.34;
    const n = 4;

    final grid = [
      [1, 1, 2, 2],
      [1, 1, 1, 2],
      [2, 1, 2, 1],
      [2, 2, 1, 1],
    ];
    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n; col++) {
        _drawDisc(
          canvas,
          origin.dx + col * cell + cell / 2,
          origin.dy + row * cell + cell / 2,
          r,
          grid[row][col] == 1,
        );
      }
    }

    final alpha = (0.5 + 0.5 * math.sin(t * 2 * math.pi)).clamp(0.0, 1.0);
    final tp = TextPainter(
      text: TextSpan(
        text: '9 - 7',
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 20));
  }

  @override
  bool shouldRepaint(_CountPainter old) => old.t != t;
}
