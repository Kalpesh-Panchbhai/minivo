import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'game_logo_living.dart';

// ---------------------------------------------------------------------------
// 1. Solitaire
// ---------------------------------------------------------------------------

Widget buildSolitaireLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Solitaire',
      bg: const [Color(0xFF1B5E20), Color(0xFF0A280E)],
      accent: const Color(0xFF22C55E),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _SolitaireArtPainter(t),
    );

class _SolitaireArtPainter extends CustomPainter {
  final double t;
  const _SolitaireArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFF14532D));

    final cardW = artSize * 0.30;
    final cardH = artSize * 0.42;
    final cardR = Radius.circular(cardW * 0.10);

    final stackX = zone.left + artSize * 0.30;
    final stackY = zone.top + artSize * 0.50;
    final foundX = zone.left + artSize * 0.72;
    final foundY = zone.top + artSize * 0.28;

    final foundOutline = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(foundX, foundY), width: cardW, height: cardH),
      cardR,
    );
    canvas.drawRRect(
      foundOutline,
      Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final cardBackFill = Paint()..color = const Color(0xFF1E40AF);
    final cardBackPattern = Paint()..color = const Color(0xFF2563EB);
    final cardFaceFill = Paint()..color = const Color(0xFFFAFAFA);
    final cardBorderPaint = Paint()
      ..color = const Color(0xFFD4D4D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < 2; i++) {
      final off = (1 - i) * 3.5;
      final cr = Rect.fromCenter(
        center: Offset(stackX + off, stackY + off),
        width: cardW,
        height: cardH,
      );
      final crRR = RRect.fromRectAndRadius(cr, cardR);
      canvas.drawRRect(crRR.shift(const Offset(1.5, 2)), shadowPaint);
      canvas.drawRRect(crRR, cardBackFill);
      final patternInset = cr.deflate(cardW * 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(patternInset, Radius.circular(cardW * 0.06)),
        Paint()
          ..color = cardBackPattern.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      final dSize = cardW * 0.08;
      canvas.save();
      canvas.translate(cr.center.dx, cr.center.dy);
      canvas.rotate(0.785);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: dSize, height: dSize),
        Paint()..color = const Color(0xFF3B82F6),
      );
      canvas.restore();
    }

    double topCardCx = stackX;
    double topCardCy = stackY;
    double topCardScaleX = 1.0;
    bool showFace = false;

    if (t < 0.25) {
      final p = t / 0.25;
      if (p < 0.5) {
        topCardScaleX = 1.0 - p * 2.0;
      } else {
        topCardScaleX = (p - 0.5) * 2.0 - 1.0;
        showFace = true;
      }
    } else if (t < 0.55) {
      showFace = true;
      topCardScaleX = -1.0;
      final p = Curves.easeInOutCubic.transform((t - 0.25) / 0.30);
      topCardCx = stackX + (foundX - stackX) * p;
      topCardCy = stackY + (foundY - stackY) * p;
    } else if (t < 0.65) {
      showFace = true;
      topCardScaleX = -1.0;
      topCardCx = foundX;
      topCardCy = foundY;
    } else {
      showFace = false;
      topCardScaleX = 1.0;
      topCardCx = stackX;
      topCardCy = stackY;
    }

    canvas.save();
    canvas.translate(topCardCx, topCardCy);
    final sx = topCardScaleX.abs() < 0.02 ? 0.02 : topCardScaleX;
    canvas.scale(sx, 1.0);

    final topRect = Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH);
    final topRR = RRect.fromRectAndRadius(topRect, cardR);
    canvas.drawRRect(topRR.shift(const Offset(1.5, 2)), shadowPaint);

    if (showFace) {
      canvas.drawRRect(topRR, cardFaceFill);
      canvas.drawRRect(topRR, cardBorderPaint);

      final heartS = cardW * 0.22;
      _drawHeart(canvas, 0, cardH * 0.02, heartS, Paint()..color = const Color(0xFFDC2626));

      final tp = TextPainter(
        text: TextSpan(
          text: 'A',
          style: TextStyle(
            color: const Color(0xFFDC2626),
            fontSize: cardW * 0.22,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-cardW * 0.38, -cardH * 0.42));

      final miniH = heartS * 0.4;
      _drawHeart(canvas, -cardW * 0.30, -cardH * 0.22, miniH, Paint()..color = const Color(0xFFDC2626));
    } else {
      canvas.drawRRect(topRR, cardBackFill);
      final patternInset = topRect.deflate(cardW * 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(patternInset, Radius.circular(cardW * 0.06)),
        Paint()
          ..color = cardBackPattern.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      final dSize = cardW * 0.08;
      canvas.save();
      canvas.rotate(0.785);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: dSize, height: dSize),
        Paint()..color = const Color(0xFF3B82F6),
      );
      canvas.restore();
    }
    canvas.restore();

    if (t >= 0.55 && t < 0.65) {
      final glowP = math.sin(((t - 0.55) / 0.10) * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(foundX, foundY), width: cardW + 6, height: cardH + 6),
          Radius.circular(cardW * 0.12 + 3),
        ),
        Paint()
          ..color = const Color(0xFF22C55E).withValues(alpha: 0.35 * glowP)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.restore();

    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawHeart(Canvas canvas, double cx, double cy, double s, Paint paint) {
    final path = Path()
      ..moveTo(cx, cy + s * 0.25)
      ..cubicTo(cx - s * 0.5, cy - s * 0.3, cx - s * 0.5, cy - s * 0.6, cx, cy - s * 0.2)
      ..cubicTo(cx + s * 0.5, cy - s * 0.6, cx + s * 0.5, cy - s * 0.3, cx, cy + s * 0.25)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SolitaireArtPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 2. Maze Paint
// ---------------------------------------------------------------------------

Widget buildMazePaintLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Maze Paint',
      bg: const [Color(0xFF831843), Color(0xFF500724)],
      accent: const Color(0xFFF472B6),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _MazePaintArtPainter(t),
    );

class _MazePaintArtPainter extends CustomPainter {
  final double t;
  const _MazePaintArtPainter(this.t);

  static const _floorColor = Color(0xFF4F5B6E);
  static const _floorLight = Color(0xFF5E6B80);
  static const _floorDark = Color(0xFF3E4A5A);
  static const _startTint = Color(0xFF22D3EE);
  static const _paintColor = Color(0xFF00D4AA);

  static const _rows = 5;
  static const _cols = 5;
  static const _walls = {2, 3, 4, 9, 14, 19, 24, 23};
  static const _start = 0;
  static const _ballPath = [0, 5, 10, 15, 16, 17, 12, 7, 8, 13, 18];

  bool _isFloor(int r, int c) {
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return false;
    return !_walls.contains(r * _cols + c);
  }

  bool _isFilled(int r, int c, bool Function(int) test) {
    if (!_isFloor(r, c)) return false;
    return test(r * _cols + c);
  }

  Path _buildContour(bool Function(int) test, double cell, Offset origin, double inset) {
    final vCols = _cols + 1;
    int vid(int r, int c) => r * vCols + c;

    final edges = <int, List<int>>{};
    int totalEdges = 0;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (!_isFilled(r, c, test)) continue;
        void add(int from, int to) {
          (edges[from] ??= []).add(to);
          totalEdges++;
        }
        if (!_isFilled(r - 1, c, test)) add(vid(r, c), vid(r, c + 1));
        if (!_isFilled(r, c + 1, test)) add(vid(r, c + 1), vid(r + 1, c + 1));
        if (!_isFilled(r + 1, c, test)) add(vid(r + 1, c + 1), vid(r + 1, c));
        if (!_isFilled(r, c - 1, test)) add(vid(r + 1, c), vid(r, c));
      }
    }

    int edgeDir(int from, int to) {
      final d = to - from;
      if (d == 1) return 0;
      if (d == vCols) return 1;
      if (d == -1) return 2;
      return 3;
    }

    int pickNext(List<int> outs, int v, int inDir) {
      if (outs.length == 1) return 0;
      final prio = [(inDir + 1) % 4, inDir, (inDir + 3) % 4, (inDir + 2) % 4];
      for (final p in prio) {
        for (int i = 0; i < outs.length; i++) {
          if (edgeDir(v, outs[i]) == p) return i;
        }
      }
      return 0;
    }

    final rad = cell * 0.22;
    final path = Path();
    int consumed = 0;

    while (consumed < totalEdges) {
      int? startV;
      for (final k in edges.keys) {
        if (edges[k]!.isNotEmpty) { startV = k; break; }
      }
      if (startV == null) break;

      final startOuts = edges[startV]!;
      final firstEnd = startOuts.removeLast();
      consumed++;
      final loop = <int>[startV];
      int cur = firstEnd;
      int inDir = edgeDir(startV, firstEnd);

      while (cur != startV) {
        loop.add(cur);
        final outs = edges[cur];
        if (outs == null || outs.isEmpty) break;
        final idx = pickNext(outs, cur, inDir);
        final next = outs.removeAt(idx);
        consumed++;
        inDir = edgeDir(cur, next);
        cur = next;
        if (consumed > totalEdges) break;
      }

      if (loop.length < 3) continue;
      final n = loop.length;

      Offset insetVtx(int v) {
        final vr = v ~/ vCols, vc = v % vCols;
        double x = origin.dx + vc * cell, y = origin.dy + vr * cell;
        final tl = _isFilled(vr - 1, vc - 1, test);
        final tr = _isFilled(vr - 1, vc, test);
        final bl = _isFilled(vr, vc - 1, test);
        final br = _isFilled(vr, vc, test);
        final filledCount = (tl ? 1 : 0) + (tr ? 1 : 0) + (bl ? 1 : 0) + (br ? 1 : 0);
        if (filledCount == 1) {
          if (br) { x += inset; y += inset; }
          else if (bl) { x -= inset; y += inset; }
          else if (tr) { x += inset; y -= inset; }
          else { x -= inset; y -= inset; }
        } else if (filledCount == 3) {
          if (!br) { x -= inset; y -= inset; }
          else if (!bl) { x += inset; y -= inset; }
          else if (!tr) { x -= inset; y += inset; }
          else { x += inset; y += inset; }
        } else {
          if (!tl && !tr) { y += inset; }
          else if (!bl && !br) { y -= inset; }
          else if (!tl && !bl) { x += inset; }
          else if (!tr && !br) { x -= inset; }
        }
        return Offset(x, y);
      }

      for (int i = 0; i < n; i++) {
        final prev = insetVtx(loop[(i - 1 + n) % n]);
        final curr = insetVtx(loop[i]);
        final next = insetVtx(loop[(i + 1) % n]);
        final d1 = Offset(curr.dx - prev.dx, curr.dy - prev.dy);
        final d2 = Offset(next.dx - curr.dx, next.dy - curr.dy);
        final len1 = d1.distance, len2 = d2.distance;
        final t1 = (len1 > 0) ? math.min(rad, len1 / 2) / len1 : 0.0;
        final t2 = (len2 > 0) ? math.min(rad, len2 / 2) / len2 : 0.0;
        final arcStart = Offset(curr.dx - d1.dx * t1, curr.dy - d1.dy * t1);
        final arcEnd = Offset(curr.dx + d2.dx * t2, curr.dy + d2.dy * t2);
        if (i == 0) {
          path.moveTo(arcStart.dx, arcStart.dy);
        } else {
          path.lineTo(arcStart.dx, arcStart.dy);
        }
        path.quadraticBezierTo(curr.dx, curr.dy, arcEnd.dx, arcEnd.dy);
      }
      path.close();
    }

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    final cell = artSize / _cols;
    final inset = cell * 0.08;
    final origin = zone.topLeft;

    final floorPath = _buildContour((_) => true, cell, origin, inset);
    final bounds = floorPath.getBounds();

    canvas.drawPath(
      floorPath.shift(Offset(0, cell * 0.10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.10),
    );

    canvas.drawPath(
      floorPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bounds.left, bounds.top),
          Offset(bounds.left, bounds.bottom),
          [_floorLight, _floorColor, _floorDark],
          [0.0, 0.4, 1.0],
        ),
    );

    canvas.save();
    canvas.clipPath(floorPath);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bounds.left, bounds.top),
          Offset(bounds.left, bounds.bottom),
          [Colors.white.withValues(alpha: 0.08), Colors.transparent, Colors.black.withValues(alpha: 0.10)],
          [0.0, 0.45, 1.0],
        ),
    );
    canvas.restore();

    double fillProgress;
    bool flash = false;
    if (t < 0.80) {
      fillProgress = t / 0.80;
    } else {
      fillProgress = 1.0;
      flash = true;
    }

    final totalCells = _ballPath.length;
    final cellsFilled = (fillProgress * totalCells).floor().clamp(0, totalCells);
    final cellFrac = (fillProgress * totalCells) - cellsFilled;

    if (cellsFilled > 0) {
      final paintedSet = <int>{};
      for (int i = 0; i < cellsFilled && i < totalCells; i++) {
        paintedSet.add(_ballPath[i]);
      }

      final paintPath = _buildContour(paintedSet.contains, cell, origin, inset);
      final paintBounds = paintPath.getBounds();
      final paintLight = Color.lerp(_paintColor, Colors.white, 0.15)!;
      final paintDark = Color.lerp(_paintColor, Colors.black, 0.12)!;

      final flashAlpha = flash ? (0.08 + 0.06 * math.sin((t - 0.80) / 0.20 * math.pi * 2)) : 0.0;

      canvas.drawPath(
        paintPath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(paintBounds.left, paintBounds.top),
            Offset(paintBounds.left, paintBounds.bottom),
            [paintLight, _paintColor, paintDark],
            [0.0, 0.4, 1.0],
          ),
      );

      canvas.save();
      canvas.clipPath(paintPath);
      canvas.drawRect(
        paintBounds,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(paintBounds.left, paintBounds.top),
            Offset(paintBounds.left, paintBounds.bottom),
            [Colors.white.withValues(alpha: 0.12), Colors.transparent, Colors.black.withValues(alpha: 0.08)],
            [0.0, 0.45, 1.0],
          ),
      );
      canvas.restore();

      if (flash) {
        canvas.drawPath(
          paintPath,
          Paint()..color = Colors.white.withValues(alpha: flashAlpha),
        );
      }
    }

    final sr = _start ~/ _cols, sc = _start % _cols;
    final startRect = Rect.fromLTWH(
      origin.dx + sc * cell + inset, origin.dy + sr * cell + inset,
      cell - 2 * inset, cell - 2 * inset,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(startRect, Radius.circular(cell * 0.18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, cell * 0.04)
        ..color = _startTint.withValues(alpha: 0.85),
    );

    if (cellsFilled < totalCells) {
      final curCell = _ballPath[cellsFilled];
      final curR = curCell ~/ _cols, curC = curCell % _cols;
      double dotX, dotY;
      if (cellsFilled > 0) {
        final prevCell = _ballPath[cellsFilled - 1];
        final prevR = prevCell ~/ _cols, prevC = prevCell % _cols;
        dotX = origin.dx + (prevC + (curC - prevC) * cellFrac + 0.5) * cell;
        dotY = origin.dy + (prevR + (curR - prevR) * cellFrac + 0.5) * cell;
      } else {
        dotX = origin.dx + (curC + 0.5) * cell;
        dotY = origin.dy + (curR + 0.5) * cell;
      }
      _drawBall(canvas, Offset(dotX, dotY), cell);
    } else {
      final lastCell = _ballPath.last;
      final lastR = lastCell ~/ _cols, lastC = lastCell % _cols;
      _drawBall(canvas, Offset(
        origin.dx + (lastC + 0.5) * cell,
        origin.dy + (lastR + 0.5) * cell,
      ), cell);
    }

    canvas.restore();

    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawBall(Canvas canvas, Offset c, double cell) {
    final radius = cell * 0.32;

    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0.5, radius * 0.35), width: radius * 1.6, height: radius * 0.45),
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
        ..color = Colors.black.withValues(alpha: 0.20),
    );

    canvas.drawCircle(
      c, radius,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-radius * 0.20, -radius * 0.25),
          radius * 2.0,
          const [Color(0xFFFFFFFF), Color(0xFFF0F0F0), Color(0xFFD0D0D0), Color(0xFFAAAAAA)],
          const [0.0, 0.3, 0.65, 1.0],
        ),
    );

    canvas.drawCircle(
      c, radius,
      Paint()
        ..shader = ui.Gradient.radial(
          c.translate(-radius * 0.30, -radius * 0.35),
          radius * 0.75,
          [Colors.white.withValues(alpha: 0.7), Colors.white.withValues(alpha: 0.0)],
        ),
    );

    canvas.drawCircle(c.translate(-radius * 0.22, -radius * 0.22), radius * 0.12, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MazePaintArtPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 3. Block Escape
// ---------------------------------------------------------------------------

Widget buildBlockEscapeLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Block Escape',
      bg: const [Color(0xFF5C3D2E), Color(0xFF3A2518)],
      accent: const Color(0xFFE74C3C),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _BlockEscapeArtPainter(t),
    );

class _BlockEscapeArtPainter extends CustomPainter {
  final double t;
  const _BlockEscapeArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFF5C3D2E));

    final cell = artSize / 5;
    final boardRect = Rect.fromLTWH(zone.left, zone.top, cell * 5, cell * 5);
    final boardBorder = Paint()
      ..color = const Color(0xFFA67C5B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.deflate(1), Radius.circular(cell * 0.25)),
      boardBorder,
    );

    final blockR = Radius.circular(cell * 0.18);
    final gap = cell * 0.06;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    double yb1Row;
    double yb2Row;
    double redCol;
    double glowAlpha = 0.0;

    if (t < 0.25) {
      yb1Row = 1.0;
      yb2Row = 2.0;
      redCol = 0.0;
    } else if (t < 0.45) {
      final p = Curves.easeInOutCubic.transform((t - 0.25) / 0.20);
      yb1Row = 1.0 - p * 1.0;
      yb2Row = 2.0;
      redCol = 0.0;
    } else if (t < 0.55) {
      yb1Row = 0.0;
      yb2Row = 2.0;
      redCol = 0.0;
    } else if (t < 0.75) {
      final p = Curves.easeInOutCubic.transform((t - 0.55) / 0.20);
      yb1Row = 0.0;
      yb2Row = 2.0 + p * 1.0;
      redCol = 0.0;
    } else if (t < 0.80) {
      yb1Row = 0.0;
      yb2Row = 3.0;
      redCol = 0.0;
    } else if (t < 0.92) {
      yb1Row = 0.0;
      yb2Row = 3.0;
      final p = Curves.easeInOutCubic.transform((t - 0.80) / 0.12);
      redCol = p * 3.0;
    } else {
      yb1Row = 0.0;
      yb2Row = 3.0;
      redCol = 3.0;
      final p = ((t - 0.92) / 0.08);
      glowAlpha = 0.4 * math.sin(p * math.pi);
    }

    final g1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(zone.left + 2 * cell + gap, zone.top + yb1Row * cell + gap,
          cell - gap * 2, 2 * cell - gap * 2),
      blockR,
    );
    canvas.drawRRect(g1.shift(const Offset(0, 1.5)), shadowPaint);
    canvas.drawRRect(g1, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEEC060), Color(0xFFE8A838)],
      ).createShader(g1.outerRect));

    final g2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(zone.left + 3 * cell + gap, zone.top + yb2Row * cell + gap,
          cell - gap * 2, 2 * cell - gap * 2),
      blockR,
    );
    canvas.drawRRect(g2.shift(const Offset(0, 1.5)), shadowPaint);
    canvas.drawRRect(g2, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEEC060), Color(0xFFE8A838)],
      ).createShader(g2.outerRect));

    final g3 = RRect.fromRectAndRadius(
      Rect.fromLTWH(zone.left + 0 * cell + gap, zone.top + 3 * cell + gap,
          cell - gap * 2, 2 * cell - gap * 2),
      blockR,
    );
    canvas.drawRRect(g3.shift(const Offset(0, 1.5)), shadowPaint);
    canvas.drawRRect(g3, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEEC060), Color(0xFFE8A838)],
      ).createShader(g3.outerRect));

    final g4 = RRect.fromRectAndRadius(
      Rect.fromLTWH(zone.left + 0 * cell + gap, zone.top + 0 * cell + gap,
          2 * cell - gap * 2, cell - gap * 2),
      blockR,
    );
    canvas.drawRRect(g4.shift(const Offset(0, 1.5)), shadowPaint);
    canvas.drawRRect(g4, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEEC060), Color(0xFFE8A838)],
      ).createShader(g4.outerRect));

    if (glowAlpha > 0) {
      canvas.drawRect(
        Rect.fromLTWH(zone.left + redCol * cell, zone.top + 2 * cell, 2 * cell, cell),
        Paint()
          ..color = const Color(0xFFE74C3C).withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(zone.left + redCol * cell + gap, zone.top + 2 * cell + gap,
          2 * cell - gap * 2, cell - gap * 2),
      blockR,
    );
    canvas.drawRRect(rr.shift(const Offset(0, 1.5)), shadowPaint);
    canvas.drawRRect(rr, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF07070), Color(0xFFE74C3C)],
      ).createShader(rr.outerRect));

    final arrowSize = cell * 0.16;
    final arrowX = rr.right - gap * 2;
    final arrowY = zone.top + 2 * cell + cell * 0.5;
    final arrowPath = Path()
      ..moveTo(arrowX - arrowSize, arrowY - arrowSize)
      ..lineTo(arrowX, arrowY)
      ..lineTo(arrowX - arrowSize, arrowY + arrowSize);
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, cell * 0.06)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final exitY = zone.top + 2 * cell;
    canvas.drawRect(
      Rect.fromLTWH(zone.right - 3, exitY + cell * 0.10, 3, cell * 0.80),
      Paint()..color = const Color(0xFFC0392B).withValues(alpha: 0.60),
    );

    canvas.restore();

    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_BlockEscapeArtPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 4. Sudoku
// ---------------------------------------------------------------------------

Widget buildSudokuLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Sudoku',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _SudokuArtPainter(t),
    );

class _SudokuArtPainter extends CustomPainter {
  final double t;
  const _SudokuArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    canvas.drawRRect(zoneRR, Paint()..color = Colors.white.withValues(alpha: 0.06));

    final cell = artSize / 3;
    final thinPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final thickPaint = Paint()
      ..color = const Color(0xFF4338CA).withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    for (int i = 0; i <= 3; i++) {
      final paint = (i == 0 || i == 3) ? thickPaint : thinPaint;
      canvas.drawLine(
        Offset(zone.left + i * cell, zone.top),
        Offset(zone.left + i * cell, zone.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(zone.left, zone.top + i * cell),
        Offset(zone.right, zone.top + i * cell),
        paint,
      );
    }

    canvas.drawLine(Offset(zone.left, zone.top), Offset(zone.right, zone.top), thickPaint);
    canvas.drawLine(Offset(zone.left, zone.bottom), Offset(zone.right, zone.bottom), thickPaint);
    canvas.drawLine(Offset(zone.left, zone.top), Offset(zone.left, zone.bottom), thickPaint);
    canvas.drawLine(Offset(zone.right, zone.top), Offset(zone.right, zone.bottom), thickPaint);

    final prefilled = [
      [0, 0, '5'],
      [2, 0, '3'],
      [0, 1, '1'],
      [1, 1, '6'],
      [1, 2, '9'],
      [2, 2, '7'],
    ];
    final animated = [
      [1, 0, '8'],
      [2, 1, '4'],
      [0, 2, '2'],
    ];

    final fontSize = cell * 0.48;
    for (final entry in prefilled) {
      _drawCellText(
        canvas, zone, cell, entry[0] as int, entry[1] as int, entry[2] as String,
        const Color(0xFFE0E7FF).withValues(alpha: 0.85), fontSize, 1.0,
        fontWeight: FontWeight.w900,
      );
    }

    for (int i = 0; i < animated.length; i++) {
      final start = i / animated.length;
      final end = (i + 0.6) / animated.length;
      final p = ((t - start) / (end - start)).clamp(0.0, 1.0);
      if (p > 0) {
        final scale = 0.8 + 0.2 * Curves.easeOutBack.transform(p);
        final alpha = p;
        _drawCellText(
          canvas, zone, cell,
          animated[i][0] as int, animated[i][1] as int, animated[i][2] as String,
          const Color(0xFF818CF8).withValues(alpha: alpha), fontSize, scale,
          fontWeight: FontWeight.w600,
        );
      }
    }

    canvas.restore();

    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawCellText(Canvas canvas, Rect zone, double cell, int col, int row,
      String text, Color color, double fontSize, double scale,
      {FontWeight fontWeight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize * scale,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final cx = zone.left + (col + 0.5) * cell;
    final cy = zone.top + (row + 0.5) * cell;
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SudokuArtPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 5. Water Sort
// ---------------------------------------------------------------------------

Widget buildWaterSortLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Water Sort',
      bg: const [Color(0xFF155E75), Color(0xFF083344)],
      accent: const Color(0xFF22D3EE),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _WaterSortArtPainter(t),
    );

class _WaterSortArtPainter extends CustomPainter {
  final double t;
  const _WaterSortArtPainter(this.t);

  static const _red = Color(0xFFE53935);
  static const _blue = Color(0xFF1E88E5);
  static const _green = Color(0xFF43A047);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    canvas.drawRRect(zoneRR, Paint()
      ..shader = ui.Gradient.linear(
        Offset(zone.left, zone.top), Offset(zone.left, zone.bottom),
        const [Color(0xFF0C4A6E), Color(0xFF164E63)],
      ));

    final tubeW = artSize * 0.18;
    final tubeH = artSize * 0.52;
    final bottomR = tubeW * 0.42;
    final gapX = artSize * 0.07;
    final totalW = 3 * tubeW + 2 * gapX;
    final startX = zone.left + (artSize - totalW) / 2;
    final baseY = zone.top + artSize * 0.85;
    final segH = (tubeH - bottomR * 0.15) / 4;

    final t0cx = startX + tubeW / 2;
    final t1cx = startX + tubeW + gapX + tubeW / 2;
    final t2cx = startX + 2 * (tubeW + gapX) + tubeW / 2;

    double liftT = 0, slideT = 0, tiltT = 0, streamAlpha = 0.0;
    bool waterTransferred = false;

    if (t < 0.08) {
    } else if (t < 0.18) {
      liftT = Curves.easeOut.transform(((t - 0.08) / 0.10).clamp(0.0, 1.0));
    } else if (t < 0.36) {
      liftT = 1.0;
      final p = Curves.easeInOut.transform(((t - 0.18) / 0.18).clamp(0.0, 1.0));
      slideT = p;
      tiltT = p;
    } else if (t < 0.58) {
      liftT = 1.0;
      slideT = 1.0;
      tiltT = 1.0;
      final pourP = ((t - 0.36) / 0.22).clamp(0.0, 1.0);
      streamAlpha = (pourP < 0.12 ? pourP / 0.12 : (pourP > 0.85 ? (1.0 - pourP) / 0.15 : 1.0)).clamp(0.0, 1.0);
      if (t >= 0.47) waterTransferred = true;
    } else if (t < 0.70) {
      waterTransferred = true;
      liftT = 1.0;
      final p = Curves.easeInOut.transform(((t - 0.58) / 0.12).clamp(0.0, 1.0));
      slideT = 1.0 - p;
      tiltT = 1.0 - p;
    } else if (t < 0.80) {
      waterTransferred = true;
      liftT = 1.0 - Curves.easeIn.transform(((t - 0.70) / 0.10).clamp(0.0, 1.0));
    } else {
      waterTransferred = true;
    }

    final liftAmount = artSize * 0.10 * liftT;
    final maxTilt = 0.52;
    final tiltAngle = tiltT * maxTilt;
    final slideDx = gapX * 0.6 * slideT;

    final srcLayers = waterTransferred
        ? const [_green, _blue]
        : const [_green, _blue, _red, _red];
    final destLayers = waterTransferred
        ? const [_red, _red, _red]
        : const <Color>[_red];

    _drawGlassTube(canvas, t2cx, baseY, tubeW, tubeH, bottomR, segH,
        const [_green, _blue, _blue]);

    if (waterTransferred && t > 0.80) {
      final glowP = math.sin(((t - 0.80) / 0.20).clamp(0.0, 1.0) * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(t1cx - tubeW / 2 - 2, baseY - tubeH - 2, tubeW + 4, tubeH + 4),
          Radius.circular(bottomR + 2),
        ),
        Paint()
          ..color = _red.withValues(alpha: 0.25 * glowP)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    _drawGlassTube(canvas, t1cx, baseY, tubeW, tubeH, bottomR, segH, destLayers);

    final pivotX = t0cx + slideDx;
    final pivotY = baseY - liftAmount;
    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.rotate(tiltAngle);
    canvas.translate(-pivotX, -pivotY);
    _drawGlassTube(canvas, t0cx + slideDx, baseY - liftAmount, tubeW, tubeH,
        bottomR, segH, srcLayers);
    canvas.restore();

    if (streamAlpha > 0) {
      final cosA = math.cos(tiltAngle);
      final sinA = math.sin(tiltAngle);
      final rimX = pivotX + (tubeW / 2) * cosA + tubeH * sinA;
      final rimY = pivotY + (tubeW / 2) * sinA - tubeH * cosA;
      final destWaterTop = baseY - destLayers.length * segH;
      final streamW = tubeW * 0.12;

      canvas.drawLine(
        Offset(rimX, rimY),
        Offset(t1cx, math.max(rimY, baseY - tubeH + 2)),
        Paint()
          ..color = _red.withValues(alpha: streamAlpha * 0.70)
          ..strokeWidth = streamW
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(t1cx, baseY - tubeH + 2),
        Offset(t1cx, destWaterTop),
        Paint()
          ..color = _red.withValues(alpha: streamAlpha * 0.85)
          ..strokeWidth = streamW
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();

    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawGlassTube(Canvas canvas, double cx, double by, double tw,
      double th, double br, double segH, List<Color> layers) {
    final left = cx - tw / 2;
    final right = cx + tw / 2;
    final top = by - th;

    final strokePath = Path()
      ..moveTo(left, top)
      ..lineTo(left, by - br)
      ..arcToPoint(Offset(left + br, by), radius: Radius.circular(br))
      ..lineTo(right - br, by)
      ..arcToPoint(Offset(right, by - br), radius: Radius.circular(br))
      ..lineTo(right, top);

    final clipPath = Path.from(strokePath)..close();

    canvas.drawPath(clipPath, Paint()
      ..shader = ui.Gradient.linear(
        Offset(left, top), Offset(right, top),
        [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.03), Colors.white.withValues(alpha: 0.12)],
        const [0.0, 0.5, 1.0],
      ));

    if (layers.isNotEmpty) {
      canvas.save();
      canvas.clipPath(clipPath);
      for (int i = 0; i < layers.length; i++) {
        final layerBottom = by - i * segH;
        final layerTop = layerBottom - segH;
        final c = layers[i];
        final dark = Color.lerp(c, Colors.black, 0.15)!;
        final light = Color.lerp(c, Colors.white, 0.25)!;
        final darkEdge = Color.lerp(c, Colors.black, 0.10)!;
        canvas.drawRect(
          Rect.fromLTRB(left, layerTop, right, layerBottom),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(left, layerTop), Offset(right, layerTop),
              [dark, c, light, c, darkEdge],
              const [0.0, 0.2, 0.45, 0.7, 1.0],
            ),
        );
        if (i == layers.length - 1) {
          final hlW = tw * 0.30;
          final hlH = math.max(1.0, segH * 0.08);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(left + tw * 0.15, layerTop + segH * 0.10, hlW, hlH),
              Radius.circular(hlH),
            ),
            Paint()..color = Colors.white.withValues(alpha: 0.30),
          );
        }
      }
      canvas.restore();
    }

    final hlX = left + tw * 0.12;
    final hlW = tw * 0.12;
    canvas.save();
    canvas.clipPath(clipPath);
    canvas.drawRect(
      Rect.fromLTWH(hlX, top, hlW, th),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(hlX, top), Offset(hlX, by),
          [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.05)],
        ),
    );
    canvas.restore();

    canvas.drawPath(strokePath, Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);
  }

  @override
  bool shouldRepaint(_WaterSortArtPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 6. 2048 Merge
// ---------------------------------------------------------------------------

Widget buildNumberMergeLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: '2048 Merge',
      bg: const [Color(0xFF92400E), Color(0xFF451A03)],
      accent: const Color(0xFFFBBF24),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _NumberMergeArtPainter(t),
    );

class _NumberMergeArtPainter extends CustomPainter {
  final double t;
  const _NumberMergeArtPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    canvas.drawRRect(zoneRR, Paint()..color = const Color(0xFFBBADA0).withValues(alpha: 0.50));

    final cell = artSize / 2;
    final pad = cell * 0.08;
    final tileR = Radius.circular(cell * 0.12);

    final emptyPaint = Paint()..color = const Color(0xFFCDC1B4).withValues(alpha: 0.40);
    for (int r = 0; r < 2; r++) {
      for (int c = 0; c < 2; c++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              zone.left + c * cell + pad,
              zone.top + r * cell + pad,
              cell - pad * 2,
              cell - pad * 2,
            ),
            tileR,
          ),
          emptyPaint,
        );
      }
    }

    const color256 = Color(0xFFEDCC61);
    const color512 = Color(0xFFEDC850);
    const color1024 = Color(0xFFEDC53F);
    const color2048 = Color(0xFFEDC22E);
    const textWhite = Color(0xFFF9F6F2);

    _drawTile(canvas, zone, cell, pad, tileR, 0, 1, '256', color256, textWhite, 1.0);
    _drawTile(canvas, zone, cell, pad, tileR, 1, 1, '512', color512, textWhite, 1.0);

    if (t < 0.30) {
      _drawTile(canvas, zone, cell, pad, tileR, 0, 0, '1024', color1024, textWhite, 1.0);
      _drawTile(canvas, zone, cell, pad, tileR, 1, 0, '1024', color1024, textWhite, 1.0);
    } else if (t < 0.60) {
      final p = Curves.easeInOutCubic.transform((t - 0.30) / 0.30);
      _drawTile(canvas, zone, cell, pad, tileR, 0 + p, 0, '1024', color1024, textWhite, 1.0 - p);
      if (p < 0.8) {
        _drawTile(canvas, zone, cell, pad, tileR, 1, 0, '1024', color1024, textWhite, 1.0 - p * 0.6);
      }
      if (p > 0.8) {
        final popP = ((p - 0.8) / 0.2).clamp(0.0, 1.0);
        final scale = 1.0 + 0.18 * math.sin(popP * math.pi);
        _drawTileScaled(canvas, zone, cell, pad, tileR, 1, 0, '2048', color2048, textWhite, scale);
      }
    } else {
      _drawTile(canvas, zone, cell, pad, tileR, 1, 0, '2048', color2048, textWhite, 1.0);
      if (t < 0.75) {
        final glow = math.sin((t - 0.60) / 0.15 * math.pi) * 0.25;
        if (glow > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(zone.left + cell + pad - 2, zone.top + pad - 2,
                  cell - pad * 2 + 4, cell - pad * 2 + 4),
              tileR),
            Paint()
              ..color = color2048.withValues(alpha: glow)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
        }
      }
    }

    canvas.restore();

    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  double _tileFontSize(double cell, int textLen) {
    if (textLen <= 2) return cell * 0.36;
    if (textLen <= 3) return cell * 0.28;
    return cell * 0.22;
  }

  void _drawTile(Canvas canvas, Rect zone, double cell, double pad,
      Radius tileR, double col, int row, String text, Color bg, Color fg, double alpha) {
    final rect = Rect.fromLTWH(
      zone.left + col * cell + pad,
      zone.top + row * cell + pad,
      cell - pad * 2,
      cell - pad * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, tileR),
      Paint()..color = bg.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
    if (alpha > 0.3) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: fg.withValues(alpha: alpha.clamp(0.0, 1.0)),
            fontSize: _tileFontSize(cell, text.length),
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
    }
  }

  void _drawTileScaled(Canvas canvas, Rect zone, double cell, double pad,
      Radius tileR, int col, int row, String text, Color bg, Color fg, double scale) {
    final cx = zone.left + (col + 0.5) * cell;
    final cy = zone.top + (row + 0.5) * cell;
    final tw = (cell - pad * 2) * scale;
    final th = (cell - pad * 2) * scale;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: tw, height: th);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, tileR),
      Paint()..color = bg,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: fg,
          fontSize: _tileFontSize(cell, text.length) * scale,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_NumberMergeArtPainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// 7. Zip
// ---------------------------------------------------------------------------

Widget buildZipLivingLogo(double size) => buildLivingPreviewLogo(
      size: size,
      title: 'Zip',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      period: const Duration(milliseconds: 3500),
      artBuilder: (t) => _ZipArtPainter(t),
    );

class _ZipArtPainter extends CustomPainter {
  final double t;
  const _ZipArtPainter(this.t);

  static const _checkpoints = [
    [0, 0],
    [2, 1],
    [0, 2],
  ];

  static const _pathCells = [
    [0, 0], [1, 0], [2, 0],
    [2, 1],
    [2, 2], [1, 2], [1, 1],
    [0, 1], [0, 2],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final artSize = w * 0.52;
    final zone = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.40),
      width: artSize,
      height: artSize,
    );
    final zoneRR = RRect.fromRectAndRadius(zone, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(zoneRR);

    final cell = artSize / 3;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (int i = 0; i <= 3; i++) {
      canvas.drawLine(
        Offset(zone.left + i * cell, zone.top),
        Offset(zone.left + i * cell, zone.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(zone.left, zone.top + i * cell),
        Offset(zone.right, zone.top + i * cell),
        gridPaint,
      );
    }

    double pathProgress;
    bool glow = false;
    if (t < 0.70) {
      pathProgress = t / 0.70;
    } else {
      pathProgress = 1.0;
      glow = true;
    }

    final totalSegs = _pathCells.length;
    final filledCells = (pathProgress * totalSegs).floor().clamp(0, totalSegs);
    final segFrac = (pathProgress * totalSegs) - filledCells;

    final fillPaint = Paint()..color = const Color(0xFF818CF8).withValues(alpha: 0.35);
    final glowAlpha = glow ? (0.35 + 0.2 * math.sin((t - 0.70) / 0.30 * math.pi * 2)) : 0.35;
    final glowFill = Paint()..color = Color(0xFF818CF8).withValues(alpha: glowAlpha);

    for (int i = 0; i < filledCells && i < totalSegs; i++) {
      final c = _pathCells[i];
      canvas.drawRect(
        Rect.fromLTWH(zone.left + c[0] * cell + 1, zone.top + c[1] * cell + 1, cell - 2, cell - 2),
        glow ? glowFill : fillPaint,
      );
    }

    if (filledCells >= 2) {
      final linePaint = Paint()
        ..color = const Color(0xFF818CF8).withValues(alpha: 0.70)
        ..strokeWidth = cell * 0.10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final first = _pathCells[0];
      path.moveTo(
        zone.left + (first[0] + 0.5) * cell,
        zone.top + (first[1] + 0.5) * cell,
      );

      for (int i = 1; i < filledCells && i < totalSegs; i++) {
        final c = _pathCells[i];
        path.lineTo(
          zone.left + (c[0] + 0.5) * cell,
          zone.top + (c[1] + 0.5) * cell,
        );
      }

      if (filledCells < totalSegs && segFrac > 0) {
        final prev = _pathCells[filledCells - 1];
        final cur = _pathCells[filledCells];
        path.lineTo(
          zone.left + (prev[0] + (cur[0] - prev[0]) * segFrac + 0.5) * cell,
          zone.top + (prev[1] + (cur[1] - prev[1]) * segFrac + 0.5) * cell,
        );
      }

      canvas.drawPath(path, linePaint);
    }

    for (int ci = 0; ci < _checkpoints.length; ci++) {
      final cp = _checkpoints[ci];
      final cx = zone.left + (cp[0] + 0.5) * cell;
      final cy = zone.top + (cp[1] + 0.5) * cell;
      final cr = cell * 0.22;

      bool reached = false;
      for (int i = 0; i < filledCells && i < totalSegs; i++) {
        if (_pathCells[i][0] == cp[0] && _pathCells[i][1] == cp[1]) {
          reached = true;
          break;
        }
      }

      canvas.drawCircle(
        Offset(cx, cy),
        cr,
        Paint()..color = reached ? const Color(0xFF818CF8) : Colors.white.withValues(alpha: 0.20),
      );
      final numTp = TextPainter(
        text: TextSpan(
          text: '${ci + 1}',
          style: TextStyle(
            color: reached ? Colors.white : Colors.white.withValues(alpha: 0.50),
            fontSize: cr * 1.0,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numTp.paint(canvas, Offset(cx - numTp.width / 2, cy - numTp.height / 2));
    }

    canvas.restore();

    canvas.drawRRect(
      zoneRR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_ZipArtPainter old) => old.t != t;
}
