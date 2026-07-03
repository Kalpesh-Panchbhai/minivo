import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> arrowPuzzleSteps() => [
  GameHowToPlayStep(
    text: 'Arrows are tangled on the board. Tap an arrow to try to free it.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _TapArrowPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'An arrow can only be freed if nothing blocks its exit path ahead.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _BlockedPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'Free all arrows to complete the level! Fewer taps = better score.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _AllFreePainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
];

void _drawGrid(Canvas canvas, Size size) {
  final gridPaint = Paint()
    ..color = Colors.grey.withValues(alpha: 0.15)
    ..strokeWidth = 0.5;
  final gridStep = size.width / 5;
  for (int i = 0; i <= 5; i++) {
    canvas.drawLine(Offset(i * gridStep, 0), Offset(i * gridStep, size.height), gridPaint);
    canvas.drawLine(Offset(0, i * gridStep), Offset(size.width, i * gridStep), gridPaint);
  }
}

const _kDark = Color(0xFF1E293B);
const _kBlue = Color(0xFF3B82F6);
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);

void _drawArrowShape(Canvas canvas, Offset from, Offset to, Offset headDir, Color color, double strokeW, {double opacity = 1.0, Offset offset = Offset.zero}) {
  final paint = Paint()
    ..color = color.withValues(alpha: opacity)
    ..strokeWidth = strokeW
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  final f = from + offset;
  final t2 = to + offset;
  canvas.drawLine(f, t2, paint);

  canvas.drawCircle(f, strokeW * 0.7, Paint()..color = color.withValues(alpha: opacity));

  final headLen = 8.0;
  final headW = 5.0;
  final perpX = -headDir.dy;
  final perpY = headDir.dx;
  final tipX = t2.dx + headDir.dx * 6;
  final tipY = t2.dy + headDir.dy * 6;
  final arrowHead = ui.Path()
    ..moveTo(tipX, tipY)
    ..lineTo(tipX - headDir.dx * headLen + perpX * headW, tipY - headDir.dy * headLen + perpY * headW)
    ..lineTo(tipX - headDir.dx * headLen - perpX * headW, tipY - headDir.dy * headLen - perpY * headW)
    ..close();
  canvas.drawPath(arrowHead, Paint()..color = color.withValues(alpha: opacity));
}

class _TapArrowPainter extends CustomPainter {
  final double t;
  _TapArrowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    final cx = size.width / 2;
    final cy = size.height / 2;

    _drawArrowShape(canvas, Offset(cx - 60, cy - 20), Offset(cx + 20, cy - 20), const Offset(1, 0), _kDark, 3);
    _drawArrowShape(canvas, Offset(cx - 30, cy + 30), Offset(cx - 30, cy - 10), const Offset(0, -1), _kDark, 3);

    final flyT = (t < 0.4) ? 0.0 : ((t - 0.4) / 0.5).clamp(0.0, 1.0);
    final flyOffset = Offset(flyT * 80, 0);
    final opacity = (1 - flyT).clamp(0.0, 1.0);
    _drawArrowShape(canvas, Offset(cx - 40, cy + 10), Offset(cx + 40, cy + 10), const Offset(1, 0), _kBlue, 3, opacity: opacity, offset: flyOffset);

    if (t < 0.4) {
      final tapPulse = math.sin(t / 0.4 * math.pi);
      canvas.drawCircle(
        Offset(cx, cy + 10),
        12 * (1 + tapPulse * 0.3),
        Paint()..color = _kBlue.withValues(alpha: 0.15 * (1 - t / 0.4)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TapArrowPainter old) => t != old.t;
}

class _BlockedPainter extends CustomPainter {
  final double t;
  _BlockedPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    final cx = size.width / 2;
    final cy = size.height / 2;

    _drawArrowShape(canvas, Offset(cx + 10, cy - 30), Offset(cx + 10, cy + 30), const Offset(0, 1), _kDark, 3);

    final shake = math.sin(t * math.pi * 6) * 3 * (1 - t).clamp(0.0, 1.0);
    if (t > 0.3 && t < 0.7) {
      _drawArrowShape(canvas, Offset(cx - 50 + shake, cy), Offset(cx + 30 + shake, cy), const Offset(1, 0), _kRed, 3);
    } else {
      _drawArrowShape(canvas, Offset(cx - 50, cy), Offset(cx + 30, cy), const Offset(1, 0), _kRed, 3);
    }

    final xPaint = Paint()
      ..color = _kRed.withValues(alpha: t > 0.5 ? 0.6 : 0.0)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    if (t > 0.5) {
      canvas.drawLine(Offset(cx + 30, cy - 10), Offset(cx + 46, cy + 6), xPaint);
      canvas.drawLine(Offset(cx + 46, cy - 10), Offset(cx + 30, cy + 6), xPaint);
    }

    final labelPainter = TextPainter(
      text: TextSpan(
        text: 'BLOCKED',
        style: TextStyle(
          color: _kRed.withValues(alpha: 0.70),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(canvas, Offset(cx - labelPainter.width / 2, cy + 40));
  }

  @override
  bool shouldRepaint(covariant _BlockedPainter old) => t != old.t;
}

class _AllFreePainter extends CustomPainter {
  final double t;
  _AllFreePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    final cx = size.width / 2;
    final cy = size.height / 2;

    final step = (t * 3).floor().clamp(0, 2);
    final froms = [Offset(cx - 60, cy - 20), Offset(cx - 30, cy + 10), Offset(cx + 10, cy + 20)];
    final tos = [Offset(cx + 10, cy - 20), Offset(cx - 30, cy - 30), Offset(cx + 60, cy + 20)];
    final dirs = [const Offset(1, 0), const Offset(0, -1), const Offset(1, 0)];

    for (int i = 0; i < 3; i++) {
      if (i < step) continue;
      final isFreeing = i == step;
      final frac = (t * 3 - step).clamp(0.0, 1.0);
      if (isFreeing) {
        final flyOff = dirs[i] * (frac * 60);
        final op = (1 - frac).clamp(0.0, 1.0);
        _drawArrowShape(canvas, froms[i], tos[i], dirs[i], _kBlue, 3, opacity: op, offset: flyOff);
      } else {
        _drawArrowShape(canvas, froms[i], tos[i], dirs[i], _kDark, 3);
      }
    }

    if (step >= 2 && (t * 3 - 2) > 0.8) {
      final checkPaint = Paint()
        ..color = _kGreen
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = ui.Path()
        ..moveTo(cx - 10, cy)
        ..lineTo(cx - 2, cy + 8)
        ..lineTo(cx + 12, cy - 6);
      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AllFreePainter old) => t != old.t;
}
