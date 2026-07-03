import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> mancalaSteps() => [
      GameHowToPlayStep(
        text: 'Tap a pit on your side to pick up all its seeds and sow them counterclockwise.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4500),
          painter: (t) => _SowPainter(t),
          canvasSize: const Size(220, 140),
        ),
      ),
      GameHowToPlayStep(
        text: 'If your last seed lands in your store, you get another turn!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _ExtraTurnPainter(t),
          canvasSize: const Size(220, 140),
        ),
      ),
      GameHowToPlayStep(
        text:
            'If your last seed lands in an empty pit on your side, capture it and the opposite pit\'s seeds!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4500),
          painter: (t) => _CapturePainter(t),
          canvasSize: const Size(220, 140),
        ),
      ),
      GameHowToPlayStep(
        text: 'The game ends when one side is empty. Most seeds in your store wins!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(220, 140),
        ),
      ),
    ];

const _kBoard = Color(0xFF8D6E4C);
const _kBoardDark = Color(0xFF6B5236);
const _kPit = Color(0xFF5D4037);
const _kPitLight = Color(0xFF795548);
const _kSeedText = Color(0xFFFFF8E1);
const _kHighlight = Color(0xFFFFB300);
const _kGreen = Color(0xFF66BB6A);

void _drawBoard(Canvas canvas, Size size) {
  final r = RRect.fromRectAndRadius(
    Rect.fromLTWH(4, 8, size.width - 8, size.height - 16),
    const Radius.circular(14),
  );
  canvas.drawRRect(
    r.shift(const Offset(0, 2)),
    Paint()..color = Colors.black.withValues(alpha: 0.18),
  );
  canvas.drawRRect(r, Paint()..color = _kBoard);
  canvas.drawRRect(
    r,
    Paint()
      ..color = _kBoardDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

void _drawStore(Canvas canvas, double cx, double cy, double w, double h, int count,
    {Color? glow}) {
  final r = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy), width: w, height: h),
    const Radius.circular(10),
  );
  if (glow != null) {
    canvas.drawRRect(
      r.inflate(3),
      Paint()
        ..color = glow.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
  canvas.drawRRect(r, Paint()..color = _kPit);
  canvas.drawRRect(
    r,
    Paint()
      ..color = _kPitLight.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );
  if (count >= 0) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$count',
        style: TextStyle(color: _kSeedText, fontSize: h * 0.28, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
}

void _drawPit(Canvas canvas, double cx, double cy, double r, int seeds,
    {Color? ring, double ringAlpha = 1.0}) {
  canvas.drawCircle(
    Offset(cx, cy + 1),
    r,
    Paint()..color = Colors.black.withValues(alpha: 0.12),
  );
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _kPit);
  canvas.drawCircle(
    Offset(cx, cy),
    r,
    Paint()
      ..color = _kPitLight.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8,
  );
  if (ring != null) {
    canvas.drawCircle(
      Offset(cx, cy),
      r + 2,
      Paint()
        ..color = ring.withValues(alpha: 0.7 * ringAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }
  if (seeds > 0) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$seeds',
        style: TextStyle(color: _kSeedText, fontSize: r * 0.7, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
}

void _drawLabel(Canvas canvas, Size size, String text, Color color, double alpha) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontWeight: FontWeight.w900,
        fontSize: 13,
        shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3 * alpha), blurRadius: 3)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final px = (size.width - tp.width) / 2;
  final py = size.height - tp.height - 10;
  final bg = RRect.fromRectAndRadius(
    Rect.fromLTWH(px - 8, py - 3, tp.width + 16, tp.height + 6),
    const Radius.circular(8),
  );
  canvas.drawRRect(bg, Paint()..color = color.withValues(alpha: 0.12 * alpha));
  tp.paint(canvas, Offset(px, py));
}

class _BoardLayout {
  final Size size;
  late final double storeW;
  late final double storeH;
  late final double pitR;
  late final double y1;
  late final double y2;
  late final double storeY;
  late final double leftStoreX;
  late final double rightStoreX;

  _BoardLayout(this.size) {
    storeW = 22.0;
    storeH = size.height * 0.56;
    pitR = 11.0;
    y1 = size.height * 0.33;
    y2 = size.height * 0.62;
    storeY = size.height * 0.48;
    leftStoreX = 22.0;
    rightStoreX = size.width - 22.0;
  }

  double pitX(int i) => 44.0 + i * ((size.width - 88) / 5);
}

class _SowPainter extends CustomPainter {
  final double t;
  const _SowPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawBoard(canvas, size);
    final b = _BoardLayout(size);
    final seeds = [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4];
    var storeR = 0;

    final phase = (t * 2.5).clamp(0.0, 1.0);
    const sowPit = 2;

    if (phase > 0.15) {
      seeds[sowPit] = 0;
      final dropCount = (((phase - 0.15) / 0.70) * 4).floor().clamp(0, 3);
      for (int i = 0; i <= dropCount; i++) {
        final target = sowPit + 1 + i;
        if (target == 6) {
          storeR++;
        } else {
          seeds[target < 6 ? target : target - 1]++;
        }
      }
    }

    _drawStore(canvas, b.leftStoreX, b.storeY, b.storeW, b.storeH, 0);
    _drawStore(canvas, b.rightStoreX, b.storeY, b.storeW, b.storeH, storeR,
        glow: storeR > 0 ? _kHighlight : null);

    for (int i = 0; i < 6; i++) {
      final px = b.pitX(i);
      final isSource = i == sowPit && phase < 0.15;
      final justDropped = phase > 0.15 && i > sowPit && i <= sowPit + 1 + (((phase - 0.15) / 0.70) * 4).floor().clamp(0, 3);
      _drawPit(canvas, px, b.y2, b.pitR, seeds[i],
          ring: isSource
              ? _kHighlight
              : justDropped
                  ? _kGreen
                  : null);
      _drawPit(canvas, px, b.y1, b.pitR, seeds[11 - i]);
    }

    if (phase < 0.15) {
      _drawLabel(canvas, size, 'TAP PIT ${sowPit + 1}', _kHighlight, 1.0);
    } else if (phase < 0.85) {
      _drawLabel(canvas, size, 'SOWING...', _kGreen, 1.0);
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
    _drawBoard(canvas, size);
    final b = _BoardLayout(size);

    final seeds = [4, 4, 2, 4, 4, 4, 4, 4, 4, 4, 4, 4];
    var storeR = 0;
    const sowPit = 4;

    final phase = (t * 2.2).clamp(0.0, 1.0);

    if (phase > 0.12) {
      seeds[sowPit] = 0;
      final dropCount = (((phase - 0.12) / 0.60) * 2).floor().clamp(0, 1);
      for (int i = 0; i <= dropCount; i++) {
        final target = sowPit + 1 + i;
        if (target == 6) {
          storeR++;
        } else if (target < 6) {
          seeds[target]++;
        }
      }
    }

    _drawStore(canvas, b.leftStoreX, b.storeY, b.storeW, b.storeH, 0);
    final storeGlow = storeR > 0 ? _kGreen : null;
    _drawStore(canvas, b.rightStoreX, b.storeY, b.storeW, b.storeH, storeR, glow: storeGlow);

    for (int i = 0; i < 6; i++) {
      final px = b.pitX(i);
      _drawPit(canvas, px, b.y2, b.pitR, seeds[i],
          ring: i == sowPit && phase < 0.12 ? _kHighlight : null);
      _drawPit(canvas, px, b.y1, b.pitR, seeds[11 - i]);
    }

    if (storeR > 0 && phase > 0.55) {
      final alpha = ((phase - 0.55) / 0.30).clamp(0.0, 1.0);
      final pulse = 0.85 + math.sin(t * math.pi * 4) * 0.15;
      final tp = TextPainter(
        text: TextSpan(
          text: 'FREE TURN!',
          style: TextStyle(
            color: _kGreen.withValues(alpha: alpha),
            fontWeight: FontWeight.w900,
            fontSize: 15 * pulse,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3 * alpha), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - tp.height - 10));
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
    _drawBoard(canvas, size);
    final b = _BoardLayout(size);

    final seeds = [4, 3, 0, 4, 4, 4, 4, 4, 3, 4, 4, 4];
    var storeR = 0;
    const capturePit = 2;

    final phase = (t * 2.2).clamp(0.0, 1.0);

    if (phase > 0.10 && phase <= 0.40) {
      seeds[1] = 0;
      final frac = ((phase - 0.10) / 0.30).clamp(0.0, 1.0);
      final drops = (frac * 3).floor().clamp(0, 2);
      for (int i = 0; i <= drops; i++) {
        seeds[capturePit + i]++;
      }
    } else if (phase > 0.40) {
      seeds[1] = 0;
      seeds[capturePit] = 1;
      seeds[3] = 5;
      seeds[4] = 5;
    }

    final showCapture = phase > 0.50;
    if (showCapture) {
      final oppIdx = 11 - capturePit;
      storeR = seeds[capturePit] + seeds[oppIdx];
      seeds[capturePit] = 0;
      seeds[oppIdx] = 0;
    }

    _drawStore(canvas, b.leftStoreX, b.storeY, b.storeW, b.storeH, 0);
    _drawStore(canvas, b.rightStoreX, b.storeY, b.storeW, b.storeH, storeR,
        glow: storeR > 0 ? _kHighlight : null);

    for (int i = 0; i < 6; i++) {
      final px = b.pitX(i);
      final isCaptureSrc = showCapture && i == capturePit;
      final isOpp = showCapture && i == (5 - capturePit);
      _drawPit(canvas, px, b.y2, b.pitR, seeds[i],
          ring: isCaptureSrc ? _kHighlight : null);
      _drawPit(canvas, px, b.y1, b.pitR, seeds[11 - i],
          ring: isOpp ? Colors.red : null);
    }

    if (showCapture) {
      final alpha = ((phase - 0.50) / 0.25).clamp(0.0, 1.0);
      if (alpha > 0) {
        final capX = b.pitX(capturePit);
        final oppX = b.pitX(5 - capturePit);
        final arrowPaint = Paint()
          ..color = _kHighlight.withValues(alpha: 0.6 * alpha)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(capX, b.y2 - b.pitR - 4), Offset(capX, b.y1 + b.pitR + 4), arrowPaint);
        canvas.drawLine(Offset(oppX, b.y1 + b.pitR + 4), Offset(b.rightStoreX, b.storeY), arrowPaint);
      }
      _drawLabel(canvas, size, '+$storeR CAPTURED!', _kHighlight, alpha);
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
    _drawBoard(canvas, size);
    final b = _BoardLayout(size);

    final phase = (t * 2.0).clamp(0.0, 1.0);
    final bottomSeeds = phase < 0.3
        ? [2, 1, 1, 0, 0, 0]
        : [0, 0, 0, 0, 0, 0];
    final topSeeds = [0, 0, 0, 0, 0, 0];

    final playerStore = phase < 0.3 ? 24 : 28;
    final aiStore = 20;

    _drawStore(canvas, b.rightStoreX, b.storeY, b.storeW, b.storeH, playerStore,
        glow: phase > 0.4 ? _kGreen : null);
    _drawStore(canvas, b.leftStoreX, b.storeY, b.storeW, b.storeH, aiStore);

    for (int i = 0; i < 6; i++) {
      final px = b.pitX(i);
      _drawPit(canvas, px, b.y2, b.pitR, bottomSeeds[i]);
      _drawPit(canvas, px, b.y1, b.pitR, topSeeds[i]);
    }

    if (phase > 0.45) {
      final alpha = ((phase - 0.45) / 0.30).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'You: $playerStore',
              style: TextStyle(
                color: _kGreen.withValues(alpha: alpha),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            TextSpan(
              text: '  vs  ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6 * alpha),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: 'AI: $aiStore',
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.7 * alpha),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height - tp.height - 10));
    }

    if (phase > 0.70) {
      final alpha = ((phase - 0.70) / 0.25).clamp(0.0, 1.0);
      final checkPaint = Paint()
        ..color = _kGreen.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      final cx = size.width / 2;
      final cy = size.height * 0.46;
      canvas.drawCircle(
        Offset(cx, cy),
        14,
        Paint()..color = _kGreen.withValues(alpha: 0.15 * alpha),
      );
      final path = Path()
        ..moveTo(cx - 6, cy)
        ..lineTo(cx - 1, cy + 5)
        ..lineTo(cx + 7, cy - 5);
      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}
