import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Frame Rush — object silhouettes.
//
// One painter draws each object BOTH ways: filled+detailed for the moving hero,
// and as a glowing neon outline for the target "frame". Both share the exact
// same silhouette Path so a perfect capture visually fills the outline.
//
// Every silhouette is authored in unit space, centered at the origin, facing
// +x (to the right). The screen positions/rotates/scales it via the canvas.
// ---------------------------------------------------------------------------

class FrObject {
  static const int car = 0;
  static const int bird = 1;
  static const int plane = 2;
  static const int rocket = 3;
  static const int fish = 4;
  static const int bus = 5;
}

/// Objects with a clear "belly down" (car, bus, bird, fish): they tilt with the
/// path but never flip upside down, and mirror horizontally when travelling
/// left. Top-view objects (plane, rocket) rotate fully to face their heading.
bool frameRushIsUprightObject(int type) =>
    type == FrObject.car ||
    type == FrObject.bus ||
    type == FrObject.bird ||
    type == FrObject.fish;

/// Orients the canvas so an object of [type] faces travel direction [angle].
/// Upright objects stay belly-down (tilt + mirror); free objects rotate fully.
/// The caller has already translated to the object's centre.
void frameRushApplyOrientation(Canvas canvas, int type, double angle) {
  if (frameRushIsUprightObject(type)) {
    final c = math.cos(angle), s = math.sin(angle);
    canvas.rotate(math.atan2(s, c.abs()));
    if (c < 0) canvas.scale(-1.0, 1.0);
  } else {
    canvas.rotate(angle);
  }
}

class FrTheme {
  final String name;
  final Color body;
  final Color bodyDark;
  final Color detail;
  final List<Color> bg; // scene background gradient (top -> bottom)
  final Color accent; // scene accent (glow / particles)
  const FrTheme(this.name, this.body, this.bodyDark, this.detail, this.bg,
      this.accent);
}

const _themes = <FrTheme>[
  // car — red car on a concrete ramp
  FrTheme('Car', Color(0xFFE23B4E), Color(0xFF9B1C2C), Color(0xFF2A2E35),
      [Color(0xFF6B7480), Color(0xFF3A4048)], Color(0xFF7DD3FC)),
  // bird — blue bird in the sky
  FrTheme('Bird', Color(0xFF3B82F6), Color(0xFF1D4FB0), Color(0xFFFDBA33),
      [Color(0xFF7EC8F5), Color(0xFF3E86D4)], Color(0xFFFFFFFF)),
  // plane — silver plane, higher sky
  FrTheme('Plane', Color(0xFFE6EAF0), Color(0xFF9AA6B8), Color(0xFF3B4a63),
      [Color(0xFF5AA0E6), Color(0xFF2A5DAE)], Color(0xFFFFFFFF)),
  // rocket — white/red rocket in space
  FrTheme('Rocket', Color(0xFFF4F6FB), Color(0xFFB9C2D6), Color(0xFFE23B4E),
      [Color(0xFF2A2A5E), Color(0xFF0E0E24)], Color(0xFF8B7BFF)),
  // fish — orange fish underwater
  FrTheme('Fish', Color(0xFFFB923C), Color(0xFFC2560F), Color(0xFF3A2410),
      [Color(0xFF12A8A8), Color(0xFF0B4F6C)], Color(0xFF9BE7E7)),
  // bus — yellow bus on the street
  FrTheme('Bus', Color(0xFFF5B400), Color(0xFFB57F00), Color(0xFF2A2E35),
      [Color(0xFF7A828E), Color(0xFF474D57)], Color(0xFFFFE08A)),
];

FrTheme frameRushTheme(int type) => _themes[type % _themes.length];

// ---------------------------------------------------------------------------
// Silhouettes — built once in unit space, cached, then scaled per draw.
// ---------------------------------------------------------------------------

final Map<int, Path> _silCache = {};

Path _silhouette(int type) => _silCache.putIfAbsent(type, () => _build(type));

Path _u(PathOperation op, Path a, Path b) => Path.combine(op, a, b);

// Hand-drawn (wobbly marker) version of each silhouette — built once in unit
// space by walking the clean contour and nudging it with a smooth, deterministic
// low-frequency wobble so it looks sketched by hand (never jitters frame-to-frame).
final Map<int, Path> _handCache = {};

Path _handDrawnSilhouette(int type) =>
    _handCache.putIfAbsent(type, () => _buildHandDrawn(type));

Path _buildHandDrawn(int type) {
  final out = Path();
  for (final metric in _silhouette(type).computeMetrics()) {
    final len = metric.length;
    if (len < 1e-4) continue;
    final steps = math.max(20, (len / 0.045).round());
    final pts = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      final u = i / steps;
      final tan = metric.getTangentForOffset(len * u);
      if (tan == null) continue;
      final normal = Offset(-tan.vector.dy, tan.vector.dx);
      // Integer harmonics of the full loop keep the wobble continuous at the seam.
      final wob = (math.sin(u * 2 * math.pi * 3 + type) * 0.6 +
              math.sin(u * 2 * math.pi * 7 + type * 1.7) * 0.4) *
          0.035;
      pts.add(tan.position + normal * wob);
    }
    if (pts.length < 3) continue;
    out.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1], cur = pts[i];
      out.quadraticBezierTo(
          prev.dx, prev.dy, (prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
    }
    out.close();
  }
  return out;
}

/// True for objects that ride on a solid surface and cast a ground contact
/// shadow (the spillway vehicles).
bool frameRushIsGroundVehicle(int type) =>
    type == FrObject.car || type == FrObject.bus;

/// Soft elliptical contact shadow on the ramp surface, under [center].
void paintFrameRushGroundShadow(Canvas canvas, Offset center, double radius) {
  canvas.drawOval(
    Rect.fromCenter(
        center: center, width: radius * 2.1, height: radius * 0.5),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.26)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.13),
  );
}

Path _build(int type) {
  switch (type) {
    case FrObject.car:
      return _buildCar();
    case FrObject.bird:
      return _buildBird();
    case FrObject.plane:
      return _buildPlane();
    case FrObject.rocket:
      return _buildRocket();
    case FrObject.fish:
      return _buildFish();
    case FrObject.bus:
      return _buildBus();
    default:
      return _buildCar();
  }
}

Path _buildCar() {
  final body = Path()
    ..addRRect(RRect.fromLTRBR(-1.15, -0.06, 1.15, 0.46, const Radius.circular(0.3)));
  final cabin = Path()
    ..moveTo(-0.52, -0.02)
    ..lineTo(-0.34, -0.5)
    ..quadraticBezierTo(-0.28, -0.6, -0.16, -0.6)
    ..lineTo(0.28, -0.6)
    ..quadraticBezierTo(0.4, -0.6, 0.5, -0.5)
    ..lineTo(0.66, -0.02)
    ..close();
  final wl = Path()..addOval(Rect.fromCircle(center: const Offset(-0.6, 0.44), radius: 0.34));
  final wr = Path()..addOval(Rect.fromCircle(center: const Offset(0.66, 0.44), radius: 0.34));
  return _u(PathOperation.union, _u(PathOperation.union, _u(PathOperation.union, body, cabin), wl), wr);
}

Path _buildBus() {
  final body = Path()
    ..addRRect(RRect.fromLTRBAndCorners(-1.2, -0.62, 1.2, 0.46,
        topLeft: const Radius.circular(0.34),
        topRight: const Radius.circular(0.16),
        bottomLeft: const Radius.circular(0.2),
        bottomRight: const Radius.circular(0.2)));
  final wl = Path()..addOval(Rect.fromCircle(center: const Offset(-0.66, 0.46), radius: 0.3));
  final wr = Path()..addOval(Rect.fromCircle(center: const Offset(0.72, 0.46), radius: 0.3));
  return _u(PathOperation.union, _u(PathOperation.union, body, wl), wr);
}

Path _buildBird() {
  // body + head facing +x, with a swept wing above and tail behind.
  final body = Path()
    ..addOval(Rect.fromCenter(center: const Offset(0.05, 0.05), width: 1.5, height: 0.72));
  final head = Path()..addOval(Rect.fromCircle(center: const Offset(0.78, -0.08), radius: 0.3));
  final beak = Path()
    ..moveTo(1.0, -0.12)
    ..lineTo(1.35, 0.0)
    ..lineTo(1.0, 0.12)
    ..close();
  final wing = Path()
    ..moveTo(-0.1, -0.05)
    ..quadraticBezierTo(-0.05, -0.9, 0.4, -0.75)
    ..quadraticBezierTo(0.15, -0.35, 0.2, -0.02)
    ..close();
  final tail = Path()
    ..moveTo(-0.55, -0.02)
    ..lineTo(-1.25, -0.28)
    ..lineTo(-1.2, 0.12)
    ..lineTo(-0.55, 0.2)
    ..close();
  var p = _u(PathOperation.union, body, head);
  p = _u(PathOperation.union, p, beak);
  p = _u(PathOperation.union, p, wing);
  p = _u(PathOperation.union, p, tail);
  return p;
}

Path _buildPlane() {
  // top-down airliner facing +x.
  final fuse = Path()
    ..addRRect(RRect.fromLTRBR(-1.05, -0.16, 1.15, 0.16, const Radius.circular(0.16)));
  final nose = Path()
    ..moveTo(1.05, -0.16)
    ..quadraticBezierTo(1.35, 0.0, 1.05, 0.16)
    ..close();
  final wings = Path()
    ..moveTo(0.16, -0.12)
    ..lineTo(-0.15, -0.95)
    ..lineTo(0.05, -0.95)
    ..lineTo(0.4, -0.1)
    ..lineTo(0.4, 0.1)
    ..lineTo(0.05, 0.95)
    ..lineTo(-0.15, 0.95)
    ..lineTo(0.16, 0.12)
    ..close();
  final tail = Path()
    ..moveTo(-0.78, -0.1)
    ..lineTo(-1.05, -0.5)
    ..lineTo(-0.88, -0.5)
    ..lineTo(-0.5, -0.08)
    ..lineTo(-0.5, 0.08)
    ..lineTo(-0.88, 0.5)
    ..lineTo(-1.05, 0.5)
    ..lineTo(-0.78, 0.1)
    ..close();
  var p = _u(PathOperation.union, fuse, nose);
  p = _u(PathOperation.union, p, wings);
  p = _u(PathOperation.union, p, tail);
  return p;
}

Path _buildRocket() {
  // rocket facing +x: nose cone at +x, fins at -x.
  final body = Path()
    ..addRRect(RRect.fromLTRBR(-0.7, -0.34, 0.7, 0.34, const Radius.circular(0.24)));
  final nose = Path()
    ..moveTo(0.6, -0.34)
    ..quadraticBezierTo(1.3, -0.05, 1.32, 0.0)
    ..quadraticBezierTo(1.3, 0.05, 0.6, 0.34)
    ..close();
  final finTop = Path()
    ..moveTo(-0.4, -0.3)
    ..lineTo(-0.95, -0.72)
    ..lineTo(-0.5, -0.28)
    ..close();
  final finBot = Path()
    ..moveTo(-0.4, 0.3)
    ..lineTo(-0.95, 0.72)
    ..lineTo(-0.5, 0.28)
    ..close();
  final tail = Path()
    ..addRRect(RRect.fromLTRBR(-0.86, -0.2, -0.66, 0.2, const Radius.circular(0.08)));
  var p = _u(PathOperation.union, body, nose);
  p = _u(PathOperation.union, p, finTop);
  p = _u(PathOperation.union, p, finBot);
  p = _u(PathOperation.union, p, tail);
  return p;
}

Path _buildFish() {
  final body = Path()
    ..addOval(Rect.fromCenter(center: const Offset(0.1, 0.0), width: 1.7, height: 0.86));
  final tail = Path()
    ..moveTo(-0.6, 0.0)
    ..lineTo(-1.25, -0.5)
    ..lineTo(-1.05, 0.0)
    ..lineTo(-1.25, 0.5)
    ..close();
  final topFin = Path()
    ..moveTo(-0.1, -0.4)
    ..quadraticBezierTo(0.1, -0.8, 0.45, -0.34)
    ..close();
  var p = _u(PathOperation.union, body, tail);
  p = _u(PathOperation.union, p, topFin);
  return p;
}

// ---------------------------------------------------------------------------
// Painting
// ---------------------------------------------------------------------------

/// Draws the object [type] centered at the origin, facing +x, at [radius] px.
/// The caller must have already applied translate/rotate/mirror.
///
/// [fill] = 0 draws just the glowing neon outline (the target frame);
/// [fill] in (0,1] draws the solid, detailed hero object; when [captured] is
/// true the body is flooded with the capture-green.
void paintFrameRushObject(
  Canvas canvas,
  int type,
  double radius, {
  required bool outlineOnly,
  Color outlineColor = const Color(0xFF39FF6A),
  bool captured = false,
  double captureFlash = 0.0,
}) {
  final unit = _silhouette(type);
  final m = (Matrix4.identity()..scaleByDouble(radius, radius, 1.0, 1.0)).storage;
  final sil = unit.transform(m);

  if (outlineOnly) {
    // Hand-drawn marker outline — a wobbly, glowing neon sketch of the object.
    final hand = _handDrawnSilhouette(type).transform(m);
    // Soft outer glow.
    canvas.drawPath(
      hand,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.22
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = outlineColor.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.16),
    );
    // Thick bright marker stroke.
    canvas.drawPath(
      hand,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.095
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = outlineColor,
    );
    // Glossy core highlight.
    canvas.drawPath(
      hand,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.03
        ..strokeJoin = StrokeJoin.round
        ..color = Color.lerp(outlineColor, Colors.white, 0.55)!,
    );
    return;
  }

  final theme = frameRushTheme(type);
  // Drop shadow.
  canvas.drawPath(
    sil.shift(Offset(0, radius * 0.12)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.1),
  );

  final bodyTop = captured ? const Color(0xFF6BFF9A) : theme.body;
  final bodyBot = captured ? const Color(0xFF17C24A) : theme.bodyDark;
  final bounds = sil.getBounds();
  canvas.drawPath(
    sil,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, bounds.top),
        Offset(0, bounds.bottom),
        [
          Color.lerp(bodyTop, Colors.white, 0.18)!,
          bodyTop,
          bodyBot,
        ],
        const [0.0, 0.45, 1.0],
      ),
  );

  _paintDetails(canvas, type, radius, theme, captured);

  // Crisp dark rim.
  canvas.drawPath(
    sil,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.035
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.black.withValues(alpha: 0.22),
  );

  if (captureFlash > 0) {
    canvas.drawPath(
      sil,
      Paint()..color = Colors.white.withValues(alpha: 0.6 * captureFlash),
    );
  }
}

void _paintDetails(
    Canvas canvas, int type, double r, FrTheme theme, bool captured) {
  final glass = Paint()
    ..color = (captured ? const Color(0xFF0B3A1E) : theme.detail)
        .withValues(alpha: 0.85);
  final tyre = Paint()..color = const Color(0xFF1B1E24);
  final hub = Paint()..color = const Color(0xFFC9CED6);

  switch (type) {
    case FrObject.car:
      // windows
      final win = Path()
        ..moveTo(-0.4 * r, -0.04 * r)
        ..lineTo(-0.26 * r, -0.42 * r)
        ..lineTo(0.24 * r, -0.42 * r)
        ..lineTo(0.42 * r, -0.04 * r)
        ..close();
      canvas.drawPath(win, glass);
      canvas.drawLine(Offset(0.0, -0.42 * r), Offset(0.0, -0.04 * r),
          Paint()..color = theme.body..strokeWidth = r * 0.04);
      for (final cx in [-0.6, 0.66]) {
        canvas.drawCircle(Offset(cx * r, 0.44 * r), 0.32 * r, tyre);
        canvas.drawCircle(Offset(cx * r, 0.44 * r), 0.13 * r, hub);
      }
      // headlight
      canvas.drawCircle(Offset(1.05 * r, 0.12 * r), 0.07 * r,
          Paint()..color = const Color(0xFFFFF3B0));
      break;
    case FrObject.bus:
      for (double wx = -0.86; wx <= 0.94; wx += 0.36) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(wx * r, -0.28 * r),
                  width: 0.26 * r,
                  height: 0.34 * r),
              Radius.circular(0.05 * r)),
          glass,
        );
      }
      for (final cx in [-0.66, 0.72]) {
        canvas.drawCircle(Offset(cx * r, 0.46 * r), 0.28 * r, tyre);
        canvas.drawCircle(Offset(cx * r, 0.46 * r), 0.11 * r, hub);
      }
      break;
    case FrObject.bird:
      canvas.drawCircle(Offset(0.82 * r, -0.14 * r), 0.08 * r,
          Paint()..color = Colors.white);
      canvas.drawCircle(Offset(0.85 * r, -0.14 * r), 0.04 * r,
          Paint()..color = const Color(0xFF10233F));
      // wing shading
      final wing = Path()
        ..moveTo(-0.1 * r, -0.05 * r)
        ..quadraticBezierTo(-0.05 * r, -0.88 * r, 0.38 * r, -0.72 * r)
        ..quadraticBezierTo(0.12 * r, -0.34 * r, 0.18 * r, -0.02 * r)
        ..close();
      canvas.drawPath(wing, Paint()..color = theme.bodyDark.withValues(alpha: 0.55));
      break;
    case FrObject.plane:
      for (double wx = -0.7; wx <= 0.6; wx += 0.28) {
        canvas.drawCircle(Offset(wx * r, 0.0), 0.05 * r, glass);
      }
      canvas.drawPath(
        Path()
          ..moveTo(1.05 * r, -0.12 * r)
          ..quadraticBezierTo(1.28 * r, 0.0, 1.05 * r, 0.12 * r)
          ..close(),
        Paint()..color = theme.detail.withValues(alpha: 0.8),
      );
      break;
    case FrObject.rocket:
      canvas.drawCircle(Offset(0.28 * r, 0.0), 0.18 * r,
          Paint()..color = const Color(0xFF7DD3FC));
      canvas.drawCircle(Offset(0.28 * r, 0.0), 0.18 * r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05
            ..color = theme.detail);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(-0.2 * r, 0.0), width: 0.16 * r, height: 0.5 * r),
            Radius.circular(0.05 * r)),
        Paint()..color = theme.detail.withValues(alpha: 0.5),
      );
      break;
    case FrObject.fish:
      canvas.drawCircle(Offset(0.68 * r, -0.08 * r), 0.09 * r,
          Paint()..color = Colors.white);
      canvas.drawCircle(Offset(0.71 * r, -0.08 * r), 0.045 * r,
          Paint()..color = const Color(0xFF10233F));
      // gill
      canvas.drawArc(
          Rect.fromCircle(center: Offset(0.45 * r, 0.0), radius: 0.28 * r),
          -0.9, 1.8, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05
            ..color = theme.bodyDark.withValues(alpha: 0.6));
      break;
  }
}

/// The natural half-size (in unit space) used to keep objects roughly the same
/// visual footprint. Widest objects (bus/fish) get slightly smaller radius.
double frameRushObjectScale(int type) {
  switch (type) {
    case FrObject.bus:
    case FrObject.fish:
      return 0.92;
    case FrObject.plane:
      return 0.86;
    default:
      return 1.0;
  }
}
