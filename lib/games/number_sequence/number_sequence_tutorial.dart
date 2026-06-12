import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> numberSequenceSteps() => [
  GameHowToPlayStep(
    text: 'Numbers are scattered across the screen. Find and tap them in order: 1, 2, 3…',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _ScatterPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'Tap the correct next number. It disappears with a satisfying pop! Wrong taps do nothing.',
    demo: AnimatedDemo(
      period: const Duration(seconds: 2),
      painter: (t) => _TapPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
  GameHowToPlayStep(
    text: 'Complete the sequence as fast as possible. Your best time is saved per difficulty!',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _TimerPainter(t),
      canvasSize: const Size(200, 160),
    ),
  ),
];

class _ScatterPainter extends CustomPainter {
  final double t;
  _ScatterPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final positions = [
      [0.2, 0.3, '1'], [0.7, 0.2, '2'], [0.4, 0.6, '3'],
      [0.8, 0.7, '4'], [0.15, 0.75, '5'],
    ];
    final colors = [
      const Color(0xFF6366F1), const Color(0xFF8B5CF6), const Color(0xFF06B6D4),
      const Color(0xFFF59E0B), const Color(0xFFEF4444),
    ];
    for (int i = 0; i < positions.length; i++) {
      final p = positions[i];
      final cx = size.width * (p[0] as double);
      final cy = size.height * (p[1] as double);
      final r = 16.0;
      final phase = (t + i * 0.2) % 1.0;
      final scale = 0.8 + 0.2 * math.sin(phase * math.pi * 2);
      canvas.drawCircle(
        Offset(cx, cy),
        r * scale,
        Paint()..color = colors[i],
      );
      final tp = TextPainter(
        text: TextSpan(text: p[2] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_ScatterPainter old) => true;
}

class _TapPainter extends CustomPainter {
  final double t;
  _TapPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final r = 24.0;

    if (t < 0.5) {
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = const Color(0xFF6366F1));
      final tp = TextPainter(
        text: const TextSpan(text: '1', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    } else {
      final shrink = (t - 0.5) * 2;
      final scale = 1.0 - shrink;
      if (scale > 0) {
        canvas.drawCircle(Offset(cx, cy), r * scale, Paint()..color = const Color(0xFF6366F1).withValues(alpha: scale));
      }
      final ringAlpha = (1.0 - shrink).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(cx, cy),
        r + 12 * shrink,
        Paint()
          ..color = const Color(0xFF6366F1).withValues(alpha: ringAlpha * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_TapPainter old) => true;
}

class _TimerPainter extends CustomPainter {
  final double t;
  _TimerPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    final seconds = (t * 60).toInt();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    final tp = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: const TextStyle(color: Color(0xFF6366F1), fontSize: 28, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    final barY = cy + 28;
    final barW = size.width * 0.6;
    final barH = 6.0;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - barW / 2, barY, barW, barH),
      const Radius.circular(3),
    );
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFFE5E7EB));
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - barW / 2, barY, barW * t, barH),
      const Radius.circular(3),
    );
    canvas.drawRRect(fillRect, Paint()..color = const Color(0xFF6366F1));
  }

  @override
  bool shouldRepaint(_TimerPainter old) => true;
}
