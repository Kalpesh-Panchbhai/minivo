import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> checkersSteps() => [
      GameHowToPlayStep(
        text: 'Move your pieces diagonally forward on dark squares.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _MovePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Jump over an opponent\'s piece to capture it!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _CapturePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Reach the far side to crown your piece into a King. Kings move diagonally in any direction!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _KingPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Capture all opponent pieces or block them completely to win!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kRed = Color(0xFFE53935);
const _kBlack = Color(0xFF212121);
const _kBoard = Color(0xFF5D4037);
const _kLight = Color(0xFFF5DEB3);

void _drawBoard(Canvas canvas, double left, double top, double cellSize, int gridSize) {
  for (int r = 0; r < gridSize; r++) {
    for (int c = 0; c < gridSize; c++) {
      final isDark = (r + c) % 2 == 1;
      final rect = Rect.fromLTWH(left + c * cellSize, top + r * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, Paint()..color = isDark ? _kBoard : _kLight);
    }
  }
}

void _drawPiece(Canvas canvas, double cx, double cy, double r, Color color, {bool isKing = false}) {
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color);
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  if (isKing) {
    final crown = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - r * 0.4, cy + r * 0.1), Offset(cx - r * 0.2, cy - r * 0.3), crown);
    canvas.drawLine(Offset(cx - r * 0.2, cy - r * 0.3), Offset(cx, cy + r * 0.1), crown);
    canvas.drawLine(Offset(cx, cy + r * 0.1), Offset(cx + r * 0.2, cy - r * 0.3), crown);
    canvas.drawLine(Offset(cx + r * 0.2, cy - r * 0.3), Offset(cx + r * 0.4, cy + r * 0.1), crown);
  }
}

class _MovePainter extends CustomPainter {
  final double t;
  const _MovePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 4;
    final cellSize = size.width / grid;
    final left = 0.0;
    final top = (size.height - cellSize * grid) / 2;
    _drawBoard(canvas, left, top, cellSize, grid);

    final moveT = (t * 2).clamp(0.0, 1.0);
    final startR = 2, startC = 1;
    final endR = 1, endC = 2;
    final curR = startR + (endR - startR) * Curves.easeInOut.transform(moveT);
    final curC = startC + (endC - startC) * Curves.easeInOut.transform(moveT);
    final cx = left + (curC + 0.5) * cellSize;
    final cy = top + (curR + 0.5) * cellSize;
    _drawPiece(canvas, cx, cy, cellSize * 0.34, _kRed);

    _drawPiece(canvas, left + 3.5 * cellSize, top + 0.5 * cellSize, cellSize * 0.34, _kBlack);
  }

  @override
  bool shouldRepaint(_MovePainter old) => old.t != t;
}

class _CapturePainter extends CustomPainter {
  final double t;
  const _CapturePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 4;
    final cellSize = size.width / grid;
    final left = 0.0;
    final top = (size.height - cellSize * grid) / 2;
    _drawBoard(canvas, left, top, cellSize, grid);

    final jumpT = (t * 2).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(jumpT);

    final capturedAlpha = jumpT > 0.5 ? 1.0 - ((jumpT - 0.5) * 2).clamp(0.0, 1.0) : 1.0;
    _drawPiece(
      canvas,
      left + 2.5 * cellSize,
      top + 1.5 * cellSize,
      cellSize * 0.34,
      _kBlack.withValues(alpha: capturedAlpha),
    );

    final startR = 2.0, startC = 1.0;
    final endR = 0.0, endC = 3.0;
    final curR = startR + (endR - startR) * eased;
    final curC = startC + (endC - startC) * eased;
    final bounceY = -math.sin(eased * math.pi) * cellSize * 0.3;
    final cx = left + (curC + 0.5) * cellSize;
    final cy = top + (curR + 0.5) * cellSize + bounceY;
    _drawPiece(canvas, cx, cy, cellSize * 0.34, _kRed);
  }

  @override
  bool shouldRepaint(_CapturePainter old) => old.t != t;
}

class _KingPainter extends CustomPainter {
  final double t;
  const _KingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 4;
    final cellSize = size.width / grid;
    final left = 0.0;
    final top = (size.height - cellSize * grid) / 2;
    _drawBoard(canvas, left, top, cellSize, grid);

    final moveT = (t * 2).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(moveT);
    final isKing = moveT > 0.95;

    final startR = 1.0, startC = 2.0;
    final endR = 0.0, endC = 3.0;
    final curR = startR + (endR - startR) * eased;
    final curC = startC + (endC - startC) * eased;
    final cx = left + (curC + 0.5) * cellSize;
    final cy = top + (curR + 0.5) * cellSize;

    if (isKing) {
      final glow = Paint()
        ..color = Colors.amber.withValues(alpha: 0.3 + (t - 0.5).abs() * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.44, glow);
    }
    _drawPiece(canvas, cx, cy, cellSize * 0.34, _kRed, isKing: isKing);
  }

  @override
  bool shouldRepaint(_KingPainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 4;
    final cellSize = size.width / grid;
    final left = 0.0;
    final top = (size.height - cellSize * grid) / 2;
    _drawBoard(canvas, left, top, cellSize, grid);

    _drawPiece(canvas, left + 0.5 * cellSize, top + 0.5 * cellSize, cellSize * 0.34, _kRed, isKing: true);
    _drawPiece(canvas, left + 2.5 * cellSize, top + 1.5 * cellSize, cellSize * 0.34, _kRed);
    _drawPiece(canvas, left + 1.5 * cellSize, top + 2.5 * cellSize, cellSize * 0.34, _kRed);

    if (t > 0.5) {
      final celebT = ((t - 0.5) * 2).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'YOU WIN!',
          style: TextStyle(
            color: Colors.amber.withValues(alpha: celebT),
            fontWeight: FontWeight.w900,
            fontSize: 18,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.08));
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}
