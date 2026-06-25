import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildMazePaintLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Maze Paint',
      bg: const [Color(0xFF4A0028), Color(0xFF111827)],
      accent: const Color(0xFFFF1493),
      art: _mazePaintArt,
    );

// Mini 4×4 maze layout for the logo.
// Floor cells form an irregular connected shape (matching gameplay style).
const _n = 4;
const _walls = <int>{3, 7, 11}; // right column removed for irregular shape
const _painted = <int>{0, 1, 2, 4, 5, 6, 8, 9}; // partial paint trail
const _ballIdx = 9; // ball sits at bottom of painted region
const _startIdx = 0;

bool _isLogoFloor(int r, int c) {
  if (r < 0 || r >= _n || c < 0 || c >= _n) return false;
  return !_walls.contains(r * _n + c);
}

bool _isLogoFilled(int r, int c, bool Function(int) test) {
  if (!_isLogoFloor(r, c)) return false;
  return test(r * _n + c);
}

Path _logoContour(double cell, double ox, double oy, bool Function(int) test, double inset) {
  final vCols = _n + 1;
  int vid(int r, int c) => r * vCols + c;

  final edges = <int, int>{};
  for (int r = 0; r < _n; r++) {
    for (int c = 0; c < _n; c++) {
      if (!_isLogoFilled(r, c, test)) continue;
      if (!_isLogoFilled(r - 1, c, test)) edges[vid(r, c)] = vid(r, c + 1);
      if (!_isLogoFilled(r, c + 1, test)) edges[vid(r, c + 1)] = vid(r + 1, c + 1);
      if (!_isLogoFilled(r + 1, c, test)) edges[vid(r + 1, c + 1)] = vid(r + 1, c);
      if (!_isLogoFilled(r, c - 1, test)) edges[vid(r + 1, c)] = vid(r, c);
    }
  }

  final rad = cell * 0.24;
  final path = Path();
  final visited = <int>{};

  while (visited.length < edges.length) {
    int? startV;
    for (final k in edges.keys) {
      if (!visited.contains(k)) { startV = k; break; }
    }
    if (startV == null) break;

    final loop = <int>[];
    int cur = startV;
    do {
      loop.add(cur);
      visited.add(cur);
      cur = edges[cur]!;
    } while (cur != startV);
    if (loop.length < 3) continue;

    final n = loop.length;

    Offset insetVtx(int v) {
      final vr = v ~/ vCols, vc = v % vCols;
      double x = ox + vc * cell, y = oy + vr * cell;
      final tl = _isLogoFilled(vr - 1, vc - 1, test);
      final tr = _isLogoFilled(vr - 1, vc, test);
      final bl = _isLogoFilled(vr, vc - 1, test);
      final br = _isLogoFilled(vr, vc, test);
      final cnt = (tl ? 1 : 0) + (tr ? 1 : 0) + (bl ? 1 : 0) + (br ? 1 : 0);
      if (cnt == 1) {
        if (br) { x += inset; y += inset; }
        else if (bl) { x -= inset; y += inset; }
        else if (tr) { x += inset; y -= inset; }
        else { x -= inset; y -= inset; }
      } else if (cnt == 3) {
        if (!br) { x -= inset; y -= inset; }
        else if (!bl) { x += inset; y -= inset; }
        else if (!tr) { x -= inset; y += inset; }
        else { x += inset; y += inset; }
      } else {
        if (!tl && !tr) { y += inset; }
        else if (!bl && !br) { y -= inset; }
        else if (!tl && !bl) { x += inset; }
        else if (!tr && !br) { x -= inset; }
      }
      return Offset(x, y);
    }

    for (int i = 0; i < n; i++) {
      final prev = insetVtx(loop[(i - 1 + n) % n]);
      final curr = insetVtx(loop[i]);
      final next = insetVtx(loop[(i + 1) % n]);
      final d1 = Offset(curr.dx - prev.dx, curr.dy - prev.dy);
      final d2 = Offset(next.dx - curr.dx, next.dy - curr.dy);
      final len1 = d1.distance, len2 = d2.distance;
      final t1 = (len1 > 0) ? math.min(rad, len1 / 2) / len1 : 0.0;
      final t2 = (len2 > 0) ? math.min(rad, len2 / 2) / len2 : 0.0;
      final arcStart = Offset(curr.dx - d1.dx * t1, curr.dy - d1.dy * t1);
      final arcEnd = Offset(curr.dx + d2.dx * t2, curr.dy + d2.dy * t2);
      if (i == 0) {
        path.moveTo(arcStart.dx, arcStart.dy);
      } else {
        path.lineTo(arcStart.dx, arcStart.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, arcEnd.dx, arcEnd.dy);
    }
    path.close();
  }
  return path;
}

void _mazePaintArt(Canvas canvas, Rect zone) {
  final cell = zone.width / _n;
  final ox = zone.left, oy = zone.top;
  final inset = cell * 0.08;

  const floorLight = Color(0xFF5E6B80);
  const floorColor = Color(0xFF4F5B6E);
  const floorDark = Color(0xFF3E4A5A);
  const paintBase = Color(0xFFFF1493);
  final paintLight = Color.lerp(paintBase, Colors.white, 0.15)!;
  final paintDark = Color.lerp(paintBase, Colors.black, 0.12)!;

  // Floor shape
  final floorPath = _logoContour(cell, ox, oy, (_) => true, inset);
  final fb = floorPath.getBounds();

  // Shadow
  canvas.drawPath(
    floorPath.shift(Offset(0, cell * 0.10)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.10),
  );

  // Floor gradient
  canvas.drawPath(
    floorPath,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(fb.left, fb.top), Offset(fb.left, fb.bottom),
        [floorLight, floorColor, floorDark], [0.0, 0.4, 1.0],
      ),
  );

  // Floor lighting overlay
  canvas.save();
  canvas.clipPath(floorPath);
  canvas.drawRect(
    fb,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(fb.left, fb.top), Offset(fb.left, fb.bottom),
        [Colors.white.withValues(alpha: 0.08), Colors.transparent, Colors.black.withValues(alpha: 0.10)],
        [0.0, 0.45, 1.0],
      ),
  );
  canvas.restore();

  // Painted region
  final paintPath = _logoContour(cell, ox, oy, _painted.contains, inset);
  final pb = paintPath.getBounds();

  canvas.drawPath(
    paintPath,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(pb.left, pb.top), Offset(pb.left, pb.bottom),
        [paintLight, paintBase, paintDark], [0.0, 0.4, 1.0],
      ),
  );

  canvas.save();
  canvas.clipPath(paintPath);
  canvas.drawRect(
    pb,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(pb.left, pb.top), Offset(pb.left, pb.bottom),
        [Colors.white.withValues(alpha: 0.12), Colors.transparent, Colors.black.withValues(alpha: 0.08)],
        [0.0, 0.45, 1.0],
      ),
  );
  canvas.restore();

  // Start marker
  final sr = _startIdx ~/ _n, sc = _startIdx % _n;
  final startRect = Rect.fromLTWH(ox + sc * cell + inset, oy + sr * cell + inset, cell - 2 * inset, cell - 2 * inset);
  canvas.drawRRect(
    RRect.fromRectAndRadius(startRect, Radius.circular(cell * 0.18)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, cell * 0.05)
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.85),
  );

  // Ball
  final bc = _ballIdx % _n, br2 = _ballIdx ~/ _n;
  final ballC = Offset(ox + bc * cell + cell / 2, oy + br2 * cell + cell / 2);
  final radius = cell * 0.34;

  canvas.drawOval(
    Rect.fromCenter(center: ballC.translate(0.5, radius * 0.35), width: radius * 1.6, height: radius * 0.4),
    Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..color = Colors.black.withValues(alpha: 0.18),
  );

  canvas.drawCircle(
    ballC, radius,
    Paint()
      ..shader = ui.Gradient.radial(
        ballC.translate(-radius * 0.20, -radius * 0.25), radius * 2.0,
        const [Color(0xFFFFFFFF), Color(0xFFF0F0F0), Color(0xFFD0D0D0), Color(0xFFAAAAAA)],
        const [0.0, 0.3, 0.65, 1.0],
      ),
  );

  canvas.drawCircle(
    ballC, radius,
    Paint()
      ..shader = ui.Gradient.radial(
        ballC.translate(-radius * 0.30, -radius * 0.35), radius * 0.75,
        [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.0)],
      ),
  );

  canvas.drawCircle(ballC.translate(-radius * 0.22, -radius * 0.22), radius * 0.12, Paint()..color = Colors.white);
  canvas.drawCircle(ballC.translate(-radius * 0.08, -radius * 0.34), radius * 0.04, Paint()..color = Colors.white.withValues(alpha: 0.7));
}
