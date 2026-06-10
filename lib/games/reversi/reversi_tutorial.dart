import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> reversiSteps() => [
      GameHowToPlayStep(
        text: 'Place a disc next to your opponent\'s to sandwich them',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3600),
          painter: (t) => _PlacePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Sandwiched discs flip to your color!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _FlipPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'You can flip in multiple directions at once',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4200),
          painter: (t) => _MultiFlipPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Most discs when the board fills wins!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4400),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kBlack = Color(0xFF1A1A1A);
const _kWhite = Color(0xFFF5F5F5);
const _kBoard = Color(0xFF2E7D32);
const _kBg = Color(0xFFF0F8F0);
const _kAccent = Color(0xFF66BB6A);

(Offset, double) _boardMetrics(Size size, {int n = 4}) {
  const pad = 14.0;
  final s = math.min(size.width, size.height) - pad * 2;
  final cell = s / n;
  final ox = (size.width - s) / 2;
  final oy = (size.height - s) / 2;
  return (Offset(ox, oy), cell);
}

void _drawBoardBase(Canvas canvas, Size size, {int n = 4, double alpha = 1.0}) {
  canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBg);
  final (origin, cell) = _boardMetrics(size, n: n);
  final s = cell * n;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, s, s), const Radius.circular(6)),
    Paint()..color = _kBoard.withValues(alpha: alpha),
  );
  final gridPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.15 * alpha)
    ..strokeWidth = 0.8;
  for (int i = 1; i < n; i++) {
    canvas.drawLine(Offset(origin.dx + i * cell, origin.dy),
        Offset(origin.dx + i * cell, origin.dy + s), gridPaint);
    canvas.drawLine(Offset(origin.dx, origin.dy + i * cell),
        Offset(origin.dx + s, origin.dy + i * cell), gridPaint);
  }
}

void _drawDisc(Canvas canvas, double cx, double cy, double r, bool isBlack,
    {double alpha = 1.0, double scaleX = 1.0}) {
  final color = isBlack ? _kBlack : _kWhite;
  canvas.save();
  canvas.translate(cx, cy);
  canvas.scale(scaleX, 1.0);

  canvas.drawCircle(
    const Offset(0, 1.5),
    r,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.15 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  canvas.drawCircle(Offset.zero, r, Paint()..color = color.withValues(alpha: alpha));
  canvas.drawCircle(
    Offset(-r * 0.22, -r * 0.22),
    r * 0.18,
    Paint()..color = Colors.white.withValues(alpha: 0.22 * alpha),
  );
  canvas.restore();
}

void _drawValidHint(Canvas canvas, double cx, double cy, double r) {
  canvas.drawCircle(
    Offset(cx, cy),
    r * 0.35,
    Paint()..color = Colors.white.withValues(alpha: 0.25),
  );
}

class _PlacePainter extends CustomPainter {
  final double t;
  const _PlacePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBoardBase(canvas, size);
    final (origin, cell) = _boardMetrics(size);
    final r = cell * 0.34;

    _drawDisc(canvas, origin.dx + 1 * cell + cell / 2,
        origin.dy + 1 * cell + cell / 2, r, false);
    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2,
        origin.dy + 2 * cell + cell / 2, r, false);
    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2,
        origin.dy + 1 * cell + cell / 2, r, true);
    _drawDisc(canvas, origin.dx + 1 * cell + cell / 2,
        origin.dy + 2 * cell + cell / 2, r, true);

    final targetCx = origin.dx + 0 * cell + cell / 2;
    final targetCy = origin.dy + 1 * cell + cell / 2;

    if (t < 0.30) {
      final pulseT = (t / 0.30);
      final pulseAlpha = (0.15 + 0.15 * math.sin(pulseT * math.pi * 3)).clamp(0.0, 1.0);
      _drawValidHint(canvas, targetCx, targetCy, r);

      _drawValidHint(canvas, origin.dx + 1 * cell + cell / 2,
          origin.dy + 0 * cell + cell / 2, r);
      _drawValidHint(canvas, origin.dx + 0 * cell + cell / 2,
          origin.dy + 2 * cell + cell / 2, r);
      _drawValidHint(canvas, origin.dx + 2 * cell + cell / 2,
          origin.dy + 0 * cell + cell / 2, r);

      canvas.drawCircle(
        Offset(targetCx, targetCy),
        r * 0.55,
        Paint()
          ..color = _kAccent.withValues(alpha: pulseAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    if (t >= 0.15 && t < 0.30) {
      final fingerAlpha = ((0.30 - t) / 0.15).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '👆',
          style: TextStyle(
            fontSize: cell * 0.55,
            color: Colors.black.withValues(alpha: fingerAlpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(targetCx - tp.width / 2, targetCy - cell * 0.8));
    }

    if (t >= 0.25 && t < 0.35) {
      final ripT = ((t - 0.25) / 0.10).clamp(0.0, 1.0);
      final ripR = r * 0.3 + ripT * r * 1.2;
      final ripAlpha = (1 - ripT) * 0.4;
      canvas.drawCircle(
        Offset(targetCx, targetCy),
        ripR,
        Paint()
          ..color = _kBlack.withValues(alpha: ripAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    if (t >= 0.28) {
      final popT = ((t - 0.28) / 0.12).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(popT).clamp(0.0, 1.2);
      _drawDisc(canvas, targetCx, targetCy, r * scale.clamp(0.0, 1.0), true);
    }

    if (t >= 0.40 && t < 0.60) {
      final arrowT = ((t - 0.40) / 0.20).clamp(0.0, 1.0);
      final arrowAlpha = arrowT < 0.3
          ? arrowT / 0.3
          : arrowT > 0.7
              ? (1 - (arrowT - 0.7) / 0.3).clamp(0.0, 1.0)
              : 1.0;
      final startX = origin.dx + 0 * cell + cell / 2;
      final endX = origin.dx + 2 * cell + cell / 2;
      final y = origin.dy + 1 * cell + cell / 2;
      final paint = Paint()
        ..color = _kAccent.withValues(alpha: 0.6 * arrowAlpha)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final curEnd = startX + (endX - startX) * Curves.easeOut.transform(arrowT.clamp(0.0, 1.0));
      canvas.drawLine(Offset(startX + r, y), Offset(curEnd, y), paint);

      canvas.drawLine(Offset(curEnd - 5, y - 4), Offset(curEnd, y), paint);
      canvas.drawLine(Offset(curEnd - 5, y + 4), Offset(curEnd, y), paint);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: 'SANDWICH TO CAPTURE',
        style: TextStyle(
          color: _kBoard.withValues(alpha: 0.6),
          fontSize: 7,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - 11));
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

    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2,
        origin.dy + 2 * cell + cell / 2, r, false);
    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2,
        origin.dy + 1 * cell + cell / 2, r, true);
    _drawDisc(canvas, origin.dx + 1 * cell + cell / 2,
        origin.dy + 2 * cell + cell / 2, r, true);

    final flipCx = origin.dx + 1 * cell + cell / 2;
    final flipCy = origin.dy + 1 * cell + cell / 2;
    final placeCx = origin.dx + 0 * cell + cell / 2;
    final placeCy = origin.dy + 1 * cell + cell / 2;

    if (t < 0.20) {
      _drawDisc(canvas, flipCx, flipCy, r, false);
    }

    if (t >= 0.10 && t < 0.25) {
      final popT = ((t - 0.10) / 0.15).clamp(0.0, 1.0);
      final scale = Curves.easeOutBack.transform(popT);
      _drawDisc(canvas, placeCx, placeCy, r * scale.clamp(0.0, 1.0), true);
    }
    if (t >= 0.25) {
      _drawDisc(canvas, placeCx, placeCy, r, true);
    }

    if (t >= 0.30 && t < 0.65) {
      final flipProgress = ((t - 0.30) / 0.35).clamp(0.0, 1.0);

      if (flipProgress < 0.5) {
        final scaleX = 1.0 - flipProgress * 2;
        _drawDisc(canvas, flipCx, flipCy, r, false, scaleX: scaleX);
      } else {
        final scaleX = (flipProgress - 0.5) * 2;
        _drawDisc(canvas, flipCx, flipCy, r, true, scaleX: scaleX);
      }

      if (flipProgress > 0.3 && flipProgress < 0.7) {
        final sparkT = (flipProgress - 0.3) / 0.4;
        final sparkAlpha = (1 - sparkT) * 0.5;
        for (int i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + sparkT * math.pi;
          final dist = sparkT * r * 1.5;
          canvas.drawCircle(
            Offset(flipCx + math.cos(angle) * dist,
                flipCy + math.sin(angle) * dist),
            2.5 * (1 - sparkT),
            Paint()..color = _kAccent.withValues(alpha: sparkAlpha),
          );
        }
      }
    }

    if (t >= 0.65) {
      _drawDisc(canvas, flipCx, flipCy, r, true);

      if (t < 0.78) {
        final glowT = (t - 0.65) / 0.13;
        final glowAlpha = math.sin(glowT * math.pi) * 0.25;
        canvas.drawCircle(
          Offset(flipCx, flipCy),
          r * 1.3,
          Paint()
            ..color = _kAccent.withValues(alpha: glowAlpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }

    if (t >= 0.70 && t < 0.90) {
      final countT = ((t - 0.70) / 0.20).clamp(0.0, 1.0);
      final countAlpha = countT < 0.2
          ? countT / 0.2
          : countT > 0.8
              ? (1 - (countT - 0.8) / 0.2).clamp(0.0, 1.0)
              : 1.0;
      final tp = TextPainter(
        text: TextSpan(
          text: '+1 FLIPPED!',
          style: TextStyle(
            color: _kAccent.withValues(alpha: countAlpha),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, size.height - tp.height - 4));
    }
  }

  @override
  bool shouldRepaint(_FlipPainter old) => old.t != t;
}

class _MultiFlipPainter extends CustomPainter {
  final double t;
  const _MultiFlipPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBoardBase(canvas, size, n: 5);
    final (origin, cell) = _boardMetrics(size, n: 5);
    final r = cell * 0.34;

    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2,
        origin.dy + 0 * cell + cell / 2, r, true);
    _drawDisc(canvas, origin.dx + 2 * cell + cell / 2,
        origin.dy + 4 * cell + cell / 2, r, true);
    _drawDisc(canvas, origin.dx + 0 * cell + cell / 2,
        origin.dy + 2 * cell + cell / 2, r, true);
    _drawDisc(canvas, origin.dx + 4 * cell + cell / 2,
        origin.dy + 2 * cell + cell / 2, r, true);

    final toFlip = [
      [2, 1],
      [2, 3],
      [1, 2],
      [3, 2],
    ];
    final placeCx = origin.dx + 2 * cell + cell / 2;
    final placeCy = origin.dy + 2 * cell + cell / 2;

    if (t < 0.20) {
      for (final pos in toFlip) {
        _drawDisc(canvas, origin.dx + pos[0] * cell + cell / 2,
            origin.dy + pos[1] * cell + cell / 2, r, false);
      }
      final pulseT = t / 0.20;
      final pulseAlpha = 0.15 + 0.12 * math.sin(pulseT * math.pi * 2);
      _drawValidHint(canvas, placeCx, placeCy, r);
      canvas.drawCircle(
        Offset(placeCx, placeCy),
        r * 0.5,
        Paint()
          ..color = _kAccent.withValues(alpha: pulseAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (t >= 0.15 && t < 0.25) {
      final popT = ((t - 0.15) / 0.10).clamp(0.0, 1.0);
      final scale = Curves.easeOutBack.transform(popT);
      _drawDisc(canvas, placeCx, placeCy, r * scale.clamp(0.0, 1.0), true);
    }
    if (t >= 0.25) {
      _drawDisc(canvas, placeCx, placeCy, r, true);
    }

    if (t >= 0.28) {
      for (int i = 0; i < toFlip.length; i++) {
        final delay = i * 0.06;
        final flipStart = 0.28 + delay;
        final flipEnd = flipStart + 0.22;
        final pos = toFlip[i];
        final cx = origin.dx + pos[0] * cell + cell / 2;
        final cy = origin.dy + pos[1] * cell + cell / 2;

        if (t < flipStart) {
          _drawDisc(canvas, cx, cy, r, false);
        } else if (t < flipEnd) {
          final flipProgress = ((t - flipStart) / (flipEnd - flipStart)).clamp(0.0, 1.0);
          if (flipProgress < 0.5) {
            _drawDisc(canvas, cx, cy, r, false, scaleX: 1.0 - flipProgress * 2);
          } else {
            _drawDisc(canvas, cx, cy, r, true, scaleX: (flipProgress - 0.5) * 2);
          }
        } else {
          _drawDisc(canvas, cx, cy, r, true);

          final glowEnd = flipEnd + 0.10;
          if (t < glowEnd) {
            final glowT = (t - flipEnd) / 0.10;
            canvas.drawCircle(
              Offset(cx, cy),
              r * 1.2,
              Paint()
                ..color = _kAccent.withValues(alpha: math.sin(glowT * math.pi) * 0.2)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
            );
          }
        }
      }
    } else {
      for (final pos in toFlip) {
        _drawDisc(canvas, origin.dx + pos[0] * cell + cell / 2,
            origin.dy + pos[1] * cell + cell / 2, r, false);
      }
    }

    if (t >= 0.25 && t < 0.50) {
      final lineAlpha = t < 0.35
          ? ((t - 0.25) / 0.10).clamp(0.0, 1.0) * 0.4
          : ((0.50 - t) / 0.15).clamp(0.0, 1.0) * 0.4;
      final linePaint = Paint()
        ..color = _kAccent.withValues(alpha: lineAlpha)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(placeCx, placeCy - r),
          Offset(placeCx, origin.dy + 0 * cell + cell / 2 + r), linePaint);
      canvas.drawLine(Offset(placeCx, placeCy + r),
          Offset(placeCx, origin.dy + 4 * cell + cell / 2 - r), linePaint);
      canvas.drawLine(Offset(placeCx - r, placeCy),
          Offset(origin.dx + 0 * cell + cell / 2 + r, placeCy), linePaint);
      canvas.drawLine(Offset(placeCx + r, placeCy),
          Offset(origin.dx + 4 * cell + cell / 2 - r, placeCy), linePaint);
    }

    if (t >= 0.65 && t < 0.85) {
      final countT = ((t - 0.65) / 0.20).clamp(0.0, 1.0);
      final countAlpha = countT < 0.2
          ? countT / 0.2
          : countT > 0.8
              ? (1 - (countT - 0.8) / 0.2).clamp(0.0, 1.0)
              : 1.0;
      final tp = TextPainter(
        text: TextSpan(
          text: '+4 FLIPPED!',
          style: TextStyle(
            color: _kAccent.withValues(alpha: countAlpha),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, size.height - tp.height - 4));
    }
  }

  @override
  bool shouldRepaint(_MultiFlipPainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final globalAlpha = t > 0.88 ? (1 - (t - 0.88) / 0.12).clamp(0.0, 1.0) : 1.0;

    final scaleIn = t < 0.08 ? Curves.easeOutBack.transform(t / 0.08) : 1.0;
    canvas.save();
    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.scale(scaleIn);
    canvas.translate(-center.dx, -center.dy);

    _drawBoardBase(canvas, size, alpha: globalAlpha);
    final (origin, cell) = _boardMetrics(size);
    final r = cell * 0.34;
    const n = 4;

    final grid = [
      [1, 1, 2, 1],
      [1, 1, 1, 2],
      [2, 1, 1, 1],
      [1, 2, 1, 1],
    ];

    final fillOrder = <List<int>>[];
    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n; col++) {
        fillOrder.add([row, col, grid[row][col]]);
      }
    }

    final fillProgress = ((t - 0.05) / 0.50).clamp(0.0, 1.0);
    final visibleCount = (fillProgress * fillOrder.length).floor();

    for (int i = 0; i < visibleCount && i < fillOrder.length; i++) {
      final item = fillOrder[i];
      final isBlack = item[2] == 1;
      final cx = origin.dx + item[1] * cell + cell / 2;
      final cy = origin.dy + item[0] * cell + cell / 2;

      if (i == visibleCount - 1 && fillProgress < 1.0) {
        final itemT = (fillProgress * fillOrder.length - i).clamp(0.0, 1.0);
        final popScale = Curves.easeOutBack.transform(itemT);
        _drawDisc(canvas, cx, cy, r * popScale.clamp(0.0, 1.0), isBlack,
            alpha: globalAlpha);
      } else {
        _drawDisc(canvas, cx, cy, r, isBlack, alpha: globalAlpha);
      }
    }

    canvas.restore();

    if (t > 0.55 && t < 0.90) {
      int blackCount = 0;
      int whiteCount = 0;
      for (final item in fillOrder) {
        if (item[2] == 1) {
          blackCount++;
        } else {
          whiteCount++;
        }
      }

      final scoreT = ((t - 0.55) / 0.15).clamp(0.0, 1.0);
      final scoreAlpha = scoreT < 0.3
          ? scoreT / 0.3
          : t > 0.85
              ? (1 - (t - 0.85) / 0.05).clamp(0.0, 1.0)
              : 1.0;

      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '⚫ $blackCount',
              style: TextStyle(
                color: _kBlack.withValues(alpha: scoreAlpha),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: '  vs  ',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: scoreAlpha * 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: '$whiteCount ⚪',
              style: TextStyle(
                color: Colors.grey.shade600.withValues(alpha: scoreAlpha),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, size.height - tp.height - 4));

      if (t > 0.68 && t < 0.88) {
        final celebT = (t - 0.68) / 0.20;
        final celebAlpha = celebT < 0.3
            ? celebT / 0.3
            : celebT > 0.7
                ? (1 - (celebT - 0.7) / 0.3).clamp(0.0, 1.0)
                : 1.0;

        for (int i = 0; i < 10; i++) {
          final angle = i * math.pi / 5 + celebT * math.pi * 0.5;
          final dist = celebT * 28;
          canvas.drawCircle(
            Offset(center.dx + math.cos(angle) * dist,
                center.dy - size.height * 0.15 + math.sin(angle) * dist),
            3.0 * (1 - celebT * 0.5),
            Paint()
              ..color = (i.isEven ? _kAccent : const Color(0xFFFFD700))
                  .withValues(alpha: celebAlpha * (1 - celebT * 0.3)),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}
