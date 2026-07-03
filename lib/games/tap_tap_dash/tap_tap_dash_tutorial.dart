import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> tapTapDashSteps() => [
      GameHowToPlayStep(
        text: 'Your ball runs forward — tap to turn at corners!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _TurnDemoPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Turn too late and you fall off — timing is everything!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3000),
          painter: (t) => _FallDemoPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Speed ramps up as you go — survive as long as you can!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _SpeedDemoPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
    ];

const Color _kBg = Color(0xFF1A1A2E);
const Color _kCyan = Color(0xFF00D4FF);
const double _kTile = 20.0;
const double _kGap = 1.0;
const double _kStep = _kTile + _kGap;

void _bg(Canvas c, Size s) {
  c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), Paint()..color = _kBg);
}

void _tile(Canvas c, double x, double y, {double alpha = 0.25}) {
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, _kTile, _kTile),
      const Radius.circular(3),
    ),
    Paint()..color = _kCyan.withValues(alpha: alpha),
  );
}

void _ball(Canvas c, double cx, double cy, {double glow = 1.0}) {
  final r = _kTile * 0.34;
  if (glow > 0) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _kCyan.withValues(alpha: 0.45 * glow),
          _kCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 2.8));
    c.drawCircle(Offset(cx, cy), r * 2.8, glowPaint);
  }
  final bodyPaint = Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      colors: [
        Color.lerp(_kCyan, Colors.white, 0.5)!,
        _kCyan,
        _kCyan.withValues(alpha: 0.8),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  c.drawCircle(Offset(cx, cy), r, bodyPaint);
  c.drawCircle(
    Offset(cx - r * 0.25, cy - r * 0.25),
    r * 0.2,
    Paint()..color = Colors.white.withValues(alpha: 0.6),
  );
}

Offset _tileCenter(double x, double y) =>
    Offset(x + _kTile / 2, y + _kTile / 2);

void _tapRipple(Canvas c, Offset center, double rippleT) {
  if (rippleT < 0 || rippleT > 1) return;
  final maxR = 18.0;
  final r = maxR * rippleT;
  final alpha = (1.0 - rippleT) * 0.5;
  c.drawCircle(
    center,
    r,
    Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * (1.0 - rippleT) + 0.5,
  );
  if (rippleT < 0.5) {
    c.drawCircle(
      center,
      r * 0.5,
      Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * (1.0 - rippleT),
    );
  }
}

void _label(Canvas c, String text, Offset pos,
    {double alpha = 1.0,
    double fontSize = 13,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w900}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: fontSize,
        fontWeight: weight,
        letterSpacing: 1.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
}

// ── Step 1: Tap to turn ─────────────────────────────────────────────────────

class _TurnDemoPainter extends CustomPainter {
  final double t;
  const _TurnDemoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas, size);

    final ox = size.width * 0.1;
    final oy = size.height * 0.25;

    for (int i = 0; i < 6; i++) {
      _tile(canvas, ox + i * _kStep, oy);
    }
    for (int i = 1; i < 5; i++) {
      _tile(canvas, ox + 5 * _kStep, oy + i * _kStep);
    }

    final cornerIdx = 5.0;
    final totalLen = cornerIdx + 4.0;

    final ease = _smoothStep(t);
    final progress = ease * totalLen;

    double px, py;
    if (progress <= cornerIdx) {
      px = ox + progress * _kStep;
      py = oy;
    } else {
      px = ox + cornerIdx * _kStep;
      py = oy + (progress - cornerIdx) * _kStep;
    }

    final bc = _tileCenter(px, py);

    if (progress > cornerIdx - 0.5 && progress < cornerIdx + 1.5) {
      final trailAlpha =
          (1.0 - ((progress - cornerIdx).abs() / 1.5)).clamp(0.0, 1.0) * 0.15;
      for (int i = 1; i <= 3; i++) {
        canvas.drawCircle(
          Offset(bc.dx - (progress <= cornerIdx ? i * 6.0 : 0),
              bc.dy - (progress > cornerIdx ? i * 6.0 : 0)),
          _kTile * 0.15,
          Paint()..color = _kCyan.withValues(alpha: trailAlpha / i),
        );
      }
    }

    _ball(canvas, bc.dx, bc.dy);

    final turnT = cornerIdx / totalLen;
    final tapStart = turnT - 0.06;
    final tapEnd = turnT + 0.12;

    if (t >= tapStart && t <= tapEnd) {
      final fadeIn = ((t - tapStart) / 0.04).clamp(0.0, 1.0);
      final fadeOut = ((tapEnd - t) / 0.06).clamp(0.0, 1.0);
      final a = fadeIn * fadeOut;
      final cornerCenter =
          _tileCenter(ox + cornerIdx * _kStep, oy);
      _label(canvas, 'TAP!', Offset(cornerCenter.dx, cornerCenter.dy - 22),
          alpha: a, fontSize: 14, color: Colors.white);
    }

    final rippleStart = turnT - 0.02;
    final rippleDur = 0.12;
    if (t >= rippleStart && t <= rippleStart + rippleDur) {
      final rt = ((t - rippleStart) / rippleDur).clamp(0.0, 1.0);
      final cornerCenter =
          _tileCenter(ox + cornerIdx * _kStep, oy);
      _tapRipple(canvas, cornerCenter, rt);
    }

    final cornerTile = _tileCenter(ox + cornerIdx * _kStep, oy);
    if (t < turnT) {
      final pulse = (math.sin(t * math.pi * 8) * 0.5 + 0.5) * 0.3 + 0.3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: cornerTile, width: _kTile + 4, height: _kTile + 4),
          const Radius.circular(4),
        ),
        Paint()
          ..color = _kCyan.withValues(alpha: pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TurnDemoPainter old) => old.t != t;
}

// ── Step 2: Fall off ────────────────────────────────────────────────────────

class _FallDemoPainter extends CustomPainter {
  final double t;
  const _FallDemoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas, size);

    final ox = size.width * 0.12;
    final oy = size.height * 0.28;

    for (int i = 0; i < 5; i++) {
      _tile(canvas, ox + i * _kStep, oy);
    }
    for (int i = 1; i < 4; i++) {
      _tile(canvas, ox + 4 * _kStep, oy + i * _kStep);
    }

    final endTile = 4.0;
    final overshootStart = 0.45;
    final fallStart = 0.55;

    double px, py;
    double glow = 1.0;
    double rot = 0.0;

    if (t < overshootStart) {
      final p = t / overshootStart;
      final smooth = _smoothStep(p);
      px = ox + smooth * endTile * _kStep;
      py = oy;
    } else if (t < fallStart) {
      final p = (t - overshootStart) / (fallStart - overshootStart);
      px = ox + (endTile + p * 1.2) * _kStep;
      py = oy;
    } else {
      final fallT = (t - fallStart) / (1.0 - fallStart);
      px = ox + (endTile + 1.2 + fallT * 0.8) * _kStep;
      final gravity = fallT * fallT;
      py = oy + gravity * size.height * 1.2;
      glow = (1.0 - fallT).clamp(0.0, 1.0);
      rot = fallT * math.pi * 1.5;
    }

    final bc = _tileCenter(px, py);

    if (t >= fallStart) {
      final fallT = ((t - fallStart) / (1.0 - fallStart)).clamp(0.0, 1.0);
      for (int i = 1; i <= 4; i++) {
        final trailT = (fallT - i * 0.06).clamp(0.0, 1.0);
        if (trailT > 0) {
          final trailY = oy + _kTile / 2 + trailT * trailT * size.height * 1.2;
          final trailX =
              ox + (endTile + 1.2 + trailT * 0.8) * _kStep + _kTile / 2;
          canvas.drawCircle(
            Offset(trailX, trailY),
            _kTile * 0.12 * (1.0 - trailT),
            Paint()..color = Colors.redAccent.withValues(alpha: 0.3 * (1.0 - trailT)),
          );
        }
      }
    }

    if (bc.dy < size.height + 20) {
      canvas.save();
      canvas.translate(bc.dx, bc.dy);
      canvas.rotate(rot);
      canvas.translate(-bc.dx, -bc.dy);
      _ball(canvas, bc.dx, bc.dy, glow: glow);
      canvas.restore();
    }

    if (t >= fallStart + 0.05) {
      final showT =
          ((t - fallStart - 0.05) / 0.25).clamp(0.0, 1.0);
      final scale = Curves.elasticOut.transform(showT.clamp(0.0, 1.0));

      final xCenter = Offset(size.width * 0.5, size.height * 0.2);

      canvas.save();
      canvas.translate(xCenter.dx, xCenter.dy);
      canvas.scale(scale);
      canvas.translate(-xCenter.dx, -xCenter.dy);

      final xSize = 14.0;
      final xPaint = Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(xCenter.dx - xSize, xCenter.dy - xSize),
        Offset(xCenter.dx + xSize, xCenter.dy + xSize),
        xPaint,
      );
      canvas.drawLine(
        Offset(xCenter.dx + xSize, xCenter.dy - xSize),
        Offset(xCenter.dx - xSize, xCenter.dy + xSize),
        xPaint,
      );

      canvas.restore();

      if (showT > 0.3) {
        final textAlpha = ((showT - 0.3) / 0.3).clamp(0.0, 1.0);
        _label(
          canvas,
          'GAME OVER',
          Offset(size.width / 2, size.height * 0.2 + 26),
          alpha: textAlpha,
          fontSize: 12,
          color: Colors.redAccent,
          weight: FontWeight.w900,
        );
      }
    }

    if (t >= overshootStart && t < fallStart + 0.1) {
      final warnT =
          ((t - overshootStart) / (fallStart - overshootStart + 0.1))
              .clamp(0.0, 1.0);
      final pulse = math.sin(warnT * math.pi * 4) * 0.5 + 0.5;
      final warningAlpha = pulse * 0.12;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.red.withValues(alpha: warningAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FallDemoPainter old) => old.t != t;
}

// ── Step 3: Speed ramps up ──────────────────────────────────────────────────

class _SpeedDemoPainter extends CustomPainter {
  final double t;
  const _SpeedDemoPainter(this.t);

  static const _segments = <_Seg>[
    _Seg(0, 1, 4),
    _Seg(1, 0, 3),
    _Seg(0, 1, 3),
    _Seg(1, 0, 2),
    _Seg(0, 1, 2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _bg(canvas, size);

    final speeds = <double>[1.0, 1.4, 1.9, 2.5, 3.2];
    double totalTime = 0;
    final segTimes = <double>[];
    for (int i = 0; i < _segments.length; i++) {
      final dur = _segments[i].len / speeds[i];
      segTimes.add(dur);
      totalTime += dur;
    }

    final progress = t * totalTime;

    double elapsed = 0;
    int curSeg = 0;
    double segProgress = 0;
    for (int i = 0; i < _segments.length; i++) {
      if (progress < elapsed + segTimes[i]) {
        curSeg = i;
        segProgress = (progress - elapsed) / segTimes[i];
        break;
      }
      elapsed += segTimes[i];
      if (i == _segments.length - 1) {
        curSeg = _segments.length - 1;
        segProgress = 1.0;
      }
    }

    double tilesBefore = 0;
    for (int i = 0; i < curSeg; i++) {
      tilesBefore += _segments[i].len;
    }
    final currentTilePos = tilesBefore + segProgress * _segments[curSeg].len;

    final camX = _worldX(currentTilePos) - size.width * 0.35;
    final camY = _worldY(currentTilePos) - size.height * 0.4;

    canvas.save();
    canvas.translate(-camX, -camY);

    double tileOffset = 0;
    for (final seg in _segments) {
      for (int i = 0; i < seg.len; i++) {
        final idx = tileOffset + i;
        final wx = _worldX(idx);
        final wy = _worldY(idx);
        if (wx - camX > -30 &&
            wx - camX < size.width + 30 &&
            wy - camY > -30 &&
            wy - camY < size.height + 30) {
          _tile(canvas, wx, wy, alpha: 0.3);
        }
      }
      tileOffset += seg.len;
    }

    final ballWorld =
        Offset(_worldX(currentTilePos), _worldY(currentTilePos));
    final bc = _tileCenter(ballWorld.dx, ballWorld.dy);

    final currentSpeed = speeds[curSeg.clamp(0, speeds.length - 1)];
    final speedNorm = (currentSpeed - 1.0) / 2.2;
    final lineCount = (speedNorm * 5).ceil().clamp(1, 5);

    final movingRight = _segments[curSeg].dx == 1;
    for (int i = 0; i < lineCount; i++) {
      final offset = (i + 1) * 5.0;
      final len = (8.0 + i * 3.0) * speedNorm.clamp(0.2, 1.0);
      final lineAlpha = (0.4 - i * 0.06).clamp(0.05, 0.4);
      final yOff = (i - lineCount / 2) * 4.0;

      final startX = movingRight ? bc.dx - 10 - offset : bc.dx;
      final startY = bc.dy + yOff;

      canvas.drawLine(
        Offset(movingRight ? startX - len : startX + 10 + offset,
            startY),
        Offset(movingRight ? startX : startX + 10 + offset + len,
            startY),
        Paint()
          ..color = _kCyan.withValues(alpha: lineAlpha)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    _ball(canvas, bc.dx, bc.dy);

    canvas.restore();

    final turnsCompleted = curSeg;
    if (turnsCompleted > 0) {
      for (int i = 0; i < turnsCompleted; i++) {
        double turnMoment = 0;
        for (int j = 0; j <= i; j++) {
          turnMoment += segTimes[j];
        }
        final sinceTurn = progress - turnMoment;
        if (sinceTurn >= 0 && sinceTurn < totalTime * 0.25) {
          final fadeT = (sinceTurn / (totalTime * 0.25)).clamp(0.0, 1.0);
          final a = (1.0 - fadeT);
          final rise = fadeT * 12;
          _label(
            canvas,
            '+${i + 1}',
            Offset(size.width - 28, 18 - rise),
            alpha: a,
            fontSize: 13,
            color: _kCyan,
            weight: FontWeight.w900,
          );
        }
      }
    }

    final scoreVal = turnsCompleted;
    if (scoreVal > 0) {
      final scoreTp = TextPainter(
        text: TextSpan(
          text: '$scoreVal',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final scoreX = size.width - 16 - scoreTp.width / 2;
      final scoreY = 28.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(scoreX, scoreY + scoreTp.height / 2),
            width: scoreTp.width + 16,
            height: scoreTp.height + 8,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = _kCyan.withValues(alpha: 0.2),
      );
      scoreTp.paint(
          canvas, Offset(scoreX - scoreTp.width / 2, scoreY));
    }

    final barW = size.width * 0.3;
    final barH = 4.0;
    final barX = 12.0;
    final barY = size.height - 14.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    final fillW = barW * speedNorm.clamp(0.0, 1.0);
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, fillW, barH),
          const Radius.circular(2),
        ),
        Paint()
          ..shader = LinearGradient(
            colors: [_kCyan, Colors.orangeAccent],
          ).createShader(Rect.fromLTWH(barX, barY, barW, barH)),
      );
    }

    final spdLabel = TextPainter(
      text: TextSpan(
        text: 'SPEED',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    spdLabel.paint(canvas, Offset(barX, barY - 11));
  }

  double _worldX(double tileIdx) {
    double x = 0, count = 0;
    for (final s in _segments) {
      for (int i = 0; i < s.len; i++) {
        if (count >= tileIdx) {
          return x + (tileIdx - (count - 0)) * s.dx * _kStep;
        }
        x += s.dx * _kStep;
        count++;
      }
      if (count >= tileIdx) break;
    }
    return x;
  }

  double _worldY(double tileIdx) {
    double y = 0, count = 0;
    for (final s in _segments) {
      for (int i = 0; i < s.len; i++) {
        if (count >= tileIdx) {
          return y + (tileIdx - (count - 0)) * s.dy * _kStep;
        }
        y += s.dy * _kStep;
        count++;
      }
      if (count >= tileIdx) break;
    }
    return y;
  }

  @override
  bool shouldRepaint(covariant _SpeedDemoPainter old) => old.t != t;
}

class _Seg {
  final int dx, dy, len;
  const _Seg(this.dx, this.dy, this.len);
}

double _smoothStep(double x) => x * x * (3 - 2 * x);
