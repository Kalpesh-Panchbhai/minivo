import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> chessSteps() => [
      GameHowToPlayStep(
        text: 'Tap a piece to select it. Green dots show where it can move.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _SelectPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Each piece moves differently. The Knight jumps in an L-shape!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _KnightPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Put the King in check — the opponent must escape or it\'s checkmate!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _CheckPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Checkmate the King to win the game!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _CheckmatePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kLight = Color(0xFFF0D9B5);
const _kDark = Color(0xFFB58863);
const _kWhite = Colors.white;
const _kBlack = Color(0xFF1A1A2E);

void _drawBoard(Canvas canvas, double left, double top, double cellSize, int gridSize) {
  for (int r = 0; r < gridSize; r++) {
    for (int c = 0; c < gridSize; c++) {
      final isDark = (r + c) % 2 == 1;
      final rect = Rect.fromLTWH(left + c * cellSize, top + r * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, Paint()..color = isDark ? _kDark : _kLight);
    }
  }
}

void _drawPiece(Canvas canvas, double cx, double cy, double r, Color fill, String ch) {
  canvas.drawCircle(Offset(cx, cy + 1.5), r, Paint()..color = Colors.black.withValues(alpha: 0.20));
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = fill);
  final tp = TextPainter(
    text: TextSpan(
      text: ch,
      style: TextStyle(
        fontSize: r * 1.2,
        color: fill == _kWhite ? _kBlack : _kWhite,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
}

class _SelectPainter extends CustomPainter {
  final double t;
  const _SelectPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 4;
    final cellSize = size.width / grid;
    final left = 0.0;
    final top = (size.height - cellSize * grid) / 2;
    _drawBoard(canvas, left, top, cellSize, grid);

    final selectT = (t * 2).clamp(0.0, 1.0);
    if (selectT > 0.3) {
      final alpha = ((selectT - 0.3) / 0.3).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(left + 2 * cellSize, top + 3 * cellSize, cellSize, cellSize),
        Paint()..color = Colors.amber.withValues(alpha: 0.35 * alpha),
      );
      for (final pos in [(2, 1), (2, 3), (1, 0)]) {
        final cx = left + (pos.$2 + 0.5) * cellSize;
        final cy = top + (pos.$1 + 0.5) * cellSize;
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.14, Paint()..color = Colors.green.withValues(alpha: 0.55 * alpha));
      }
    }
    _drawPiece(canvas, left + 2.5 * cellSize, top + 3.5 * cellSize, cellSize * 0.34, _kWhite, '♗');
    _drawPiece(canvas, left + 0.5 * cellSize, top + 0.5 * cellSize, cellSize * 0.34, _kBlack, '♚');
  }

  @override
  bool shouldRepaint(_SelectPainter old) => old.t != t;
}

class _KnightPainter extends CustomPainter {
  final double t;
  const _KnightPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 4;
    final cellSize = size.width / grid;
    final left = 0.0;
    final top = (size.height - cellSize * grid) / 2;
    _drawBoard(canvas, left, top, cellSize, grid);

    final moveT = (t * 2).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(moveT);
    final startR = 3.0, startC = 1.0;
    final endR = 1.0, endC = 2.0;
    final curR = startR + (endR - startR) * eased;
    final curC = startC + (endC - startC) * eased;
    final bounceY = -math.sin(eased * math.pi) * cellSize * 0.4;
    final cx = left + (curC + 0.5) * cellSize;
    final cy = top + (curR + 0.5) * cellSize + bounceY;
    _drawPiece(canvas, cx, cy, cellSize * 0.34, _kWhite, '♘');

    _drawPiece(canvas, left + 3.5 * cellSize, top + 0.5 * cellSize, cellSize * 0.34, _kBlack, '♜');
  }

  @override
  bool shouldRepaint(_KnightPainter old) => old.t != t;
}

class _CheckPainter extends CustomPainter {
  final double t;
  const _CheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 4;
    final cellSize = size.width / grid;
    final left = 0.0;
    final top = (size.height - cellSize * grid) / 2;
    _drawBoard(canvas, left, top, cellSize, grid);

    final checkT = (t * 2).clamp(0.0, 1.0);
    if (checkT > 0.5) {
      final alpha = ((checkT - 0.5) * 2).clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(left + 2 * cellSize, top + 0 * cellSize, cellSize, cellSize),
        Paint()..color = Colors.red.withValues(alpha: 0.35 * alpha),
      );
    }

    final moveT = (t * 2).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(moveT);
    final startR = 2.0;
    final endR = 2.0;
    final startC = 0.0;
    final endC = 2.0;
    final cx = left + (startC + (endC - startC) * eased + 0.5) * cellSize;
    final cy = top + (startR + (endR - startR) * eased + 0.5) * cellSize;
    _drawPiece(canvas, cx, cy, cellSize * 0.34, _kWhite, '♖');

    _drawPiece(canvas, left + 2.5 * cellSize, top + 0.5 * cellSize, cellSize * 0.34, _kBlack, '♚');
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

class _CheckmatePainter extends CustomPainter {
  final double t;
  const _CheckmatePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = 4;
    final cellSize = size.width / grid;
    final left = 0.0;
    final top = (size.height - cellSize * grid) / 2;
    _drawBoard(canvas, left, top, cellSize, grid);

    canvas.drawRect(
      Rect.fromLTWH(left + 3 * cellSize, top + 0 * cellSize, cellSize, cellSize),
      Paint()..color = Colors.red.withValues(alpha: 0.35),
    );

    _drawPiece(canvas, left + 3.5 * cellSize, top + 0.5 * cellSize, cellSize * 0.34, _kBlack, '♚');
    _drawPiece(canvas, left + 3.5 * cellSize, top + 2.5 * cellSize, cellSize * 0.34, _kWhite, '♖');
    _drawPiece(canvas, left + 1.5 * cellSize, top + 1.5 * cellSize, cellSize * 0.34, _kWhite, '♕');

    if (t > 0.5) {
      final celebT = ((t - 0.5) * 2).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'CHECKMATE!',
          style: TextStyle(
            color: Colors.amber.withValues(alpha: celebT),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.06));
    }
  }

  @override
  bool shouldRepaint(_CheckmatePainter old) => old.t != t;
}
