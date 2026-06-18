import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/animated_background.dart';
import '../shared/game_logo_scaffold.dart';

Widget buildDodgeBallLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Dodge Ball',
      bg: const [Color(0xFF155E75), Color(0xFF083344)],
      accent: const Color(0xFF22D3EE),
      art: _dodgeBallArt,
    );

void _dodgeBallArt(Canvas canvas, Rect zone) {
  // A glowing cyan ball weaving between two obstacle bars, with motion trails
  // behind it.
  const ballColor = Color(0xFF22D3EE);

  // two obstacle bars the ball weaves between (top-left and bottom-right)
  final barW = zone.width * 0.20;
  final barH = zone.height * 0.42;
  final bar1 = Rect.fromLTWH(
      zone.left + zone.width * 0.06, zone.top + zone.height * 0.04, barW, barH);
  final bar2 = Rect.fromLTWH(zone.right - zone.width * 0.06 - barW,
      zone.bottom - zone.height * 0.04 - barH, barW, barH);

  void drawBar(Rect r, List<Color> grad) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(barW * 0.28));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: grad,
          ).createShader(r));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = barW * 0.08);
  }

  drawBar(bar1, const [Color(0xFFFB7185), Color(0xFFE11D48)]);
  drawBar(bar2, const [Color(0xFFFBBF24), Color(0xFFD97706)]);

  // weaving path the ball travels (top-right toward bottom-left, S-curve)
  final ballR = zone.width * 0.11;
  final ballC = Offset(zone.center.dx, zone.center.dy);

  // motion trails behind the ball (fading toward the upper-right)
  final trailDir = Offset(zone.width * 0.16, -zone.height * 0.14);
  for (int i = 3; i >= 1; i--) {
    final c = ballC + trailDir * i.toDouble();
    canvas.drawCircle(
      c,
      ballR * (1 - i * 0.16),
      Paint()..color = ballColor.withValues(alpha: 0.10 * (4 - i)),
    );
  }

  // glow halo
  canvas.drawCircle(
    ballC,
    ballR * 1.7,
    Paint()
      ..color = ballColor.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );

  // ball body
  canvas.drawCircle(
    ballC,
    ballR,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFCFFAFE), ballColor, Color(0xFF0E7490)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: ballC, radius: ballR)),
  );
  // specular highlight
  canvas.drawCircle(
    ballC.translate(-ballR * 0.28, -ballR * 0.30),
    ballR * 0.26,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
}

class DodgeBallBgPainter extends AnimatedBgPainter {
  const DodgeBallBgPainter(super.t);

  static const _colors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFFFF9FF3),
    Color(0xFF6BCB77),
    Color(0xFFCC8EFF),
  ];

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    const fg = Color(0xFF00D4FF);

    final playerR = w * 0.035;
    final playerX = w * 0.5 + math.sin(t * 2 * math.pi) * w * 0.2;
    final playerY = h * 0.82;
    canvas.drawCircle(
      Offset(playerX, playerY),
      playerR,
      Paint()..color = fg.withValues(alpha: 0.06),
    );

    for (int i = 0; i < 5; i++) {
      final ox = w * (0.1 + i * 0.2);
      final oy = ((t + i * 0.2) % 1.0) * h * 0.75;
      canvas.drawCircle(
        Offset(ox, oy),
        w * 0.02,
        Paint()..color = _colors[i].withValues(alpha: 0.06),
      );
    }
  }
}
