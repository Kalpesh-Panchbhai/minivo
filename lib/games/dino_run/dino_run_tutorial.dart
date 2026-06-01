import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import 'dino_run_logo.dart' show drawPixelDino;

List<GameHowToPlayStep> dinoRunSteps() => [
      GameHowToPlayStep(
        text: 'Tap the screen to jump over obstacles',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _DinoJumpPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Speed increases — survive as long as you can!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _DinoSpeedPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const Color _kDino  = Color(0xFF535353);
const Color _kBg    = Color(0xFFF7F7F7);
const Color _kGround = Color(0xFF535353);

void _drawBg(Canvas canvas, Size size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = _kBg,
  );
}

void _drawGroundLine(Canvas canvas, Size size) {
  final groundY = size.height * 0.78;
  canvas.drawLine(
    Offset(0, groundY),
    Offset(size.width, groundY),
    Paint()
      ..color = _kGround
      ..strokeWidth = 1.5,
  );
}

void _drawDinoStanding(Canvas canvas, double cx, double cy) {
  drawPixelDino(canvas, cx - 10, cy + 4, 1.4, _kDino, _kBg);
}

void _drawCactus(Canvas canvas, double cx, double groundY) {
  final paint = Paint()..color = _kDino;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 3, groundY - 22, 6, 22),
      const Radius.circular(2),
    ),
    paint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(cx + 3, groundY - 16, 4, 10),
      const Radius.circular(2),
    ),
    paint,
  );
}

class _DinoJumpPainter extends CustomPainter {
  final double t;
  const _DinoJumpPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    _drawGroundLine(canvas, size);

    final groundY = size.height * 0.78;
    final dinoX = size.width * 0.30;

    final cactusX = size.width * 0.30 + (1 - t) * size.width * 0.6;
    _drawCactus(canvas, cactusX, groundY);

    final jumpT = t < 0.5 ? t * 2 : 2 - t * 2;
    final jumpH = math.sin(jumpT * math.pi) * 40;
    final dinoY = groundY - jumpH;

    _drawDinoStanding(canvas, dinoX, dinoY);

    final rippleAlpha = (1 - t).clamp(0.0, 1.0) * 0.5;
    final rippleR = 8 + t * 20;
    canvas.drawCircle(
      Offset(dinoX, groundY - 20),
      rippleR,
      Paint()
        ..color = _kDino.withValues(alpha: rippleAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final fadeIn = (math.sin(t * 2 * math.pi * 0.5) + 1) / 2;
    final tp = TextPainter(
      text: TextSpan(
        text: 'TAP',
        style: TextStyle(
          color: _kDino.withValues(alpha: fadeIn * 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(dinoX - tp.width / 2, groundY + 8));
  }

  @override
  bool shouldRepaint(covariant _DinoJumpPainter old) => old.t != t;
}

class _DinoSpeedPainter extends CustomPainter {
  final double t;
  const _DinoSpeedPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    _drawGroundLine(canvas, size);

    final groundY = size.height * 0.78;
    final dinoX = size.width * 0.25;
    _drawDinoStanding(canvas, dinoX, groundY);

    final speed = 0.4 + t * 0.6;
    for (int i = 0; i < 3; i++) {
      final lineX = dinoX - 14 - i * 8.0;
      final lineAlpha = (speed - 0.3).clamp(0.0, 1.0) * 0.6;
      canvas.drawLine(
        Offset(lineX, groundY - 10),
        Offset(lineX - 6, groundY - 10),
        Paint()
          ..color = _kDino.withValues(alpha: lineAlpha)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    final cactus1X = size.width * 0.55 + (1 - t) * size.width * speed * 0.6;
    final cactus2X = cactus1X + size.width * 0.35;
    if (cactus1X > -10 && cactus1X < size.width + 10) _drawCactus(canvas, cactus1X, groundY);
    if (cactus2X > -10 && cactus2X < size.width + 10) _drawCactus(canvas, cactus2X, groundY);

    final scoreVal = (t * 500).toInt();
    final tp = TextPainter(
      text: TextSpan(
        text: scoreVal.toString().padLeft(5, '0'),
        style: const TextStyle(
          color: _kDino,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 8, 8));
  }

  @override
  bool shouldRepaint(covariant _DinoSpeedPainter old) => old.t != t;
}
