import 'package:flutter/material.dart';

Widget buildArrowPuzzleLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _ArrowPuzzleLogoPainter(),
    ),
  );
}

class _ArrowPuzzleLogoPainter extends CustomPainter {
  static const _kBg1 = Color(0xFFF8FAFC);
  static const _kBg2 = Color(0xFFEDE9FE);
  static const _kBlue = Color(0xFF3B82F6);
  static const _kCoral = Color(0xFFF97316);
  static const _kTeal = Color(0xFF0D9488);
  static const _kPurple = Color(0xFF7C3AED);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kBg1, _kBg2],
        ).createShader(bgRect),
    );

    canvas.drawCircle(
      Offset(w * 0.5, h * 0.45),
      w * 0.40,
      Paint()
        ..shader = RadialGradient(
          colors: [_kPurple.withValues(alpha: 0.10), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.45), radius: w * 0.40)),
    );

    final sw = w * 0.045;

    _drawCurvedArrow(canvas, w, h, [
      Offset(w * 0.15, h * 0.18),
      Offset(w * 0.15, h * 0.42),
      Offset(w * 0.40, h * 0.42),
    ], _kBlue, sw, _ArrowHeadDir.right);

    _drawCurvedArrow(canvas, w, h, [
      Offset(w * 0.85, h * 0.15),
      Offset(w * 0.85, h * 0.38),
      Offset(w * 0.60, h * 0.38),
      Offset(w * 0.60, h * 0.55),
    ], _kCoral, sw, _ArrowHeadDir.down);

    _drawCurvedArrow(canvas, w, h, [
      Offset(w * 0.75, h * 0.72),
      Offset(w * 0.40, h * 0.72),
    ], _kTeal, sw, _ArrowHeadDir.left);

    _drawCurvedArrow(canvas, w, h, [
      Offset(w * 0.30, h * 0.58),
      Offset(w * 0.30, h * 0.30),
    ], _kPurple, sw, _ArrowHeadDir.up);

    final textY = h - h * 0.13;
    final pillH = h * 0.14;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, textY), width: w * 0.92, height: pillH),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [_kPurple, Color(0xFF6D28D9)],
        ).createShader(pillRect.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pillRect.left, pillRect.top, pillRect.width, pillH * 0.45),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'ARROW PUZZLE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.082,
          letterSpacing: 0.4,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.30), offset: const Offset(0, 1), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  void _drawCurvedArrow(Canvas canvas, double w, double h, List<Offset> pts, Color color, double sw, _ArrowHeadDir dir) {
    final bodyPath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      bodyPath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(bodyPath, Paint()
      ..color = color
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke);

    final tip = pts.last;
    final headLen = w * 0.10;
    final headW = w * 0.06;
    double ndx, ndy;
    switch (dir) {
      case _ArrowHeadDir.up: ndx = 0; ndy = -1;
      case _ArrowHeadDir.down: ndx = 0; ndy = 1;
      case _ArrowHeadDir.left: ndx = -1; ndy = 0;
      case _ArrowHeadDir.right: ndx = 1; ndy = 0;
    }
    final tipX = tip.dx + ndx * headLen * 0.5;
    final tipY = tip.dy + ndy * headLen * 0.5;
    final perpX = -ndy;
    final perpY = ndx;
    final baseX = tipX - ndx * headLen;
    final baseY = tipY - ndy * headLen;

    final arrowHead = Path()
      ..moveTo(tipX, tipY)
      ..quadraticBezierTo(
        tipX + perpX * headW * 0.3 - ndx * headLen * 0.1,
        tipY + perpY * headW * 0.3 - ndy * headLen * 0.1,
        baseX + perpX * headW, baseY + perpY * headW,
      )
      ..quadraticBezierTo(
        baseX + ndx * headLen * 0.12,
        baseY + ndy * headLen * 0.12,
        baseX - perpX * headW, baseY - perpY * headW,
      )
      ..quadraticBezierTo(
        tipX - perpX * headW * 0.3 - ndx * headLen * 0.1,
        tipY - perpY * headW * 0.3 - ndy * headLen * 0.1,
        tipX, tipY,
      )
      ..close();
    canvas.drawPath(arrowHead, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _ArrowHeadDir { up, down, left, right }
