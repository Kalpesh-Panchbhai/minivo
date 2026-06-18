import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildTapTapDashLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Tap Tap Dash',
      bg: const [Color(0xFF0E7490), Color(0xFF083344)],
      accent: const Color(0xFF38BDF8),
      art: _tapTapDashArt,
    );

void _tapTapDashArt(Canvas canvas, Rect zone) {
  // A winding zig-zag track made of segments, with a small runner travelling
  // along it.
  final w = zone.width;

  Offset p(double fx, double fy) =>
      Offset(zone.left + w * fx, zone.top + zone.height * fy);

  // zig-zag waypoints across the zone
  final pts = [
    p(0.08, 0.74),
    p(0.34, 0.74),
    p(0.34, 0.42),
    p(0.62, 0.42),
    p(0.62, 0.16),
    p(0.92, 0.16),
  ];

  final track = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (int i = 1; i < pts.length; i++) {
    track.lineTo(pts[i].dx, pts[i].dy);
  }

  // soft outer glow
  canvas.drawPath(
    track,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );

  // dim full track
  canvas.drawPath(
    track,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.32),
  );

  // bright "travelled" portion from the start up to the runner
  final runner = pts[2]; // sits on the second corner
  final travelled = Path()..moveTo(pts[0].dx, pts[0].dy);
  travelled.lineTo(pts[1].dx, pts[1].dy);
  travelled.lineTo(runner.dx, runner.dy);
  canvas.drawPath(
    travelled,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: const [Color(0xFFBAE6FD), Color(0xFF38BDF8)],
      ).createShader(zone),
  );

  // runner: a rounded triangle pointing along the track (upward here)
  final rs = w * 0.11;
  final runnerPath = Path()
    ..moveTo(runner.dx, runner.dy - rs)
    ..lineTo(runner.dx + rs * 0.86, runner.dy + rs * 0.7)
    ..lineTo(runner.dx - rs * 0.86, runner.dy + rs * 0.7)
    ..close();

  // runner glow
  canvas.drawCircle(
    runner,
    rs * 1.4,
    Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawPath(
    runnerPath,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8)],
      ).createShader(Rect.fromCircle(center: runner, radius: rs)),
  );
  canvas.drawPath(
    runnerPath,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.015
      ..strokeJoin = StrokeJoin.round,
  );
}
