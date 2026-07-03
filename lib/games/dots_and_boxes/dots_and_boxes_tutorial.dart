import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

const _kP1 = Color(0xFF339AF0);
const _kP2 = Color(0xFFFF6B6B);
const _kDot = Color(0xFF333333);
const _kPad = 30.0;
const _kStep = 60.0;
const _kDotR = 5.0;
const _kLineW = 3.5;

Offset _dot(int r, int c) => Offset(_kPad + c * _kStep, _kPad + r * _kStep);

void _drawDots(Canvas canvas) {
  final p = Paint()..color = _kDot;
  for (int r = 0; r <= 2; r++) {
    for (int c = 0; c <= 2; c++) {
      canvas.drawCircle(_dot(r, c), _kDotR, p);
    }
  }
}

void _edge(Canvas canvas, Offset a, Offset b, Color color,
    [double progress = 1.0]) {
  if (progress <= 0) return;
  final end = Offset.lerp(a, b, progress.clamp(0.0, 1.0))!;
  canvas.drawLine(
    a,
    end,
    Paint()
      ..color = color
      ..strokeWidth = _kLineW
      ..strokeCap = StrokeCap.round,
  );
}

void _boxFill(Canvas canvas, int r, int c, Color color,
    [double alpha = 0.28]) {
  if (alpha <= 0) return;
  final o = _dot(r, c);
  canvas.drawRect(
    Rect.fromLTWH(o.dx, o.dy, _kStep, _kStep),
    Paint()..color = color.withValues(alpha: alpha),
  );
}

void _centeredText(
    Canvas canvas, String text, Offset center, Color color, double fontSize,
    {FontWeight weight = FontWeight.w900}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
    canvas,
    Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
  );
}

List<GameHowToPlayStep> dotsAndBoxesSteps() => [
      GameHowToPlayStep(
        text: 'Tap between dots to draw a line. Players take turns.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3500),
          painter: (t) => _TurnsPainter(t),
          canvasSize: const Size(180, 180),
        ),
      ),
      GameHowToPlayStep(
        text:
            'Complete a box by drawing its 4th side — you claim it and score!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _ClaimPainter(t),
          canvasSize: const Size(180, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Complete a box and you go again — chain your moves!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 5000),
          painter: (t) => _ChainPainter(t),
          canvasSize: const Size(180, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Most boxes when the board is full wins!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4500),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(180, 180),
        ),
      ),
    ];

class _TurnsPainter extends CustomPainter {
  final double t;
  const _TurnsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 0.08) {
      final p = Curves.easeOut.transform(
        ((t - 0.08) / 0.30).clamp(0.0, 1.0),
      );
      _edge(canvas, _dot(0, 0), _dot(0, 1), _kP1, p);
    }

    if (t >= 0.52) {
      final p = Curves.easeOut.transform(
        ((t - 0.52) / 0.30).clamp(0.0, 1.0),
      );
      _edge(canvas, _dot(0, 1), _dot(0, 2), _kP2, p);
    }

    _drawDots(canvas);

    final isP1 = t < 0.46;
    final color = isP1 ? _kP1 : _kP2;
    final who = isP1 ? 'P1' : 'P2';
    final indicatorY = size.height - 10.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, indicatorY),
          width: 72,
          height: 17,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = color.withValues(alpha: 0.15),
    );
    _centeredText(
      canvas,
      "$who's turn",
      Offset(size.width / 2, indicatorY),
      color,
      9,
      weight: FontWeight.w800,
    );
  }

  @override
  bool shouldRepaint(_TurnsPainter old) => old.t != t;
}

class _ClaimPainter extends CustomPainter {
  final double t;
  const _ClaimPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 0.50) {
      final a = ((t - 0.50) / 0.10).clamp(0.0, 1.0);
      _boxFill(canvas, 0, 0, _kP1, a * 0.28);
    }

    _edge(canvas, _dot(0, 0), _dot(0, 1), _kP1);
    _edge(canvas, _dot(0, 0), _dot(1, 0), _kP1);
    _edge(canvas, _dot(0, 1), _dot(1, 1), _kP1);

    if (t >= 0.15) {
      final p = Curves.easeOut.transform(
        ((t - 0.15) / 0.35).clamp(0.0, 1.0),
      );
      _edge(canvas, _dot(1, 0), _dot(1, 1), _kP1, p);
    }

    _drawDots(canvas);

    if (t >= 0.62) {
      final a = ((t - 0.62) / 0.10).clamp(0.0, 1.0);
      _centeredText(
        canvas,
        'P1',
        _dot(0, 0) + const Offset(_kStep / 2, _kStep / 2),
        _kP1.withValues(alpha: a),
        18,
      );
    }

    if (t >= 0.74) {
      final bt = ((t - 0.74) / 0.18).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(bt);
      final pos = Offset(_dot(0, 1).dx + 14, _dot(0, 0).dy + _kStep * 0.35);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.scale(scale);
      canvas.translate(-pos.dx, -pos.dy);
      _centeredText(canvas, '+1', pos, _kP1.withValues(alpha: bt), 15);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ClaimPainter old) => old.t != t;
}

class _ChainPainter extends CustomPainter {
  final double t;
  const _ChainPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 0.30) {
      final a = ((t - 0.30) / 0.08).clamp(0.0, 1.0);
      _boxFill(canvas, 0, 0, _kP1, a * 0.28);
    }
    if (t >= 0.66) {
      final a = ((t - 0.66) / 0.08).clamp(0.0, 1.0);
      _boxFill(canvas, 0, 1, _kP1, a * 0.28);
    }

    _edge(canvas, _dot(0, 0), _dot(0, 1), _kP1);
    _edge(canvas, _dot(0, 0), _dot(1, 0), _kP2);
    _edge(canvas, _dot(0, 1), _dot(1, 1), _kP1);
    _edge(canvas, _dot(0, 1), _dot(0, 2), _kP2);
    _edge(canvas, _dot(0, 2), _dot(1, 2), _kP2);

    if (t >= 0.08) {
      final p = Curves.easeOut.transform(
        ((t - 0.08) / 0.22).clamp(0.0, 1.0),
      );
      _edge(canvas, _dot(1, 0), _dot(1, 1), _kP1, p);
    }

    if (t >= 0.44) {
      final p = Curves.easeOut.transform(
        ((t - 0.44) / 0.22).clamp(0.0, 1.0),
      );
      _edge(canvas, _dot(1, 1), _dot(1, 2), _kP1, p);
    }

    _drawDots(canvas);

    if (t >= 0.34 && t < 0.44) {
      final a = (t < 0.37)
          ? ((t - 0.34) / 0.03).clamp(0.0, 1.0)
          : ((0.44 - t) / 0.07).clamp(0.0, 1.0);
      _centeredText(
        canvas,
        'GO AGAIN!',
        Offset(size.width / 2, size.height - 12),
        const Color(0xFFFF9900).withValues(alpha: a),
        10,
        weight: FontWeight.w800,
      );
    }

    if (t >= 0.76) {
      final bt = ((t - 0.76) / 0.16).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(bt);
      final center = Offset(size.width / 2, size.height - 12);

      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final dist = bt * 28;
        final pa = (1 - bt).clamp(0.0, 1.0) * 0.55;
        canvas.drawCircle(
          Offset(
            center.dx + math.cos(angle) * dist,
            center.dy + math.sin(angle) * dist,
          ),
          2.5 * (1 - bt * 0.5),
          Paint()
            ..color = (i.isEven ? _kP1 : const Color(0xFFFF9900))
                .withValues(alpha: pa),
        );
      }

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(scale);
      canvas.translate(-center.dx, -center.dy);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: 72, height: 20),
          const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFFFF9900).withValues(alpha: bt * 0.2),
      );
      _centeredText(
        canvas,
        'CHAIN!',
        center,
        const Color(0xFFFF9900).withValues(alpha: bt),
        12,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ChainPainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final boxes = [
      (0, 0, _kP1, 0.05),
      (0, 1, _kP1, 0.12),
      (1, 0, _kP2, 0.19),
      (1, 1, _kP1, 0.26),
    ];
    for (final (r, c, color, start) in boxes) {
      final a = ((t - start) / 0.10).clamp(0.0, 1.0);
      if (a > 0) _boxFill(canvas, r, c, color, a * 0.28);
    }

    const lc = Color(0xFF555555);
    for (int r = 0; r <= 2; r++) {
      for (int c = 0; c < 2; c++) {
        _edge(canvas, _dot(r, c), _dot(r, c + 1), lc);
      }
    }
    for (int r = 0; r < 2; r++) {
      for (int c = 0; c <= 2; c++) {
        _edge(canvas, _dot(r, c), _dot(r + 1, c), lc);
      }
    }

    _drawDots(canvas);

    if (t >= 0.50) {
      final st = ((t - 0.50) / 0.15).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '3',
              style: TextStyle(
                color: _kP1.withValues(alpha: st),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: ' vs ',
              style: TextStyle(
                color: _kDot.withValues(alpha: st * 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: '1',
              style: TextStyle(
                color: _kP2.withValues(alpha: st),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final scoreX = size.width / 2 - tp.width / 2;
      final scoreY = size.height - tp.height - 4;
      tp.paint(canvas, Offset(scoreX, scoreY));

      if (t >= 0.70) {
        final ct = ((t - 0.70) / 0.12).clamp(0.0, 1.0);
        final cp = Paint()
          ..color = const Color(0xFF51CF66).withValues(alpha: ct)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final cx = scoreX - 14;
        final cy = scoreY + tp.height / 2;
        final path = Path()
          ..moveTo(cx - 4, cy)
          ..lineTo(cx - 1, cy + 4)
          ..lineTo(cx + 6, cy - 5);
        canvas.drawPath(path, cp);
      }
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}
