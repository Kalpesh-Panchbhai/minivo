import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> goSteps() => [
      GameHowToPlayStep(
        text: 'Place stones on intersections. Black goes first, then alternate turns.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _PlacePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Surround opponent stones to capture them. Captured stones are removed.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _CapturePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Pass when you have no good moves. Two passes end the game.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _PassPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'The player with the most territory + captures wins!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _ScorePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kBoard = Color(0xFFD4A76A);
const _kLine = Color(0xFF5D4037);

void _drawGrid(Canvas canvas, double left, double top, double cellSize, int lines) {
  final paint = Paint()
    ..color = _kLine.withValues(alpha: 0.4)
    ..strokeWidth = 1.0;
  for (int i = 0; i < lines; i++) {
    final offset = i * cellSize;
    canvas.drawLine(Offset(left, top + offset), Offset(left + (lines - 1) * cellSize, top + offset), paint);
    canvas.drawLine(Offset(left + offset, top), Offset(left + offset, top + (lines - 1) * cellSize), paint);
  }
}

void _drawStone(Canvas canvas, double cx, double cy, double r, bool isBlack, {double alpha = 1.0}) {
  final color = isBlack ? Colors.black.withValues(alpha: alpha) : Colors.white.withValues(alpha: alpha);
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _kLine.withValues(alpha: 0.3 * alpha)..style = PaintingStyle.stroke..strokeWidth = 1.0);
}

class _PlacePainter extends CustomPainter {
  final double t;
  const _PlacePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoard);
    const lines = 5;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);

    final phase = (t * 2).clamp(0.0, 1.0);
    final r = cellSize * 0.35;

    _drawStone(canvas, left + 1 * cellSize, top + 1 * cellSize, r, true);
    if (phase > 0.3) {
      _drawStone(canvas, left + 2 * cellSize, top + 2 * cellSize, r, false);
    }
    if (phase > 0.6) {
      final scale = Curves.elasticOut.transform(((phase - 0.6) / 0.4).clamp(0.0, 1.0));
      _drawStone(canvas, left + 3 * cellSize, top + 1 * cellSize, r * scale, true);
    }
  }

  @override
  bool shouldRepaint(_PlacePainter old) => old.t != t;
}

class _CapturePainter extends CustomPainter {
  final double t;
  const _CapturePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoard);
    const lines = 5;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);
    final r = cellSize * 0.35;

    _drawStone(canvas, left + 1 * cellSize, top + 2 * cellSize, r, true);
    _drawStone(canvas, left + 3 * cellSize, top + 2 * cellSize, r, true);
    _drawStone(canvas, left + 2 * cellSize, top + 1 * cellSize, r, true);

    final captureT = (t * 2).clamp(0.0, 1.0);
    final capturedAlpha = captureT > 0.7 ? 1.0 - ((captureT - 0.7) / 0.3).clamp(0.0, 1.0) : 1.0;
    _drawStone(canvas, left + 2 * cellSize, top + 2 * cellSize, r, false, alpha: capturedAlpha);

    if (captureT > 0.4) {
      final eased = Curves.easeInOut.transform(((captureT - 0.4) / 0.3).clamp(0.0, 1.0));
      _drawStone(canvas, left + 2 * cellSize, top + 3 * cellSize, r * eased, true);
    }
  }

  @override
  bool shouldRepaint(_CapturePainter old) => old.t != t;
}

class _PassPainter extends CustomPainter {
  final double t;
  const _PassPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoard);
    final phase = (t * 2).clamp(0.0, 1.0);
    final label = phase < 0.5 ? 'PASS' : 'PASS ×2';
    final alpha = math.sin(phase * math.pi);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFF5D4037).withValues(alpha: 0.5 + alpha * 0.5),
          fontWeight: FontWeight.w900,
          fontSize: 28,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_PassPainter old) => old.t != t;
}

class _ScorePainter extends CustomPainter {
  final double t;
  const _ScorePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoard);
    const lines = 5;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);
    final r = cellSize * 0.35;

    _drawStone(canvas, left + 0, top + 0, r, true);
    _drawStone(canvas, left + cellSize, top + 0, r, true);
    _drawStone(canvas, left + 0, top + cellSize, r, true);

    _drawStone(canvas, left + 3 * cellSize, top + 3 * cellSize, r, false);
    _drawStone(canvas, left + 4 * cellSize, top + 3 * cellSize, r, false);

    if (t > 0.5) {
      final celebT = ((t - 0.5) * 2).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'Black: 15  White: 12',
          style: TextStyle(
            color: const Color(0xFF5D4037).withValues(alpha: celebT),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - tp.height - 6));
    }
  }

  @override
  bool shouldRepaint(_ScorePainter old) => old.t != t;
}
