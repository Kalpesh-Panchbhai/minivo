import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildSnakeLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Snake Classic',
      bg: const [Color(0xFF115E59), Color(0xFF042F2E)],
      accent: const Color(0xFF2DD4BF),
      art: _snakeArt,
    );

void _snakeArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;
  final cx = zone.center.dx;
  final cy = zone.center.dy;

  final bodyW = w * 0.13;

  final path = Path()
    ..moveTo(cx + w * 0.28, cy - h * 0.32)
    ..cubicTo(
      cx + w * 0.42, cy - h * 0.18,
      cx + w * 0.38, cy + h * 0.05,
      cx + w * 0.08, cy + h * 0.08,
    )
    ..cubicTo(
      cx - w * 0.22, cy + h * 0.11,
      cx - w * 0.38, cy + h * 0.02,
      cx - w * 0.30, cy + h * 0.30,
    );

  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xFF4ADE80).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = bodyW * 1.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );

  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = bodyW,
  );

  canvas.drawPath(
    path,
    Paint()
      ..color = const Color(0xFFBBF7D0).withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = bodyW * 0.35,
  );

  final headC = Offset(cx + w * 0.28, cy - h * 0.32);
  final headR = bodyW * 0.72;
  canvas.drawCircle(headC, headR, Paint()..color = const Color(0xFF16A34A));
  canvas.drawCircle(
    headC,
    headR,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: const [Color(0xFF4ADE80), Color(0xFF15803D)],
      ).createShader(Rect.fromCircle(center: headC, radius: headR)),
  );

  final eyeC = headC.translate(headR * 0.35, -headR * 0.20);
  canvas.drawCircle(eyeC, headR * 0.38, Paint()..color = Colors.white);
  canvas.drawCircle(
    eyeC.translate(headR * 0.10, 0),
    headR * 0.20,
    Paint()..color = const Color(0xFF0B2E1A),
  );
  canvas.drawCircle(
    eyeC.translate(headR * 0.06, -headR * 0.06),
    headR * 0.08,
    Paint()..color = Colors.white.withValues(alpha: 0.80),
  );

  final tongueStart = headC.translate(headR * 0.75, headR * 0.10);
  final tongueEnd = tongueStart.translate(headR * 0.55, headR * 0.15);
  canvas.drawLine(
    tongueStart,
    tongueEnd,
    Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    tongueEnd,
    tongueEnd.translate(headR * 0.18, -headR * 0.15),
    Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = w * 0.010
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    tongueEnd,
    tongueEnd.translate(headR * 0.18, headR * 0.15),
    Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = w * 0.010
      ..strokeCap = StrokeCap.round,
  );

  final appleC = Offset(cx - w * 0.25, cy - h * 0.18);
  final appleR = w * 0.10;

  canvas.drawCircle(
    appleC,
    appleR * 1.8,
    Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, appleR * 0.8),
  );
  canvas.drawCircle(appleC, appleR, Paint()..color = const Color(0xFFEF4444));
  canvas.drawCircle(
    appleC,
    appleR,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: const [Color(0xFFF87171), Color(0xFFDC2626)],
      ).createShader(Rect.fromCircle(center: appleC, radius: appleR)),
  );
  canvas.drawCircle(
    appleC.translate(-appleR * 0.30, -appleR * 0.30),
    appleR * 0.22,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );

  final stemTop = appleC.translate(appleR * 0.05, -appleR * 1.0);
  final stemBot = appleC.translate(0, -appleR * 0.7);
  canvas.drawLine(
    stemTop,
    stemBot,
    Paint()
      ..color = const Color(0xFF5C3316)
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round,
  );

  final leafC = appleC.translate(appleR * 0.35, -appleR * 0.95);
  canvas.drawOval(
    Rect.fromCenter(center: leafC, width: appleR * 0.55, height: appleR * 0.28),
    Paint()..color = const Color(0xFF22C55E),
  );
}
