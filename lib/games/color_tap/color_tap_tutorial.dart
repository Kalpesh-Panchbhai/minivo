import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> colorTapSteps() => [
      GameHowToPlayStep(
        text: 'A color circle appears — remember the target!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _ColorShowPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'TAP if the colors match!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2400),
          painter: (t) => _ColorMatchPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: "SKIP if they don't match — and don't run out of time!",
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2800),
          painter: (t) => _ColorSkipPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

const _kRed    = Color(0xFFEF4444);
const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kYellow = Color(0xFFEAB308);

const _kColorNames = ['RED', 'BLUE', 'GREEN', 'YELLOW'];
const _kColors = [_kRed, _kBlue, _kGreen, _kYellow];

void _drawBackground(Canvas canvas, Size size) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = const Color(0xFF1A0A00),
  );
}

void _drawLabel(Canvas canvas, Size size, String text, Color color, double alpha) {
  final tp = TextPainter(
    text: TextSpan(
      text: 'TARGET: $text',
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.10));
}

void _drawCircle(Canvas canvas, Size size, Color color, double alpha) {
  final cx = size.width / 2;
  final cy = size.height * 0.52;
  final r = size.width * 0.20;
  // Glow
  canvas.drawCircle(
    Offset(cx, cy),
    r * 1.25,
    Paint()
      ..color = color.withValues(alpha: 0.18 * alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
  );
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: alpha));
  canvas.drawCircle(
    Offset(cx - r * 0.28, cy - r * 0.28),
    r * 0.22,
    Paint()..color = Colors.white.withValues(alpha: 0.40 * alpha),
  );
}

// Step 1: Target label cycles, large circle changes color
class _ColorShowPainter extends CustomPainter {
  final double t;
  const _ColorShowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    final colorIdx = (t * _kColors.length).floor() % _kColors.length;
    final phase = (t * _kColors.length) % 1.0;
    final fadeAlpha = phase < 0.15
        ? phase / 0.15
        : phase > 0.80
            ? (1 - (phase - 0.80) / 0.20).clamp(0.0, 1.0)
            : 1.0;

    _drawLabel(canvas, size, _kColorNames[colorIdx], _kColors[colorIdx], fadeAlpha);
    _drawCircle(canvas, size, _kColors[colorIdx], fadeAlpha.clamp(0.5, 1.0));
  }

  @override
  bool shouldRepaint(covariant _ColorShowPainter old) => old.t != t;
}

// Step 2: Matching pair → TAP → checkmark
class _ColorMatchPainter extends CustomPainter {
  final double t;
  const _ColorMatchPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    // Phase 0–0.45: show matching pair (green circle, target GREEN)
    // Phase 0.45–0.65: tap ripple
    // Phase 0.65–1.0: checkmark flash
    if (t < 0.45) {
      _drawLabel(canvas, size, 'GREEN', _kGreen, 1.0);
      _drawCircle(canvas, size, _kGreen, 1.0);
    } else if (t < 0.65) {
      final tapT = (t - 0.45) / 0.20;
      _drawLabel(canvas, size, 'GREEN', _kGreen, 1.0);
      _drawCircle(canvas, size, _kGreen, 1.0);
      // Ripple
      final cx = size.width / 2;
      final cy = size.height * 0.52;
      final rippleR = size.width * 0.20 + tapT * size.width * 0.18;
      canvas.drawCircle(
        Offset(cx, cy),
        rippleR,
        Paint()
          ..color = Colors.white.withValues(alpha: (1 - tapT) * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    } else {
      final checkT = (t - 0.65) / 0.35;
      _drawLabel(canvas, size, 'GREEN', _kGreen, 1.0 - checkT * 0.4);
      _drawCircle(canvas, size, _kGreen, 1.0 - checkT * 0.3);

      // Checkmark
      final alpha = math.sin(checkT * math.pi).clamp(0.0, 1.0);
      final cx = size.width / 2;
      final cy = size.height * 0.52;
      final ck = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(cx - 14, cy),
        Offset(cx - 4, cy + 10),
        ck,
      );
      canvas.drawLine(
        Offset(cx - 4, cy + 10),
        Offset(cx + 16, cy - 10),
        ck,
      );

      // "+10 pts"
      final tp = TextPainter(
        text: TextSpan(
          text: '+10',
          style: TextStyle(
            color: _kGreen.withValues(alpha: alpha),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - 38 - checkT * 10));
    }
  }

  @override
  bool shouldRepaint(covariant _ColorMatchPainter old) => old.t != t;
}

// Step 3: Timer depletes → X mark → SKIP button
class _ColorSkipPainter extends CustomPainter {
  final double t;
  const _ColorSkipPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    // Blue circle with RED target → mismatch
    _drawLabel(canvas, size, 'RED', _kRed, 1.0);
    _drawCircle(canvas, size, _kBlue, 1.0);

    // Timer bar depleting
    final barW = size.width * 0.72;
    final barH = 6.0;
    final barX = (size.width - barW) / 2;
    final barY = size.height * 0.82;
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    // Fill — depletes over t
    final fillW = (barW * (1 - t)).clamp(0.0, barW);
    final barColor = t < 0.5 ? _kGreen : (t < 0.75 ? _kYellow : _kRed);
    if (fillW > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, fillW, barH), const Radius.circular(3)),
        Paint()..color = barColor,
      );
    }

    // After 0.55 show SKIP button suggestion
    if (t > 0.45) {
      final skipAlpha = ((t - 0.45) / 0.30).clamp(0.0, 1.0);
      final cx = size.width / 2;
      final btnY = size.height * 0.90;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, btnY), width: 70, height: 24),
        const Radius.circular(12),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = const Color(0xFFFF6B35).withValues(alpha: skipAlpha),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'SKIP →',
          style: TextStyle(
            color: Colors.white.withValues(alpha: skipAlpha),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, btnY - tp.height / 2));
    }

    // Near end: X flash if time runs out
    if (t > 0.85) {
      final xAlpha = ((t - 0.85) / 0.15).clamp(0.0, 1.0);
      final cx = size.width / 2;
      final cy = size.height * 0.52;
      final xPaint = Paint()
        ..color = _kRed.withValues(alpha: xAlpha * 0.80)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - 12, cy - 12), Offset(cx + 12, cy + 12), xPaint);
      canvas.drawLine(Offset(cx + 12, cy - 12), Offset(cx - 12, cy + 12), xPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ColorSkipPainter old) => old.t != t;
}
