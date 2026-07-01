import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildFlappyTapLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Flappy Tap',
      bg: const [Color(0xFF4A9FD4), Color(0xFF71B9E8)],
      accent: const Color(0xFF4ECDC4),
      art: _flappyTapArt,
    );

void _flappyTapArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;
  final cx = zone.center.dx;
  final cy = zone.center.dy;

  // Pipes
  final pipeW = w * 0.13;
  final capW = pipeW + w * 0.04;
  final capH = w * 0.05;
  final gapHalf = h * 0.20;

  void drawPipe(double x, double topY, double botY, bool isTop) {
    final pipeRect = Rect.fromLTWH(x - pipeW / 2, topY, pipeW, botY - topY);
    canvas.drawRect(
      pipeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Color(0xFF66BB6A), Color(0xFF4CAF50), Color(0xFF2E7D32)],
        ).createShader(pipeRect),
    );
    canvas.drawRect(
      Rect.fromLTWH(x - pipeW / 2, topY, pipeW * 0.16, botY - topY),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    final capY = isTop ? botY - capH : topY;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - capW / 2, capY, capW, capH),
        Radius.circular(w * 0.012),
      ),
      Paint()..color = const Color(0xFF388E3C),
    );
  }

  final leftPipeX = zone.left + w * 0.10;
  drawPipe(leftPipeX, zone.top - h * 0.05, cy - gapHalf, true);
  drawPipe(leftPipeX, cy + gapHalf, zone.bottom + h * 0.05, false);
  final rightPipeX = zone.right - w * 0.10;
  drawPipe(rightPipeX, zone.top - h * 0.05, cy - gapHalf * 0.75, true);
  drawPipe(rightPipeX, cy + gapHalf * 1.25, zone.bottom + h * 0.05, false);

  // Bird — proper proportions matching game (width:height ~ 2.2:2.0)
  final birdR = w * 0.14;
  final birdW = birdR * 2.2;
  final birdH = birdR * 2.0;
  final birdCx = cx;
  final birdCy = cy;
  final birdRect = Rect.fromCenter(
    center: Offset(birdCx, birdCy),
    width: birdW,
    height: birdH,
  );

  // Shadow
  canvas.drawOval(
    birdRect.translate(0, birdH * 0.08),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  // Body
  canvas.drawOval(
    birdRect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        colors: const [Color(0xFFFFE44A), Color(0xFFFFD700)],
      ).createShader(birdRect),
  );

  // Belly
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(birdCx + birdW * 0.04, birdCy + birdH * 0.10),
      width: birdW * 0.55,
      height: birdH * 0.48,
    ),
    Paint()..color = const Color(0xFFFFF0A0),
  );

  // Tail feathers
  final tailX = birdCx - birdW * 0.42;
  final tailY = birdCy;
  for (int i = 0; i < 3; i++) {
    final angle = -0.30 + i * 0.18;
    final tipX = tailX - birdW * 0.18;
    final tipY = tailY + birdH * angle;
    final f = Path()
      ..moveTo(tailX, tailY)
      ..quadraticBezierTo(tailX - birdW * 0.10, tipY, tipX, tipY)
      ..quadraticBezierTo(tailX - birdW * 0.06, tailY + birdH * angle * 0.3, tailX, tailY)
      ..close();
    canvas.drawPath(
      f,
      Paint()..color = Color.lerp(const Color(0xFFE6B800), const Color(0xFFD4A000), i / 2)!,
    );
  }

  // Wing
  final wingX = birdCx - birdW * 0.18;
  final wingY = birdCy + birdH * 0.02;
  final wing = Path()
    ..moveTo(wingX + birdW * 0.10, wingY)
    ..quadraticBezierTo(wingX - birdW * 0.18, wingY - birdH * 0.45,
        wingX - birdW * 0.25, wingY - birdH * 0.02)
    ..quadraticBezierTo(wingX - birdW * 0.12, wingY + birdH * 0.12,
        wingX + birdW * 0.10, wingY)
    ..close();
  canvas.drawPath(wing, Paint()..color = const Color(0xFFE6B800));

  // Beak
  final beakTip = Offset(birdCx + birdW * 0.52, birdCy + birdH * 0.02);
  final beakTop = Offset(birdCx + birdW * 0.28, birdCy - birdH * 0.08);
  final beakBot = Offset(birdCx + birdW * 0.28, birdCy + birdH * 0.14);
  canvas.drawPath(
    Path()..moveTo(beakTop.dx, beakTop.dy)..lineTo(beakTip.dx, beakTip.dy)
      ..lineTo(beakBot.dx, beakBot.dy)..close(),
    Paint()..color = const Color(0xFFFF8C00),
  );

  // Eye
  final eyeC = Offset(birdCx + birdW * 0.12, birdCy - birdH * 0.16);
  final eyeR = birdW * 0.10;
  canvas.drawCircle(eyeC, eyeR, Paint()..color = Colors.white);
  final pupilC = eyeC.translate(eyeR * 0.18, 0);
  canvas.drawCircle(pupilC, eyeR * 0.52, Paint()..color = const Color(0xFF1A1A2E));
  canvas.drawCircle(
    pupilC.translate(-eyeR * 0.12, -eyeR * 0.12),
    eyeR * 0.16,
    Paint()..color = Colors.white.withValues(alpha: 0.85),
  );

  // Smiley mouth
  final smileC = Offset(birdCx + birdW * 0.24, birdCy + birdH * 0.06);
  final smileR = birdW * 0.07;
  canvas.drawPath(
    Path()..addArc(
      Rect.fromCenter(center: smileC, width: smileR * 2, height: smileR * 1.4),
      math.pi * 0.15,
      math.pi * 0.70,
    ),
    Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round,
  );
}
