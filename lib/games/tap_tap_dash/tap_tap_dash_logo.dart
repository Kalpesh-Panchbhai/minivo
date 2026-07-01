import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildTapTapDashLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Tap Tap Dash',
      bg: const [Color(0xFF0E4D64), Color(0xFF062C3A)],
      accent: const Color(0xFF22D3EE),
      art: _tapTapDashArt,
    );

void _tapTapDashArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;

  Offset p(double fx, double fy) =>
      Offset(zone.left + w * fx, zone.top + h * fy);

  final pts = [
    p(0.10, 0.82),
    p(0.35, 0.82),
    p(0.35, 0.48),
    p(0.62, 0.48),
    p(0.62, 0.18),
    p(0.90, 0.18),
  ];

  final track = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (int i = 1; i < pts.length; i++) {
    track.lineTo(pts[i].dx, pts[i].dy);
  }

  canvas.drawPath(
    track,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );

  canvas.drawPath(
    track,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.28),
  );

  final runnerPos = pts[3];
  final travelled = Path()..moveTo(pts[0].dx, pts[0].dy);
  travelled.lineTo(pts[1].dx, pts[1].dy);
  travelled.lineTo(pts[2].dx, pts[2].dy);
  travelled.lineTo(runnerPos.dx, runnerPos.dy);
  canvas.drawPath(
    travelled,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: const [Color(0xFFCFFAFE), Color(0xFF22D3EE)],
      ).createShader(zone),
  );

  final speedPaint = Paint()
    ..color = const Color(0xFF22D3EE).withValues(alpha: 0.5)
    ..strokeWidth = w * 0.025
    ..strokeCap = StrokeCap.round;
  for (int i = 1; i <= 3; i++) {
    final ly = runnerPos.dy + (i - 2) * w * 0.06;
    canvas.drawLine(
      Offset(runnerPos.dx - w * 0.08 - i * w * 0.04, ly),
      Offset(runnerPos.dx - w * 0.08, ly),
      speedPaint..color = const Color(0xFF22D3EE).withValues(alpha: 0.6 / i),
    );
  }

  final headR = w * 0.06;
  final headC = Offset(runnerPos.dx + headR * 0.2, runnerPos.dy - headR * 2.0);

  canvas.drawCircle(
    runnerPos,
    w * 0.12,
    Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
  );

  canvas.drawCircle(headC, headR, Paint()..color = Colors.white);
  canvas.drawCircle(
    headC.translate(-headR * 0.25, -headR * 0.2),
    headR * 0.2,
    Paint()..color = Colors.white.withValues(alpha: 0.6),
  );

  final bodyTop = headC.dy + headR * 0.7;
  final bodyW = headR * 1.0;
  final bodyH = headR * 1.6;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(headC.dx - bodyW / 2, bodyTop, bodyW, bodyH),
      Radius.circular(bodyW * 0.3),
    ),
    Paint()..color = const Color(0xFF22D3EE),
  );

  final legPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = headR * 0.5
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    Offset(headC.dx - bodyW * 0.2, bodyTop + bodyH),
    Offset(headC.dx - bodyW * 0.5, bodyTop + bodyH + headR * 0.9),
    legPaint,
  );
  canvas.drawLine(
    Offset(headC.dx + bodyW * 0.2, bodyTop + bodyH),
    Offset(headC.dx + bodyW * 0.6, bodyTop + bodyH + headR * 0.6),
    legPaint,
  );
}
