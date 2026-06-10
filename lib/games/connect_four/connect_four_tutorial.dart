import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> connectFourSteps() => [
      GameHowToPlayStep(
        text: 'Tap a column to drop your disc — it falls to the lowest open row',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3200),
          painter: (t) => _DropPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Players take turns — red vs yellow. Plan your moves!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _TurnsPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Connect 4 of your discs in a row to win!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4200),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Win horizontally, vertically, or diagonally',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4800),
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
  final ox = (size.width - bw) / 2;
  final oy = (size.height - cell * rows) / 2;
  return (Offset(ox, oy), cell, bw);
}

void _drawBoard(Canvas canvas, Size size, List<List<int>> grid,
    {double globalAlpha = 1.0}) {
  final (origin, cell, bw) = _boardMetrics(size);
  const rows = 6;
  const cols = 7;

  canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBg);

  final boardRect = Rect.fromLTWH(origin.dx, origin.dy, bw, cell * rows);
  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect, const Radius.circular(6)),
    Paint()..color = _kBoard.withValues(alpha: globalAlpha),
  );

  final holePaint = Paint()..color = _kBg;

  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      final cx = origin.dx + c * cell + cell / 2;
      final cy = origin.dy + r * cell + cell / 2;
      final radius = cell * 0.36;
      if (grid[r][c] == 0) {
        canvas.drawCircle(Offset(cx, cy), radius, holePaint);
      } else {
        final color = grid[r][c] == 1 ? _kRed : _kYellow;
        canvas.drawCircle(
            Offset(cx, cy), radius, Paint()..color = color.withValues(alpha: globalAlpha));
      }
    }
  }
}

void _drawDiscShadowed(Canvas canvas, double cx, double cy, double r,
    Color color, {double alpha = 1.0}) {
  canvas.drawCircle(
    Offset(cx, cy + 1.5),
    r,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.18 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: alpha));
  canvas.drawCircle(
    Offset(cx - r * 0.25, cy - r * 0.25),
    r * 0.22,
    Paint()..color = Colors.white.withValues(alpha: 0.28 * alpha),
  );
}

List<List<int>> _emptyGrid() => List.generate(6, (_) => List.filled(7, 0));

class _DropPainter extends CustomPainter {
  final double t;
  const _DropPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _emptyGrid();
    if (t > 0.42) grid[5][3] = 1;
    _drawBoard(canvas, size, grid);

    final (origin, cell, _) = _boardMetrics(size);
    final r = cell * 0.36;
    final cx = origin.dx + 3 * cell + cell / 2;

    if (t < 0.12) {
      final ripT = t / 0.12;
      final ripR = cell * 0.3 + ripT * cell * 0.6;
      final ripAlpha = (1 - ripT) * 0.5;
      canvas.drawCircle(
        Offset(cx, origin.dy - cell * 0.3),
        ripR,
        Paint()
          ..color = _kRed.withValues(alpha: ripAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '👆',
          style: TextStyle(
            fontSize: cell * 0.7,
            color: Colors.black.withValues(alpha: (1 - ripT * 1.5).clamp(0.0, 1.0)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, origin.dy - cell * 1.3));
    }

    if (t >= 0.10 && t < 0.42) {
      final dropT = ((t - 0.10) / 0.32).clamp(0.0, 1.0);
      final startY = origin.dy - cell * 0.5;
      final endY = origin.dy + 5 * cell + cell / 2;
      final cy = startY + (endY - startY) * Curves.bounceOut.transform(dropT);
      _drawDiscShadowed(canvas, cx, cy, r, _kRed);
    }

    if (t > 0.42 && t < 0.55) {
      final impactT = ((t - 0.42) / 0.13).clamp(0.0, 1.0);
      final impactR = cell * 0.4 + impactT * cell * 0.5;
      final impactAlpha = (1 - impactT) * 0.3;
      canvas.drawCircle(
        Offset(cx, origin.dy + 5 * cell + cell / 2),
        impactR,
        Paint()
          ..color = _kRed.withValues(alpha: impactAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    final tp = TextPainter(
      text: TextSpan(
        text: 'TAP A COLUMN',
        style: TextStyle(
          color: _kBoard.withValues(alpha: 0.6),
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 12));
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.t != t;
}

class _TurnsPainter extends CustomPainter {
  final double t;
  const _TurnsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _emptyGrid();

    if (t > 0.18) grid[5][3] = 1;
    if (t > 0.42) grid[5][4] = 2;
    if (t > 0.62) grid[4][3] = 1;
    if (t > 0.82) grid[5][2] = 2;

    _drawBoard(canvas, size, grid);

    final (origin, cell, _) = _boardMetrics(size);
    final r = cell * 0.36;

    if (t >= 0.05 && t < 0.18) {
      final dropT = ((t - 0.05) / 0.13).clamp(0.0, 1.0);
      final cx = origin.dx + 3 * cell + cell / 2;
      final startY = origin.dy - cell * 0.5;
      final endY = origin.dy + 5 * cell + cell / 2;
      final cy = startY + (endY - startY) * Curves.bounceOut.transform(dropT);
      _drawDiscShadowed(canvas, cx, cy, r, _kRed);
    }

    if (t >= 0.22 && t < 0.42) {
      final thinkEnd = 0.32;
      if (t < thinkEnd) {
        final thinkT = (t - 0.22) / (thinkEnd - 0.22);
        final cx = origin.dx + 4 * cell + cell / 2;
        for (int d = 0; d < 3; d++) {
          final dotPhase = (thinkT * 3 + d * 0.25) % 1.0;
          final dotScale = 0.5 + math.sin(dotPhase * math.pi) * 0.6;
          final dotAlpha = (0.3 + math.sin(dotPhase * math.pi) * 0.6).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(cx - 7 + d * 7, origin.dy - cell * 0.3),
            3.0 * dotScale,
            Paint()..color = _kYellow.withValues(alpha: dotAlpha),
          );
        }
      }

      if (t >= thinkEnd) {
        final dropT = ((t - thinkEnd) / (0.42 - thinkEnd)).clamp(0.0, 1.0);
        final cx = origin.dx + 4 * cell + cell / 2;
        final startY = origin.dy - cell * 0.5;
        final endY = origin.dy + 5 * cell + cell / 2;
        final cy = startY + (endY - startY) * Curves.bounceOut.transform(dropT);
        _drawDiscShadowed(canvas, cx, cy, r, _kYellow);
      }
    }

    if (t >= 0.48 && t < 0.62) {
      final dropT = ((t - 0.48) / 0.14).clamp(0.0, 1.0);
      final cx = origin.dx + 3 * cell + cell / 2;
      final startY = origin.dy - cell * 0.5;
      final endY = origin.dy + 4 * cell + cell / 2;
      final cy = startY + (endY - startY) * Curves.bounceOut.transform(dropT);
      _drawDiscShadowed(canvas, cx, cy, r, _kRed);
    }

    if (t >= 0.68 && t < 0.82) {
      final dropT = ((t - 0.68) / 0.14).clamp(0.0, 1.0);
      final cx = origin.dx + 2 * cell + cell / 2;
      final startY = origin.dy - cell * 0.5;
      final endY = origin.dy + 5 * cell + cell / 2;
      final cy = startY + (endY - startY) * Curves.bounceOut.transform(dropT);
      _drawDiscShadowed(canvas, cx, cy, r, _kYellow);
    }

    final indicatorT = t < 0.18
        ? 1
        : t < 0.42
            ? 2
            : t < 0.62
                ? 1
                : 2;
    final color = indicatorT == 1 ? _kRed : _kYellow;
    final label = indicatorT == 1 ? 'RED' : 'YELLOW';
    final barY = size.height - 11.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, barY), width: 52, height: 13),
        const Radius.circular(6),
      ),
      Paint()..color = color.withValues(alpha: 0.2),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '$label\'s turn',
        style: TextStyle(
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, barY - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TurnsPainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _emptyGrid();
    grid[5][1] = 1; grid[5][2] = 1; grid[5][3] = 1;
    grid[4][2] = 2; grid[4][3] = 2; grid[5][5] = 2;
    grid[4][1] = 2;

    if (t > 0.25) grid[5][4] = 1;

    final globalAlpha = t > 0.85 ? (1 - (t - 0.85) / 0.15).clamp(0.0, 1.0) : 1.0;

    final scaleIn = t < 0.08 ? Curves.easeOutBack.transform(t / 0.08) : 1.0;
    canvas.save();
    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.scale(scaleIn);
    canvas.translate(-center.dx, -center.dy);

    _drawBoard(canvas, size, grid, globalAlpha: globalAlpha);

    final (origin, cell, _) = _boardMetrics(size);
    final r = cell * 0.36;

    if (t >= 0.10 && t < 0.25) {
      final dropT = ((t - 0.10) / 0.15).clamp(0.0, 1.0);
      final cx = origin.dx + 4 * cell + cell / 2;
      final startY = origin.dy - cell * 0.5;
      final endY = origin.dy + 5 * cell + cell / 2;
      final cy = startY + (endY - startY) * Curves.bounceOut.transform(dropT);
      _drawDiscShadowed(canvas, cx, cy, r, _kRed, alpha: globalAlpha);
    }

    if (t > 0.30) {
      final lineT = ((t - 0.30) / 0.25).clamp(0.0, 1.0);
      final y = origin.dy + 5 * cell + cell / 2;
      final startX = origin.dx + 1 * cell + cell / 2;
      final endX = origin.dx + 4 * cell + cell / 2;
      final curX = startX + (endX - startX) * Curves.easeOut.transform(lineT);

      canvas.drawLine(
        Offset(startX, y),
        Offset(curX, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25 * globalAlpha)
          ..strokeWidth = cell * 0.7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawLine(
        Offset(startX, y),
        Offset(curX, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9 * globalAlpha)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();

    if (t > 0.58 && t < 0.85) {
      final celebT = (t - 0.58) / 0.27;
      final celebAlpha = celebT < 0.3
          ? celebT / 0.3
          : celebT > 0.75
              ? (1 - (celebT - 0.75) / 0.25).clamp(0.0, 1.0)
              : 1.0;

      final burstCenter = Offset(size.width / 2, size.height * 0.4);
      for (int i = 0; i < 12; i++) {
        final angle = i * math.pi / 6;
        final dist = celebT * 32;
        canvas.drawCircle(
          Offset(burstCenter.dx + math.cos(angle) * dist,
              burstCenter.dy + math.sin(angle) * dist),
          3.5 * (1 - celebT * 0.6),
          Paint()
            ..color = (i.isEven ? _kRed : const Color(0xFFFFD700))
                .withValues(alpha: celebAlpha * (1 - celebT * 0.4)),
        );
      }

      final tp = TextPainter(
        text: TextSpan(
          text: '🏆 4 IN A ROW!',
          style: TextStyle(
            color: _kRed.withValues(alpha: celebAlpha),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height - tp.height - 4));
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
    final phase = (t * 3).floor() % 3;
    final phaseT = (t * 3) % 1.0;

    final grid = _emptyGrid();

    if (phase == 0) {
      grid[5][1] = 1; grid[5][2] = 1; grid[5][3] = 1; grid[5][4] = 1;
      grid[4][2] = 2; grid[4][3] = 2; grid[5][5] = 2;
    } else if (phase == 1) {
      grid[5][2] = 1; grid[4][2] = 1; grid[3][2] = 1; grid[2][2] = 1;
      grid[5][3] = 2; grid[5][4] = 2; grid[4][3] = 2;
    } else {
      grid[5][1] = 1; grid[4][2] = 1; grid[3][3] = 1; grid[2][4] = 1;
      grid[5][2] = 2; grid[5][3] = 2; grid[4][3] = 2;
    }

    final scaleIn = phaseT < 0.08 ? Curves.easeOut.transform(phaseT / 0.08) : 1.0;
    final fadeOut = phaseT > 0.88 ? (1 - (phaseT - 0.88) / 0.12).clamp(0.0, 1.0) : 1.0;
    final alpha = scaleIn * fadeOut;

    canvas.save();
    final c = Offset(size.width / 2, size.height / 2);
    canvas.translate(c.dx, c.dy);
    canvas.scale(0.92 + 0.08 * scaleIn);
    canvas.translate(-c.dx, -c.dy);

    _drawBoard(canvas, size, grid, globalAlpha: alpha);

    final (origin, cell, _) = _boardMetrics(size);

    final lineT = ((phaseT - 0.15) / 0.35).clamp(0.0, 1.0);
    if (lineT > 0) {
      late Offset start, end;
      if (phase == 0) {
        final y = origin.dy + 5 * cell + cell / 2;
        start = Offset(origin.dx + 1 * cell + cell / 2, y);
        end = Offset(origin.dx + 4 * cell + cell / 2, y);
      } else if (phase == 1) {
        final x = origin.dx + 2 * cell + cell / 2;
        start = Offset(x, origin.dy + 5 * cell + cell / 2);
        end = Offset(x, origin.dy + 2 * cell + cell / 2);
      } else {
        start = Offset(origin.dx + 1 * cell + cell / 2, origin.dy + 5 * cell + cell / 2);
        end = Offset(origin.dx + 4 * cell + cell / 2, origin.dy + 2 * cell + cell / 2);
      }
      final curEnd = Offset(
        start.dx + (end.dx - start.dx) * Curves.easeOut.transform(lineT),
        start.dy + (end.dy - start.dy) * Curves.easeOut.transform(lineT),
      );

      canvas.drawLine(
        start, curEnd,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25 * alpha)
          ..strokeWidth = cell * 0.65
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawLine(
        start, curEnd,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9 * alpha)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();

    final labels = ['HORIZONTAL', 'VERTICAL', 'DIAGONAL'];
    final tp = TextPainter(
      text: TextSpan(
        text: '→  ${labels[phase]}',
        style: TextStyle(
          color: _kBoard.withValues(alpha: 0.7 * alpha),
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 12));
  }

  @override
  bool shouldRepaint(_DirectionsPainter old) => old.t != t;
}
