import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import 'frame_rush_objects.dart';

const _kNeon = Color(0xFF39FF6A);
const _kCanvas = Size(200, 150);

List<GameHowToPlayStep> frameRushSteps() => [
      GameHowToPlayStep(
        text: 'An object loops around the track — smooth and non-stop.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _FrPainter(t, phase: 0),
          canvasSize: _kCanvas,
        ),
      ),
      GameHowToPlayStep(
        text: 'Tap anywhere to freeze it right inside the green frame.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3200),
          painter: (t) => _FrPainter(t, phase: 1),
          canvasSize: _kCanvas,
        ),
      ),
      GameHowToPlayStep(
        text: 'Line it up perfectly to win — in as few taps as you can!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3200),
          painter: (t) => _FrPainter(t, phase: 2),
          canvasSize: _kCanvas,
        ),
      ),
    ];

class _FrPainter extends CustomPainter {
  final double t;
  final int phase;
  const _FrPainter(this.t, {required this.phase});

  // Ellipse geometry in canvas space.
  static const _a = 62.0;
  static const _b = 40.0;
  Offset _pos(Offset c, double s) =>
      Offset(c.dx + _a * math.cos(2 * math.pi * s), c.dy + _b * math.sin(2 * math.pi * s));
  double _angle(Offset c, double s) {
    final p0 = _pos(c, (s - 0.004) % 1.0);
    final p1 = _pos(c, (s + 0.004) % 1.0);
    return math.atan2(p1.dy - p0.dy, p1.dx - p0.dx);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const r = 22.0;
    const frameS = 0.0; // target at rightmost point

    // Track.
    final track = Path();
    for (int i = 0; i <= 64; i++) {
      final p = _pos(c, i / 64);
      i == 0 ? track.moveTo(p.dx, p.dy) : track.lineTo(p.dx, p.dy);
    }
    track.close();
    canvas.drawPath(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    // Target frame (phases 1 & 2).
    if (phase >= 1) {
      final fp = _pos(c, frameS);
      canvas.save();
      canvas.translate(fp.dx, fp.dy);
      frameRushApplyOrientation(canvas, FrObject.car, _angle(c, frameS));
      paintFrameRushObject(canvas, FrObject.car, r, outlineOnly: true, outlineColor: _kNeon);
      canvas.restore();
    }

    // Object motion + capture.
    double s;
    bool captured = false;
    double flash = 0;
    if (phase == 0) {
      s = t;
    } else {
      // Ease the object toward the frame, snap at t≈0.7, hold captured.
      if (t < 0.7) {
        s = (0.62 + Curves.easeInOut.transform(t / 0.7) * 0.38) % 1.0;
      } else {
        s = frameS;
        captured = true;
        flash = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
      }
    }

    // Tap ripple just before the snap (phase 1 & 2).
    if (phase >= 1 && t > 0.5 && t < 0.72) {
      final rp = ((t - 0.5) / 0.22).clamp(0.0, 1.0);
      final fp = _pos(c, frameS);
      canvas.drawCircle(
        fp,
        10 + rp * 26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - rp)
          ..color = Colors.white.withValues(alpha: 0.7 * (1 - rp)),
      );
    }

    // Capture burst.
    if (captured) {
      final fp = _pos(c, frameS);
      canvas.drawCircle(
        fp,
        r * (1 + flash * 1.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12 * (1 - flash)
          ..color = _kNeon.withValues(alpha: 0.7 * (1 - flash)),
      );
    }

    final op = _pos(c, s);
    canvas.save();
    canvas.translate(op.dx, op.dy);
    frameRushApplyOrientation(canvas, FrObject.car, _angle(c, s));
    paintFrameRushObject(canvas, FrObject.car, r,
        outlineOnly: false, captured: captured, captureFlash: flash * 0.6);
    canvas.restore();

    // Win check badge (phase 2).
    if (phase == 2 && captured && flash > 0.2) {
      final bc = Offset(c.dx + _a * 0.5, c.dy - _b - 12);
      canvas.drawCircle(bc, 11, Paint()..color = _kNeon);
      final check = Path()
        ..moveTo(bc.dx - 4.5, bc.dy)
        ..lineTo(bc.dx - 1, bc.dy + 4)
        ..lineTo(bc.dx + 5, bc.dy - 4);
      canvas.drawPath(
        check,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF0A1F17)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_FrPainter old) => old.t != t || old.phase != phase;
}
