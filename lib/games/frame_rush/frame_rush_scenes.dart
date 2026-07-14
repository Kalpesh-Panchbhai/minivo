import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'frame_rush_objects.dart';

// ---------------------------------------------------------------------------
// Frame Rush — vector scenes.
//
// Each object theme gets a believable, lightweight environment drawn entirely
// in code: vehicles slide on a concrete dam spillway, birds fly in open sky,
// planes cruise high, rockets streak through space, fish glide underwater.
// All motion is subtle + ambient, driven by [t] (0..1, loops with the object).
// ---------------------------------------------------------------------------

const int _kSpillway = 0;
const int _kSky = 1;
const int _kHighSky = 2;
const int _kSpace = 3;
const int _kWater = 4;

int _sceneOf(int type) {
  switch (type) {
    case FrObject.car:
    case FrObject.bus:
      return _kSpillway;
    case FrObject.bird:
      return _kSky;
    case FrObject.plane:
      return _kHighSky;
    case FrObject.rocket:
      return _kSpace;
    case FrObject.fish:
      return _kWater;
    default:
      return _kSpillway;
  }
}

/// Full-screen vertical gradient painted behind everything (so the HUD/footer
/// blend into the scene). The detailed scene is drawn on top within the board.
List<Color> frameRushSceneBg(int type) {
  switch (_sceneOf(type)) {
    case _kSky:
      return const [Color(0xFF8FD0F5), Color(0xFF5AA6E4), Color(0xFF3E83C9)];
    case _kHighSky:
      return const [Color(0xFF6FB4EE), Color(0xFF3E7FD0), Color(0xFF24509C)];
    case _kSpace:
      return const [Color(0xFF2A2A5E), Color(0xFF16163A), Color(0xFF080816)];
    case _kWater:
      return const [Color(0xFF29C0C0), Color(0xFF117FA0), Color(0xFF073E58)];
    case _kSpillway:
    default:
      return const [Color(0xFF9AA6B4), Color(0xFF5E6772), Color(0xFF232D34)];
  }
}

double _rnd(int i) {
  var h = (i * 374761393 + 668265263) & 0x7fffffff;
  h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff;
  return ((h ^ (h >> 16)) & 0xffff) / 0xffff;
}

void paintFrameRushScene(Canvas canvas, Size size, int type, double t) {
  switch (_sceneOf(type)) {
    case _kSky:
      _paintSky(canvas, size, t, high: false);
      break;
    case _kHighSky:
      _paintSky(canvas, size, t, high: true);
      break;
    case _kSpace:
      _paintSpace(canvas, size, t);
      break;
    case _kWater:
      _paintWater(canvas, size, t);
      break;
    case _kSpillway:
    default:
      _paintSpillway(canvas, size, t);
      break;
  }
}

// ── Concrete dam spillway (car / bus) ───────────────────────────────────────
void _paintSpillway(Canvas canvas, Size size, double t) {
  final w = size.width, h = size.height;

  // Thin sky strip at the very top.
  final skyH = h * 0.12;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, skyH),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFAEBED0), Color(0xFF8A97A6)],
      ).createShader(Rect.fromLTWH(0, 0, w, skyH)),
  );

  // Main concrete slope.
  final concrete = Rect.fromLTWH(0, skyH, w, h - skyH);
  canvas.drawRect(
    concrete,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, skyH),
        Offset(0, h),
        const [Color(0xFF7C858F), Color(0xFF636B75), Color(0xFF3B444D)],
        const [0.0, 0.5, 1.0],
      ),
  );

  // Curved sheen down the middle (suggests the ramp's rounded surface).
  canvas.drawRect(
    concrete,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        Offset(w * 0.5, skyH + (h - skyH) * 0.35),
        w * 0.62,
        [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.0)],
      ),
  );

  // Side channel walls (darker angled panels, like the reference).
  final leftWall = Path()
    ..moveTo(0, skyH)
    ..lineTo(w * 0.16, skyH)
    ..lineTo(0, h)
    ..close();
  final rightWall = Path()
    ..moveTo(w, skyH)
    ..lineTo(w * 0.84, skyH)
    ..lineTo(w, h)
    ..close();
  final wallPaint = Paint()..color = Colors.black.withValues(alpha: 0.16);
  canvas.drawPath(leftWall, wallPaint);
  canvas.drawPath(rightWall, wallPaint);

  // Panel seams.
  final seam = Paint()
    ..color = Colors.black.withValues(alpha: 0.14)
    ..strokeWidth = 1.2;
  for (int i = 1; i < 7; i++) {
    final y = skyH + (h - skyH) * i / 7;
    canvas.drawLine(Offset(w * 0.05, y), Offset(w * 0.95, y), seam);
  }
  for (int i = 1; i < 6; i++) {
    final x = w * i / 6;
    canvas.drawLine(Offset(x, skyH), Offset(x, h * 0.92), seam);
  }

  // Weather stains streaking down.
  for (int i = 0; i < 7; i++) {
    final x = w * (0.08 + 0.84 * _rnd(i * 3 + 1));
    final sw = w * (0.015 + 0.03 * _rnd(i * 3 + 2));
    final top = skyH + (h - skyH) * 0.02;
    final len = (h - skyH) * (0.3 + 0.5 * _rnd(i * 3 + 3));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, top, sw, len), Radius.circular(sw)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  // Waterline at the bottom with gentle shimmer.
  final waterTop = h * 0.9;
  canvas.drawRect(
    Rect.fromLTWH(0, waterTop, w, h - waterTop),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, waterTop),
        Offset(0, h),
        const [Color(0xFF2E8C8C), Color(0xFF12556B)],
      ),
  );
  final shimmer = Paint()
    ..color = Colors.white.withValues(alpha: 0.16)
    ..strokeWidth = 1.4;
  for (int i = 0; i < 4; i++) {
    final y = waterTop + (h - waterTop) * (0.2 + 0.2 * i);
    final dx = math.sin((t * 2 * math.pi) + i) * w * 0.03;
    canvas.drawLine(Offset(w * 0.1 + dx, y), Offset(w * 0.4 + dx, y), shimmer);
    canvas.drawLine(Offset(w * 0.6 - dx, y), Offset(w * 0.9 - dx, y), shimmer);
  }
}

// ── Sky (bird) / high sky (plane) ───────────────────────────────────────────
void _paintSky(Canvas canvas, Size size, double t, {required bool high}) {
  final w = size.width, h = size.height;

  // Sun glow.
  final sunC = Offset(w * 0.82, h * 0.16);
  canvas.drawCircle(
    sunC,
    w * 0.4,
    Paint()
      ..shader = ui.Gradient.radial(sunC, w * 0.4, [
        Colors.white.withValues(alpha: high ? 0.16 : 0.28),
        Colors.white.withValues(alpha: 0.0),
      ]),
  );

  // Drifting clouds.
  final cloudPaint = Paint()
    ..color = Colors.white.withValues(alpha: high ? 0.45 : 0.85)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  final n = high ? 3 : 4;
  for (int i = 0; i < n; i++) {
    final baseY = h * (0.18 + 0.6 * _rnd(i * 5 + 1));
    final drift = (t * (0.2 + 0.15 * i) + _rnd(i * 5 + 2)) % 1.0;
    final cx = drift * (w + w * 0.5) - w * 0.25;
    final cw = w * (0.22 + 0.16 * _rnd(i * 5 + 3));
    _cloud(canvas, Offset(cx, baseY), cw, cloudPaint);
  }

  if (!high) {
    // Distant hills.
    for (int i = 0; i < 2; i++) {
      final hillPaint = Paint()
        ..color = (i == 0 ? const Color(0xFF3E7C9A) : const Color(0xFF356C86))
            .withValues(alpha: 0.55);
      final path = Path()..moveTo(0, h);
      final baseY = h * (0.86 - i * 0.05);
      path.lineTo(0, baseY);
      for (double x = 0; x <= w; x += w / 6) {
        path.quadraticBezierTo(x + w / 12, baseY - h * 0.05 * _rnd(i * 7 + x.toInt()),
            x + w / 6, baseY);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, hillPaint);
    }
  }
}

void _cloud(Canvas canvas, Offset c, double s, Paint p) {
  canvas.drawOval(Rect.fromCenter(center: c, width: s, height: s * 0.5), p);
  canvas.drawOval(
      Rect.fromCenter(center: c.translate(-s * 0.28, s * 0.06), width: s * 0.6, height: s * 0.4), p);
  canvas.drawOval(
      Rect.fromCenter(center: c.translate(s * 0.3, s * 0.05), width: s * 0.55, height: s * 0.38), p);
}

// ── Space (rocket) ──────────────────────────────────────────────────────────
void _paintSpace(Canvas canvas, Size size, double t) {
  final w = size.width, h = size.height;

  // Nebula wisps.
  for (int i = 0; i < 2; i++) {
    final c = Offset(w * (0.2 + 0.6 * _rnd(i + 1)), h * (0.2 + 0.4 * _rnd(i + 5)));
    canvas.drawCircle(
      c,
      w * 0.4,
      Paint()
        ..shader = ui.Gradient.radial(c, w * 0.4, [
          const Color(0xFF6C5CE7).withValues(alpha: 0.16),
          const Color(0xFF6C5CE7).withValues(alpha: 0.0),
        ]),
    );
  }

  // Stars (twinkle).
  for (int i = 0; i < 46; i++) {
    final x = w * _rnd(i * 2 + 1);
    final y = h * 0.9 * _rnd(i * 2 + 2);
    final phase = _rnd(i * 2 + 3);
    final tw = 0.4 + 0.6 * ((math.sin((t + phase) * 2 * math.pi) + 1) / 2);
    final r = 0.6 + 1.4 * _rnd(i * 3 + 1);
    canvas.drawCircle(
        Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: 0.8 * tw));
  }

  // Planet curve at the bottom.
  final pr = w * 1.1;
  final pc = Offset(w * 0.5, h + pr * 0.72);
  canvas.drawCircle(
      pc, pr, Paint()..shader = ui.Gradient.radial(
          Offset(w * 0.35, h * 0.92), pr, const [Color(0xFF3B6EA5), Color(0xFF1B3A5E)]));
  canvas.drawCircle(
      pc,
      pr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF7DB4E6).withValues(alpha: 0.4));
}

// ── Underwater (fish) ───────────────────────────────────────────────────────
void _paintWater(Canvas canvas, Size size, double t) {
  final w = size.width, h = size.height;

  // God rays.
  for (int i = 0; i < 4; i++) {
    final x = w * (0.1 + 0.24 * i);
    final ray = Path()
      ..moveTo(x, 0)
      ..lineTo(x + w * 0.08, 0)
      ..lineTo(x + w * 0.22, h)
      ..lineTo(x + w * 0.06, h)
      ..close();
    canvas.drawPath(
        ray,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  // Rising bubbles.
  for (int i = 0; i < 18; i++) {
    final x = w * _rnd(i * 2 + 1);
    final speed = 0.4 + 0.5 * _rnd(i * 2 + 2);
    final y = (h * (1 - ((t * speed + _rnd(i * 3 + 1)) % 1.0)));
    final r = 1.5 + 3.5 * _rnd(i * 3 + 2);
    canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.3));
  }

  // Sandy bottom.
  final sandTop = h * 0.9;
  final sand = Path()..moveTo(0, h)..lineTo(0, sandTop);
  for (double x = 0; x <= w; x += w / 8) {
    sand.quadraticBezierTo(
        x + w / 16, sandTop - h * 0.02 * _rnd(x.toInt() + 3), x + w / 8, sandTop);
  }
  sand
    ..lineTo(w, h)
    ..close();
  canvas.drawPath(sand, Paint()..color = const Color(0xFFCBB68A).withValues(alpha: 0.7));
}
