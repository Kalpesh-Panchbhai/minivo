import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

const _kBlue = Color(0xFF339AF0);
const _kGreen = Color(0xFF51CF66);
const _kOrange = Color(0xFFFF922B);
const _kPink = Color(0xFFF06595);
const _kRed = Color(0xFFEF4444);
const _kCheckGreen = Color(0xFF22C55E);
const _kGridLine = Color(0xFFCBD5E1);
const _kCellBg = Color(0xFFF1F5F9);
const _kTextDark = Color(0xFF334155);

const _kCanvasSize = Size(200, 180);

const _clues = [
  [2, 0, 4, 0],
  [0, 0, 0, 0],
  [0, 3, 0, 0],
  [0, 0, 0, 2],
];

List<GameHowToPlayStep> patchesTutorialSteps() => [
      GameHowToPlayStep(
        text:
            'Each number tells you the area of its patch.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 5000),
          painter: (t) => _Step1Painter(t),
          canvasSize: _kCanvasSize,
        ),
      ),
      GameHowToPlayStep(
        text:
            'Drag across cells to create a rectangular patch.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _Step2Painter(t),
          canvasSize: _kCanvasSize,
        ),
      ),
      GameHowToPlayStep(
        text:
            'Every cell must be covered. No gaps, no overlaps!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 6000),
          painter: (t) => _Step3Painter(t),
          canvasSize: _kCanvasSize,
        ),
      ),
      GameHowToPlayStep(
        text:
            'Each patch must contain exactly one clue number.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 5000),
          painter: (t) => _Step4Painter(t),
          canvasSize: _kCanvasSize,
        ),
      ),
    ];

const _gridN = 4;
const _cellS = 32.0;
const _gap = 2.0;

double _gridTotalW() => _gridN * _cellS + (_gridN - 1) * _gap;
double _gridTotalH() => _gridN * _cellS + (_gridN - 1) * _gap;

Offset _gridOrigin(Size size) {
  final tw = _gridTotalW();
  final th = _gridTotalH();
  return Offset((size.width - tw) / 2, (size.height - th) / 2);
}

Rect _cellRect(Offset origin, int r, int c) => Rect.fromLTWH(
      origin.dx + c * (_cellS + _gap),
      origin.dy + r * (_cellS + _gap),
      _cellS,
      _cellS,
    );

void _drawGrid(Canvas canvas, Size size, {Offset? origin}) {
  final o = origin ?? _gridOrigin(size);
  for (int r = 0; r < _gridN; r++) {
    for (int c = 0; c < _gridN; c++) {
      final rect = _cellRect(o, r, c);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rr, Paint()..color = _kCellBg);
      canvas.drawRRect(
          rr,
          Paint()
            ..color = _kGridLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
    }
  }
}

void _drawClueNumber(Canvas canvas, Offset center, int number,
    {Color color = _kTextDark, double fontSize = 13}) {
  final tp = TextPainter(
    text: TextSpan(
      text: '$number',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
      canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
}

void _drawClues(Canvas canvas, Offset origin) {
  for (int r = 0; r < _gridN; r++) {
    for (int c = 0; c < _gridN; c++) {
      final v = _clues[r][c];
      if (v > 0) {
        _drawClueNumber(canvas, _cellRect(origin, r, c).center, v);
      }
    }
  }
}

void _drawPatch(Canvas canvas, Offset origin, int r1, int c1, int r2, int c2,
    Color color,
    {double opacity = 1.0, double scale = 1.0}) {
  final topLeft = _cellRect(origin, r1, c1);
  final bottomRight = _cellRect(origin, r2, c2);
  final fullRect = Rect.fromLTRB(
      topLeft.left, topLeft.top, bottomRight.right, bottomRight.bottom);

  if (scale < 1.0) {
    final ctr = fullRect.center;
    final scaledW = fullRect.width * scale;
    final scaledH = fullRect.height * scale;
    final scaledRect =
        Rect.fromCenter(center: ctr, width: scaledW, height: scaledH);
    final rr = RRect.fromRectAndRadius(scaledRect, const Radius.circular(6));
    canvas.drawRRect(
        rr, Paint()..color = color.withValues(alpha: 0.20 * opacity));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = color.withValues(alpha: 0.85 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
  } else {
    final rr = RRect.fromRectAndRadius(fullRect, const Radius.circular(6));
    canvas.drawRRect(
        rr, Paint()..color = color.withValues(alpha: 0.20 * opacity));
    canvas.drawRRect(
        rr,
        Paint()
          ..color = color.withValues(alpha: 0.85 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
  }
}

void _drawHighlightRing(Canvas canvas, Rect rect, Color color, double pulse) {
  final rr = RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(6));
  canvas.drawRRect(
      rr,
      Paint()
        ..color = color.withValues(alpha: 0.3 + 0.2 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);
}

void _drawLabel(Canvas canvas, Size size, String text, Color color,
    {double y = 0.92, double fontSize = 10}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        letterSpacing: 0.6,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas,
      Offset(size.width / 2 - tp.width / 2, size.height * y - tp.height / 2));
}

void _drawCheckmark(Canvas canvas, Offset center, double radius,
    {double alpha = 1.0}) {
  canvas.drawCircle(
      center, radius, Paint()..color = _kCheckGreen.withValues(alpha: alpha));
  final check = Path()
    ..moveTo(center.dx - radius * 0.4, center.dy)
    ..lineTo(center.dx - radius * 0.1, center.dy + radius * 0.35)
    ..lineTo(center.dx + radius * 0.45, center.dy - radius * 0.3);
  canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke);
}

void _drawFingerIcon(Canvas canvas, Offset pos, double alpha) {
  canvas.drawCircle(
      pos.translate(0, 1), 7, Paint()..color = Colors.black.withValues(alpha: 0.10 * alpha));
  canvas.drawCircle(
      pos, 7, Paint()..color = Colors.white.withValues(alpha: 0.9 * alpha));
  canvas.drawCircle(
      pos,
      7,
      Paint()
        ..color = _kBlue.withValues(alpha: 0.7 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
  final dotR = 2.5;
  canvas.drawCircle(
      pos.translate(0, -1), dotR, Paint()..color = _kBlue.withValues(alpha: 0.5 * alpha));
}

class _Step1Painter extends CustomPainter {
  final double t;
  const _Step1Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = _gridOrigin(size);
    _drawGrid(canvas, size, origin: origin);
    _drawClues(canvas, origin);

    final pulse = math.sin(t * math.pi * 4).abs();

    if (t < 0.45) {
      final sub = t / 0.45;
      final clueRect = _cellRect(origin, 0, 0);
      _drawHighlightRing(canvas, clueRect, _kBlue, pulse);

      if (sub > 0.35) {
        final patchT = ((sub - 0.35) / 0.65).clamp(0.0, 1.0);
        final eased = Curves.elasticOut.transform(patchT.clamp(0.0, 1.0));
        _drawPatch(canvas, origin, 0, 0, 0, 1, _kBlue, scale: eased);

        _drawClueNumber(canvas, _cellRect(origin, 0, 0).center, 2,
            color: _kBlue);
      }

      _drawLabel(canvas, size, '"2" = PATCH OF 2 CELLS', _kBlue);
    } else if (t < 0.90) {
      _drawPatch(canvas, origin, 0, 0, 0, 1, _kBlue);
      _drawClueNumber(canvas, _cellRect(origin, 0, 0).center, 2,
          color: _kBlue);

      final sub = (t - 0.45) / 0.45;
      final clueRect = _cellRect(origin, 0, 2);
      _drawHighlightRing(canvas, clueRect, _kOrange, pulse);

      if (sub > 0.35) {
        final patchT = ((sub - 0.35) / 0.65).clamp(0.0, 1.0);
        final eased = Curves.elasticOut.transform(patchT.clamp(0.0, 1.0));
        _drawPatch(canvas, origin, 0, 2, 1, 3, _kOrange, scale: eased);

        _drawClueNumber(canvas, _cellRect(origin, 0, 2).center, 4,
            color: _kOrange);
      }

      _drawLabel(canvas, size, '"4" = PATCH OF 4 CELLS', _kOrange);
    } else {
      _drawPatch(canvas, origin, 0, 0, 0, 1, _kBlue);
      _drawClueNumber(canvas, _cellRect(origin, 0, 0).center, 2,
          color: _kBlue);
      _drawPatch(canvas, origin, 0, 2, 1, 3, _kOrange);
      _drawClueNumber(canvas, _cellRect(origin, 0, 2).center, 4,
          color: _kOrange);

      _drawLabel(canvas, size, 'AREA = CLUE NUMBER', _kCheckGreen);
    }
  }

  @override
  bool shouldRepaint(covariant _Step1Painter old) => old.t != t;
}

class _Step2Painter extends CustomPainter {
  final double t;
  const _Step2Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = _gridOrigin(size);
    _drawGrid(canvas, size, origin: origin);
    _drawClues(canvas, origin);

    if (t < 0.15) {
      final startRect = _cellRect(origin, 2, 1);
      final fingerPos = startRect.center.translate(0, 14 * (1 - t / 0.15));
      _drawFingerIcon(canvas, fingerPos, (t / 0.15).clamp(0.0, 1.0));
      _drawLabel(canvas, size, 'START DRAGGING', _kBlue);
    } else if (t < 0.55) {
      final dragT = ((t - 0.15) / 0.40).clamp(0.0, 1.0);
      final startRect = _cellRect(origin, 2, 1);
      final endRect = _cellRect(origin, 2, 3);

      final startX = startRect.center.dx;
      final endX = endRect.center.dx;
      final currentX = startX + (endX - startX) * Curves.easeInOut.transform(dragT);
      final fingerY = startRect.center.dy;

      final cellsCovered = (dragT * 3).ceil().clamp(1, 3);
      for (int i = 0; i < cellsCovered; i++) {
        final cIdx = 1 + i;
        if (cIdx < _gridN) {
          final rect = _cellRect(origin, 2, cIdx);
          final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
          canvas.drawRRect(
              rr, Paint()..color = _kGreen.withValues(alpha: 0.25));
          canvas.drawRRect(
              rr,
              Paint()
                ..color = _kGreen.withValues(alpha: 0.5)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0);
        }
      }

      _drawFingerIcon(canvas, Offset(currentX, fingerY), 1.0);
      _drawLabel(canvas, size, 'DRAG TO SELECT CELLS', _kGreen);
    } else if (t < 0.75) {
      final popT = ((t - 0.55) / 0.20).clamp(0.0, 1.0);
      final eased = Curves.elasticOut.transform(popT);
      _drawPatch(canvas, origin, 2, 1, 2, 3, _kGreen, scale: eased);
      _drawClueNumber(canvas, _cellRect(origin, 2, 1).center, 3,
          color: _kGreen);
      _drawLabel(canvas, size, 'PATCH CREATED!', _kCheckGreen);
    } else {
      _drawPatch(canvas, origin, 2, 1, 2, 3, _kGreen);
      _drawClueNumber(canvas, _cellRect(origin, 2, 1).center, 3,
          color: _kGreen);

      final checkAlpha = ((t - 0.75) / 0.10).clamp(0.0, 1.0);
      final patchTopLeft = _cellRect(origin, 2, 1);
      final patchBottomRight = _cellRect(origin, 2, 3);
      final checkCenter = Offset(
          patchBottomRight.right - 2, patchTopLeft.top - 2);
      _drawCheckmark(canvas, checkCenter, 8, alpha: checkAlpha);
      _drawLabel(canvas, size, '3 CELLS = CLUE "3"', _kCheckGreen);
    }
  }

  @override
  bool shouldRepaint(covariant _Step2Painter old) => old.t != t;
}

class _Step3Painter extends CustomPainter {
  final double t;
  const _Step3Painter(this.t);

  static const _patches = [
    [0, 0, 0, 1, _kBlue, 2],
    [0, 2, 1, 3, _kOrange, 4],
    [2, 1, 2, 3, _kGreen, 3],
    [2, 0, 3, 0, _kPink, 2],
    [1, 0, 1, 0, _kBlue, 1],
    [3, 1, 3, 3, _kGreen, 3],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final origin = _gridOrigin(size);
    _drawGrid(canvas, size, origin: origin);

    final patchPhases = _patches.length;
    final totalPhases = patchPhases + 1.5;
    final progress = t * totalPhases;
    final patchesShown = progress.floor().clamp(0, patchPhases);

    for (int i = 0; i < patchesShown; i++) {
      final p = _patches[i];
      final color = p[4] as Color;
      _drawPatch(canvas, origin, p[0] as int, p[1] as int, p[2] as int,
          p[3] as int, color);

      final clueR = p[0] as int;
      final clueC = p[1] as int;
      final clueVal = p[5] as int;
      if (clueVal > 0) {
        _drawClueNumber(canvas, _cellRect(origin, clueR, clueC).center,
            clueVal,
            color: color);
      }
    }

    if (patchesShown < patchPhases) {
      final frac = progress - patchesShown;
      final p = _patches[patchesShown];
      final color = p[4] as Color;
      final eased = Curves.elasticOut.transform(frac.clamp(0.0, 1.0));
      _drawPatch(canvas, origin, p[0] as int, p[1] as int, p[2] as int,
          p[3] as int, color,
          scale: eased);

      final clueVal = p[5] as int;
      if (clueVal > 0 && frac > 0.3) {
        _drawClueNumber(
            canvas,
            _cellRect(origin, p[0] as int, p[1] as int).center,
            clueVal,
            color: color);
      }

      _drawLabel(canvas, size, '${patchesShown + 1}/$patchPhases PATCHES',
          _kBlue);
    } else {
      final checkT = ((progress - patchPhases) / 1.5).clamp(0.0, 1.0);

      for (final p in _patches) {
        final clueR = p[0] as int;
        final clueC = p[1] as int;
        final clueVal = p[5] as int;
        final color = p[4] as Color;
        if (clueVal > 0) {
          _drawClueNumber(
              canvas, _cellRect(origin, clueR, clueC).center, clueVal,
              color: color);
        }
      }

      final tw = _gridTotalW();
      final checkCenter =
          Offset(origin.dx + tw / 2, origin.dy + _gridTotalH() + 14);
      final checkScale = Curves.elasticOut.transform(checkT);
      canvas.save();
      canvas.translate(checkCenter.dx, checkCenter.dy);
      canvas.scale(checkScale);
      _drawCheckmark(canvas, Offset.zero, 10);
      canvas.restore();

      _drawLabel(canvas, size, 'ALL CELLS COVERED!', _kCheckGreen, y: 0.96);
    }
  }

  @override
  bool shouldRepaint(covariant _Step3Painter old) => old.t != t;
}

class _Step4Painter extends CustomPainter {
  final double t;
  const _Step4Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final halfW = size.width / 2;
    final leftOrigin = Offset(halfW / 2 - _gridTotalW() / 2, 20);
    final rightOrigin = Offset(halfW + halfW / 2 - _gridTotalW() / 2, 20);

    final pulse = math.sin(t * math.pi * 4).abs();

    if (t < 0.50) {
      final sub = (t / 0.50).clamp(0.0, 1.0);
      _drawMiniGrid(canvas, leftOrigin);

      if (sub > 0.15) {
        final patchAlpha = ((sub - 0.15) / 0.35).clamp(0.0, 1.0);
        _drawPatch(canvas, leftOrigin, 0, 0, 1, 1, _kRed,
            opacity: patchAlpha);

        _drawClueNumber(canvas, _cellRect(leftOrigin, 0, 0).center, 2,
            color: _kRed);
        _drawClueNumber(canvas, _cellRect(leftOrigin, 1, 1).center, 3,
            color: _kRed);

        if (sub > 0.50) {
          final shakeT = ((sub - 0.50) / 0.50).clamp(0.0, 1.0);
          final shakeX = math.sin(shakeT * math.pi * 6) * 2 * (1 - shakeT);

          final badgeCenter = Offset(
              leftOrigin.dx + _gridTotalW() / 2 + shakeX,
              leftOrigin.dy + _gridTotalH() + 14);
          _drawXBadge(canvas, badgeCenter, pulse);
        }
      }

      final wrongLabel = Offset(leftOrigin.dx + _gridTotalW() / 2,
          leftOrigin.dy - 10);
      _drawBadgeLabel(canvas, wrongLabel, 'WRONG', _kRed, 8);
      _drawLabel(canvas, size, '2 CLUES IN 1 PATCH', _kRed, y: 0.95);
    } else {
      final sub = ((t - 0.50) / 0.50).clamp(0.0, 1.0);
      _drawMiniGrid(canvas, rightOrigin);

      if (sub > 0.10) {
        final p1Alpha = ((sub - 0.10) / 0.30).clamp(0.0, 1.0);
        _drawPatch(canvas, rightOrigin, 0, 0, 0, 1, _kBlue,
            opacity: p1Alpha);
        _drawClueNumber(canvas, _cellRect(rightOrigin, 0, 0).center, 2,
            color: _kBlue);
      }

      if (sub > 0.40) {
        final p2Alpha = ((sub - 0.40) / 0.30).clamp(0.0, 1.0);
        _drawPatch(canvas, rightOrigin, 1, 0, 1, 2, _kGreen,
            opacity: p2Alpha);
        _drawClueNumber(canvas, _cellRect(rightOrigin, 1, 1).center, 3,
            color: _kGreen);
      }

      if (sub > 0.70) {
        final checkAlpha = ((sub - 0.70) / 0.30).clamp(0.0, 1.0);
        final checkCenter = Offset(
            rightOrigin.dx + _gridTotalW() / 2,
            rightOrigin.dy + _gridTotalH() + 14);
        _drawCheckmark(canvas, checkCenter, 9, alpha: checkAlpha);
      }

      final correctLabel = Offset(rightOrigin.dx + _gridTotalW() / 2,
          rightOrigin.dy - 10);
      _drawBadgeLabel(canvas, correctLabel, 'CORRECT', _kCheckGreen, 8);
      _drawLabel(canvas, size, '1 CLUE PER PATCH', _kCheckGreen, y: 0.95);
    }
  }

  void _drawMiniGrid(Canvas canvas, Offset origin) {
    for (int r = 0; r < 2; r++) {
      for (int c = 0; c < 3; c++) {
        final rect = Rect.fromLTWH(
            origin.dx + c * (_cellS + _gap),
            origin.dy + r * (_cellS + _gap),
            _cellS,
            _cellS);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
        canvas.drawRRect(rr, Paint()..color = _kCellBg);
        canvas.drawRRect(
            rr,
            Paint()
              ..color = _kGridLine
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0);
      }
    }
  }

  void _drawXBadge(Canvas canvas, Offset center, double pulse) {
    final r = 9.0;
    canvas.drawCircle(
        center, r, Paint()..color = _kRed.withValues(alpha: 0.8 + 0.2 * pulse));
    final xs = r * 0.4;
    final xPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx - xs, center.dy - xs),
        Offset(center.dx + xs, center.dy + xs), xPaint);
    canvas.drawLine(Offset(center.dx + xs, center.dy - xs),
        Offset(center.dx - xs, center.dy + xs), xPaint);
  }

  void _drawBadgeLabel(
      Canvas canvas, Offset pos, String text, Color color, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          height: 1,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pad = 4.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: pos,
          width: tp.width + pad * 2,
          height: tp.height + pad * 2),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _Step4Painter old) => old.t != t;
}
