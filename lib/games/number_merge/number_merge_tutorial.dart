import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

// ── Public API ──────────────────────────────────────────────────────────────

List<GameHowToPlayStep> numberMergeSteps() => [
      GameHowToPlayStep(
        text: 'Swipe to slide all tiles in one direction',
        demo: AnimatedDemo(
          period: const Duration(seconds: 4),
          painter: (t) => _MergeSwipePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Same numbers merge and double!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 2600),
          painter: (t) => _MergeCombinePainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
      GameHowToPlayStep(
        text: 'Keep merging — reach 2048!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3000),
          painter: (t) => _MergeGoalPainter(t),
          canvasSize: const Size(180, 150),
        ),
      ),
    ];

// ── Tile colours (matching real 2048 palette) ───────────────────────────────

const Map<int, _TileStyle> _kTileStyles = {
  0:    _TileStyle(Color(0xFFCDC1B4), Color(0xFFCDC1B4)),
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

// ── Board layout constants ──────────────────────────────────────────────────
// 4×4 board centred in 180×150 canvas.
// cellSize=28, gap=4 → boardSize = 4*28+3*4 = 124.
const _kCellSize = 28.0;
const _kGap = 4.0;
const _kBoardSize = _kCellSize * 4 + _kGap * 3; // 124
const _kBoardBg = Color(0xFFBBADA0);
const _kEmptyCell = Color(0xFFCDC1B4);

/// Draws a complete 4×4 board background with empty cells.
/// Returns the top-left origin of the board.
Offset _drawBoardBg(Canvas canvas, Size size) {
  final ox = (size.width - _kBoardSize) / 2;
  final oy = (size.height - _kBoardSize) / 2;
  final boardRect = Rect.fromLTWH(ox, oy, _kBoardSize, _kBoardSize);
  canvas.drawRRect(
    RRect.fromRectAndRadius(boardRect, const Radius.circular(8)),
    Paint()..color = _kBoardBg,
  );
  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 4; c++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _cellRect(c, r, Offset(ox, oy)),
          const Radius.circular(4),
        ),
        Paint()..color = _kEmptyCell,
      );
    }
  }
  return Offset(ox, oy);
}

Rect _cellRect(int col, int row, Offset origin) {
  final x = origin.dx + col * (_kCellSize + _kGap);
  final y = origin.dy + row * (_kCellSize + _kGap);
  return Rect.fromLTWH(x, y, _kCellSize, _kCellSize);
}

/// Draws a tile at [col,row] with optional pixel [offset] and [scale].
void _drawTile(Canvas canvas, int col, int row, int value, Offset origin,
    {Offset pixelOffset = Offset.zero, double scale = 1.0, double opacity = 1.0}) {
  if (value == 0) return;
  final style = _styleFor(value);
  final base = _cellRect(col, row, origin).shift(pixelOffset);
  final center = base.center;
  final sr = _kCellSize / 2 * scale;
  final scaledRect = Rect.fromCenter(center: center, width: sr * 2, height: sr * 2);

  canvas.drawRRect(
    RRect.fromRectAndRadius(scaledRect, Radius.circular(4 * scale)),
    Paint()..color = style.bg.withValues(alpha: opacity),
  );

  if (value > 0) {
    final label = '$value';
    final fontSize = value < 100
        ? _kCellSize * 0.50
        : value < 1000
            ? _kCellSize * 0.38
            : _kCellSize * 0.28;
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
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }
}

// ── Step 1: ONE tile slides to the wall per swipe; cycles all 4 directions ──
//
// Static tiles sit at the edges (nowhere to go). Each quarter-period shows a
// fresh tile with empty space ahead, sliding in the swiped direction.
//
// Directions & moving tile:
//   → (col 1,row 1) → (col 3, row 1)   2 columns right
//   ↓ (col 2,row 0) → (col 2, row 3)   3 rows down
//   ← (col 2,row 2) → (col 0, row 2)   2 columns left
//   ↑ (col 1,row 3) → (col 1, row 0)   3 rows up
//
// Each quarter: 12% fade-in/rest, 58% slide, 20% settle, 10% fade-out.

// Helper: each direction's config [startCol, startRow, endCol, endRow, arrowChar]
typedef _Dir = ({int sc, int sr, int ec, int er, String arrow});

const _kDirs = <_Dir>[
  (sc: 1, sr: 1, ec: 3, er: 1, arrow: '→'),
  (sc: 2, sr: 0, ec: 2, er: 3, arrow: '↓'),
  (sc: 2, sr: 2, ec: 0, er: 2, arrow: '←'),
  (sc: 1, sr: 3, ec: 1, er: 0, arrow: '↑'),
];

class _MergeSwipePainter extends CustomPainter {
  final double t;
  const _MergeSwipePainter(this.t);

  // Tiles that never move (already at a wall, blocked in every direction shown)
  static const _staticTiles = [
    [3, 0, 4],   // right wall, row 0
    [0, 3, 8],   // left wall, row 3
    [3, 1, 16],  // right wall, row 1
  ];

  static const _movingValue = 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFFAF0E6));
    final origin = _drawBoardBg(canvas, size);

    const step = _kCellSize + _kGap;

    // Which of the 4 directions are we in, and how far through it?
    final dirIdx = (t * 4).floor() % 4;
    final phase = (t * 4) % 1.0; // 0→1 within current direction
    final dir = _kDirs[dirIdx];

    double movingCol, movingRow, tileAlpha, arrowAlpha;

    if (phase < 0.12) {
      // Fade in at start position
      movingCol = dir.sc.toDouble();
      movingRow = dir.sr.toDouble();
      tileAlpha = (phase / 0.12).clamp(0.0, 1.0);
      arrowAlpha = tileAlpha * 0.85;
    } else if (phase < 0.70) {
      // Slide from start → end
      final slideT = Curves.easeInOut.transform((phase - 0.12) / 0.58);
      movingCol = dir.sc + (dir.ec - dir.sc) * slideT;
      movingRow = dir.sr + (dir.er - dir.sr) * slideT;
      tileAlpha = 1.0;
      arrowAlpha = (1 - slideT).clamp(0.0, 1.0) * 0.85;
    } else if (phase < 0.90) {
      // Settled at end position
      movingCol = dir.ec.toDouble();
      movingRow = dir.er.toDouble();
      tileAlpha = 1.0;
      arrowAlpha = 0;
    } else {
      // Fade out
      movingCol = dir.ec.toDouble();
      movingRow = dir.er.toDouble();
      tileAlpha = (1 - (phase - 0.90) / 0.10).clamp(0.0, 1.0);
      arrowAlpha = 0;
    }

    // Draw static tiles
    for (final tile in _staticTiles) {
      _drawTile(canvas, tile[0], tile[1], tile[2], origin);
    }

    // Draw moving tile at its continuous position
    final movingX = origin.dx + movingCol * step;
    final movingY = origin.dy + movingRow * step;
    final rect = Rect.fromLTWH(movingX, movingY, _kCellSize, _kCellSize);
    final style = _styleFor(_movingValue);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = style.bg.withValues(alpha: tileAlpha),
    );
    if (tileAlpha > 0) {
      final numTp = TextPainter(
        text: TextSpan(
          text: '$_movingValue',
          style: TextStyle(
            color: style.fg.withValues(alpha: tileAlpha),
            fontSize: _kCellSize * 0.50,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numTp.paint(canvas, Offset(
        rect.center.dx - numTp.width / 2,
        rect.center.dy - numTp.height / 2,
      ));
    }

    // Swipe arrow outside the board
    if (arrowAlpha > 0) {
      final arrTp = TextPainter(
        text: TextSpan(
          text: dir.arrow,
          style: TextStyle(
            color: _kBoardBg.withValues(alpha: arrowAlpha),
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Place arrow on the side the tile slides toward
      final Offset arrPos;
      if (dir.arrow == '→') {
        final bx = origin.dx + _kBoardSize + 6;
        arrPos = Offset(math.min(bx, size.width - arrTp.width - 2),
            size.height / 2 - arrTp.height / 2);
      } else if (dir.arrow == '←') {
        arrPos = Offset(math.max(2, origin.dx - arrTp.width - 6),
            size.height / 2 - arrTp.height / 2);
      } else if (dir.arrow == '↓') {
        arrPos = Offset(size.width / 2 - arrTp.width / 2,
            math.min(origin.dy + _kBoardSize + 4, size.height - arrTp.height - 2));
      } else {
        // ↑
        arrPos = Offset(size.width / 2 - arrTp.width / 2,
            math.max(2, origin.dy - arrTp.height - 4));
      }
      arrTp.paint(canvas, arrPos);
    }
  }

  @override
  bool shouldRepaint(covariant _MergeSwipePainter old) => old.t != t;
}

// ── Step 2: Two same tiles slide together and merge ─────────────────────────
//
// Shows one row of the board: [0, 2, 2, 0]
// Tiles slide toward each other and merge into 4, then 4+4→8, etc.

class _MergeCombinePainter extends CustomPainter {
  final double t;
  const _MergeCombinePainter(this.t);

  static const _pairs = [[2, 4], [4, 8], [8, 16]];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFFAF0E6));

    // Show only a single 1×4 row centred vertically.
    // Use same cell size but show one row; extend canvas width for all 4 cells.
    const rowH = _kCellSize + 8; // extra padding
    final rowOx = (size.width - _kBoardSize) / 2;
    final rowOy = (size.height - rowH) / 2;
    final origin = Offset(rowOx, rowOy);

    // Row background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rowOx - 4, rowOy - 4, _kBoardSize + 8, _kCellSize + 8),
        const Radius.circular(8),
      ),
      Paint()..color = _kBoardBg,
    );
    // Empty cells
    for (int c = 0; c < 4; c++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(_cellRect(c, 0, origin), const Radius.circular(4)),
        Paint()..color = _kEmptyCell,
      );
    }

    final pairIdx = (t * _pairs.length).floor() % _pairs.length;
    final phase = (t * _pairs.length) % 1.0;
    final src = _pairs[pairIdx][0];
    final dst = _pairs[pairIdx][1];

    // phase 0–0.45: left tile moves right, right tile moves left (sliding in)
    // phase 0.45–0.65: merge pop on dst tile at col 2 (right position)
    // phase 0.65–1.0: result visible, fades

    if (phase < 0.45) {
      final slideT = Curves.easeInOut.transform(phase / 0.45);
      // Left tile slides from col 1 → col 2
      final leftOffset = Offset(slideT * (_kCellSize + _kGap), 0);
      // Right tile slides from col 2 → col 2 (stays, left tile comes to it)
      // Actually: left tile starts col 1, right tile starts col 2.
      // They meet at col 2 (right tile's position).
      _drawTile(canvas, 1, 0, src, origin, pixelOffset: leftOffset);
      _drawTile(canvas, 2, 0, src, origin);
    } else if (phase < 0.65) {
      final popT = (phase - 0.45) / 0.20;
      final scale = 1.0 + math.sin(popT * math.pi) * 0.32;
      _drawTile(canvas, 2, 0, dst, origin, scale: scale);

      // Particle burst
      final center = _cellRect(2, 0, origin).center;
      if (popT > 0.05) {
        for (int i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final dist = popT * _kCellSize * 0.9;
          final pAlpha = (1 - popT).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(center.dx + math.cos(angle) * dist, center.dy + math.sin(angle) * dist),
            3.5 * pAlpha,
            Paint()..color = _styleFor(dst).bg.withValues(alpha: pAlpha),
          );
        }
      }

      // +score label
      final scoreAlpha = math.sin(popT * math.pi).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '+$dst',
          style: TextStyle(
            color: const Color(0xFF776E65).withValues(alpha: scoreAlpha),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, rowOy - 20 - popT * 8));
    } else {
      final fadeT = (phase - 0.65) / 0.35;
      _drawTile(canvas, 2, 0, dst, origin, opacity: (1 - fadeT * 0.6).clamp(0.0, 1.0));
    }
  }

  @override
  bool shouldRepaint(covariant _MergeCombinePainter old) => old.t != t;
}

// ── Step 3: 1024 + 1024 → 2048 on a real board ─────────────────────────────
//
// Shows a late-game board where the final merge produces the 2048 tile.

class _MergeGoalPainter extends CustomPainter {
  final double t;
  const _MergeGoalPainter(this.t);

  // Late-game board (row, col, value). Two 1024s will merge.
  static const _staticTiles = [
    [0, 0, 512], [1, 0, 256], [2, 0, 128], [3, 0, 64],
    [0, 1, 32],  [1, 1, 16],  [2, 1, 8],   [3, 1, 4],
    [0, 2, 2],   [1, 2, 0],   [2, 2, 0],   [3, 2, 0],
    // Row 3: two 1024 tiles that will merge
    [0, 3, 1024],[1, 3, 0],   [2, 3, 0],   [3, 3, 1024],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFFAF0E6));

    final origin = _drawBoardBg(canvas, size);

    if (t < 0.40) {
      // Static board — two 1024 tiles visible
      for (final tile in _staticTiles) {
        _drawTile(canvas, tile[0], tile[1], tile[2], origin);
      }
      // Pulsing arrows pointing inward toward the two 1024s
      final arrowAlpha = (math.sin(t * 2 * math.pi * 2) * 0.4 + 0.6).clamp(0.0, 1.0);
      _drawArrow(canvas, origin, arrowAlpha);
    } else if (t < 0.65) {
      // Slide phase: left 1024 moves right, right 1024 stays
      final slideT = Curves.easeInOut.transform((t - 0.40) / 0.25);
      for (final tile in _staticTiles) {
        if (tile[0] == 0 && tile[1] == 3) {
          // Left 1024 slides right 3 cells
          final px = slideT * (_kCellSize + _kGap) * 3;
          _drawTile(canvas, tile[0], tile[1], 1024, origin, pixelOffset: Offset(px, 0));
        } else if (tile[0] == 3 && tile[1] == 3) {
          // Right 1024 stays (gets eaten)
          final opacity = (1 - slideT * 0.8).clamp(0.0, 1.0);
          _drawTile(canvas, tile[0], tile[1], 1024, origin, opacity: opacity);
        } else {
          _drawTile(canvas, tile[0], tile[1], tile[2], origin);
        }
      }
    } else if (t < 0.82) {
      // Merge pop: 2048 appears at col 3, row 3
      final popT = (t - 0.65) / 0.17;
      final scale = 1.0 + math.sin(popT * math.pi) * 0.45;

      for (final tile in _staticTiles) {
        if ((tile[0] == 0 && tile[1] == 3) || (tile[0] == 3 && tile[1] == 3)) {
          continue; // replaced by merged tile
        }
        _drawTile(canvas, tile[0], tile[1], tile[2], origin);
      }
      _drawTile(canvas, 3, 3, 2048, origin, scale: scale);

      // Celebration burst
      final center = _cellRect(3, 3, origin).center;
      if (popT > 0.1) {
        for (int i = 0; i < 10; i++) {
          final angle = i * math.pi / 5;
          final dist = popT * _kCellSize * 1.1;
          final pAlpha = (1 - popT).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(center.dx + math.cos(angle) * dist, center.dy + math.sin(angle) * dist),
            4 * pAlpha,
            Paint()..color = const Color(0xFFEDC22E).withValues(alpha: pAlpha),
          );
        }
      }
    } else {
      // Final state: show full board with 2048 tile glowing
      final glowPulse = math.sin((t - 0.82) / 0.18 * math.pi);
      for (final tile in _staticTiles) {
        if ((tile[0] == 0 && tile[1] == 3) || (tile[0] == 3 && tile[1] == 3)) {
          continue;
        }
        _drawTile(canvas, tile[0], tile[1], tile[2], origin);
      }
      // Glow behind 2048
      final center = _cellRect(3, 3, origin).center;
      canvas.drawCircle(
        center,
        _kCellSize * 0.75,
        Paint()
          ..color = const Color(0xFFEDC22E).withValues(alpha: 0.30 + glowPulse * 0.20)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10),
      );
      _drawTile(canvas, 3, 3, 2048, origin);

      // "YOU WIN!" label
      final winAlpha = ((t - 0.82) / 0.10).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: '🎉 YOU WIN!',
          style: TextStyle(
            color: const Color(0xFF776E65).withValues(alpha: winAlpha),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, origin.dy - 20));
    }
  }

  void _drawArrow(Canvas canvas, Offset origin, double alpha) {
    // Small → arrow between the two 1024 tiles, pointing right
    final left = _cellRect(0, 3, origin).center;
    final right = _cellRect(3, 3, origin).center;
    final midY = (left.dy + right.dy) / 2;
    final p = Paint()
      ..color = const Color(0xFF776E65).withValues(alpha: alpha * 0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // Two inward arrows
    final midX = (left.dx + right.dx) / 2;
    canvas.drawLine(Offset(left.dx + 16, midY), Offset(midX - 4, midY), p);
    canvas.drawLine(Offset(right.dx - 16, midY), Offset(midX + 4, midY), p);
  }

  @override
  bool shouldRepaint(covariant _MergeGoalPainter old) => old.t != t;
}
