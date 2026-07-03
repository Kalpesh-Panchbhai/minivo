import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> numberSequenceSteps() => [
      GameHowToPlayStep(
        text:
            'Find and tap numbers in order: 1, 2, 3...',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4500),
          painter: (t) => _Step1Painter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text:
            'Tap the correct next number — wrong taps do nothing!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4200),
          painter: (t) => _Step2Painter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text:
            'Complete the sequence fast! Your best time is saved.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4800),
          painter: (t) => _Step3Painter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
    ];

const _kCircleColors = [
  Color(0xFF6366F1),
  Color(0xFFF59E0B),
  Color(0xFF06B6D4),
  Color(0xFF22C55E),
  Color(0xFFEF4444),
  Color(0xFF8B5CF6),
];

const _kPositions = <List<double>>[
  [0.18, 0.28],
  [0.72, 0.20],
  [0.44, 0.52],
  [0.80, 0.60],
  [0.17, 0.76],
  [0.60, 0.82],
];

const _kRadius = 15.0;
const _kGreen = Color(0xFF22C55E);
const _kRed = Color(0xFFEF4444);
const _kBlue = Color(0xFF339AF0);

void _drawBackground(Canvas canvas, Size size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F1A3A), Color(0xFF0A1628)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
  );

  final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.035);
  const spacing = 20.0;
  for (double x = spacing / 2; x < size.width; x += spacing) {
    for (double y = spacing / 2; y < size.height; y += spacing) {
      canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
    }
  }
}

void _drawNumberCircle(
  Canvas canvas,
  Offset center,
  int number,
  Color color, {
  double scale = 1.0,
  double alpha = 1.0,
  double shakeX = 0.0,
  bool redFlash = false,
}) {
  if (scale <= 0.01 || alpha <= 0.01) return;

  final r = _kRadius * scale;
  final c = Offset(center.dx + shakeX, center.dy);

  canvas.drawCircle(
    c + const Offset(1.5, 2.5),
    r,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.30 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  final circleColor = redFlash ? _kRed : color;

  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(circleColor, Colors.white, 0.35)!.withValues(alpha: alpha),
          circleColor.withValues(alpha: alpha),
          Color.lerp(circleColor, Colors.black, 0.18)!.withValues(alpha: alpha),
        ],
        stops: const [0.0, 0.55, 1.0],
        center: const Alignment(-0.30, -0.30),
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );

  canvas.drawCircle(
    Offset(c.dx - r * 0.25, c.dy - r * 0.25),
    r * 0.22,
    Paint()..color = Colors.white.withValues(alpha: 0.40 * alpha),
  );

  canvas.drawCircle(
    c,
    r,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.22 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );

  if (scale > 0.3) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: 12.5 * scale,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }
}

void _drawGhostCircle(Canvas canvas, Offset center, Color color) {
  canvas.drawCircle(
    center,
    _kRadius,
    Paint()
      ..color = color.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    center,
    _kRadius,
    Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );
}

void _drawTapIndicator(
  Canvas canvas,
  Offset center,
  double alpha, {
  Color color = _kBlue,
}) {
  if (alpha <= 0.01) return;

  canvas.drawCircle(
    center,
    13,
    Paint()
      ..color = color.withValues(alpha: 0.25 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0,
  );

  canvas.drawCircle(
    center,
    4.5,
    Paint()..color = color.withValues(alpha: 0.55 * alpha),
  );

  canvas.drawCircle(
    center,
    4.5,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.30 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );
}

void _drawPopEffect(
  Canvas canvas,
  Offset center,
  double progress,
  Color color,
) {
  if (progress <= 0 || progress >= 1) return;

  final fade = (1.0 - progress).clamp(0.0, 1.0);

  for (int ring = 0; ring < 2; ring++) {
    final ringT = (progress - ring * 0.12).clamp(0.0, 1.0);
    if (ringT <= 0) continue;
    final ringR = _kRadius + 22 * ringT;
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..color = color.withValues(alpha: (1.0 - ringT) * 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1.0 - ringT),
    );
  }

  const sparkleCount = 8;
  for (int i = 0; i < sparkleCount; i++) {
    final angle = (i / sparkleCount) * 2 * math.pi + progress * 1.5;
    final dist = _kRadius * 0.6 + 18 * progress;
    final sx = center.dx + math.cos(angle) * dist;
    final sy = center.dy + math.sin(angle) * dist;
    canvas.drawCircle(
      Offset(sx, sy),
      2.2 * fade,
      Paint()..color = color.withValues(alpha: fade * 0.65),
    );
  }
}

void _drawRipple(
  Canvas canvas,
  Offset center,
  double progress,
  Color color,
) {
  if (progress <= 0 || progress >= 1) return;
  canvas.drawCircle(
    center,
    _kRadius * progress,
    Paint()
      ..color = color.withValues(alpha: (1.0 - progress) * 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0,
  );
}

void _drawLabel(
  Canvas canvas,
  String text,
  Offset center,
  double alpha, {
  Color color = _kBlue,
  double fontSize = 10,
}) {
  if (alpha <= 0.01) return;

  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final pillRect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(center.dx, center.dy + tp.height / 2),
      width: tp.width + 12,
      height: tp.height + 6,
    ),
    const Radius.circular(6),
  );
  canvas.drawRRect(
    pillRect,
    Paint()..color = color.withValues(alpha: alpha * 0.15),
  );
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
}

Offset _pos(Size size, int index) => Offset(
      size.width * _kPositions[index][0],
      size.height * _kPositions[index][1],
    );

class _Step1Painter extends CustomPainter {
  final double t;
  const _Step1Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    const tapStart = [0.04, 0.34, 0.64];
    const indicatorDur = 0.10;
    const rippleDur = 0.03;
    const popDur = 0.16;

    for (int i = 0; i < 6; i++) {
      final center = _pos(size, i);

      if (i < 3) {
        final ts = tapStart[i];
        final rippleStart = ts + indicatorDur;
        final popStart = rippleStart + rippleDur;
        final popEnd = popStart + popDur;

        if (t < ts) {
          _drawNumberCircle(canvas, center, i + 1, _kCircleColors[i]);
        } else if (t < rippleStart) {
          _drawNumberCircle(canvas, center, i + 1, _kCircleColors[i]);
          final indicatorAlpha = ((t - ts) / indicatorDur).clamp(0.0, 1.0);
          _drawTapIndicator(canvas, center, indicatorAlpha,
              color: _kCircleColors[i]);
        } else if (t < popStart) {
          _drawNumberCircle(canvas, center, i + 1, _kCircleColors[i]);
          final rippleP = ((t - rippleStart) / rippleDur).clamp(0.0, 1.0);
          _drawRipple(canvas, center, rippleP, _kCircleColors[i]);
        } else if (t < popEnd) {
          final popP = ((t - popStart) / popDur).clamp(0.0, 1.0);
          final shrink = (1.0 - popP * 1.6).clamp(0.0, 1.0);
          _drawNumberCircle(canvas, center, i + 1, _kCircleColors[i],
              scale: shrink, alpha: shrink);
          _drawPopEffect(canvas, center, popP, _kCircleColors[i]);
        } else {
          _drawGhostCircle(canvas, center, _kCircleColors[i]);
        }
      } else {
        _drawNumberCircle(canvas, center, i + 1, _kCircleColors[i]);
      }
    }

    if (t > 0.90) {
      final nextAlpha =
          math.sin(((t - 0.90) / 0.10) * math.pi).clamp(0.0, 1.0);
      final center4 = _pos(size, 3);
      _drawLabel(
        canvas,
        'NEXT: 4',
        Offset(center4.dx, center4.dy - _kRadius - 14),
        nextAlpha * 0.85,
        color: _kCircleColors[3],
        fontSize: 9,
      );
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
    _drawBackground(canvas, size);

    for (int i = 0; i < 3; i++) {
      _drawGhostCircle(canvas, _pos(size, i), _kCircleColors[i]);
    }

    final center4 = _pos(size, 3);
    final center5 = _pos(size, 4);
    final center6 = _pos(size, 5);

    _drawStep2Number6(canvas, size, center6);
    _drawStep2Number5(canvas, center5);
    _drawStep2Number4(canvas, size, center4);

    _drawStep2NextLabel(canvas, size);
  }

  void _drawStep2Number6(Canvas canvas, Size size, Offset center6) {
    double shakeX = 0;
    bool redFlash = false;

    if (t >= 0.20 && t < 0.42) {
      final shakeT = ((t - 0.20) / 0.22).clamp(0.0, 1.0);
      if (shakeT < 0.70) {
        shakeX =
            math.sin(shakeT * math.pi * 7) * 5 * (1.0 - shakeT / 0.70);
      }
      redFlash = shakeT < 0.45;
    }

    _drawNumberCircle(canvas, center6, 6, _kCircleColors[5],
        shakeX: shakeX, redFlash: redFlash);

    if (t >= 0.04 && t < 0.22) {
      final indicatorAlpha = ((t - 0.04) / 0.12).clamp(0.0, 1.0);
      _drawTapIndicator(canvas, center6, indicatorAlpha, color: _kRed);
    }

    if (t >= 0.22 && t < 0.44) {
      final labelAlpha =
          math.sin(((t - 0.22) / 0.22) * math.pi).clamp(0.0, 1.0);
      _drawLabel(
        canvas,
        'WRONG!',
        Offset(center6.dx, center6.dy - _kRadius - 14),
        labelAlpha,
        color: _kRed,
        fontSize: 10,
      );
    }

    if (t >= 0.22 && t < 0.36) {
      final xAlpha = ((t - 0.22) / 0.04).clamp(0.0, 1.0) *
          (1.0 - ((t - 0.26) / 0.10).clamp(0.0, 1.0));
      if (xAlpha > 0.01) {
        final xPaint = Paint()
          ..color = _kRed.withValues(alpha: xAlpha * 0.70)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          center6 + const Offset(-6, -6),
          center6 + const Offset(6, 6),
          xPaint,
        );
        canvas.drawLine(
          center6 + const Offset(6, -6),
          center6 + const Offset(-6, 6),
          xPaint,
        );
      }
    }
  }

  void _drawStep2Number5(Canvas canvas, Offset center5) {
    _drawNumberCircle(canvas, center5, 5, _kCircleColors[4]);
  }

  void _drawStep2Number4(Canvas canvas, Size size, Offset center4) {
    if (t < 0.62) {
      _drawNumberCircle(canvas, center4, 4, _kCircleColors[3]);
      if (t >= 0.48) {
        final indicatorAlpha = ((t - 0.48) / 0.12).clamp(0.0, 1.0);
        _drawTapIndicator(canvas, center4, indicatorAlpha,
            color: _kCircleColors[3]);
      }
    } else if (t < 0.65) {
      _drawNumberCircle(canvas, center4, 4, _kCircleColors[3]);
      final rippleP = ((t - 0.62) / 0.03).clamp(0.0, 1.0);
      _drawRipple(canvas, center4, rippleP, _kCircleColors[3]);
    } else if (t < 0.82) {
      final popP = ((t - 0.65) / 0.17).clamp(0.0, 1.0);
      final shrink = (1.0 - popP * 1.6).clamp(0.0, 1.0);
      _drawNumberCircle(canvas, center4, 4, _kCircleColors[3],
          scale: shrink, alpha: shrink);
      _drawPopEffect(canvas, center4, popP, _kCircleColors[3]);
    } else {
      canvas.drawCircle(
        center4,
        _kRadius,
        Paint()..color = _kCircleColors[3].withValues(alpha: 0.07),
      );
    }

    if (t >= 0.67 && t < 0.85) {
      final labelAlpha =
          math.sin(((t - 0.67) / 0.18) * math.pi).clamp(0.0, 1.0);
      _drawLabel(
        canvas,
        'CORRECT!',
        Offset(center4.dx, center4.dy - _kRadius - 14),
        labelAlpha,
        color: _kGreen,
        fontSize: 10,
      );
    }
  }

  void _drawStep2NextLabel(Canvas canvas, Size size) {
    if (t > 0.88) {
      final nextAlpha =
          math.sin(((t - 0.88) / 0.12) * math.pi).clamp(0.0, 1.0);
      final center5 = _pos(size, 4);
      _drawLabel(
        canvas,
        'NEXT: 5',
        Offset(center5.dx, center5.dy - _kRadius - 14),
        nextAlpha * 0.85,
        color: _kCircleColors[4],
        fontSize: 9,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Step2Painter old) => old.t != t;
}

class _Step3Painter extends CustomPainter {
  final double t;
  const _Step3Painter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    _drawTimer(canvas, size);

    for (int i = 0; i < 4; i++) {
      final center = _pos(size, i);
      canvas.drawCircle(
        center,
        _kRadius,
        Paint()..color = _kCircleColors[i].withValues(alpha: 0.06),
      );
    }

    _drawStep3Number5(canvas, size);
    _drawStep3Number6(canvas, size);
    _drawCompleteOverlay(canvas, size);
  }

  void _drawTimer(Canvas canvas, Size size) {
    final completed = t >= 0.78;
    final timerSeconds = completed ? 14.7 : 12.3 + t * 3.1;
    final timeStr = '${timerSeconds.toStringAsFixed(1)}s';

    final timerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 60, 7, 54, 22),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      timerRect,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      timerRect,
      Paint()
        ..color = (completed ? _kGreen : _kBlue).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    final iconCx = size.width - 52.0;
    const iconCy = 18.0;
    canvas.drawCircle(
      Offset(iconCx, iconCy),
      5.5,
      Paint()
        ..color = (completed ? _kGreen : _kBlue).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    final handAngle = -math.pi / 2 + (t * math.pi * 6);
    canvas.drawLine(
      Offset(iconCx, iconCy),
      Offset(
        iconCx + math.cos(handAngle) * 3.5,
        iconCy + math.sin(handAngle) * 3.5,
      ),
      Paint()
        ..color = (completed ? _kGreen : _kBlue).withValues(alpha: 0.65)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: TextStyle(
          color: completed
              ? _kGreen.withValues(alpha: 0.90)
              : Colors.white.withValues(alpha: 0.75),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - 42, 18 - tp.height / 2));
  }

  void _drawStep3Number5(Canvas canvas, Size size) {
    final center5 = _pos(size, 4);

    if (t < 0.18) {
      _drawNumberCircle(canvas, center5, 5, _kCircleColors[4]);
      if (t >= 0.06) {
        final indicatorAlpha = ((t - 0.06) / 0.10).clamp(0.0, 1.0);
        _drawTapIndicator(canvas, center5, indicatorAlpha,
            color: _kCircleColors[4]);
      }
    } else if (t < 0.21) {
      _drawNumberCircle(canvas, center5, 5, _kCircleColors[4]);
      final rippleP = ((t - 0.18) / 0.03).clamp(0.0, 1.0);
      _drawRipple(canvas, center5, rippleP, _kCircleColors[4]);
    } else if (t < 0.38) {
      final popP = ((t - 0.21) / 0.17).clamp(0.0, 1.0);
      final shrink = (1.0 - popP * 1.6).clamp(0.0, 1.0);
      _drawNumberCircle(canvas, center5, 5, _kCircleColors[4],
          scale: shrink, alpha: shrink);
      _drawPopEffect(canvas, center5, popP, _kCircleColors[4]);
    } else {
      canvas.drawCircle(
        center5,
        _kRadius,
        Paint()..color = _kCircleColors[4].withValues(alpha: 0.06),
      );
    }
  }

  void _drawStep3Number6(Canvas canvas, Size size) {
    final center6 = _pos(size, 5);

    if (t < 0.56) {
      _drawNumberCircle(canvas, center6, 6, _kCircleColors[5]);
      if (t >= 0.44) {
        final indicatorAlpha = ((t - 0.44) / 0.10).clamp(0.0, 1.0);
        _drawTapIndicator(canvas, center6, indicatorAlpha,
            color: _kCircleColors[5]);
      }
    } else if (t < 0.59) {
      _drawNumberCircle(canvas, center6, 6, _kCircleColors[5]);
      final rippleP = ((t - 0.56) / 0.03).clamp(0.0, 1.0);
      _drawRipple(canvas, center6, rippleP, _kCircleColors[5]);
    } else if (t < 0.76) {
      final popP = ((t - 0.59) / 0.17).clamp(0.0, 1.0);
      final shrink = (1.0 - popP * 1.6).clamp(0.0, 1.0);
      _drawNumberCircle(canvas, center6, 6, _kCircleColors[5],
          scale: shrink, alpha: shrink);
      _drawPopEffect(canvas, center6, popP, _kCircleColors[5]);
    } else {
      canvas.drawCircle(
        center6,
        _kRadius,
        Paint()..color = _kCircleColors[5].withValues(alpha: 0.06),
      );
    }
  }

  void _drawCompleteOverlay(Canvas canvas, Size size) {
    if (t < 0.78) return;

    final cx = size.width / 2;
    final cy = size.height / 2 - 2;
    final completeT = ((t - 0.78) / 0.22).clamp(0.0, 1.0);

    if (completeT > 0.02) {
      final bgAlpha = (completeT * 0.35).clamp(0.0, 0.35);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black.withValues(alpha: bgAlpha),
      );
    }

    final checkScale =
        Curves.elasticOut.transform((completeT / 0.50).clamp(0.0, 1.0));
    final checkAlpha = (completeT / 0.20).clamp(0.0, 1.0);
    final checkR = 20.0 * checkScale;

    canvas.drawCircle(
      Offset(cx, cy - 14),
      checkR + 4,
      Paint()
        ..color = _kGreen.withValues(alpha: checkAlpha * 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawCircle(
      Offset(cx, cy - 14),
      checkR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(_kGreen, Colors.white, 0.25)!
                .withValues(alpha: checkAlpha),
            _kGreen.withValues(alpha: checkAlpha),
          ],
          center: const Alignment(-0.3, -0.3),
        ).createShader(
          Rect.fromCircle(center: Offset(cx, cy - 14), radius: checkR),
        ),
    );

    if (checkScale > 0.45) {
      final strokeAlpha =
          ((checkScale - 0.45) / 0.55).clamp(0.0, 1.0) * checkAlpha;
      final path = Path()
        ..moveTo(cx - 9, cy - 14)
        ..lineTo(cx - 3, cy - 7)
        ..lineTo(cx + 9, cy - 21);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: strokeAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (completeT > 0.15) {
      final textAlpha = ((completeT - 0.15) / 0.25).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'COMPLETE!',
          style: TextStyle(
            color: _kGreen.withValues(alpha: textAlpha),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            shadows: [
              Shadow(
                color: _kGreen.withValues(alpha: textAlpha * 0.40),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + 10));
    }

    if (completeT > 0.35) {
      final timeAlpha = ((completeT - 0.35) / 0.20).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '14.7s',
          style: TextStyle(
            color: Colors.white.withValues(alpha: timeAlpha * 0.65),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + 32));
    }

    if (completeT > 0.10) {
      final sparkleT = ((completeT - 0.10) / 0.90).clamp(0.0, 1.0);
      const sparkleCount = 12;
      for (int i = 0; i < sparkleCount; i++) {
        final angle =
            (i / sparkleCount) * 2 * math.pi + sparkleT * math.pi;
        final dist = 28 + 30 * sparkleT;
        final sx = cx + math.cos(angle) * dist;
        final sy = (cy - 2) + math.sin(angle) * dist * 0.7;
        final fade = (1.0 - sparkleT).clamp(0.0, 1.0);
        final sparkleColor = _kCircleColors[i % _kCircleColors.length];
        canvas.drawCircle(
          Offset(sx, sy),
          2.5 * (1.0 - sparkleT * 0.4),
          Paint()..color = sparkleColor.withValues(alpha: fade * 0.55),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Step3Painter old) => old.t != t;
}
