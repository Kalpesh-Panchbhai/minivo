import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> slidingPuzzleSteps() => [
      GameHowToPlayStep(
        text: 'Tap a tile next to the empty space to slide it into place.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _SlidePainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Arrange all tiles in order — numbers or image pieces!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _OrderPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Solve it fast with fewer moves for a higher score!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _ScorePainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
    ];

const _kBg = Color(0xFF1A0F2E);
const _kAccent = Color(0xFF8B5CF6);
const _kTile = Color(0xFF7C3AED);
const _kGreen = Color(0xFF22C55E);

double _ease(double x) => x * x * (3 - 2 * x);

void _drawBg(Canvas canvas, Size size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = _kBg,
  );
  canvas.drawCircle(
    Offset(size.width / 2, size.height * 0.5),
    size.width * 0.5,
    Paint()
      ..shader = RadialGradient(
        colors: [_kAccent.withValues(alpha: 0.10), Colors.transparent],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.5),
          radius: size.width * 0.5,
        ),
      ),
  );
}

void _drawTile(
  Canvas canvas,
  double x,
  double y,
  double s,
  String label, {
  double alpha = 1.0,
}) {
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(x, y, s, s),
    Radius.circular(s * 0.15),
  );
  canvas.drawRRect(rect, Paint()..color = _kTile.withValues(alpha: alpha));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, s, s * 0.35),
      Radius.circular(s * 0.15),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.15 * alpha),
  );
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: alpha),
        fontSize: s * 0.45,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
    canvas,
    Offset(x + s / 2 - tp.width / 2, y + s / 2 - tp.height / 2),
  );
}

class _SlidePainter extends CustomPainter {
  final double t;
  const _SlidePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBg(canvas, size);

    const cs = 34.0;
    const sp = 4.0;
    const gap = cs + sp;
    final sx = (size.width - 3 * cs - 2 * sp) / 2;
    final sy = (size.height - 3 * cs - 2 * sp) / 2 - 10;

    // Board: 1 2 3 / 4 _ 5 / 6 7 8
    // Move 1 (t 0.12–0.38): tile 5 slides LEFT  (r1,c2)→(r1,c1)
    //   empty moves (r1,c1)→(r1,c2)
    //   Result: 1 2 3 / 4 5 _ / 6 7 8
    // Move 2 (t 0.52–0.78): tile 2 slides DOWN   (r0,c1)→(r1,c1)
    //   But tile 5 now occupies (r1,c1) — so we use tile 3 which
    //   is at (r0,c2) above the new empty at (r1,c2). Valid move.
    //   tile 3 slides DOWN (r0,c2)→(r1,c2), empty (r1,c2)→(r0,c2)
    //   Result: 1 2 _ / 4 5 3 / 6 7 8

    final m1 = t < 0.12
        ? 0.0
        : _ease(((t - 0.12) / 0.26).clamp(0.0, 1.0));
    final m2 = t < 0.52
        ? 0.0
        : _ease(((t - 0.52) / 0.26).clamp(0.0, 1.0));

    final pos = <int, List<double>>{
      1: [0, 0],
      2: [0, 1],
      3: [0 + m2, 2],
      4: [1, 0],
      5: [1, 2 - m1],
      6: [2, 0],
      7: [2, 1],
      8: [2, 2],
    };

    double eR, eC;
    if (m1 < 1.0) {
      eR = 1;
      eC = 1 + m1;
    } else {
      eR = 1 - m2;
      eC = 2;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          sx + eC * gap + 3,
          sy + eR * gap + 3,
          cs - 6,
          cs - 6,
        ),
        Radius.circular(cs * 0.10),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    for (final e in pos.entries) {
      _drawTile(
        canvas,
        sx + e.value[1] * gap,
        sy + e.value[0] * gap,
        cs,
        '${e.key}',
      );
    }

    if (t < 0.12) {
      final a = (math.sin(t * math.pi * 16) * 0.2 + 0.2).clamp(0.0, 0.5);
      _ring(canvas, sx + 2 * gap, sy + 1 * gap, cs, a);
    } else if (t >= 0.40 && t < 0.52) {
      final a =
          (math.sin((t - 0.40) * math.pi * 16) * 0.2 + 0.2).clamp(0.0, 0.5);
      _ring(canvas, sx + 2 * gap, sy + 0 * gap, cs, a);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: 'Tap to slide',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height - tp.height - 4),
    );
  }

  void _ring(Canvas canvas, double x, double y, double s, double a) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2, y - 2, s + 4, s + 4),
        Radius.circular(s * 0.18),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
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
    final cs = size.width * 0.17;
    final gap = cs + 4;
    final sx = (size.width - 3 * cs - 2 * 4) / 2;
    final sy = (size.height - 3 * cs - 2 * 4) / 2 - 10;

    final progress = (t * 9).floor().clamp(0, 8);
    for (int i = 0; i < 9; i++) {
      if (i == 8) continue;
      final r = i ~/ 3;
      final c = i % 3;
      final alpha = i < progress ? 1.0 : 0.4;
      _drawTile(
        canvas,
        sx + c * gap,
        sy + r * gap,
        cs,
        '${i + 1}',
        alpha: alpha,
      );
    }

    if (progress >= 8) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'SOLVED!',
          style: TextStyle(
            color: _kGreen.withValues(
              alpha: ((t - 0.85) / 0.15).clamp(0.0, 1.0),
            ),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          size.width / 2 - tp.width / 2,
          size.height - tp.height - 6,
        ),
      );
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

    const cs = 26.0;
    const sp = 3.0;
    const gap = cs + sp;
    final gridW = 3 * cs + 2 * sp;
    final sx = (size.width - gridW) / 2;
    const sy = 8.0;

    final reveal = _ease((t / 0.20).clamp(0.0, 1.0));
    final glow = _ease(((t - 0.15) / 0.15).clamp(0.0, 1.0));
    final solved = _ease(((t - 0.28) / 0.12).clamp(0.0, 1.0));
    final hud = _ease(((t - 0.40) / 0.15).clamp(0.0, 1.0));
    final check = _ease(((t - 0.55) / 0.15).clamp(0.0, 1.0));

    for (int i = 0; i < 8; i++) {
      final r = i ~/ 3;
      final c = i % 3;
      final a = (reveal * 9 - i).clamp(0.0, 1.0);
      if (a <= 0) continue;

      final x = sx + c * gap;
      final y = sy + r * gap;

      if (glow > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 2, y - 2, cs + 4, cs + 4),
            Radius.circular(cs * 0.18),
          ),
          Paint()..color = _kGreen.withValues(alpha: 0.20 * glow),
        );
      }

      _drawTile(canvas, x, y, cs, '${i + 1}', alpha: a);
    }

    if (solved > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'SOLVED!',
          style: TextStyle(
            color: _kGreen.withValues(alpha: solved),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width / 2 - tp.width / 2, sy + 3 * gap + 4),
      );
    }

    if (hud > 0) {
      final panelTop = sy + 3 * gap + 28;
      const panelH = 50.0;
      final panelW = size.width * 0.78;
      final panelX = (size.width - panelW) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(panelX, panelTop, panelW, panelH),
          const Radius.circular(10),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.07 * hud),
      );

      final movesTP = TextPainter(
        text: TextSpan(
          text: 'Moves: 24',
          style: TextStyle(
            color: _kAccent.withValues(alpha: hud),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      movesTP.paint(canvas, Offset(panelX + 12, panelTop + 8));

      final timeTP = TextPainter(
        text: TextSpan(
          text: 'Time: 01:30',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7 * hud),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      timeTP.paint(canvas, Offset(panelX + 12, panelTop + 28));

      if (check > 0) {
        final cx = panelX + panelW - 28;
        final cy = panelTop + panelH / 2;
        final r = 13.0 * check;

        canvas.drawCircle(
          Offset(cx, cy),
          r,
          Paint()..color = _kGreen.withValues(alpha: check),
        );

        if (check > 0.5) {
          final ca = ((check - 0.5) / 0.5).clamp(0.0, 1.0);
          final path = Path()
            ..moveTo(cx - 5, cy)
            ..lineTo(cx - 1, cy + 4)
            ..lineTo(cx + 6, cy - 4);
          canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withValues(alpha: ca)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScorePainter old) => old.t != t;
}
