import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> whackAMoleSteps() => [
      GameHowToPlayStep(
        text: 'Moles pop up from holes — tap them fast!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _MolePopPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Golden moles are worth bonus points — don\'t miss!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2600),
          painter: (t) => _GoldenMolePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Avoid bombs — they cost points and time!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2400),
          painter: (t) => _BombPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kBrown    = Color(0xFF8B6914);
const _kDarkHole = Color(0xFF3D2B1F);
const _kGrass    = Color(0xFF4CAF50);
const _kGold     = Color(0xFFFFD700);
const _kRed      = Color(0xFFEF4444);

void _drawGrassBackground(Canvas canvas, Size size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF2D5A27), Color(0xFF1B3D17)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
  );
}

void _drawHole(Canvas canvas, double cx, double cy, double w, double h) {
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
    Paint()..color = _kDarkHole,
  );
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
    Paint()
      ..color = _kDarkHole.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0,
  );
}

void _drawMole(Canvas canvas, double cx, double cy, double popUp, {bool golden = false}) {
  final bodyColor = golden ? _kGold : _kBrown;
  final bodyH = 28.0 * popUp;
  if (bodyH <= 0) return;

  final bodyRect = Rect.fromCenter(
    center: Offset(cx, cy - bodyH / 2),
    width: 30,
    height: bodyH,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(bodyRect, const Radius.circular(14)),
    Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(bodyColor, Colors.white, 0.35)!,
          bodyColor,
          Color.lerp(bodyColor, Colors.black, 0.20)!,
        ],
        stops: const [0.0, 0.5, 1.0],
        center: const Alignment(-0.3, -0.3),
      ).createShader(bodyRect),
  );

  if (popUp > 0.4) {
    final eyeY = cy - bodyH * 0.65;
    canvas.drawCircle(Offset(cx - 6, eyeY), 3, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + 6, eyeY), 3, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx - 6, eyeY), 1.5, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(cx + 6, eyeY), 1.5, Paint()..color = Colors.black);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, eyeY + 6), width: 6, height: 3),
      Paint()..color = const Color(0xFFFF8A80),
    );
  }

  if (golden && popUp > 0.3) {
    canvas.drawCircle(
      Offset(cx, cy - bodyH),
      12,
      Paint()
        ..color = _kGold.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}

class _MolePopPainter extends CustomPainter {
  final double t;
  const _MolePopPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrassBackground(canvas, size);

    final cx = size.width / 2;
    final cy = size.height * 0.55;
    _drawHole(canvas, cx, cy, 50, 18);

    double popUp;
    if (t < 0.15) {
      popUp = t / 0.15;
    } else if (t < 0.50) {
      popUp = 1.0;
    } else if (t < 0.55) {
      final tapT = (t - 0.50) / 0.05;
      popUp = 1.0 - tapT;
    } else {
      popUp = 0.0;
    }

    _drawMole(canvas, cx, cy - 2, popUp);

    if (t >= 0.50 && t < 0.70) {
      final hitAlpha = 1.0 - (t - 0.50) / 0.20;
      final tp = TextPainter(
        text: TextSpan(
          text: '+10',
          style: TextStyle(
            color: _kGrass.withValues(alpha: hitAlpha),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - 50 - (t - 0.50) * 40));
    }
  }

  @override
  bool shouldRepaint(covariant _MolePopPainter old) => old.t != t;
}

class _GoldenMolePainter extends CustomPainter {
  final double t;
  const _GoldenMolePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrassBackground(canvas, size);

    final cx = size.width / 2;
    final cy = size.height * 0.55;
    _drawHole(canvas, cx, cy, 50, 18);

    double popUp;
    if (t < 0.12) {
      popUp = t / 0.12;
    } else if (t < 0.38) {
      popUp = 1.0;
    } else if (t < 0.42) {
      popUp = 1.0 - (t - 0.38) / 0.04;
    } else {
      popUp = 0.0;
    }

    _drawMole(canvas, cx, cy - 2, popUp, golden: true);

    if (t >= 0.42 && t < 0.68) {
      final hitAlpha = 1.0 - (t - 0.42) / 0.26;
      final sparkle = math.sin(t * math.pi * 8) * 0.3 + 0.7;
      final tp = TextPainter(
        text: TextSpan(
          text: '+25 ⭐',
          style: TextStyle(
            color: _kGold.withValues(alpha: hitAlpha * sparkle),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - 50 - (t - 0.42) * 40));
    }
  }

  @override
  bool shouldRepaint(covariant _GoldenMolePainter old) => old.t != t;
}

class _BombPainter extends CustomPainter {
  final double t;
  const _BombPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrassBackground(canvas, size);

    final cx = size.width / 2;
    final cy = size.height * 0.55;
    _drawHole(canvas, cx, cy, 50, 18);

    double popUp;
    if (t < 0.12) {
      popUp = t / 0.12;
    } else if (t < 0.45) {
      popUp = 1.0;
    } else if (t < 0.50) {
      popUp = 1.0 - (t - 0.45) / 0.05;
    } else {
      popUp = 0.0;
    }

    if (popUp > 0) {
      final bodyH = 26.0 * popUp;
      final bombRect = Rect.fromCenter(
        center: Offset(cx, cy - 2 - bodyH / 2),
        width: 28,
        height: bodyH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bombRect, const Radius.circular(12)),
        Paint()..color = const Color(0xFF333333),
      );
      if (popUp > 0.4) {
        canvas.drawCircle(
          Offset(cx, cy - 2 - bodyH * 0.65),
          4,
          Paint()..color = _kRed,
        );
        final fuseT = (math.sin(t * math.pi * 12) + 1) / 2;
        canvas.drawCircle(
          Offset(cx, cy - 2 - bodyH - 4),
          3 + fuseT * 2,
          Paint()..color = Color.lerp(_kRed, Colors.orange, fuseT)!.withValues(alpha: 0.85),
        );
      }
    }

    if (t >= 0.50 && t < 0.75) {
      final alpha = 1.0 - (t - 0.50) / 0.25;
      final flashR = (t - 0.50) / 0.25 * 45;
      canvas.drawCircle(
        Offset(cx, cy - 20),
        flashR,
        Paint()..color = _kRed.withValues(alpha: alpha * 0.30),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '-15  −3s',
          style: TextStyle(
            color: _kRed.withValues(alpha: alpha),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - 55 - (t - 0.50) * 30));
    }
  }

  @override
  bool shouldRepaint(covariant _BombPainter old) => old.t != t;
}
