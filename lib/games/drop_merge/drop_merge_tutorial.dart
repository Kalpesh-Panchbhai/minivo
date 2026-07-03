import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> dropMergeSteps() => [
      GameHowToPlayStep(
        text: 'Tap a column to drop the current tile. '
            'It falls to the lowest empty row in that column.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3200),
          painter: (t) => _DropPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Matching tiles merge! Two 2s become a 4, '
            'two 4s become an 8 -- and so on.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _MergePainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Chain reactions score bonus points! '
            'Each extra merge adds a x0.5 multiplier.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 5000),
          painter: (t) => _ChainPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
      GameHowToPlayStep(
        text: 'Board fills up fast -- plan where to drop each tile. '
            'Game over when no moves remain!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 5500),
          painter: (t) => _GameOverPainter(t),
          canvasSize: const Size(200, 180),
        ),
      ),
    ];

const Map<int, _TileStyle> _kStyles = {
  0:    _TileStyle(Color(0xFFCDC1B4), Color(0xFFCDC1B4)),
  2:    _TileStyle(Color(0xFFEEE4DA), Color(0xFF776E65)),
  4:    _TileStyle(Color(0xFFEDE0C8), Color(0xFF776E65)),
  8:    _TileStyle(Color(0xFFF2B179), Color(0xFFFFFFFF)),
  16:   _TileStyle(Color(0xFFF59563), Color(0xFFFFFFFF)),
  32:   _TileStyle(Color(0xFFF67C5F), Color(0xFFFFFFFF)),
  64:   _TileStyle(Color(0xFFF65E3B), Color(0xFFFFFFFF)),
  128:  _TileStyle(Color(0xFFEDCF72), Color(0xFFFFFFFF)),
  256:  _TileStyle(Color(0xFFEDCC61), Color(0xFFFFFFFF)),
  512:  _TileStyle(Color(0xFFEDC850), Color(0xFFFFFFFF)),
  1024: _TileStyle(Color(0xFFEDC53F), Color(0xFFFFFFFF)),
  2048: _TileStyle(Color(0xFFEDC22E), Color(0xFFFFFFFF)),
};

class _TileStyle {
  final Color bg;
  final Color fg;
  const _TileStyle(this.bg, this.fg);
}

_TileStyle _styleFor(int v) =>
    _kStyles[v] ?? const _TileStyle(Color(0xFF3C3A32), Color(0xFFFFFFFF));

const _kCols = 4;
const _kRows = 5;
const _kCell = 28.0;
const _kGap = 3.0;
const _kBoardW = _kCols * _kCell + (_kCols - 1) * _kGap;
const _kBoardH = _kRows * _kCell + (_kRows - 1) * _kGap;
const _kBoardBg = Color(0xFFBBADA0);
const _kEmptyCell = Color(0xFFCDC1B4);
const _kCanvasBg = Color(0xFFFAF8EF);

Offset _drawBoardBg(Canvas canvas, Size size, {double alpha = 1.0}) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = _kCanvasBg,
  );
  final ox = (size.width - _kBoardW) / 2;
  final oy = (size.height - _kBoardH) / 2;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(ox - 4, oy - 4, _kBoardW + 8, _kBoardH + 8),
      const Radius.circular(8),
    ),
    Paint()..color = _kBoardBg.withValues(alpha: alpha),
  );
  for (int r = 0; r < _kRows; r++) {
    for (int c = 0; c < _kCols; c++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _cellRect(c, r, Offset(ox, oy)),
          const Radius.circular(6),
        ),
        Paint()..color = _kEmptyCell.withValues(alpha: alpha),
      );
    }
  }
  return Offset(ox, oy);
}

Rect _cellRect(int col, int row, Offset origin) {
  final x = origin.dx + col * (_kCell + _kGap);
  final y = origin.dy + row * (_kCell + _kGap);
  return Rect.fromLTWH(x, y, _kCell, _kCell);
}

void _drawTile(
  Canvas canvas,
  int col,
  int row,
  int value,
  Offset origin, {
  Offset pixelOffset = Offset.zero,
  double scale = 1.0,
  double opacity = 1.0,
}) {
  if (value == 0) return;
  final style = _styleFor(value);
  final base = _cellRect(col, row, origin).shift(pixelOffset);
  final center = base.center;
  final sr = _kCell / 2 * scale;
  final scaledRect =
      Rect.fromCenter(center: center, width: sr * 2, height: sr * 2);

  canvas.drawRRect(
    RRect.fromRectAndRadius(scaledRect, Radius.circular(6 * scale)),
    Paint()..color = style.bg.withValues(alpha: opacity),
  );

  final label = '$value';
  final fontSize = value < 100
      ? _kCell * 0.46
      : value < 1000
          ? _kCell * 0.36
          : _kCell * 0.26;
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

void _drawTileAt(
  Canvas canvas,
  double x,
  double y,
  int value, {
  double scale = 1.0,
  double opacity = 1.0,
}) {
  if (value == 0) return;
  final style = _styleFor(value);
  final center = Offset(x + _kCell / 2, y + _kCell / 2);
  final sr = _kCell / 2 * scale;
  final rect = Rect.fromCenter(center: center, width: sr * 2, height: sr * 2);

  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(6 * scale)),
    Paint()..color = style.bg.withValues(alpha: opacity),
  );

  final label = '$value';
  final fontSize = value < 100
      ? _kCell * 0.46
      : value < 1000
          ? _kCell * 0.36
          : _kCell * 0.26;
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

void _drawText(
  Canvas canvas,
  String text,
  Offset center,
  double fontSize,
  Color color, {
  FontWeight weight = FontWeight.w800,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
}

class _DropPainter extends CustomPainter {
  final double t;
  const _DropPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = _drawBoardBg(canvas, size);

    _drawTile(canvas, 0, 4, 4, origin);
    _drawTile(canvas, 1, 3, 2, origin);
    _drawTile(canvas, 1, 4, 8, origin);
    _drawTile(canvas, 3, 4, 16, origin);

    final dropCol = 2;
    final targetRow = 4;
    final cx = origin.dx + dropCol * (_kCell + _kGap) + _kCell / 2;

    if (t < 0.15) {
      final tapT = t / 0.15;
      final ripR = _kCell * 0.3 + tapT * _kCell * 0.6;
      final ripAlpha = (1 - tapT) * 0.5;
      canvas.drawCircle(
        Offset(cx, origin.dy - _kCell * 0.6),
        ripR,
        Paint()
          ..color = const Color(0xFFBBADA0).withValues(alpha: ripAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      final fingerAlpha = (1 - tapT * 1.2).clamp(0.0, 1.0);
      _drawText(
        canvas,
        'TAP',
        Offset(cx, origin.dy - _kCell * 1.2),
        9,
        const Color(0xFF776E65).withValues(alpha: fingerAlpha),
      );

      final indicPaint = Paint()
        ..color = const Color(0xFF776E65).withValues(alpha: fingerAlpha * 0.7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx, origin.dy - _kCell * 0.9),
        Offset(cx, origin.dy - _kCell * 0.55),
        indicPaint,
      );
      canvas.drawLine(
        Offset(cx - 4, origin.dy - _kCell * 0.65),
        Offset(cx, origin.dy - _kCell * 0.55),
        indicPaint,
      );
      canvas.drawLine(
        Offset(cx + 4, origin.dy - _kCell * 0.65),
        Offset(cx, origin.dy - _kCell * 0.55),
        indicPaint,
      );
    }

    if (t >= 0.12 && t < 0.50) {
      final dropT = ((t - 0.12) / 0.38).clamp(0.0, 1.0);
      final startY = origin.dy - _kCell * 0.5;
      final endY = origin.dy + targetRow * (_kCell + _kGap);
      final curY =
          startY + (endY - startY) * Curves.bounceOut.transform(dropT);
      _drawTileAt(canvas, origin.dx + dropCol * (_kCell + _kGap), curY, 2);
    }

    if (t >= 0.50) {
      _drawTile(canvas, dropCol, targetRow, 2, origin);
    }

    if (t > 0.50 && t < 0.65) {
      final impactT = ((t - 0.50) / 0.15).clamp(0.0, 1.0);
      final impactR = _kCell * 0.4 + impactT * _kCell * 0.5;
      final impactAlpha = (1 - impactT) * 0.3;
      final cellCenter = _cellRect(dropCol, targetRow, origin).center;
      canvas.drawCircle(
        cellCenter,
        impactR,
        Paint()
          ..color = _styleFor(2).bg.withValues(alpha: impactAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    _drawText(
      canvas,
      'TAP A COLUMN TO DROP',
      Offset(size.width / 2, size.height - 8),
      7.5,
      const Color(0xFF776E65).withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _DropPainter old) => old.t != t;
}

class _MergePainter extends CustomPainter {
  final double t;
  const _MergePainter(this.t);

  static const _pairs = [
    [2, 4],
    [4, 8],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final origin = _drawBoardBg(canvas, size);

    final pairIdx = (t * _pairs.length).floor() % _pairs.length;
    final phase = (t * _pairs.length) % 1.0;
    final src = _pairs[pairIdx][0];
    final dst = _pairs[pairIdx][1];

    final col = 1;

    _drawTile(canvas, 0, 4, 8, origin);
    _drawTile(canvas, 2, 3, 16, origin);
    _drawTile(canvas, 2, 4, 4, origin);
    _drawTile(canvas, 3, 4, 32, origin);

    if (phase < 0.10) {
      _drawTile(canvas, col, 3, src, origin);
      _drawTile(canvas, col, 4, src, origin);
    } else if (phase < 0.40) {
      final slideT =
          Curves.easeInOut.transform((phase - 0.10) / 0.30);
      final offset = Offset(0, slideT * (_kCell + _kGap));
      _drawTile(canvas, col, 4, src, origin);
      _drawTile(canvas, col, 3, src, origin, pixelOffset: offset);
    } else if (phase < 0.65) {
      final popT = (phase - 0.40) / 0.25;
      final scale = 1.0 + math.sin(popT * math.pi) * 0.35;
      _drawTile(canvas, col, 4, dst, origin, scale: scale);

      final cellCenter = _cellRect(col, 4, origin).center;
      if (popT > 0.05) {
        for (int i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final dist = popT * _kCell * 0.9;
          final pAlpha = (1 - popT).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(
              cellCenter.dx + math.cos(angle) * dist,
              cellCenter.dy + math.sin(angle) * dist,
            ),
            3.5 * pAlpha,
            Paint()..color = _styleFor(dst).bg.withValues(alpha: pAlpha),
          );
        }
      }

      final glowAlpha = math.sin(popT * math.pi) * 0.4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _cellRect(col, 4, origin).inflate(4),
          const Radius.circular(10),
        ),
        Paint()
          ..color = _styleFor(dst).bg.withValues(alpha: glowAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      final scoreAlpha = math.sin(popT * math.pi).clamp(0.0, 1.0);
      _drawText(
        canvas,
        '+$dst',
        Offset(cellCenter.dx, cellCenter.dy - _kCell * 0.8 - popT * 12),
        12,
        const Color(0xFF776E65).withValues(alpha: scoreAlpha),
        weight: FontWeight.w900,
      );
    } else {
      final fadeT = (phase - 0.65) / 0.35;
      _drawTile(
        canvas,
        col,
        4,
        dst,
        origin,
        opacity: (1 - fadeT * 0.5).clamp(0.0, 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MergePainter old) => old.t != t;
}

class _ChainPainter extends CustomPainter {
  final double t;
  const _ChainPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final origin = _drawBoardBg(canvas, size);

    _drawTile(canvas, 0, 4, 16, origin);
    _drawTile(canvas, 3, 3, 8, origin);
    _drawTile(canvas, 3, 4, 32, origin);

    final dropCol = 1;
    final existingRow = 4;

    if (t < 0.15) {
      _drawTile(canvas, dropCol, existingRow, 2, origin);
      _drawTile(canvas, 2, existingRow, 4, origin);

      final dropT = (t / 0.15).clamp(0.0, 1.0);
      final startY = origin.dy - _kCell * 0.5;
      final endY = origin.dy + 3 * (_kCell + _kGap);
      final curY =
          startY + (endY - startY) * Curves.bounceOut.transform(dropT);
      _drawTileAt(
        canvas,
        origin.dx + dropCol * (_kCell + _kGap),
        curY,
        2,
      );
    } else if (t < 0.25) {
      _drawTile(canvas, dropCol, 3, 2, origin);
      _drawTile(canvas, dropCol, existingRow, 2, origin);
      _drawTile(canvas, 2, existingRow, 4, origin);
    } else if (t < 0.45) {
      _drawTile(canvas, 2, existingRow, 4, origin);

      final mergeT = ((t - 0.25) / 0.20).clamp(0.0, 1.0);
      final slideOffset = Offset(0, mergeT * (_kCell + _kGap));
      _drawTile(canvas, dropCol, existingRow, 2, origin);
      _drawTile(canvas, dropCol, 3, 2, origin, pixelOffset: slideOffset);
    } else if (t < 0.58) {
      _drawTile(canvas, 2, existingRow, 4, origin);

      final popT = ((t - 0.45) / 0.13).clamp(0.0, 1.0);
      final scale = 1.0 + math.sin(popT * math.pi) * 0.35;
      _drawTile(canvas, dropCol, existingRow, 4, origin, scale: scale);

      final cellCenter = _cellRect(dropCol, existingRow, origin).center;
      if (popT > 0.05) {
        for (int i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final dist = popT * _kCell * 0.8;
          final pAlpha = (1 - popT).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(
              cellCenter.dx + math.cos(angle) * dist,
              cellCenter.dy + math.sin(angle) * dist,
            ),
            3.0 * pAlpha,
            Paint()..color = _styleFor(4).bg.withValues(alpha: pAlpha),
          );
        }
      }

      final scoreAlpha = math.sin(popT * math.pi).clamp(0.0, 1.0);
      _drawText(
        canvas,
        '+4',
        Offset(cellCenter.dx, cellCenter.dy - _kCell * 0.7 - popT * 10),
        11,
        const Color(0xFF776E65).withValues(alpha: scoreAlpha),
        weight: FontWeight.w900,
      );
    } else if (t < 0.68) {
      final slideT = ((t - 0.58) / 0.10).clamp(0.0, 1.0);
      final slideOffset =
          Offset(Curves.easeInOut.transform(slideT) * (_kCell + _kGap), 0);
      _drawTile(canvas, 2, existingRow, 4, origin);
      _drawTile(canvas, dropCol, existingRow, 4, origin,
          pixelOffset: slideOffset);
    } else if (t < 0.82) {
      final popT = ((t - 0.68) / 0.14).clamp(0.0, 1.0);
      final scale = 1.0 + math.sin(popT * math.pi) * 0.40;
      _drawTile(canvas, 2, existingRow, 8, origin, scale: scale);

      final cellCenter = _cellRect(2, existingRow, origin).center;
      if (popT > 0.05) {
        for (int i = 0; i < 10; i++) {
          final angle = i * math.pi / 5;
          final dist = popT * _kCell * 1.0;
          final pAlpha = (1 - popT).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(
              cellCenter.dx + math.cos(angle) * dist,
              cellCenter.dy + math.sin(angle) * dist,
            ),
            3.5 * pAlpha,
            Paint()..color = _styleFor(8).bg.withValues(alpha: pAlpha),
          );
        }
      }

      final scoreAlpha = math.sin(popT * math.pi).clamp(0.0, 1.0);
      _drawText(
        canvas,
        '+8',
        Offset(cellCenter.dx, cellCenter.dy - _kCell * 0.7 - popT * 10),
        11,
        const Color(0xFF776E65).withValues(alpha: scoreAlpha),
        weight: FontWeight.w900,
      );
    } else {
      _drawTile(canvas, 2, existingRow, 8, origin);

      final badgeT = ((t - 0.82) / 0.18).clamp(0.0, 1.0);
      final badgeAlpha = badgeT < 0.3
          ? badgeT / 0.3
          : badgeT > 0.8
              ? (1 - (badgeT - 0.8) / 0.2).clamp(0.0, 1.0)
              : 1.0;

      final badgeScale =
          0.6 + Curves.elasticOut.transform(badgeT.clamp(0.0, 1.0)) * 0.4;

      final badgeCx = size.width / 2;
      final badgeCy = origin.dy - 10;

      canvas.save();
      canvas.translate(badgeCx, badgeCy);
      canvas.scale(badgeScale);
      canvas.translate(-badgeCx, -badgeCy);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(badgeCx, badgeCy),
            width: 80,
            height: 20,
          ),
          const Radius.circular(10),
        ),
        Paint()
          ..color = const Color(0xFFF2B179).withValues(alpha: badgeAlpha),
      );
      _drawText(
        canvas,
        'CHAIN x1.5',
        Offset(badgeCx, badgeCy),
        10,
        Colors.white.withValues(alpha: badgeAlpha),
        weight: FontWeight.w900,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ChainPainter old) => old.t != t;
}

class _GameOverPainter extends CustomPainter {
  final double t;
  const _GameOverPainter(this.t);

  static const _fullGrid = [
    [2, 4, 8, 2],
    [8, 16, 2, 4],
    [4, 2, 32, 16],
    [16, 8, 4, 8],
    [2, 32, 16, 4],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t < 0.55) {
      final origin = _drawBoardBg(canvas, size);
      final fillT = (t / 0.55).clamp(0.0, 1.0);

      final totalCells = _kRows * _kCols;
      final filledCount = (fillT * totalCells).floor();

      for (int idx = 0; idx < totalCells; idx++) {
        final r = (_kRows - 1) - (idx ~/ _kCols);
        final c = idx % _kCols;
        final val = _fullGrid[r][c];

        if (idx < filledCount) {
          _drawTile(canvas, c, r, val, origin);
        } else if (idx == filledCount) {
          final cellT = (fillT * totalCells - idx).clamp(0.0, 1.0);
          final dropStartY = origin.dy - _kCell;
          final dropEndY = origin.dy + r * (_kCell + _kGap);
          final curY = dropStartY +
              (dropEndY - dropStartY) *
                  Curves.bounceOut.transform(cellT);
          _drawTileAt(
            canvas,
            origin.dx + c * (_kCell + _kGap),
            curY,
            val,
          );
        }
      }
    } else if (t < 0.80) {
      final origin = _drawBoardBg(canvas, size);

      for (int r = 0; r < _kRows; r++) {
        for (int c = 0; c < _kCols; c++) {
          _drawTile(canvas, c, r, _fullGrid[r][c], origin);
        }
      }

      final overlayT = ((t - 0.55) / 0.25).clamp(0.0, 1.0);
      final overlayAlpha = Curves.easeIn.transform(overlayT) * 0.55;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            origin.dx - 4,
            origin.dy - 4,
            _kBoardW + 8,
            _kBoardH + 8,
          ),
          const Radius.circular(8),
        ),
        Paint()..color = Colors.black.withValues(alpha: overlayAlpha),
      );

      final textAlpha =
          ((t - 0.62) / 0.10).clamp(0.0, 1.0);
      if (textAlpha > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: 'GAME OVER',
            style: TextStyle(
              color: Colors.white.withValues(alpha: textAlpha),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            size.width / 2 - tp.width / 2,
            size.height / 2 - tp.height / 2,
          ),
        );
      }
    } else {
      final clearT = ((t - 0.80) / 0.20).clamp(0.0, 1.0);

      if (clearT < 0.50) {
        final fadeT = clearT / 0.50;
        final tileOpacity = (1 - fadeT).clamp(0.0, 1.0);
        final origin = _drawBoardBg(canvas, size);

        for (int r = 0; r < _kRows; r++) {
          for (int c = 0; c < _kCols; c++) {
            _drawTile(
              canvas,
              c,
              r,
              _fullGrid[r][c],
              origin,
              opacity: tileOpacity,
              scale: 1.0 - fadeT * 0.3,
            );
          }
        }

        final overlayAlpha = 0.55 * (1 - fadeT);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              origin.dx - 4,
              origin.dy - 4,
              _kBoardW + 8,
              _kBoardH + 8,
            ),
            const Radius.circular(8),
          ),
          Paint()..color = Colors.black.withValues(alpha: overlayAlpha),
        );

        final textFade = (1 - fadeT * 2).clamp(0.0, 1.0);
        if (textFade > 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: 'GAME OVER',
              style: TextStyle(
                color: Colors.white.withValues(alpha: textFade),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                height: 1,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            Offset(
              size.width / 2 - tp.width / 2,
              size.height / 2 - tp.height / 2,
            ),
          );
        }
      } else {
        final freshT = (clearT - 0.50) / 0.50;
        final origin = _drawBoardBg(canvas, size);

        final hintAlpha =
            freshT < 0.3 ? freshT / 0.3 : 1.0;

        _drawText(
          canvas,
          'PLAN AHEAD!',
          Offset(size.width / 2, size.height / 2 - 4),
          13,
          const Color(0xFF776E65).withValues(alpha: hintAlpha),
          weight: FontWeight.w900,
        );

        final sparkleT = (freshT * 3) % 1.0;
        final sparkAlpha = math.sin(sparkleT * math.pi) * 0.6;
        for (int i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + freshT * math.pi * 2;
          final dist = 30 + math.sin(freshT * math.pi * 2 + i) * 8;
          canvas.drawCircle(
            Offset(
              size.width / 2 + math.cos(angle) * dist,
              size.height / 2 + math.sin(angle) * dist,
            ),
            2.5,
            Paint()
              ..color = _styleFor(8)
                  .bg
                  .withValues(alpha: sparkAlpha.clamp(0.0, 1.0)),
          );
        }

        if (freshT > 0.4) {
          final tileAlpha =
              ((freshT - 0.4) / 0.3).clamp(0.0, 1.0);
          _drawTile(canvas, 1, 4, 2, origin, opacity: tileAlpha);
          _drawTile(canvas, 2, 4, 4, origin, opacity: tileAlpha);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GameOverPainter old) => old.t != t;
}
