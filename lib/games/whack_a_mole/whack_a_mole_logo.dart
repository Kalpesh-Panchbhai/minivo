import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildWhackAMoleLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Whack-a-Mole',
      bg: const [Color(0xFF7C2D12), Color(0xFF431407)],
      accent: const Color(0xFFFB923C),
      art: _whackAMoleArt,
    );

void _whackAMoleArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;
  final cx = zone.center.dx;

  final holeCenter = Offset(cx, zone.top + h * 0.72);
  canvas.drawOval(
    Rect.fromCenter(center: holeCenter, width: w * 0.70, height: w * 0.22),
    Paint()..color = const Color(0xFF1C0A00),
  );
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(holeCenter.dx, holeCenter.dy - w * 0.01),
        width: w * 0.70,
        height: w * 0.22),
    Paint()
      ..color = const Color(0xFF5C3A1E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03,
  );

  const brown = Color(0xFF8B5A2B);
  final headCenter = Offset(cx, zone.top + h * 0.44);
  final headR = w * 0.26;
  final headRect = Rect.fromCircle(center: headCenter, radius: headR);
  canvas.drawCircle(
    headCenter,
    headR,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          Color.lerp(brown, Colors.white, 0.30)!,
          brown,
          Color.lerp(brown, Colors.black, 0.22)!,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(headRect),
  );

  for (final sign in const [-1.0, 1.0]) {
    final earC =
        Offset(headCenter.dx + sign * headR * 0.80, headCenter.dy - headR * 0.58);
    canvas.drawCircle(earC, headR * 0.26, Paint()..color = brown);
    canvas.drawCircle(
      earC,
      headR * 0.14,
      Paint()..color = const Color(0xFFD4956A),
    );
  }

  for (final sign in const [-1.0, 1.0]) {
    final eyeC =
        Offset(headCenter.dx + sign * headR * 0.38, headCenter.dy - headR * 0.12);
    canvas.drawCircle(eyeC, headR * 0.20, Paint()..color = Colors.white);
    canvas.drawCircle(
      eyeC.translate(sign * headR * 0.05, headR * 0.02),
      headR * 0.11,
      Paint()..color = const Color(0xFF1A1A1A),
    );
    canvas.drawCircle(
      eyeC.translate(sign * headR * 0.02, -headR * 0.04),
      headR * 0.05,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  final noseC = Offset(headCenter.dx, headCenter.dy + headR * 0.30);
  canvas.drawOval(
    Rect.fromCenter(center: noseC, width: headR * 0.34, height: headR * 0.24),
    Paint()..color = const Color(0xFFEC4899),
  );
  canvas.drawCircle(
    noseC.translate(-headR * 0.05, -headR * 0.04),
    headR * 0.06,
    Paint()..color = Colors.white.withValues(alpha: 0.50),
  );

  _drawMallet(
    canvas,
    Offset(zone.right - w * 0.16, zone.top + h * 0.08),
    w * 0.38,
    math.pi / 5,
  );
}

void _drawMallet(Canvas canvas, Offset pivot, double len, double angle) {
  canvas.save();
  canvas.translate(pivot.dx, pivot.dy);
  canvas.rotate(angle);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(0, len * 0.45), width: len * 0.16, height: len * 0.90),
      Radius.circular(len * 0.07),
    ),
    Paint()..color = const Color(0xFF92400E),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(0, len * 0.45), width: len * 0.16, height: len * 0.90),
      Radius.circular(len * 0.07),
    ),
    Paint()
      ..color = const Color(0xFFB45309)
      ..style = PaintingStyle.stroke
      ..strokeWidth = len * 0.02,
  );

  final headRect = Rect.fromCenter(
    center: Offset(0, -len * 0.14),
    width: len * 0.68,
    height: len * 0.40,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(headRect, Radius.circular(len * 0.09)),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
      ).createShader(headRect),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
          headRect.left, headRect.top, headRect.width, headRect.height * 0.38),
      Radius.circular(len * 0.09),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.30),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(headRect, Radius.circular(len * 0.09)),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = len * 0.02,
  );
  canvas.restore();
}
