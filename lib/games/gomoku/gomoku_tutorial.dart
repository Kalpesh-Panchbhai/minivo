import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> gomokuSteps() => [
      GameHowToPlayStep(
        text: 'Take turns placing stones on a grid. Black goes first.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _PlacePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Connect 5 stones in a row — horizontally, vertically, or diagonally — to win!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Block your opponent while building your own lines!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _BlockPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Win horizontally, vertically, or diagonally — any direction counts!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _DiagonalWinPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kLine = Color(0xFF4A90D9);

void _drawGrid(Canvas canvas, double left, double top, double cellSize, int lines) {
  final paint = Paint()..color = _kLine.withValues(alpha: 0.25)..strokeWidth = 1.0;
  for (int i = 0; i < lines; i++) {
    final o = i * cellSize;
    canvas.drawLine(Offset(left, top + o), Offset(left + (lines - 1) * cellSize, top + o), paint);
    canvas.drawLine(Offset(left + o, top), Offset(left + o, top + (lines - 1) * cellSize), paint);
  }
}

void _drawStone(Canvas canvas, double cx, double cy, double r, bool isBlack, {double alpha = 1.0}) {
  final color = isBlack ? Colors.black.withValues(alpha: alpha) : Colors.white.withValues(alpha: alpha);
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
  canvas.drawCircle(Offset(cx, cy), r, Paint()
    ..color = (isBlack ? Colors.white : Colors.grey).withValues(alpha: 0.3 * alpha)
    ..style = PaintingStyle.stroke..strokeWidth = 1.0);
}

class _PlacePainter extends CustomPainter {
  final double t;
  const _PlacePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFDCEAF8));
    const lines = 7;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);
    final r = cellSize * 0.38;

    final phase = (t * 3).clamp(0.0, 1.0);
    _drawStone(canvas, left + 3 * cellSize, top + 3 * cellSize, r, true);
    if (phase > 0.3) {
      _drawStone(canvas, left + 4 * cellSize, top + 3 * cellSize, r, false);
    }
    if (phase > 0.6) {
      final scale = Curves.elasticOut.transform(((phase - 0.6) / 0.4).clamp(0.0, 1.0));
      _drawStone(canvas, left + 2 * cellSize, top + 4 * cellSize, r * scale, true);
    }
  }

  @override
  bool shouldRepaint(_PlacePainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFDCEAF8));
    const lines = 7;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);
    final r = cellSize * 0.38;

    final stoneCount = ((t * 2).clamp(0.0, 1.0) * 5).floor().clamp(0, 5);
    for (int i = 0; i < stoneCount; i++) {
      _drawStone(canvas, left + (1 + i) * cellSize, top + 3 * cellSize, r, true);
    }

    if (stoneCount >= 5 && t > 0.6) {
      final start = Offset(left + 1 * cellSize, top + 3 * cellSize);
      final end = Offset(left + 5 * cellSize, top + 3 * cellSize);
      final lineT = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
      final current = Offset.lerp(start, end, lineT)!;
      canvas.drawLine(start, current, Paint()
        ..color = Colors.amber.withValues(alpha: 0.6)
        ..strokeWidth = cellSize * 0.12
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}

class _BlockPainter extends CustomPainter {
  final double t;
  const _BlockPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFDCEAF8));
    const lines = 7;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);
    final r = cellSize * 0.38;

    _drawStone(canvas, left + 2 * cellSize, top + 3 * cellSize, r, false);
    _drawStone(canvas, left + 3 * cellSize, top + 3 * cellSize, r, false);
    _drawStone(canvas, left + 4 * cellSize, top + 3 * cellSize, r, false);

    final phase = (t * 2).clamp(0.0, 1.0);
    if (phase > 0.5) {
      final scale = Curves.elasticOut.transform(((phase - 0.5) / 0.5).clamp(0.0, 1.0));
      _drawStone(canvas, left + 5 * cellSize, top + 3 * cellSize, r * scale, true);
      final blockPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.5 * scale)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(left + 5 * cellSize, top + 3 * cellSize), r + 3, blockPaint);
    }
  }

  @override
  bool shouldRepaint(_BlockPainter old) => old.t != t;
}

class _DiagonalWinPainter extends CustomPainter {
  final double t;
  const _DiagonalWinPainter(this.t);

  static const _stones = [[1, 1], [2, 2], [3, 3], [4, 4], [5, 5]];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFFDCEAF8));
    const lines = 7;
    final cellSize = size.width / (lines + 1);
    final left = cellSize;
    final top = (size.height - (lines - 1) * cellSize) / 2;
    _drawGrid(canvas, left, top, cellSize, lines);
    final r = cellSize * 0.38;

    final stonePhase = (t * 2.0).clamp(0.0, 1.0);
    final stoneCount = (stonePhase * 5).floor().clamp(0, 5);
    final currentFrac = (stonePhase * 5 - stoneCount).clamp(0.0, 1.0);

    for (int i = 0; i < stoneCount; i++) {
      _drawStone(canvas, left + _stones[i][0] * cellSize, top + _stones[i][1] * cellSize, r, true);
    }
    if (stoneCount < 5) {
      final scale = Curves.elasticOut.transform(currentFrac);
      _drawStone(canvas, left + _stones[stoneCount][0] * cellSize, top + _stones[stoneCount][1] * cellSize, r * scale, true);
    }

    if (stoneCount >= 5 && t > 0.6) {
      final start = Offset(left + _stones[0][0] * cellSize, top + _stones[0][1] * cellSize);
      final end = Offset(left + _stones[4][0] * cellSize, top + _stones[4][1] * cellSize);
      final lineT = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
      final current = Offset.lerp(start, end, lineT)!;
      canvas.drawLine(start, current, Paint()
        ..color = Colors.amber.withValues(alpha: 0.6)
        ..strokeWidth = cellSize * 0.12
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_DiagonalWinPainter old) => old.t != t;
}
