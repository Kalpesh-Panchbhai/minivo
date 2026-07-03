import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import 'dino_run_logo.dart' show drawPixelDino;

List<GameHowToPlayStep> dinoRunSteps() => [
      GameHowToPlayStep(
        text: 'Tap to jump over obstacles!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _JumpPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Speed increases — survive as long as you can!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3500),
          painter: (t) => _SpeedPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Hit an obstacle and it\'s game over!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3500),
          painter: (t) => _GameOverPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
    ];

const Color _kDino = Color(0xFF535353);
const Color _kBg = Color(0xFFF7F7F7);
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

void _drawDino(
  Canvas canvas,
  double cx,
  double cy, {
  bool dead = false,
  double? legPhase,
  bool inAir = false,
}) {
  drawPixelDino(canvas, cx - 10, cy + 4, 1.4, _kDino, _kBg,
      dead: dead, legPhase: legPhase, inAir: inAir);
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

// ── Step 1 — Tap to jump ────────────────────────────────────────────────

class _JumpPainter extends CustomPainter {
  final double t;
  const _JumpPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    _drawGroundLine(canvas, size);

    final groundY = size.height * 0.78;
    final dinoX = size.width * 0.28;

    final cactusX = dinoX + size.width * 1.7 * (0.5 - t);
    if (cactusX > -10 && cactusX < size.width + 10) {
      _drawCactus(canvas, cactusX, groundY);
    }

    const jumpStart = 0.30;
    const jumpEnd = 0.70;
    final jumping = t >= jumpStart && t <= jumpEnd;
    final jumpPhase =
        ((t - jumpStart) / (jumpEnd - jumpStart)).clamp(0.0, 1.0);
    final jumpH = jumping ? math.sin(jumpPhase * math.pi) * 48 : 0.0;
    final dinoY = groundY - jumpH;

    _drawDino(canvas, dinoX, dinoY,
        legPhase: jumping ? null : t * 30, inAir: jumping);

    const tapAppear = 0.24;
    const tapPeak = 0.31;
    const tapGone = 0.50;
    double tapAlpha = 0;
    if (t >= tapAppear && t < tapPeak) {
      tapAlpha = (t - tapAppear) / (tapPeak - tapAppear);
    } else if (t >= tapPeak && t < tapGone) {
      tapAlpha = 1.0 - (t - tapPeak) / (tapGone - tapPeak);
    }
    tapAlpha = tapAlpha.clamp(0.0, 1.0);

    if (tapAlpha > 0.01) {
      final rippleP =
          ((t - tapAppear) / (tapGone - tapAppear)).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(dinoX, groundY + 16),
        6 + rippleP * 18,
        Paint()
          ..color = _kDino.withValues(alpha: tapAlpha * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: 'TAP',
          style: TextStyle(
            color: _kDino.withValues(alpha: tapAlpha * 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(dinoX - tp.width / 2, groundY + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _JumpPainter old) => old.t != t;
}

// ── Step 2 — Speed increases ────────────────────────────────────────────

class _SpeedPainter extends CustomPainter {
  final double t;
  const _SpeedPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    _drawGroundLine(canvas, size);

    final groundY = size.height * 0.78;
    final dinoX = size.width * 0.25;
    final rate = size.width * 2.5;

    const a1 = 0.30;
    const a2 = 0.68;
    final c1x = dinoX + rate * (a1 - t);
    final c2x = dinoX + rate * (a2 - t);

    if (c1x > -10 && c1x < size.width + 10) _drawCactus(canvas, c1x, groundY);
    if (c2x > -10 && c2x < size.width + 10) _drawCactus(canvas, c2x, groundY);

    const j1s = 0.15, j1e = 0.45;
    const j2s = 0.53, j2e = 0.83;

    double jumpH = 0;
    bool inAir = false;
    if (t >= j1s && t <= j1e) {
      jumpH = math.sin(((t - j1s) / (j1e - j1s)) * math.pi) * 46;
      inAir = true;
    } else if (t >= j2s && t <= j2e) {
      jumpH = math.sin(((t - j2s) / (j2e - j2s)) * math.pi) * 46;
      inAir = true;
    }

    final dinoY = groundY - jumpH;
    _drawDino(canvas, dinoX, dinoY,
        legPhase: inAir ? null : t * 30, inAir: inAir);

    final lineAlpha = (0.15 + t * 0.65).clamp(0.0, 0.8);
    final lineLen = 4.0 + t * 12;
    final lp = Paint()
      ..color = _kDino.withValues(alpha: lineAlpha)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final lx = dinoX - 16 - i * 7.0;
      final ly = dinoY - 4 + i * 6.0;
      canvas.drawLine(Offset(lx, ly), Offset(lx - lineLen, ly), lp);
    }

    final score = (t * 500).toInt();
    final tp = TextPainter(
      text: TextSpan(
        text: score.toString().padLeft(5, '0'),
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
  bool shouldRepaint(covariant _SpeedPainter old) => old.t != t;
}

// ── Step 3 — Game over ──────────────────────────────────────────────────

class _GameOverPainter extends CustomPainter {
  final double t;
  const _GameOverPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    _drawGroundLine(canvas, size);

    final groundY = size.height * 0.78;
    final dinoX = size.width * 0.28;
    final rate = size.width * 2.0;
    const hitT = 0.45;

    final stopX = dinoX + 10;
    final cactusX = t <= hitT ? stopX + rate * (hitT - t) : stopX;
    if (cactusX > -10 && cactusX < size.width + 10) {
      _drawCactus(canvas, cactusX, groundY);
    }

    final dead = t > hitT;
    _drawDino(canvas, dinoX, groundY,
        dead: dead, legPhase: dead ? null : t * 30);

    if (t > hitT && t < hitT + 0.10) {
      final flash = (1.0 - (t - hitT) / 0.10) * 0.28;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.red.withValues(alpha: flash),
      );
    }

    if (t > hitT + 0.08) {
      final fade = ((t - hitT - 0.08) / 0.25).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'GAME OVER',
          style: TextStyle(
            color: _kDino.withValues(alpha: fade),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, size.height * 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GameOverPainter old) => old.t != t;
}
