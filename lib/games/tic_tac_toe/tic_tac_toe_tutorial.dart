import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

// ── Public API ──────────────────────────────────────────────────────────────

List<GameHowToPlayStep> ticTacToeSteps() => [
      GameHowToPlayStep(
        text: 'Tap any empty cell to place your X',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _TttPlacePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'The AI responds with O',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _TttAiPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Three in a row wins!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _TttWinPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

// ── Shared drawing helpers ──────────────────────────────────────────────────

const _kXColor = Color(0xFFE85D75);
const _kOColor = Color(0xFF5BC0DE);
const _kGridColor = Color(0xFF7C4DFF);
const _kBg = Color(0xFFFFF9F5);

void _drawGrid(Canvas canvas, Size size, double cellSize, Offset origin) {
  final paint = Paint()
    ..color = _kGridColor.withValues(alpha: 0.35)
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;

  // Vertical lines
  for (int i = 1; i < 3; i++) {
    canvas.drawLine(
      Offset(origin.dx + i * cellSize, origin.dy),
      Offset(origin.dx + i * cellSize, origin.dy + 3 * cellSize),
      paint,
    );
  }
  // Horizontal lines
  for (int i = 1; i < 3; i++) {
    canvas.drawLine(
      Offset(origin.dx, origin.dy + i * cellSize),
      Offset(origin.dx + 3 * cellSize, origin.dy + i * cellSize),
      paint,
    );
  }
}

Offset _cellCenter(int col, int row, double cellSize, Offset origin) {
  return Offset(
    origin.dx + col * cellSize + cellSize / 2,
    origin.dy + row * cellSize + cellSize / 2,
  );
}

void _drawX(Canvas canvas, Offset center, double size, double progress,
    {double opacity = 1.0}) {
  final half = size * 0.32;
  final paint = Paint()
    ..color = _kXColor.withValues(alpha: opacity)
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round;

  // First stroke: top-left to bottom-right
  final p1 = progress.clamp(0.0, 1.0);
  if (p1 > 0) {
    canvas.drawLine(
      Offset(center.dx - half, center.dy - half),
      Offset(center.dx - half + half * 2 * p1, center.dy - half + half * 2 * p1),
      paint,
    );
  }
  // Second stroke: top-right to bottom-left
  final p2 = ((progress - 0.5) * 2).clamp(0.0, 1.0);
  if (p2 > 0) {
    canvas.drawLine(
      Offset(center.dx + half, center.dy - half),
      Offset(center.dx + half - half * 2 * p2, center.dy - half + half * 2 * p2),
      paint,
    );
  }
}

void _drawO(Canvas canvas, Offset center, double cellSize, double progress,
    {double opacity = 1.0}) {
  final r = cellSize * 0.28;
  final paint = Paint()
    ..color = _kOColor.withValues(alpha: opacity)
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  final sweep = progress * 2 * math.pi;
  canvas.drawArc(
    Rect.fromCenter(center: center, width: r * 2, height: r * 2),
    -math.pi / 2,
    sweep,
    false,
    paint,
  );
}

// ── Step 1: X animates into a cell, finger icon appears ────────────────────

class _TttPlacePainter extends CustomPainter {
  final double t;
  const _TttPlacePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kBg);

    final cellSize = size.width * 0.26;
    final gridW = cellSize * 3;
    final origin = Offset((size.width - gridW) / 2, (size.height - gridW) / 2);

    _drawGrid(canvas, size, cellSize, origin);

    // Cycle: 0-0.6 draw X, 0.6-0.8 show finger, 0.8-1.0 fade out + move to new cell
    final cycle = t % 1.0;

    // Which cell to draw in (cycles through 0,0 → 2,0 → 1,2)
    final cellCycle = (t * 0.33).floor() % 3;
    final cells = [[0, 0], [2, 0], [1, 2]];
    final cell = cells[cellCycle];

    final center = _cellCenter(cell[0], cell[1], cellSize, origin);
    final drawProgress = (cycle / 0.55).clamp(0.0, 1.0);
    final fadeAlpha = cycle > 0.80 ? (1 - (cycle - 0.80) / 0.20).clamp(0.0, 1.0) : 1.0;

    _drawX(canvas, center, cellSize, drawProgress, opacity: fadeAlpha);

    // Finger pointer
    if (cycle > 0.55 && cycle < 0.80) {
      final fingerAlpha = ((cycle - 0.55) / 0.12).clamp(0.0, 1.0) *
          (1 - ((cycle - 0.68) / 0.12).clamp(0.0, 1.0));
      final tp = TextPainter(
        text: TextSpan(
          text: '👆',
          style: TextStyle(
            fontSize: cellSize * 0.5,
            color: Colors.black.withValues(alpha: fingerAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(center.dx - tp.width / 2, center.dy - cellSize * 0.1 - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _TttPlacePainter old) => old.t != t;
}

// ── Step 2: X already placed, O animates in, robot icon ────────────────────

class _TttAiPainter extends CustomPainter {
  final double t;
  const _TttAiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kBg);

    final cellSize = size.width * 0.26;
    final gridW = cellSize * 3;
    final origin = Offset((size.width - gridW) / 2, (size.height - gridW) / 2);

    _drawGrid(canvas, size, cellSize, origin);

    // X already in (0,0)
    _drawX(canvas, _cellCenter(0, 0, cellSize, origin), cellSize, 1.0);

    // O animates into (1,1)
    final oProgress = (t / 0.65).clamp(0.0, 1.0);
    _drawO(canvas, _cellCenter(1, 1, cellSize, origin), cellSize, oProgress);

    // Robot icon appears above (1,1) briefly
    if (t > 0.30 && t < 0.75) {
      final robotAlpha = ((t - 0.30) / 0.18).clamp(0.0, 1.0) *
          (1 - ((t - 0.60) / 0.15).clamp(0.0, 1.0));
      final robotCenter = _cellCenter(1, 1, cellSize, origin);
      final tp = TextPainter(
        text: TextSpan(
          text: '🤖',
          style: TextStyle(
            fontSize: cellSize * 0.45,
            color: Colors.black.withValues(alpha: robotAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(robotCenter.dx - tp.width / 2,
            robotCenter.dy - cellSize * 0.6 - tp.height),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TttAiPainter old) => old.t != t;
}

// ── Step 3: Winning line draws across top row, star burst ──────────────────

class _TttWinPainter extends CustomPainter {
  final double t;
  const _TttWinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kBg);

    final cellSize = size.width * 0.26;
    final gridW = cellSize * 3;
    final origin = Offset((size.width - gridW) / 2, (size.height - gridW) / 2);

    _drawGrid(canvas, size, cellSize, origin);

    // Board state: X wins top row; O has (1,1) and (0,2)
    _drawX(canvas, _cellCenter(0, 0, cellSize, origin), cellSize, 1.0);
    _drawX(canvas, _cellCenter(1, 0, cellSize, origin), cellSize, 1.0);
    _drawX(canvas, _cellCenter(2, 0, cellSize, origin), cellSize, 1.0);
    _drawO(canvas, _cellCenter(1, 1, cellSize, origin), cellSize, 1.0);
    _drawO(canvas, _cellCenter(0, 2, cellSize, origin), cellSize, 1.0);

    // Win line draws across top row (0→0.5s of cycle)
    final lineProgress = (t / 0.55).clamp(0.0, 1.0);
    if (lineProgress > 0) {
      final startX = origin.dx + cellSize * 0.15;
      final endX = origin.dx + gridW - cellSize * 0.15;
      final lineY = origin.dy + cellSize / 2;
      final currentEndX = startX + (endX - startX) * lineProgress;

      // Glow
      canvas.drawLine(
        Offset(startX, lineY),
        Offset(currentEndX, lineY),
        Paint()
          ..color = _kXColor.withValues(alpha: 0.30)
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // Line
      canvas.drawLine(
        Offset(startX, lineY),
        Offset(currentEndX, lineY),
        Paint()
          ..color = _kXColor.withValues(alpha: 0.85)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Star burst in corner when line complete
    if (t > 0.55) {
      final burstT = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
      final burstAlpha = burstT < 0.4 ? burstT / 0.4 : 1.0 - (burstT - 0.4) / 0.6;
      final starCenter = Offset(size.width * 0.88, size.height * 0.14);
      final starR = 10 + burstT * 8;
      _drawStar(canvas, starCenter, starR, burstAlpha.clamp(0.0, 1.0));
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, double alpha) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    final path = Path();
    const spikes = 5;
    const outerR = 1.0;
    const innerR = 0.45;
    for (int i = 0; i < spikes * 2; i++) {
      final angle = (i * math.pi / spikes) - math.pi / 2;
      final rad = i.isEven ? r * outerR : r * innerR;
      final x = center.dx + rad * math.cos(angle);
      final y = center.dy + rad * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TttWinPainter old) => old.t != t;
}
