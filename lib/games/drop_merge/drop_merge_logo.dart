import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/animated_background.dart';
import '../shared/game_logo_scaffold.dart';

Widget buildDropMergeLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Drop Merge',
      bg: const [Color(0xFF7C2D12), Color(0xFF2A0E04)],
      accent: const Color(0xFFFBBF24),
      art: _dropMergeArt,
    );

void _dropMergeArt(Canvas canvas, Rect zone) {
  // A vertical lane with stacked rounded number blocks at the bottom and one
  // block falling from above (with motion lines).
  final laneW = zone.width * 0.46;
  final laneRect = Rect.fromCenter(
    center: zone.center,
    width: laneW,
    height: zone.height,
  );
  final laneRRect =
      RRect.fromRectAndRadius(laneRect, Radius.circular(laneW * 0.16));

  // lane track
  canvas.drawRRect(
      laneRRect, Paint()..color = Colors.white.withValues(alpha: 0.06));
  canvas.drawRRect(
      laneRRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = laneW * 0.05);

  final block = laneW * 0.78;
  final blockGap = block * 0.12;
  final cx = zone.center.dx;

  void drawBlock(double centerY, String value, List<Color> grad) {
    final r = Rect.fromCenter(
        center: Offset(cx, centerY), width: block, height: block);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(block * 0.24));
    // contact shadow
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            r.translate(0, block * 0.05), Radius.circular(block * 0.24)),
        Paint()..color = Colors.black.withValues(alpha: 0.20));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: grad,
          ).createShader(r));
    // glossy top highlight
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.42),
            Radius.circular(block * 0.24)),
        Paint()..color = Colors.white.withValues(alpha: 0.18));

    final tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: block * 0.5,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, centerY - tp.height / 2));
  }

  // stacked blocks at the bottom
  final bottomY = laneRect.bottom - block * 0.5 - laneW * 0.06;
  drawBlock(bottomY, '8', const [Color(0xFFF59E0B), Color(0xFFB45309)]);
  drawBlock(bottomY - (block + blockGap), '4',
      const [Color(0xFFFBBF24), Color(0xFFD97706)]);
  drawBlock(bottomY - (block + blockGap) * 2, '2',
      const [Color(0xFFFDE68A), Color(0xFFF59E0B)]);

  // falling block near the top, with motion lines above it
  final fallY = laneRect.top + block * 0.62;
  final motionPaint = Paint()
    ..color = const Color(0xFFFDE68A).withValues(alpha: 0.55)
    ..strokeCap = StrokeCap.round
    ..strokeWidth = block * 0.06;
  for (final dx in [-block * 0.22, 0.0, block * 0.22]) {
    final len = dx == 0 ? block * 0.40 : block * 0.26;
    canvas.drawLine(
      Offset(cx + dx, fallY - block * 0.62),
      Offset(cx + dx, fallY - block * 0.62 - len),
      motionPaint,
    );
  }
  drawBlock(fallY, '2', const [Color(0xFFFDE68A), Color(0xFFF59E0B)]);
}

// ── Animated background painter ──────────────────────────────────────────────

class DropMergeBgPainter extends AnimatedBgPainter {
  const DropMergeBgPainter(super.t);

  static const _items = <(double, double, double, double, int)>[
    (0.08, 0.10, 30, 0.0, 2),
    (0.82, 0.06, 24, 0.8, 4),
    (0.15, 0.55, 20, 1.6, 8),
    (0.88, 0.42, 28, 2.4, 16),
    (0.05, 0.80, 22, 3.2, 4),
    (0.74, 0.88, 18, 4.0, 2),
    (0.50, 0.03, 16, 4.8, 8),
    (0.40, 0.94, 22, 5.6, 32),
    (0.92, 0.65, 14, 1.2, 2),
    (0.04, 0.44, 18, 3.7, 16),
  ];

  static const _tileColors = {
    2: Color(0xFFFFF3BF),
    4: Color(0xFFFFE066),
    8: Color(0xFFFFA94D),
    16: Color(0xFFFF6B6B),
    32: Color(0xFFE64980),
  };

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    for (final (xRel, yRel, tileSize, itemPhase, value) in _items) {
      final bobY = math.sin(phase + itemPhase * 0.6) * (tileSize * 0.25);
      final rot = math.sin(phase * 0.4 + itemPhase) * 0.12;
      final alpha = 0.05 + (math.sin(phase * 1.2 + itemPhase) + 1) / 2 * 0.06;
      final cx = w * xRel;
      final cy = h * yRel + bobY;
      final color = (_tileColors[value] ?? const Color(0xFFFFF3BF))
          .withValues(alpha: alpha);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-tileSize / 2, -tileSize / 2, tileSize, tileSize),
          const Radius.circular(5),
        ),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }
}
