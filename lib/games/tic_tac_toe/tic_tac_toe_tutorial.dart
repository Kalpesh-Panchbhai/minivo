import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

// ── Public API ──────────────────────────────────────────────────────────────

List<GameHowToPlayStep> ticTacToeSteps() => [
      GameHowToPlayStep(
        text: 'Tap any empty cell to place your X',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2600),
          painter: (t) => _TttPlacePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'The AI thinks, then plays O',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _TttAiPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Get 3 in a row to win!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3000),
          painter: (t) => _TttWinPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

// ── Shared drawing helpers ──────────────────────────────────────────────────

const _kXColor = Color(0xFF7C4DFF);   // purple — matches game accent
const _kOColor = Color(0xFFFF6B6B);   // coral red
const _kGridColor = Color(0xFF7C4DFF);
const _kBg = Color(0xFFF8F4FF);       // faint purple tint

// Draws the 3×3 grid and returns (origin, cellSize).
(Offset, double) _drawGrid(Canvas canvas, Size size) {
  const padding = 14.0;
  final gridSize = math.min(size.width, size.height) - padding * 2;
  final cellSize = gridSize / 3;
  final ox = (size.width - gridSize) / 2;
  final oy = (size.height - gridSize) / 2;
  final origin = Offset(ox, oy);

  final paint = Paint()
    ..color = _kGridColor.withValues(alpha: 0.30)
    ..strokeWidth = 2.8
    ..strokeCap = StrokeCap.round;

  for (int i = 1; i < 3; i++) {
    // Vertical
    canvas.drawLine(
      Offset(ox + i * cellSize, oy + cellSize * 0.08),
      Offset(ox + i * cellSize, oy + gridSize - cellSize * 0.08),
      paint,
    );
    // Horizontal
    canvas.drawLine(
      Offset(ox + cellSize * 0.08, oy + i * cellSize),
      Offset(ox + gridSize - cellSize * 0.08, oy + i * cellSize),
      paint,
    );
  }
  return (origin, cellSize);
}

Offset _cellCenter(int col, int row, Offset origin, double cellSize) =>
    Offset(origin.dx + col * cellSize + cellSize / 2,
           origin.dy + row * cellSize + cellSize / 2);

/// Draws an X with a stroke-by-stroke animation (progress 0→1).
void _drawX(Canvas canvas, Offset center, double cellSize, double progress,
    {double alpha = 1.0}) {
  final half = cellSize * 0.28;
  final paint = Paint()
    ..color = _kXColor.withValues(alpha: alpha)
    ..strokeWidth = 4.0
    ..strokeCap = StrokeCap.round;

  // First diagonal (top-left → bottom-right)
  final p1 = (progress * 2).clamp(0.0, 1.0);
  if (p1 > 0) {
    canvas.drawLine(
      Offset(center.dx - half, center.dy - half),
      Offset(center.dx - half + half * 2 * p1, center.dy - half + half * 2 * p1),
      paint,
    );
  }
  // Second diagonal (top-right → bottom-left)
  final p2 = ((progress * 2) - 1.0).clamp(0.0, 1.0);
  if (p2 > 0) {
    canvas.drawLine(
      Offset(center.dx + half, center.dy - half),
      Offset(center.dx + half - half * 2 * p2, center.dy - half + half * 2 * p2),
      paint,
    );
  }
}

/// Draws an O as a sweeping arc (progress 0→1 = 0°→360°).
void _drawO(Canvas canvas, Offset center, double cellSize, double progress,
    {double alpha = 1.0}) {
  final r = cellSize * 0.28;
  canvas.drawArc(
    Rect.fromCenter(center: center, width: r * 2, height: r * 2),
    -math.pi / 2,
    progress * 2 * math.pi,
    false,
    Paint()
      ..color = _kOColor.withValues(alpha: alpha)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke,
  );
}

// ── Step 1: Tap cells → marks accumulate on board ───────────────────────────
//
// Sequence (marks stay visible once placed):
//   0.00–0.33  Tap ripple + X draws at (0,0). X stays.
//   0.33–0.66  Tap ripple + X draws at (2,2). Both X's visible.
//   0.66–1.00  Tap ripple + X draws at (0,2). All 3 X's visible.

class _TttPlacePainter extends CustomPainter {
  final double t;
  const _TttPlacePainter(this.t);

  static const _cells = [[0, 0], [2, 2], [0, 2]];
  static const _stepDur = 1.0 / 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kBg);
    final (origin, cellSize) = _drawGrid(canvas, size);

    for (int i = 0; i < _cells.length; i++) {
      final stepStart = i * _stepDur;
      if (t < stepStart) continue;

      final cell = _cells[i];
      final center = _cellCenter(cell[0], cell[1], origin, cellSize);
      final local = ((t - stepStart) / _stepDur).clamp(0.0, 1.0);

      if (local < 0.25) {
        final ripT = local / 0.25;
        final ripR = cellSize * 0.18 + ripT * cellSize * 0.40;
        final ripAlpha = (1 - ripT) * 0.65;
        canvas.drawCircle(center, ripR,
            Paint()
              ..color = _kXColor.withValues(alpha: ripAlpha)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
        final fingerAlpha = (1 - ripT * 1.4).clamp(0.0, 1.0);
        if (fingerAlpha > 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: '👆',
              style: TextStyle(fontSize: cellSize * 0.48, color: Colors.black.withValues(alpha: fingerAlpha)),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - cellSize * 0.1 - tp.height));
        }
      }

      final xProgress = ((local - 0.20) / 0.40).clamp(0.0, 1.0);
      if (xProgress > 0) {
        _drawX(canvas, center, cellSize, xProgress);

        if (local > 0.65 && local < 0.90) {
          final glowAlpha = math.sin((local - 0.65) / 0.25 * math.pi) * 0.30;
          canvas.drawCircle(center, cellSize * 0.32,
              Paint()
                ..color = _kXColor.withValues(alpha: glowAlpha)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TttPlacePainter old) => old.t != t;
}

// ── Step 2: X placed, AI "thinks", O draws in ──────────────────────────────
//
// Sequence:
//   0.00–0.10  X already at (0,0), grid shown
//   0.10–0.45  "..." thinking dots pulse above the O cell (1,1)
//   0.45–0.80  O arc sweeps into (1,1)
//   0.80–1.00  hold + fade

class _TttAiPainter extends CustomPainter {
  final double t;
  const _TttAiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kBg);
    final (origin, cellSize) = _drawGrid(canvas, size);

    // X always present at (0,0)
    _drawX(canvas, _cellCenter(0, 0, origin, cellSize), cellSize, 1.0);

    final alpha = t > 0.82
        ? (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0)
        : 1.0;

    final oCenter = _cellCenter(1, 1, origin, cellSize);

    // Thinking dots (0.10 → 0.45)
    if (t >= 0.10 && t < 0.47) {
      final thinkT = (t - 0.10) / 0.37;
      for (int d = 0; d < 3; d++) {
        final dotPhase = (thinkT * 2 + d * 0.22) % 1.0;
        final dotScale = 0.6 + math.sin(dotPhase * math.pi) * 0.5;
        final dotAlpha = (0.4 + math.sin(dotPhase * math.pi) * 0.5).clamp(0.0, 1.0) * alpha;
        canvas.drawCircle(
          Offset(oCenter.dx - 8 + d * 8, oCenter.dy - cellSize * 0.55),
          3.5 * dotScale,
          Paint()..color = _kOColor.withValues(alpha: dotAlpha),
        );
      }
    }

    // O draws in (0.45 → 0.80)
    if (t >= 0.43) {
      final oProgress = ((t - 0.43) / 0.37).clamp(0.0, 1.0);
      _drawO(canvas, oCenter, cellSize, oProgress, alpha: alpha);

      // Flash glow when O completes
      if (t > 0.80 && t < 0.92) {
        final glowAlpha = math.sin((t - 0.80) / 0.12 * math.pi) * 0.30;
        canvas.drawCircle(oCenter, cellSize * 0.32,
            Paint()
              ..color = _kOColor.withValues(alpha: glowAlpha)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TttAiPainter old) => old.t != t;
}

// ── Step 3: Full board, X wins top row — line draws + celebration ───────────
//
// Board: X at (0,0),(1,0),(2,0) wins; O at (1,1),(0,2)
// Sequence:
//   0.00–0.10  board appears (scale-in)
//   0.10–0.55  win-line draws from left to right across row 0
//   0.55–0.75  star burst + "YOU WIN!" label
//   0.75–1.00  hold + fade

class _TttWinPainter extends CustomPainter {
  final double t;
  const _TttWinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _kBg);
    final (origin, cellSize) = _drawGrid(canvas, size);

    final globalAlpha = t > 0.80
        ? (1 - (t - 0.80) / 0.20).clamp(0.0, 1.0)
        : 1.0;

    // Scale-in entrance
    final scaleIn = t < 0.12 ? Curves.easeOutBack.transform(t / 0.12) : 1.0;
    canvas.save();
    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.scale(scaleIn);
    canvas.translate(-center.dx, -center.dy);

    // All marks at full progress
    _drawX(canvas, _cellCenter(0, 0, origin, cellSize), cellSize, 1.0, alpha: globalAlpha);
    _drawX(canvas, _cellCenter(1, 0, origin, cellSize), cellSize, 1.0, alpha: globalAlpha);
    _drawX(canvas, _cellCenter(2, 0, origin, cellSize), cellSize, 1.0, alpha: globalAlpha);
    _drawO(canvas, _cellCenter(1, 1, origin, cellSize), cellSize, 1.0, alpha: globalAlpha * 0.6);
    _drawO(canvas, _cellCenter(0, 2, origin, cellSize), cellSize, 1.0, alpha: globalAlpha * 0.6);

    // Win line sweeps across row 0 (t 0.10 → 0.55)
    final lineProg = t < 0.10 ? 0.0 : ((t - 0.10) / 0.45).clamp(0.0, 1.0);
    if (lineProg > 0) {
      final row0Y = _cellCenter(0, 0, origin, cellSize).dy;
      final startX = origin.dx + cellSize * 0.12;
      final endX = origin.dx + cellSize * 3 - cellSize * 0.12;
      final curEndX = startX + (endX - startX) * Curves.easeOut.transform(lineProg);

      // Glow layer
      canvas.drawLine(
        Offset(startX, row0Y),
        Offset(curEndX, row0Y),
        Paint()
          ..color = _kXColor.withValues(alpha: 0.25 * globalAlpha)
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      // Main line
      canvas.drawLine(
        Offset(startX, row0Y),
        Offset(curEndX, row0Y),
        Paint()
          ..color = _kXColor.withValues(alpha: 0.90 * globalAlpha)
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();

    // Celebration burst + label (t 0.55 → 0.80)
    if (t > 0.55 && t < 0.82) {
      final celebT = (t - 0.55) / 0.27;
      final celebAlpha = celebT < 0.30
          ? celebT / 0.30
          : celebT > 0.75
              ? (1 - (celebT - 0.75) / 0.25).clamp(0.0, 1.0)
              : 1.0;

      // Stars burst from win-line midpoint
      final burstCenter = Offset(size.width / 2, origin.dy + cellSize / 2);
      for (int i = 0; i < 10; i++) {
        final angle = i * math.pi / 5;
        final dist = celebT * 36;
        canvas.drawCircle(
          Offset(burstCenter.dx + math.cos(angle) * dist,
                 burstCenter.dy + math.sin(angle) * dist),
          4.5 * (1 - celebT * 0.7),
          Paint()..color = const Color(0xFFFFD700).withValues(alpha: celebAlpha * (1 - celebT * 0.5)),
        );
      }

      // "YOU WIN!" label
      final tp = TextPainter(
        text: TextSpan(
          text: '🏆 YOU WIN!',
          style: TextStyle(
            color: _kXColor.withValues(alpha: celebAlpha),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height - tp.height - 6));
    }
  }

  @override
  bool shouldRepaint(covariant _TttWinPainter old) => old.t != t;
}
