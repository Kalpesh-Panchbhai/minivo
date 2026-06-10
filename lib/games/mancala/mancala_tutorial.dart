import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> mancalaSteps() => [
      GameHowToPlayStep(
        text: 'Tap a pit on your side to pick up all its seeds and sow them counterclockwise.',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _SowPainter(t),
          canvasSize: const Size(200, 120),
        ),
      ),
      GameHowToPlayStep(
        text: 'If your last seed lands in your store, you get another turn!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _ExtraTurnPainter(t),
          canvasSize: const Size(200, 120),
        ),
      ),
      GameHowToPlayStep(
        text: 'If your last seed lands in an empty pit on your side, capture it and the opposite pit\'s seeds!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _CapturePainter(t),
          canvasSize: const Size(200, 120),
        ),
      ),
      GameHowToPlayStep(
        text: 'The game ends when one side is empty. Most seeds in your store wins!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(200, 120),
        ),
      ),
    ];

const _kBoard = Color(0xFF7B5B3A);
const _kPit = Color(0xFF5C3D24);
const _kSeed = Color(0xFFD4A76A);

void _drawMancalaBoard(Canvas canvas, Size size) {
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(4, 10, size.width - 8, size.height - 20),
    const Radius.circular(16),
  );
  canvas.drawRRect(rect, Paint()..color = _kBoard);
}

void _drawPit(Canvas canvas, double cx, double cy, double r, int seeds) {
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _kPit);
  if (seeds > 0) {
    final seedR = r * 0.22;
    final tp = TextPainter(
      text: TextSpan(
        text: '$seeds',
        style: TextStyle(color: _kSeed, fontSize: r * 0.6, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
}

class _SowPainter extends CustomPainter {
  final double t;
  const _SowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawMancalaBoard(canvas, size);
    final pitR = 12.0;
    final y1 = size.height * 0.35;
    final y2 = size.height * 0.65;
    final seeds = [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4];
    final phase = (t * 3).clamp(0.0, 1.0);
    final sowPit = 2;
    if (phase > 0.2) {
      seeds[sowPit] = 0;
      final sowCount = (((phase - 0.2) / 0.8) * 4).floor().clamp(0, 3);
      for (int i = 0; i <= sowCount; i++) {
        seeds[(sowPit + 1 + i) % 12]++;
      }
    }

    for (int i = 0; i < 6; i++) {
      final x = 30.0 + i * ((size.width - 60) / 5);
      _drawPit(canvas, x, y2, pitR, seeds[i]);
      _drawPit(canvas, x, y1, pitR, seeds[11 - i]);
    }
  }

  @override
  bool shouldRepaint(_SowPainter old) => old.t != t;
}

class _ExtraTurnPainter extends CustomPainter {
  final double t;
  const _ExtraTurnPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawMancalaBoard(canvas, size);
    final phase = (t * 2).clamp(0.0, 1.0);
    if (phase > 0.5) {
      final alpha = math.sin((phase - 0.5) * 2 * math.pi);
      final tp = TextPainter(
        text: TextSpan(
          text: 'FREE TURN!',
          style: TextStyle(
            color: Colors.amber.withValues(alpha: 0.5 + alpha.abs() * 0.5),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_ExtraTurnPainter old) => old.t != t;
}

class _CapturePainter extends CustomPainter {
  final double t;
  const _CapturePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawMancalaBoard(canvas, size);
    final phase = (t * 2).clamp(0.0, 1.0);
    final y1 = size.height * 0.35;
    final y2 = size.height * 0.65;
    final x = size.width * 0.5;
    final pitR = 14.0;

    _drawPit(canvas, x, y2, pitR, phase < 0.5 ? 1 : 0);
    _drawPit(canvas, x, y1, pitR, phase < 0.5 ? 3 : 0);

    if (phase > 0.5) {
      final alpha = ((phase - 0.5) * 2).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '+4 captured!',
          style: TextStyle(color: Colors.amber.withValues(alpha: alpha), fontWeight: FontWeight.w800, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.45));
    }
  }

  @override
  bool shouldRepaint(_CapturePainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawMancalaBoard(canvas, size);
    if (t > 0.3) {
      final alpha = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'You: 28  AI: 20',
          style: TextStyle(color: Colors.white.withValues(alpha: alpha), fontWeight: FontWeight.w900, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}
