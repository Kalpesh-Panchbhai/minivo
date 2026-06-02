import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> tapTapDashSteps() => [
      GameHowToPlayStep(
        text: 'Your ball runs forward automatically — tap to turn at corners',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _TurnDemoPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Turn too late and you fall off — timing is everything!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2500),
          painter: (t) => _FallDemoPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const Color _kBg     = Color(0xFF1A1A2E);
const Color _kPath   = Color(0xFF00D4FF);
const Color _kPlayer = Color(0xFF00D4FF);
const double _kTileS = 22.0;

void _drawBg(Canvas canvas, Size size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = _kBg,
  );
}

void _drawTile(Canvas canvas, double x, double y) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, _kTileS, _kTileS),
      const Radius.circular(3),
    ),
    Paint()..color = _kPath.withValues(alpha: 0.25),
  );
}

void _drawPlayer(Canvas canvas, double x, double y, {double glow = 1.0}) {
  if (glow > 0) {
    canvas.drawCircle(
      Offset(x + _kTileS / 2, y + _kTileS / 2),
      _kTileS * 0.6,
      Paint()..color = _kPlayer.withValues(alpha: 0.2 * glow),
    );
  }
  canvas.drawCircle(
    Offset(x + _kTileS / 2, y + _kTileS / 2),
    _kTileS * 0.32,
    Paint()..color = _kPlayer,
  );
}

class _TurnDemoPainter extends CustomPainter {
  final double t;
  const _TurnDemoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);

    final ox = size.width * 0.15;
    final oy = size.height * 0.25;

    for (int i = 0; i < 5; i++) {
      _drawTile(canvas, ox + i * _kTileS, oy);
    }
    for (int i = 1; i < 4; i++) {
      _drawTile(canvas, ox + 4 * _kTileS, oy + i * _kTileS);
    }

    final turnPoint = 4.0;
    final totalSteps = turnPoint + 3.0;
    final progress = t * totalSteps;

    double px, py;
    if (progress <= turnPoint) {
      px = ox + progress * _kTileS;
      py = oy;
    } else {
      px = ox + turnPoint * _kTileS;
      py = oy + (progress - turnPoint) * _kTileS;
    }

    _drawPlayer(canvas, px, py);

    if (t > 0.4 && t < 0.7) {
      final fadeIn = ((t - 0.4) / 0.1).clamp(0.0, 1.0);
      final fadeOut = ((0.7 - t) / 0.1).clamp(0.0, 1.0);
      final alpha = fadeIn * fadeOut;
      final tp = TextPainter(
        text: TextSpan(
          text: 'TAP!',
          style: TextStyle(
            color: Colors.white.withValues(alpha: alpha * 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height - 30));
    }
  }

  @override
  bool shouldRepaint(covariant _TurnDemoPainter old) => old.t != t;
}

class _FallDemoPainter extends CustomPainter {
  final double t;
  const _FallDemoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);

    final ox = size.width * 0.15;
    final oy = size.height * 0.30;

    for (int i = 0; i < 4; i++) {
      _drawTile(canvas, ox + i * _kTileS, oy);
    }
    for (int i = 1; i < 3; i++) {
      _drawTile(canvas, ox + 3 * _kTileS, oy + i * _kTileS);
    }

    final endOfPath = 3.0;
    final totalSteps = endOfPath + 2.5;
    final progress = t * totalSteps;

    double px = ox + math.min(progress, endOfPath + 1.5) * _kTileS;
    double py = oy;

    final falling = progress > endOfPath + 0.5;
    if (falling) {
      final fallT = (progress - endOfPath - 0.5) / 2.0;
      py = oy + fallT * fallT * size.height * 1.5;
    }

    final glow = falling ? (1.0 - ((progress - endOfPath - 0.5) / 2.0).clamp(0.0, 1.0)) : 1.0;
    _drawPlayer(canvas, px, py, glow: glow);

    if (falling) {
      final alpha = (1.0 - ((progress - endOfPath - 0.5) / 1.5).clamp(0.0, 1.0));
      final tp = TextPainter(
        text: TextSpan(
          text: '💀',
          style: TextStyle(fontSize: 20 * alpha),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height * 0.15));
    }
  }

  @override
  bool shouldRepaint(covariant _FallDemoPainter old) => old.t != t;
}
