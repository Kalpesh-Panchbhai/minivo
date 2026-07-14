import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_living.dart';
import 'frame_rush_objects.dart';

const _kNeon = Color(0xFF39FF6A);

/// Living home-tile logo: a car slides in and snaps into a glowing green frame.
Widget buildFrameRushLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Frame Rush',
      bg: const [Color(0xFF123A2A), Color(0xFF0A1F17)],
      accent: _kNeon,
      period: const Duration(milliseconds: 2600),
      artBuilder: (t) => _FrameRushArtPainter(t),
    );

class _FrameRushArtPainter extends CustomPainter {
  final double t;
  const _FrameRushArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final zone = Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.40), width: w * 0.58, height: w * 0.58);
    final r = zone.width * 0.32;
    final target = zone.center;

    // The green target frame (a car silhouette outline).
    canvas.save();
    canvas.translate(target.dx, target.dy);
    paintFrameRushObject(canvas, FrObject.car, r,
        outlineOnly: true, outlineColor: _kNeon);
    canvas.restore();

    final captured = t >= 0.7;
    final approach = Curves.easeInOutCubic.transform((t / 0.7).clamp(0.0, 1.0));
    final startX = zone.left - r * 0.5;
    final cx = startX + (target.dx - startX) * approach;
    final bob = captured ? 0.0 : math.sin(t * 7) * r * 0.05;

    // Capture burst rings.
    if (captured) {
      final p = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
      canvas.drawCircle(
        target,
        r * (1.0 + p * 1.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1 * (1 - p)
          ..color = _kNeon.withValues(alpha: 0.7 * (1 - p)),
      );
    }

    // The moving car.
    canvas.save();
    canvas.translate(captured ? target.dx : cx, target.dy + bob);
    final flash = captured ? ((t - 0.7) / 0.3).clamp(0.0, 1.0) : 0.0;
    paintFrameRushObject(canvas, FrObject.car, r,
        outlineOnly: false, captured: captured, captureFlash: flash * 0.7);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FrameRushArtPainter old) => old.t != t;
}
