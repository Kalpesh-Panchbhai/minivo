import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> nutsAndBoltsSteps() => [
  GameHowToPlayStep(
    text: 'Tap a bolt to pick up the top nut, then tap another bolt to place it.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _MovePainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'You can only place a nut on an empty bolt or on top of the same color.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _RulePainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'Sort all nuts so each bolt has only one color. Watch an ad to unlock extra bolt space!',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _SolvedPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
];

class _MovePainter extends CustomPainter {
  final double t;
  _MovePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    for (int i = 0; i < 2; i++) {
      final cx = w * (i == 0 ? 0.3 : 0.7);
      final baseY = h * 0.8;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, baseY), width: 44, height: 6), const Radius.circular(3)),
        Paint()..color = const Color(0xFF78716C),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, baseY - 35), width: 4, height: 60), const Radius.circular(2)),
        Paint()..color = const Color(0xFFA8A29E),
      );
    }

    final nutW = 36.0;
    final nutH = 14.0;

    if (t < 0.5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.3, h * 0.55), width: nutW, height: nutH), const Radius.circular(4)),
        Paint()..color = const Color(0xFFEF4444),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.3, h * 0.70), width: nutW, height: nutH), const Radius.circular(4)),
        Paint()..color = const Color(0xFF3B82F6),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.7, h * 0.70), width: nutW, height: nutH), const Radius.circular(4)),
        Paint()..color = const Color(0xFFEF4444),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.3, h * 0.70), width: nutW, height: nutH), const Radius.circular(4)),
        Paint()..color = const Color(0xFF3B82F6),
      );
    }
  }

  @override
  bool shouldRepaint(_MovePainter old) => true;
}

class _RulePainter extends CustomPainter {
  final double t;
  _RulePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final ok = t < 0.5;
    final color = ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final icon = ok ? '✓' : '✗';

    final tp = TextPainter(
      text: TextSpan(text: icon, style: TextStyle(color: color, fontSize: 40, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - 10));

    final label = ok ? 'Same color → OK' : 'Different → No';
    final ltp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    ltp.paint(canvas, Offset(cx - ltp.width / 2, cy + 24));
  }

  @override
  bool shouldRepaint(_RulePainter old) => true;
}

class _SolvedPainter extends CustomPainter {
  final double t;
  _SolvedPainter(this.t);

  static const _colors = [Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFF22C55E)];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final nutW = 30.0;
    final nutH = 12.0;
    final gap = 24.0;
    final totalW = nutW * 3 + gap * 2;
    final startX = (w - totalW) / 2 + nutW / 2;
    final baseY = h * 0.75;

    for (int b = 0; b < 3; b++) {
      final cx = startX + b * (nutW + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, baseY), width: nutW + 6, height: 5), const Radius.circular(3)),
        Paint()..color = const Color(0xFF78716C),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, baseY - 28), width: 3, height: 50), const Radius.circular(2)),
        Paint()..color = const Color(0xFFA8A29E),
      );
      for (int n = 0; n < 3; n++) {
        final ny = baseY - 7 - n * (nutH + 3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, ny), width: nutW, height: nutH), const Radius.circular(4)),
          Paint()..color = _colors[b],
        );
      }
    }

    final scale = 0.8 + 0.2 * math.sin(t * math.pi * 2);
    final tp = TextPainter(
      text: const TextSpan(text: '✓ Sorted!', style: TextStyle(color: Color(0xFF22C55E), fontSize: 16, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(w / 2, h * 0.18);
    canvas.scale(scale);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SolvedPainter old) => true;
}
