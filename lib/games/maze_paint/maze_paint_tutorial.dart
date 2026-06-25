import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

// ---------------------------------------------------------------------------
// Colors — identical to the in-game board painter.
// ---------------------------------------------------------------------------
const _floorLight = Color(0xFF5E6B80);
const _floorColor = Color(0xFF4F5B6E);
const _floorDark = Color(0xFF3E4A5A);
const _startTint = Color(0xFF22D3EE);
const _paintBase = Color(0xFF00D4AA);

const _kDemoSize = Size(220, 180);

// ---------------------------------------------------------------------------
// Tutorial steps.
//
// Step 0 — 1×5 strip. Ball rolls right. Shows "swipe → slide until edge".
// Step 1 — 3×3, wall at centre. Ball detours around it in 4 moves.
//   [ 0 1 2 ]
//   [ 3 W 5 ]    Route: right(0→2), down(2→8), left(8→6), up(6→0).
//   [ 6 7 8 ]    All 8 floor tiles painted.
// Step 2 — same 3×3, fully painted (win state) + pulsing checkmark.
// ---------------------------------------------------------------------------

List<GameHowToPlayStep> mazePaintSteps() => [
      GameHowToPlayStep(
        text: 'Swipe to roll the ball. It slides until hitting a wall or board edge, painting every tile along the way.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _Step0Painter(t),
          canvasSize: _kDemoSize,
        ),
      ),
      GameHowToPlayStep(
        text: 'Walls block the ball — plan your route to reach every tile. Change direction at each stop.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 5),
          painter: (t) => _Step1Painter(t),
          canvasSize: _kDemoSize,
        ),
      ),
      GameHowToPlayStep(
        text: 'Paint every floor tile to complete the level. Fewer moves means a better score!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _Step2Painter(t),
          canvasSize: _kDemoSize,
        ),
      ),
    ];

// ---------------------------------------------------------------------------
// Shared helpers — mini versions of the gameplay renderer.
// ---------------------------------------------------------------------------

final _paintLight = Color.lerp(_paintBase, Colors.white, 0.15)!;
final _paintDark = Color.lerp(_paintBase, Colors.black, 0.12)!;

bool _isFilled(int r, int c, int rows, int cols, Set<int> walls, bool Function(int) test) {
  if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
  final idx = r * cols + c;
  return !walls.contains(idx) && test(idx);
}

Path _contour(int rows, int cols, Set<int> walls, double cell, double ox, double oy,
    bool Function(int) test, double inset) {
  final vCols = cols + 1;
  int vid(int r, int c) => r * vCols + c;

  final edges = <int, int>{};
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (!_isFilled(r, c, rows, cols, walls, test)) continue;
      if (!_isFilled(r - 1, c, rows, cols, walls, test)) edges[vid(r, c)] = vid(r, c + 1);
      if (!_isFilled(r, c + 1, rows, cols, walls, test)) edges[vid(r, c + 1)] = vid(r + 1, c + 1);
      if (!_isFilled(r + 1, c, rows, cols, walls, test)) edges[vid(r + 1, c + 1)] = vid(r + 1, c);
      if (!_isFilled(r, c - 1, rows, cols, walls, test)) edges[vid(r + 1, c)] = vid(r, c);
    }
  }

  final rad = cell * 0.22;
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
      final tl = _isFilled(vr - 1, vc - 1, rows, cols, walls, test);
      final tr = _isFilled(vr - 1, vc, rows, cols, walls, test);
      final bl = _isFilled(vr, vc - 1, rows, cols, walls, test);
      final br = _isFilled(vr, vc, rows, cols, walls, test);
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

void _drawFloor(Canvas canvas, int rows, int cols, Set<int> walls,
    double cell, double ox, double oy, double inset) {
  final floorPath = _contour(rows, cols, walls, cell, ox, oy, (_) => true, inset);
  final fb = floorPath.getBounds();

  canvas.drawPath(
    floorPath.shift(Offset(0, cell * 0.10)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.10),
  );

  canvas.drawPath(
    floorPath,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(fb.left, fb.top), Offset(fb.left, fb.bottom),
        [_floorLight, _floorColor, _floorDark], [0.0, 0.4, 1.0],
      ),
  );

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
}

void _drawPainted(Canvas canvas, int rows, int cols, Set<int> walls,
    Set<int> painted, double cell, double ox, double oy, double inset) {
  if (painted.isEmpty) return;
  final paintPath = _contour(rows, cols, walls, cell, ox, oy, painted.contains, inset);
  final pb = paintPath.getBounds();

  canvas.drawPath(
    paintPath,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(pb.left, pb.top), Offset(pb.left, pb.bottom),
        [_paintLight, _paintBase, _paintDark], [0.0, 0.4, 1.0],
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
}

void _drawStartMarker(Canvas canvas, int start, int cols, double cell,
    double ox, double oy, double inset) {
  final sr = start ~/ cols, sc = start % cols;
  final rect = Rect.fromLTWH(
      ox + sc * cell + inset, oy + sr * cell + inset, cell - 2 * inset, cell - 2 * inset);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, cell * 0.05)
      ..color = _startTint.withValues(alpha: 0.85),
  );
}

void _drawBall(Canvas canvas, Offset c, double cell) {
  final radius = cell * 0.34;

  canvas.drawOval(
    Rect.fromCenter(
        center: c.translate(0.5, radius * 0.35),
        width: radius * 1.6,
        height: radius * 0.45),
    Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..color = Colors.black.withValues(alpha: 0.18),
  );

  canvas.drawCircle(
    c, radius,
    Paint()
      ..shader = ui.Gradient.radial(
        c.translate(-radius * 0.20, -radius * 0.25), radius * 2.0,
        const [Color(0xFFFFFFFF), Color(0xFFF0F0F0), Color(0xFFD0D0D0), Color(0xFFAAAAAA)],
        const [0.0, 0.3, 0.65, 1.0],
      ),
  );

  canvas.drawCircle(
    c, radius,
    Paint()
      ..shader = ui.Gradient.radial(
        c.translate(-radius * 0.30, -radius * 0.35), radius * 0.75,
        [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.0)],
      ),
  );

  canvas.drawCircle(
      c.translate(-radius * 0.22, -radius * 0.22), radius * 0.12,
      Paint()..color = Colors.white);
  canvas.drawCircle(
      c.translate(-radius * 0.08, -radius * 0.34), radius * 0.04,
      Paint()..color = Colors.white.withValues(alpha: 0.7));
}

Offset _cellCenter(int idx, int cols, double cell, double ox, double oy) =>
    Offset(ox + (idx % cols) * cell + cell / 2, oy + (idx ~/ cols) * cell + cell / 2);

({Offset pos, Set<int> painted}) _animateRoute(
    double t, List<int> route, int cols, double cell, double ox, double oy) {
  final segments = route.length - 1;
  if (segments <= 0) {
    return (pos: _cellCenter(route[0], cols, cell, ox, oy), painted: {route[0]});
  }
  final raw = t * segments;
  final idx = raw.floor().clamp(0, segments - 1);
  final frac = raw - idx;
  final from = _cellCenter(route[idx], cols, cell, ox, oy);
  final to = _cellCenter(route[(idx + 1).clamp(0, route.length - 1)], cols, cell, ox, oy);
  final pos = Offset(from.dx + (to.dx - from.dx) * frac, from.dy + (to.dy - from.dy) * frac);
  final painted = route.take(idx + 2).toSet();
  return (pos: pos, painted: painted);
}

void _drawSwipeArrow(Canvas canvas, Offset from, Offset to, double cell) {
  final paint = Paint()
    ..color = Colors.white.withValues(alpha: 0.55)
    ..strokeWidth = math.max(1.5, cell * 0.06)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(from, to, paint);
  final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
  final aLen = cell * 0.18;
  final a1 = to + Offset(math.cos(angle + 2.6) * aLen, math.sin(angle + 2.6) * aLen);
  final a2 = to + Offset(math.cos(angle - 2.6) * aLen, math.sin(angle - 2.6) * aLen);
  canvas.drawPath(
    Path()..moveTo(a1.dx, a1.dy)..lineTo(to.dx, to.dy)..lineTo(a2.dx, a2.dy),
    paint,
  );
}

// ---------------------------------------------------------------------------
// Step 0: 1×5 strip — ball rolls right painting every tile.
// ---------------------------------------------------------------------------
class _Step0Painter extends CustomPainter {
  final double t;
  _Step0Painter(this.t);

  static const _rows = 1, _cols = 5;
  static const _walls = <int>{};
  static const _start = 0;
  static const _route = [0, 1, 2, 3, 4];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / _cols, size.height / _rows) * 0.75;
    final ox = (size.width - _cols * cell) / 2;
    final oy = (size.height - _rows * cell) / 2;
    final inset = cell * 0.08;

    _drawFloor(canvas, _rows, _cols, _walls, cell, ox, oy, inset);
    _drawStartMarker(canvas, _start, _cols, cell, ox, oy, inset);

    final mt = (t / 0.7).clamp(0.0, 1.0);
    final anim = _animateRoute(mt, _route, _cols, cell, ox, oy);
    _drawPainted(canvas, _rows, _cols, _walls, anim.painted, cell, ox, oy, inset);

    if (t < 0.4) {
      final arrowFrom = _cellCenter(0, _cols, cell, ox, oy).translate(0, cell * 0.55);
      final arrowTo = arrowFrom.translate(cell * 2.5, 0);
      _drawSwipeArrow(canvas, arrowFrom, arrowTo, cell);
    }

    _drawBall(canvas, anim.pos, cell);
  }

  @override
  bool shouldRepaint(_Step0Painter old) => true;
}

// ---------------------------------------------------------------------------
// Step 1: 3×3 with wall at centre — ball navigates around it.
//  [ 0  1  2 ]
//  [ 3  W  5 ]
//  [ 6  7  8 ]
// Route: right(0→2), down(2→8), left(8→6), up(6→0). 4 moves, all 8 tiles.
// ---------------------------------------------------------------------------
class _Step1Painter extends CustomPainter {
  final double t;
  _Step1Painter(this.t);

  static const _rows = 3, _cols = 3;
  static const _walls = <int>{4};
  static const _start = 0;
  static const _route = [0, 1, 2, 5, 8, 7, 6, 3];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / _cols, size.height / _rows) * 0.72;
    final ox = (size.width - _cols * cell) / 2;
    final oy = (size.height - _rows * cell) / 2;
    final inset = cell * 0.08;

    _drawFloor(canvas, _rows, _cols, _walls, cell, ox, oy, inset);
    _drawStartMarker(canvas, _start, _cols, cell, ox, oy, inset);

    final mt = (t / 0.85).clamp(0.0, 1.0);
    final anim = _animateRoute(mt, _route, _cols, cell, ox, oy);
    _drawPainted(canvas, _rows, _cols, _walls, anim.painted, cell, ox, oy, inset);
    _drawBall(canvas, anim.pos, cell);
  }

  @override
  bool shouldRepaint(_Step1Painter old) => true;
}

// ---------------------------------------------------------------------------
// Step 2: Win state — same 3×3 board, fully painted, pulsing checkmark.
// ---------------------------------------------------------------------------
class _Step2Painter extends CustomPainter {
  final double t;
  _Step2Painter(this.t);

  static const _rows = 3, _cols = 3;
  static const _walls = <int>{4};
  static const _start = 0;
  static const _allFloor = <int>{0, 1, 2, 3, 5, 6, 7, 8};

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / _cols, size.height / _rows) * 0.72;
    final ox = (size.width - _cols * cell) / 2;
    final oy = (size.height - _rows * cell) / 2;
    final inset = cell * 0.08;

    _drawFloor(canvas, _rows, _cols, _walls, cell, ox, oy, inset);
    _drawPainted(canvas, _rows, _cols, _walls, _allFloor, cell, ox, oy, inset);
    _drawStartMarker(canvas, _start, _cols, cell, ox, oy, inset);

    _drawBall(canvas, _cellCenter(3, _cols, cell, ox, oy), cell);

    final pulse = 1.0 + math.sin(t * math.pi * 2) * 0.06;
    final bc = Offset(ox + _cols * cell - cell * 0.15, oy + cell * 0.15);
    final badgeR = cell * 0.32 * pulse;
    canvas.drawCircle(bc, badgeR + 2, Paint()..color = Colors.black.withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(bc, badgeR, Paint()..color = const Color(0xFF22C55E));
    final s = badgeR * 0.55;
    final check = Path()
      ..moveTo(bc.dx - s * 0.6, bc.dy)
      ..lineTo(bc.dx - s * 0.1, bc.dy + s * 0.5)
      ..lineTo(bc.dx + s * 0.7, bc.dy - s * 0.5);
    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..strokeWidth = math.max(2.0, s * 0.28)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Step2Painter old) => true;
}
