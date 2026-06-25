import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

const _kBoard = Color(0xFF5C3D2E);
const _kBorder = Color(0xFFA67C5B);
const _kBlockA = Color(0xFFEEC060);
const _kBlockB = Color(0xFFE8A838);
const _kTargetA = Color(0xFFF07070);
const _kTargetB = Color(0xFFE74C3C);
const _kGate = Color(0xFF27AE60);

const _kDemoSize = Size(220, 180);

List<GameHowToPlayStep> blockEscapeSteps() => [
      GameHowToPlayStep(
        text: 'Drag blocks along their direction to clear a path. Vertical blocks slide up/down, horizontal blocks slide left/right.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _Step0Painter(t),
          canvasSize: _kDemoSize,
        ),
      ),
      GameHowToPlayStep(
        text: 'Guide the red block to the green exit gate on the right. Move other blocks out of the way!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _Step1Painter(t),
          canvasSize: _kDemoSize,
        ),
      ),
      GameHowToPlayStep(
        text: 'Complete each level to unlock the next. Difficulty increases as you progress!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _Step2Painter(t),
          canvasSize: _kDemoSize,
        ),
      ),
    ];

class _BoardHelper {
  final Canvas canvas;
  final double ox, oy, cell, gap, r;
  final double boardW, boardH;

  _BoardHelper(this.canvas, Size size) :
    cell = math.min(size.width / 6.5, size.height / 6) * 0.95,
    ox = 0, oy = 0, gap = 0, r = 0, boardW = 0, boardH = 0 {
    throw UnimplementedError();
  }

  _BoardHelper._(this.canvas, this.ox, this.oy, this.cell, this.gap, this.r, this.boardW, this.boardH);

  factory _BoardHelper.create(Canvas canvas, Size size) {
    final cell = math.min(size.width / 6.5, size.height / 6) * 0.95;
    final boardW = cell * 6;
    final boardH = cell * 6;
    final ox = (size.width - boardW - cell * 0.4) / 2;
    final oy = (size.height - boardH) / 2;
    final gap = cell * 0.05;
    final r = cell * 0.13;
    return _BoardHelper._(canvas, ox, oy, cell, gap, r, boardW, boardH);
  }

  void drawBoard() {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ox, oy, boardW, boardH), Radius.circular(r * 2)),
      Paint()..color = _kBoard,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(ox, oy, boardW, boardH), Radius.circular(r * 2)),
      Paint()..color = _kBorder..style = PaintingStyle.stroke..strokeWidth = cell * 0.05,
    );
  }

  void drawGate(int exitRow) {
    final gx = ox + boardW;
    final gy = oy + exitRow * cell + gap;
    final gh = cell - gap * 2;
    final gw = cell * 0.35;
    canvas.drawRect(Rect.fromLTWH(gx - cell * 0.05, gy, cell * 0.1, gh), Paint()..color = _kBoard);
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(gx - 1, gy, gx + gw, gy + gh,
        topRight: Radius.circular(r * 0.5), bottomRight: Radius.circular(r * 0.5)),
      Paint()..color = _kGate,
    );
    final ax = gx + gw * 0.6;
    final ay = gy + gh / 2;
    final s = gh * 0.18;
    canvas.drawPath(
      Path()..moveTo(ax - s * 0.4, ay - s)..lineTo(ax + s * 0.4, ay)..lineTo(ax - s * 0.4, ay + s),
      Paint()..color = Colors.white.withValues(alpha: 0.85)..strokeWidth = cell * 0.05..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round,
    );
  }

  void block(double col, double row, double w, double h, Color c1, Color c2, {bool chevron = false}) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(ox + col * cell + gap, oy + row * cell + gap, w * cell - gap * 2, h * cell - gap * 2),
      Radius.circular(r),
    );
    canvas.drawRRect(rect, Paint()..shader = ui.Gradient.linear(rect.outerRect.topLeft, rect.outerRect.bottomRight, [c1, c2]));
    canvas.drawRRect(rect, Paint()..color = c2.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = cell * 0.03);
    if (chevron) {
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final s = rect.height * 0.22;
      canvas.drawPath(
        Path()..moveTo(cx - s * 0.3, cy - s)..lineTo(cx + s * 0.5, cy)..lineTo(cx - s * 0.3, cy + s),
        Paint()..color = Colors.white.withValues(alpha: 0.85)..strokeWidth = cell * 0.06..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void dragArrow(double fromX, double fromY, double toX, double toY) {
    final fx = ox + fromX * cell;
    final fy = oy + fromY * cell;
    final tx = ox + toX * cell;
    final ty = oy + toY * cell;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.50)
      ..strokeWidth = cell * 0.06
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(fx, fy), Offset(tx, ty), paint);
    final dx = tx - fx;
    final dy = ty - fy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final ux = dx / len;
    final uy = dy / len;
    final as1 = cell * 0.15;
    canvas.drawPath(
      Path()
        ..moveTo(tx - ux * as1 + uy * as1 * 0.5, ty - uy * as1 - ux * as1 * 0.5)
        ..lineTo(tx, ty)
        ..lineTo(tx - ux * as1 - uy * as1 * 0.5, ty - uy * as1 + ux * as1 * 0.5),
      paint,
    );
  }
}

void _drawStaticBlocks(_BoardHelper b) {
  b.block(1, 0, 2, 1, _kBlockA, _kBlockB);
  b.block(4, 0, 1, 2, _kBlockA, _kBlockB);
  b.block(0, 4, 2, 1, _kBlockA, _kBlockB);
  b.block(4, 3, 1, 3, _kBlockA, _kBlockB);
}

class _Step0Painter extends CustomPainter {
  final double t;
  _Step0Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final b = _BoardHelper.create(canvas, size);
    b.drawBoard();
    b.drawGate(2);
    _drawStaticBlocks(b);

    b.block(0, 2, 2, 1, _kTargetA, _kTargetB, chevron: true);

    final slide = t < 0.3 ? 0.0 : t < 0.7 ? (t - 0.3) / 0.4 * 2.0 : 2.0;
    b.block(2, 1 + slide, 1, 2, _kBlockA, _kBlockB);

    if (t >= 0.15 && t <= 0.85) {
      b.dragArrow(2.5, 2.2, 2.5, 3.8);
    }
  }

  @override
  bool shouldRepaint(_Step0Painter old) => true;
}

class _Step1Painter extends CustomPainter {
  final double t;
  _Step1Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final b = _BoardHelper.create(canvas, size);
    b.drawBoard();
    b.drawGate(2);
    _drawStaticBlocks(b);

    b.block(2, 3, 1, 2, _kBlockA, _kBlockB);

    final slide = t < 0.2 ? 0.0 : t < 0.7 ? (t - 0.2) / 0.5 * 4.0 : 4.0;
    b.block(0 + slide, 2, 2, 1, _kTargetA, _kTargetB, chevron: true);

    if (t >= 0.1 && t <= 0.85) {
      b.dragArrow(1.0, 2.5, 4.5, 2.5);
    }
  }

  @override
  bool shouldRepaint(_Step1Painter old) => true;
}

class _Step2Painter extends CustomPainter {
  final double t;
  _Step2Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final b = _BoardHelper.create(canvas, size);
    b.drawBoard();
    b.drawGate(2);
    _drawStaticBlocks(b);

    b.block(2, 3, 1, 2, _kBlockA, _kBlockB);
    b.block(4, 2, 2, 1, _kTargetA, _kTargetB, chevron: true);

    final pulse = 0.9 + 0.1 * math.sin(t * math.pi * 2);
    final bc = Offset(b.ox + b.boardW / 2, b.oy + b.boardH / 2);
    canvas.drawCircle(bc, 16 * pulse, Paint()..color = const Color(0xFF22C55E));
    final check = Path()
      ..moveTo(bc.dx - 6, bc.dy)
      ..lineTo(bc.dx - 2, bc.dy + 5)
      ..lineTo(bc.dx + 7, bc.dy - 5);
    canvas.drawPath(check, Paint()..color = Colors.white..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    final tp = TextPainter(
      text: TextSpan(text: 'Level Complete!', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(bc.dx - tp.width / 2, bc.dy + 22));
  }

  @override
  bool shouldRepaint(_Step2Painter old) => true;
}
