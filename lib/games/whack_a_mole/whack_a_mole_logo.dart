import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildWhackAMoleLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Whack-a-Mole',
      bg: const [Color(0xFF166534), Color(0xFF052E16)],
      accent: const Color(0xFF84CC16),
      art: _whackAMoleArt,
    );

void _whackAMoleArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final cx = zone.center.dx;

  // Grass mound across the lower part of the zone.
  final grassRect = Rect.fromLTWH(zone.left, zone.top + w * 0.55, w, w * 0.45);
  canvas.drawRRect(
    RRect.fromRectAndRadius(grassRect, Radius.circular(w * 0.12)),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF65A30D), Color(0xFF3F6212)],
      ).createShader(grassRect),
  );

  // Dark hole the mole pops out of.
  final holeCenter = Offset(cx, zone.top + w * 0.62);
  canvas.drawOval(
    Rect.fromCenter(center: holeCenter, width: w * 0.62, height: w * 0.22),
    Paint()..color = const Color(0xFF1A2E05),
  );

  // Mole head.
  const brown = Color(0xFF8B5A2B);
  final headCenter = Offset(cx, zone.top + w * 0.44);
  final headR = w * 0.26;
  final headRect = Rect.fromCircle(center: headCenter, radius: headR);
  canvas.drawCircle(
    headCenter,
    headR,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          Color.lerp(brown, Colors.white, 0.32)!,
          brown,
          Color.lerp(brown, Colors.black, 0.20)!,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(headRect),
  );

  // Ears.
  for (final sign in const [-1.0, 1.0]) {
    canvas.drawCircle(
      Offset(headCenter.dx + sign * headR * 0.78, headCenter.dy - headR * 0.55),
      headR * 0.28,
      Paint()..color = brown,
    );
  }

  // Eyes.
  for (final sign in const [-1.0, 1.0]) {
    final eyeC = Offset(headCenter.dx + sign * headR * 0.4, headCenter.dy - headR * 0.18);
    canvas.drawCircle(eyeC, headR * 0.2, Paint()..color = Colors.white);
    canvas.drawCircle(
      eyeC.translate(sign * headR * 0.04, headR * 0.02),
      headR * 0.1,
      Paint()..color = const Color(0xFF1A1A1A),
    );
  }

  // Nose.
  final noseC = Offset(headCenter.dx, headCenter.dy + headR * 0.32);
  canvas.drawCircle(noseC, headR * 0.16, Paint()..color = const Color(0xFFEC4899));
  canvas.drawCircle(
    noseC.translate(-headR * 0.05, -headR * 0.05),
    headR * 0.06,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );

  // Mallet poised above, tilted to the upper-left.
  _drawMallet(canvas, Offset(zone.left + w * 0.2, zone.top + w * 0.12), w * 0.34, -math.pi / 6);
}

void _drawMallet(Canvas canvas, Offset pivot, double len, double angle) {
  canvas.save();
  canvas.translate(pivot.dx, pivot.dy);
  canvas.rotate(angle);

  // Handle.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, len * 0.45), width: len * 0.18, height: len * 0.95),
      Radius.circular(len * 0.08),
    ),
    Paint()..color = const Color(0xFF92400E),
  );
  // Head.
  final headRect = Rect.fromCenter(
    center: Offset(0, -len * 0.18),
    width: len * 0.72,
    height: len * 0.42,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(headRect, Radius.circular(len * 0.1)),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
      ).createShader(headRect),
  );
  // Shine on the head.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(headRect.left, headRect.top, headRect.width, headRect.height * 0.4),
      Radius.circular(len * 0.1),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.35),
  );
  canvas.restore();
}
