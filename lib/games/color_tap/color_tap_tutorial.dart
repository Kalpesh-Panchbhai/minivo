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
const _kAccent = Color(0xFFFF6B35);

const _kColorNames = ['RED', 'BLUE', 'GREEN', 'YELLOW'];
const _kColors = [_kRed, _kBlue, _kGreen, _kYellow];

// ── Shared drawing helpers ─────────────────────────────────────────────────

void _drawBackground(Canvas canvas, Size size) {
  // Deep dark background with subtle radial glow
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = const Color(0xFF12060A),
  );
  // Center ambient glow
  canvas.drawCircle(
    Offset(size.width / 2, size.height * 0.52),
    size.width * 0.55,
    Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height * 0.52),
          radius: size.width * 0.55,
        ),
      ),
  );
}

void _drawTargetChip(Canvas canvas, Size size, String name, Color color, double alpha) {
  final cx = size.width / 2;
  final chipY = size.height * 0.115;
  // Pill background
  final pillW = 90.0;
  final pillH = 20.0;
  final pillRect = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, chipY), width: pillW, height: pillH),
    const Radius.circular(10),
  );
  canvas.drawRRect(
    pillRect,
    Paint()..color = color.withValues(alpha: 0.20 * alpha),
  );
  canvas.drawRRect(
    pillRect,
    Paint()
      ..color = color.withValues(alpha: 0.55 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
  // Dot swatch
  canvas.drawCircle(
    Offset(cx - pillW / 2 + 12, chipY),
    4.5,
    Paint()..color = color.withValues(alpha: alpha),
  );
  // Label text
  final tp = TextPainter(
    text: TextSpan(
      text: 'TAP IF: $name',
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(cx - pillW / 2 + 20, chipY - tp.height / 2));
}

void _drawCircle(Canvas canvas, Size size, Color color, double alpha) {
  final cx = size.width / 2;
  final cy = size.height * 0.52;
  final r = size.width * 0.20;

  // Outer glow
  canvas.drawCircle(
    Offset(cx, cy),
    r * 1.45,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.28 * alpha),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(cx, cy),
          radius: r * 1.45,
        ),
      ),
  );

  // Drop shadow
  canvas.drawCircle(
    Offset(cx, cy + 3),
    r,
    Paint()..color = Colors.black.withValues(alpha: 0.30 * alpha),
  );

  // Main circle with gradient
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(color, Colors.white, 0.40)!.withValues(alpha: alpha),
          color.withValues(alpha: alpha),
          Color.lerp(color, Colors.black, 0.20)!.withValues(alpha: alpha),
        ],
        stops: const [0.0, 0.55, 1.0],
        center: const Alignment(-0.32, -0.32),
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
  );

  // Gloss shine
  canvas.drawCircle(
    Offset(cx - r * 0.28, cy - r * 0.28),
    r * 0.20,
    Paint()..color = Colors.white.withValues(alpha: 0.48 * alpha),
  );
}

void _drawTimerBar(Canvas canvas, Size size, double progress) {
  final barW = size.width * 0.74;
  final barH = 6.0;
  final barX = (size.width - barW) / 2;
  final barY = size.height * 0.84;

  // Track
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(barX, barY, barW, barH),
      const Radius.circular(3),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.12),
  );

  // Fill
  final fillW = (barW * (1 - progress)).clamp(0.0, barW);
  if (fillW > 0) {
    final barColor = progress < 0.25
        ? _kRed
        : progress < 0.60
            ? _kYellow
            : _kGreen;
    final fillRect = Rect.fromLTWH(barX, barY, fillW, barH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fillRect, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(barColor, Colors.white, 0.35)!,
            barColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(fillRect),
    );
    // Glow on bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(fillRect, const Radius.circular(3)),
      Paint()
        ..color = barColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }
}

// Step 1: Target chip cycles, circle changes color with smooth crossfade
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
        : phase > 0.78
            ? (1 - (phase - 0.78) / 0.22).clamp(0.0, 1.0)
            : 1.0;

    _drawTargetChip(
        canvas, size, _kColorNames[colorIdx], _kColors[colorIdx], fadeAlpha);
    _drawCircle(canvas, size, _kColors[colorIdx], fadeAlpha.clamp(0.45, 1.0));

    // Draw timer bar to show time pressure
    _drawTimerBar(canvas, size, phase);
  }

  @override
  bool shouldRepaint(covariant _ColorShowPainter old) => old.t != t;
}

// Step 2: Matching pair → TAP ripple → checkmark + score popup
class _ColorMatchPainter extends CustomPainter {
  final double t;
  const _ColorMatchPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    // Phase 0–0.42: show matching GREEN pair with partial timer depleting
    // Phase 0.42–0.62: tap ripple expanding
    // Phase 0.62–1.0: checkmark + score popup floating up

    const matchColor = _kGreen;
    const matchName = 'GREEN';

    if (t < 0.42) {
      final timerProgress = t / 0.42; // goes 0 → 1 (depleting from full)
      _drawTargetChip(canvas, size, matchName, matchColor, 1.0);
      _drawCircle(canvas, size, matchColor, 1.0);
      _drawTimerBar(canvas, size, timerProgress * 0.5); // partial drain
    } else if (t < 0.62) {
      final tapT = (t - 0.42) / 0.20;
      _drawTargetChip(canvas, size, matchName, matchColor, 1.0);
      _drawCircle(canvas, size, matchColor, 1.0);

      final cx = size.width / 2;
      final cy = size.height * 0.52;
      final r = size.width * 0.20;

      // Multiple expanding ripple rings
      for (int i = 0; i < 3; i++) {
        final ringT = (tapT - i * 0.15).clamp(0.0, 1.0);
        if (ringT > 0) {
          final rippleR = r + ringT * size.width * 0.22;
          canvas.drawCircle(
            Offset(cx, cy),
            rippleR,
            Paint()
              ..color = matchColor.withValues(alpha: (1 - ringT) * 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5 - i * 0.6,
          );
        }
      }
    } else {
      final checkT = (t - 0.62) / 0.38;
      _drawTargetChip(
          canvas, size, matchName, matchColor, 1.0 - checkT * 0.35);
      _drawCircle(canvas, size, matchColor, 1.0 - checkT * 0.20);

      final cx = size.width / 2;
      final cy = size.height * 0.52;
      final alpha = math.sin(checkT * math.pi).clamp(0.0, 1.0);

      // Checkmark with nice stroke
      final ck = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(cx - 14, cy)
        ..lineTo(cx - 3, cy + 11)
        ..lineTo(cx + 17, cy - 11);
      canvas.drawPath(path, ck);

      // Score popup floating up
      final popupY = cy - 36 - checkT * 16;
      final tp = TextPainter(
        text: TextSpan(
          text: '+10',
          style: TextStyle(
            color: matchColor.withValues(alpha: alpha),
            fontSize: 17,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: matchColor.withValues(alpha: 0.40 * alpha),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, popupY - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ColorMatchPainter old) => old.t != t;
}

// Step 3: Mismatch shown → timer drains → SKIP button animates in → X flash
class _ColorSkipPainter extends CustomPainter {
  final double t;
  const _ColorSkipPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    // Blue circle, RED target = mismatch
    _drawTargetChip(canvas, size, 'RED', _kRed, 1.0);
    _drawCircle(canvas, size, _kBlue, 1.0);

    // Timer bar depleting
    _drawTimerBar(canvas, size, t);

    // After 0.40 — SKIP button fades in and bobs
    if (t > 0.38) {
      final skipAlpha = ((t - 0.38) / 0.25).clamp(0.0, 1.0);
      final cx = size.width / 2;
      final btnY = size.height * 0.93;
      final bob = math.sin(t * math.pi * 4) * 1.5;

      // Skip pill background
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, btnY + bob), width: 78, height: 26),
        const Radius.circular(13),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _kAccent.withValues(alpha: skipAlpha),
              const Color(0xFFFF922B).withValues(alpha: skipAlpha),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(rect.outerRect),
      );
      // Shine stripe
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 2, rect.top + 2, rect.width - 4, 8),
          const Radius.circular(6),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.18 * skipAlpha),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'SKIP  →',
          style: TextStyle(
            color: Colors.white.withValues(alpha: skipAlpha),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(cx - tp.width / 2, btnY + bob - tp.height / 2));
    }

    // Near end: X flash if time runs out (not tapped)
    if (t > 0.82) {
      final xAlpha = ((t - 0.82) / 0.18).clamp(0.0, 1.0);
      final cx = size.width / 2;
      final cy = size.height * 0.52;
      final xPaint = Paint()
        ..color = _kRed.withValues(alpha: xAlpha * 0.85)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(cx - 13, cy - 13), Offset(cx + 13, cy + 13), xPaint);
      canvas.drawLine(
          Offset(cx + 13, cy - 13), Offset(cx - 13, cy + 13), xPaint);

      // Red glow behind X
      canvas.drawCircle(
        Offset(cx, cy),
        size.width * 0.20,
        Paint()
          ..color = _kRed.withValues(alpha: xAlpha * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ColorSkipPainter old) => old.t != t;
}
