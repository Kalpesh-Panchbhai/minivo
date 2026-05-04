import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

// ── Public API ──────────────────────────────────────────────────────────────

List<GameHowToPlayStep> numberMergeSteps() => [
      GameHowToPlayStep(
        text: 'Swipe to slide all tiles in one direction',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _MergeSwipePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Same numbers merge and double!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _MergeCombinePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Keep merging — reach 2048!',
        demo: AnimatedDemo(
          period: const Duration(seconds: 3),
          painter: (t) => _MergeGoalPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

// ── Tile color data ─────────────────────────────────────────────────────────

const Map<int, _TileStyle> _kTileStyles = {
  2:    _TileStyle(Color(0xFFEEE4DA), Color(0xFF776E65)),
  4:    _TileStyle(Color(0xFFEDE0C8), Color(0xFF776E65)),
  8:    _TileStyle(Color(0xFFF2B179), Color(0xFFF9F6F2)),
  16:   _TileStyle(Color(0xFFF59563), Color(0xFFF9F6F2)),
  32:   _TileStyle(Color(0xFFF67C5F), Color(0xFFF9F6F2)),
  64:   _TileStyle(Color(0xFFF65E3B), Color(0xFFF9F6F2)),
  128:  _TileStyle(Color(0xFFEDCF72), Color(0xFFF9F6F2)),
  256:  _TileStyle(Color(0xFFEDCC61), Color(0xFFF9F6F2)),
  512:  _TileStyle(Color(0xFFEDC850), Color(0xFFF9F6F2)),
  1024: _TileStyle(Color(0xFFEDC53F), Color(0xFFF9F6F2)),
  2048: _TileStyle(Color(0xFFEDC22E), Color(0xFFF9F6F2)),
};

_TileStyle _styleFor(int v) =>
    _kTileStyles[v] ?? const _TileStyle(Color(0xFF3C3A32), Color(0xFFF9F6F2));

class _TileStyle {
  final Color bg;
  final Color fg;
  const _TileStyle(this.bg, this.fg);
}

void _drawTile(Canvas canvas, Rect rect, int value,
    {double scale = 1.0, double opacity = 1.0}) {
  final style = _styleFor(value);
  final center = rect.center;
  final scaledRect = Rect.fromCenter(
      center: center, width: rect.width * scale, height: rect.height * scale);

  canvas.drawRRect(
    RRect.fromRectAndRadius(scaledRect, const Radius.circular(6)),
    Paint()..color = style.bg.withValues(alpha: opacity),
  );

  final label = value >= 1000 ? '$value' : '$value';
  final fontSize = value < 100
      ? 18.0
      : value < 1000
          ? 14.0
          : 11.0;
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: style.fg.withValues(alpha: opacity),
        fontSize: fontSize * scale,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
    canvas,
    Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
  );
}

// ── Step 1: Tiles slide in a direction ──────────────────────────────────────

class _MergeSwipePainter extends CustomPainter {
  final double t;
  const _MergeSwipePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFFFF9F5));

    // Swipe directions cycle: right→down→left→up
    final dirIdx = (t * 4).floor() % 4;
    final slideT = (t * 4) % 1.0;

    // 2×2 grid of tiles
    const tileSize = 38.0;
    const gap = 6.0;
    const gridW = tileSize * 2 + gap;
    final ox = (size.width - gridW) / 2;
    final oy = (size.height - gridW) / 2;

    final values = [2, 4, 8, 16];
    final basePositions = [
      Offset(ox, oy),
      Offset(ox + tileSize + gap, oy),
      Offset(ox, oy + tileSize + gap),
      Offset(ox + tileSize + gap, oy + tileSize + gap),
    ];

    // Direction offsets for sliding effect
    const maxSlide = 8.0;
    final slideAmt = math.sin(slideT * math.pi) * maxSlide;
    final dirOffsets = [
      Offset(slideAmt, 0),   // right
      Offset(0, slideAmt),   // down
      Offset(-slideAmt, 0),  // left
      Offset(0, -slideAmt),  // up
    ];
    final slideOffset = dirOffsets[dirIdx];

    for (int i = 0; i < 4; i++) {
      final pos = basePositions[i] + slideOffset;
      _drawTile(
        canvas,
        Rect.fromLTWH(pos.dx, pos.dy, tileSize, tileSize),
        values[i],
      );
    }

    // Arrow hint
    const arrows = ['→', '↓', '←', '↑'];
    final arrowFade = slideT < 0.5 ? slideT / 0.25 : (1 - (slideT - 0.5) / 0.5);
    final tp = TextPainter(
      text: TextSpan(
        text: arrows[dirIdx],
        style: TextStyle(
          color: const Color(0xFFBBADA0).withValues(alpha: arrowFade.clamp(0.0, 1.0)),
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.80 - tp.width / 2, size.height / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _MergeSwipePainter old) => old.t != t;
}

// ── Step 2: Two same tiles slide together and merge ─────────────────────────

class _MergeCombinePainter extends CustomPainter {
  final double t;
  const _MergeCombinePainter(this.t);

  static const _sequence = [
    [2, 4],
    [4, 8],
    [8, 16],
    [16, 32],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFFFF9F5));

    final seqIdx = (t * _sequence.length).floor() % _sequence.length;
    final phase = (t * _sequence.length) % 1.0;
    final sourceVal = _sequence[seqIdx][0];
    final mergedVal = _sequence[seqIdx][1];

    const tileSize = 44.0;
    const gap = 20.0;
    final cy = size.height / 2;
    final leftX = size.width / 2 - tileSize * 1.5 - gap / 2;
    final rightX = size.width / 2 + gap / 2 + tileSize * 0.5;
    final centerX = size.width / 2 - tileSize / 2;

    // phase 0-0.5: tiles slide toward each other
    // phase 0.5-0.7: merge pop
    // phase 0.7-1.0: show result, fade

    if (phase < 0.50) {
      final slideT = phase / 0.50;
      final lx = leftX + slideT * (centerX - leftX);
      final rx = rightX - slideT * (rightX - centerX);

      _drawTile(canvas,
          Rect.fromLTWH(lx, cy - tileSize / 2, tileSize, tileSize), sourceVal);
      _drawTile(canvas,
          Rect.fromLTWH(rx, cy - tileSize / 2, tileSize, tileSize), sourceVal);
    } else if (phase < 0.70) {
      final popT = (phase - 0.50) / 0.20;
      // pop: 1.0 → 1.25 → 1.0
      final scale = 1.0 + math.sin(popT * math.pi) * 0.28;
      _drawTile(
        canvas,
        Rect.fromLTWH(centerX, cy - tileSize / 2, tileSize, tileSize),
        mergedVal,
        scale: scale,
      );

      // Particle burst
      if (popT > 0.1) {
        final particles = 6;
        for (int i = 0; i < particles; i++) {
          final angle = i * 2 * math.pi / particles;
          final dist = popT * tileSize * 0.7;
          final px = centerX + tileSize / 2 + math.cos(angle) * dist;
          final py = cy + math.sin(angle) * dist;
          final pAlpha = (1 - popT).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(px, py),
            3.5 * (1 - popT),
            Paint()..color = _styleFor(mergedVal).bg.withValues(alpha: pAlpha),
          );
        }
      }
    } else {
      final fadeT = ((phase - 0.70) / 0.30).clamp(0.0, 1.0);
      final opacity = 1.0 - fadeT * 0.5;
      _drawTile(
        canvas,
        Rect.fromLTWH(centerX, cy - tileSize / 2, tileSize, tileSize),
        mergedVal,
        opacity: opacity,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MergeCombinePainter old) => old.t != t;
}

// ── Step 3: Tile cycles through values toward 2048 ─────────────────────────

class _MergeGoalPainter extends CustomPainter {
  final double t;
  const _MergeGoalPainter(this.t);

  static const _values = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048];

  @override
  void paint(Canvas canvas, Size size) {
    final valIdx = (t * _values.length).floor() % _values.length;
    final phase = (t * _values.length) % 1.0;
    final value = _values[valIdx];
    final style = _styleFor(value);

    // Background pulse with tile color
    final bgAlpha = 0.08 + math.sin(phase * math.pi) * 0.06;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = style.bg.withValues(alpha: bgAlpha + 0.10),
    );
    // Warm base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFFFF9F5).withValues(alpha: 0.85),
    );

    const tileSize = 70.0;
    final cx = size.width / 2;
    final cy = size.height * 0.46;

    // Scale up when tile changes
    final scale = phase < 0.25
        ? 0.80 + (phase / 0.25) * 0.25
        : phase > 0.80
            ? 1.05 - ((phase - 0.80) / 0.20) * 0.05
            : 1.05;

    _drawTile(
      canvas,
      Rect.fromLTWH(cx - tileSize / 2, cy - tileSize / 2, tileSize, tileSize),
      value,
      scale: scale,
    );

    // "REACH 2048!" label at bottom
    final labelAlpha = value == 2048 ? 1.0 : 0.50;
    final tp = TextPainter(
      text: TextSpan(
        text: value == 2048 ? '🎉 2048!' : 'Reach 2048!',
        style: TextStyle(
          color: const Color(0xFFBBADA0).withValues(alpha: labelAlpha),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + tileSize * 0.58 + 6));
  }

  @override
  bool shouldRepaint(covariant _MergeGoalPainter old) => old.t != t;
}
