import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Widget buildZipLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _ZipLogoPainter(),
    ),
  );
}

class _ZipLogoPainter extends CustomPainter {
  static const _kGreen = Color(0xFF22C55E);
  static const _kGreenDark = Color(0xFF16A34A);
  static const _kBg = Color(0xFFF0FDF4);
  static const _kCellBg = Color(0xFFDCFCE7);
  static const _kGridLine = Color(0xFFD1D5DB);
  static const _kEmpty = Color(0xFFF3F4F6);
  static const _kDark = Color(0xFF1F2937);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgRR = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(w * 0.18));
    canvas.drawRRect(bgRR, Paint()..color = _kBg);

    const n = 4;
    final cellSz = w * 0.17;
    final gap = w * 0.025;
    final gridW = n * cellSz + (n - 1) * gap;
    final ox = (w - gridW) / 2;
    final oy = (h - gridW) / 2 - w * 0.04;

    final outerR = Rect.fromLTWH(ox - gap, oy - gap, gridW + 2 * gap, gridW + 2 * gap);
    final outerRR = RRect.fromRectAndRadius(outerR, Radius.circular(w * 0.1));
    canvas.save();
    canvas.clipRRect(outerRR);
    canvas.drawRect(outerR, Paint()..color = _kGridLine);

    final trail = [
      [0, 0], [0, 1], [0, 2], [0, 3],
      [1, 3], [1, 2], [1, 1], [1, 0],
      [2, 0], [2, 1], [2, 2], [2, 3],
    ];
    final trailSet = <int>{};
    for (final p in trail) trailSet.add(p[0] * n + p[1]);

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        final x = ox + c * (cellSz + gap);
        final y = oy + r * (cellSz + gap);
        final ci = r * n + c;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSz, cellSz),
          Paint()..color = trailSet.contains(ci) ? _kCellBg : _kEmpty,
        );
      }
    }

    if (trail.length > 1) {
      final pathObj = Path();
      Offset _c(List<int> p) => Offset(ox + p[1] * (cellSz + gap) + cellSz / 2, oy + p[0] * (cellSz + gap) + cellSz / 2);
      final first = _c(trail.first);
      final last = _c(trail.last);
      pathObj.moveTo(first.dx, first.dy);
      for (int i = 1; i < trail.length; i++) {
        final p = _c(trail[i]);
        pathObj.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        pathObj,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSz * 0.62
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = ui.Gradient.linear(first, last, [_kGreenDark, _kGreen]),
      );
    }

    canvas.restore();

    canvas.drawRRect(outerRR, Paint()..color = const Color(0xFFBBF7D0)..style = PaintingStyle.stroke..strokeWidth = w * 0.015);

    final checkpoints = {0: 1, 5: 2, 11: 3};
    for (final entry in checkpoints.entries) {
      final p = trail[entry.key];
      final cx = ox + p[1] * (cellSz + gap) + cellSz / 2;
      final cy = oy + p[0] * (cellSz + gap) + cellSz / 2;
      final cr = cellSz * 0.28;
      canvas.drawCircle(Offset(cx, cy + 1), cr, Paint()..color = Colors.black.withValues(alpha: 0.15));
      canvas.drawCircle(Offset(cx, cy), cr, Paint()..color = _kDark);
      final tp = TextPainter(
        text: TextSpan(
          text: '${entry.value}',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: cellSz * 0.32),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }

    final textY = h - w * 0.12;
    final tp = TextPainter(
      text: TextSpan(
        text: 'ZIP',
        style: TextStyle(
          color: _kDark,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.14,
          letterSpacing: 3.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ZipLogoPainter old) => false;
}
