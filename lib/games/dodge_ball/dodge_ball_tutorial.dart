import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> dodgeBallSteps() => [
      GameHowToPlayStep(
        text: 'Drag left & right to dodge the falling obstacles',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _DodgeDemoPainter(t),
          canvasSize: const Size(200, 160),
        ),
      ),
      GameHowToPlayStep(
        text: 'Your ball grows over time — dodging gets harder!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _GrowDemoPainter(t),
          canvasSize: const Size(200, 160),
        ),
      ),
      GameHowToPlayStep(
        text: 'Walls close in & speed ramps up — survive as long as you can!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _WallSpeedDemoPainter(t),
          canvasSize: const Size(200, 160),
        ),
      ),
    ];

const Color _kBg = Color(0xFF0F0F23);
const Color _kPlayer = Color(0xFF00D4FF);
const Color _kPlayerLt = Color(0xFF66E5FF);
const List<Color> _kObs = [
  Color(0xFFFF6B6B),
  Color(0xFFFFD93D),
  Color(0xFFFF9FF3),
  Color(0xFF6BCB77),
  Color(0xFFCC8EFF),
];

void _drawBg(Canvas canvas, Size size) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(12)),
    Paint()..color = _kBg,
  );
  final rng = math.Random(5);
  for (int i = 0; i < 15; i++) {
    canvas.drawCircle(
      Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.6),
      0.6 + rng.nextDouble() * 0.5,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
  }
}

void _drawPlayer(Canvas canvas, double x, double y, double r) {
  canvas.drawCircle(
    Offset(x, y),
    r + 6,
    Paint()
      ..color = _kPlayer.withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );
  final grad = RadialGradient(
    center: const Alignment(-0.3, -0.4),
    colors: [_kPlayerLt, _kPlayer, const Color(0xFF0099CC)],
    stops: const [0.0, 0.5, 1.0],
  );
  canvas.drawCircle(
    Offset(x, y),
    r,
    Paint()..shader = grad.createShader(Rect.fromCircle(center: Offset(x, y), radius: r)),
  );
  canvas.drawCircle(
    Offset(x - r * 0.22, y - r * 0.22),
    r * 0.25,
    Paint()..color = Colors.white.withValues(alpha: 0.35),
  );
}

void _drawObs(Canvas canvas, double x, double y, double r, Color color) {
  canvas.drawCircle(
    Offset(x, y),
    r + 4,
    Paint()
      ..color = color.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
  canvas.drawCircle(
    Offset(x - r * 0.25, y - r * 0.25),
    r * 0.2,
    Paint()..color = Colors.white.withValues(alpha: 0.30),
  );
}

void _drawLabel(Canvas canvas, Size size, String text, double alpha) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: _kPlayer.withValues(alpha: alpha),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - tp.height - 6));
}

class _DodgeDemoPainter extends CustomPainter {
  final double t;
  const _DodgeDemoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);

    final playerR = size.width * 0.055;
    final playerY = size.height * 0.78;
    final playerX = size.width * 0.5 + math.sin(t * 2 * math.pi) * size.width * 0.28;

    for (int i = 0; i < 4; i++) {
      final obsX = size.width * (0.15 + i * 0.23);
      final obsY = ((t + i * 0.25) % 1.0) * size.height * 0.7;
      final obsR = size.width * 0.035 + (i % 2) * 2;
      _drawObs(canvas, obsX, obsY, obsR, _kObs[i % _kObs.length]);
    }

    _drawPlayer(canvas, playerX, playerY, playerR);

    final arrowAlpha = (math.sin(t * math.pi * 4) + 1) / 2 * 0.7;
    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: arrowAlpha)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(playerX - 18, playerY), Offset(playerX - 26, playerY), arrowPaint);
    canvas.drawLine(Offset(playerX - 26, playerY), Offset(playerX - 22, playerY - 4), arrowPaint);
    canvas.drawLine(Offset(playerX - 26, playerY), Offset(playerX - 22, playerY + 4), arrowPaint);
    canvas.drawLine(Offset(playerX + 18, playerY), Offset(playerX + 26, playerY), arrowPaint);
    canvas.drawLine(Offset(playerX + 26, playerY), Offset(playerX + 22, playerY - 4), arrowPaint);
    canvas.drawLine(Offset(playerX + 26, playerY), Offset(playerX + 22, playerY + 4), arrowPaint);

    final fadeIn = (math.sin(t * math.pi * 2) + 1) / 2;
    _drawLabel(canvas, size, '← DRAG →', fadeIn * 0.9);
  }

  @override
  bool shouldRepaint(covariant _DodgeDemoPainter old) => old.t != t;
}

class _GrowDemoPainter extends CustomPainter {
  final double t;
  const _GrowDemoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);

    final baseR = size.width * 0.04;
    final maxR = size.width * 0.11;
    final playerR = baseR + (maxR - baseR) * t;
    final playerX = size.width * 0.5;
    final playerY = size.height * 0.72;

    for (int i = 0; i < 3; i++) {
      final obsX = size.width * (0.2 + i * 0.3);
      final obsY = ((t * 0.8 + i * 0.33) % 1.0) * size.height * 0.55;
      _drawObs(canvas, obsX, obsY, size.width * 0.03, _kObs[i]);
    }

    _drawPlayer(canvas, playerX, playerY, playerR);

    final gap1 = size.width * 0.2 - playerR;
    final gap2 = size.width * 0.3 - playerR;
    final tightColor = gap1 < 10 || gap2 < 10
        ? const Color(0xFFFF6B6B)
        : _kPlayer;

    final sizeLabel = '${(playerR / maxR * 100).toInt()}%';
    final tp = TextPainter(
      text: TextSpan(
        text: sizeLabel,
        style: TextStyle(
          color: tightColor.withValues(alpha: 0.8),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(playerX - tp.width / 2, playerY + playerR + 8));

    _drawLabel(canvas, size, 'BALL GROWS', 0.7);
  }

  @override
  bool shouldRepaint(covariant _GrowDemoPainter old) => old.t != t;
}

class _WallSpeedDemoPainter extends CustomPainter {
  final double t;
  const _WallSpeedDemoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);

    final wallInset = t * size.width * 0.15;

    if (wallInset > 1) {
      final wallAlpha = 0.15 + t * 0.20;
      final leftGrad = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          const Color(0xFF7B61FF).withValues(alpha: 0.0),
          const Color(0xFF7B61FF).withValues(alpha: wallAlpha),
        ],
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, wallInset, size.height),
        Paint()..shader = leftGrad.createShader(Rect.fromLTWH(0, 0, wallInset, size.height)),
      );
      final rightGrad = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF7B61FF).withValues(alpha: 0.0),
          const Color(0xFF7B61FF).withValues(alpha: wallAlpha),
        ],
      );
      canvas.drawRect(
        Rect.fromLTWH(size.width - wallInset, 0, wallInset, size.height),
        Paint()..shader = rightGrad.createShader(Rect.fromLTWH(size.width - wallInset, 0, wallInset, size.height)),
      );
      final edgePaint = Paint()
        ..color = const Color(0xFF9B7BFF).withValues(alpha: wallAlpha + 0.15)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawLine(Offset(wallInset, 0), Offset(wallInset, size.height), edgePaint);
      canvas.drawLine(Offset(size.width - wallInset, 0), Offset(size.width - wallInset, size.height), edgePaint);
    }

    final playerR = size.width * 0.045;
    final playerX = size.width * 0.5 + math.sin(t * math.pi * 3) * (size.width * 0.2 - wallInset);
    final playerY = size.height * 0.78;

    final speed = 0.5 + t * 0.8;
    for (int i = 0; i < 5; i++) {
      final obsX = wallInset + size.width * 0.08 + (i * 0.18) * (size.width - wallInset * 2);
      final obsY = ((t * speed + i * 0.2) % 1.0) * size.height * 0.65;
      _drawObs(canvas, obsX.clamp(wallInset + 8, size.width - wallInset - 8), obsY, size.width * 0.03, _kObs[i % _kObs.length]);
    }

    _drawPlayer(canvas, playerX.clamp(wallInset + playerR, size.width - wallInset - playerR), playerY, playerR);

    final scoreVal = (t * 500).toInt();
    final tp = TextPainter(
      text: TextSpan(
        text: scoreVal.toString().padLeft(4, '0'),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 10, 8));

    _drawLabel(canvas, size, 'WALLS CLOSE IN', 0.7);
  }

  @override
  bool shouldRepaint(covariant _WallSpeedDemoPainter old) => old.t != t;
}
