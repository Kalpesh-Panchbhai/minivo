import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> slidingPuzzleSteps() => [
      GameHowToPlayStep(
        text: 'Tap a tile next to the empty space to slide it into place.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _SlidePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Arrange all tiles in order — numbers or image pieces!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _OrderPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Solve it fast with fewer moves for a higher score!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _ScorePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kBg = Color(0xFF1A0F2E);
const _kAccent = Color(0xFF8B5CF6);
const _kTile = Color(0xFF7C3AED);

void _drawBg(Canvas canvas, Size size) {
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBg);
  canvas.drawCircle(
    Offset(size.width / 2, size.height * 0.5),
    size.width * 0.5,
    Paint()..shader = RadialGradient(colors: [_kAccent.withValues(alpha: 0.10), Colors.transparent])
        .createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.5), radius: size.width * 0.5)),
  );
}

void _drawTile(Canvas canvas, double x, double y, double s, String label, {double alpha = 1.0}) {
  final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, s, s), Radius.circular(s * 0.15));
  canvas.drawRRect(rect, Paint()..color = _kTile.withValues(alpha: alpha));
  canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, s, s * 0.35), Radius.circular(s * 0.15)),
    Paint()..color = Colors.white.withValues(alpha: 0.15 * alpha),
  );
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(color: Colors.white.withValues(alpha: alpha), fontSize: s * 0.45, fontWeight: FontWeight.w900),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(x + s / 2 - tp.width / 2, y + s / 2 - tp.height / 2));
}

class _SlidePainter extends CustomPainter {
  final double t;
  const _SlidePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    final cs = size.width * 0.2;
    final sx = size.width * 0.12;
    final sy = size.height * 0.12;
    final gap = cs + 4;

    final tiles = [1, 2, 3, 4, 0, 5, 6, 7, 8];
    final moveT = t.clamp(0.0, 1.0);

    for (int i = 0; i < 9; i++) {
      final r = i ~/ 3;
      final c = i % 3;
      if (tiles[i] == 0) continue;
      var tx = sx + c * gap;
      var ty = sy + r * gap;
      if (tiles[i] == 5 && moveT > 0.4 && moveT < 0.8) {
        final mt = ((moveT - 0.4) / 0.4);
        tx -= mt * gap;
      }
      _drawTile(canvas, tx, ty, cs, '${tiles[i]}');
    }

    final tp = TextPainter(
      text: TextSpan(
        text: 'Tap to slide',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height * 0.88));
  }

  @override
  bool shouldRepaint(covariant _SlidePainter old) => old.t != t;
}

class _OrderPainter extends CustomPainter {
  final double t;
  const _OrderPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    final cs = size.width * 0.2;
    final sx = size.width * 0.12;
    final sy = size.height * 0.12;
    final gap = cs + 4;

    final progress = (t * 9).floor().clamp(0, 8);
    for (int i = 0; i < 9; i++) {
      final r = i ~/ 3;
      final c = i % 3;
      if (i == 8) continue;
      final alpha = i < progress ? 1.0 : 0.4;
      _drawTile(canvas, sx + c * gap, sy + r * gap, cs, '${i + 1}', alpha: alpha);
    }

    if (progress >= 8) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'SOLVED!',
          style: TextStyle(color: Color(0xFF22C55E).withValues(alpha: ((t - 0.85) / 0.15).clamp(0.0, 1.0)), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height * 0.88));
    }
  }

  @override
  bool shouldRepaint(covariant _OrderPainter old) => old.t != t;
}

class _ScorePainter extends CustomPainter {
  final double t;
  const _ScorePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);
    final moves = (t * 50).floor();
    final timeS = (t * 120).floor();

    final tp1 = TextPainter(
      text: TextSpan(
        text: 'Moves: $moves',
        style: TextStyle(color: _kAccent, fontSize: 16, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp1.paint(canvas, Offset(size.width / 2 - tp1.width / 2, size.height * 0.35));

    final m = timeS ~/ 60;
    final s = timeS % 60;
    final tp2 = TextPainter(
      text: TextSpan(
        text: 'Time: ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(size.width / 2 - tp2.width / 2, size.height * 0.5));

    final score = math.max(0, 1000 - moves * 5 - timeS);
    final tp3 = TextPainter(
      text: TextSpan(
        text: 'Score: $score',
        style: TextStyle(color: const Color(0xFFFEC84B), fontSize: 18, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp3.paint(canvas, Offset(size.width / 2 - tp3.width / 2, size.height * 0.68));
  }

  @override
  bool shouldRepaint(covariant _ScorePainter old) => old.t != t;
}
