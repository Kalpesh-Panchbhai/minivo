import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildSolitaireLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Solitaire',
      bg: const [Color(0xFF14532D), Color(0xFF052E16)],
      accent: const Color(0xFF4ADE80),
      art: _solitaireArt,
    );

void _solitaireArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final cx = zone.center.dx;
  final cy = zone.center.dy;

  final cardW = w * 0.42;
  final cardH = cardW * 1.45;
  final radius = Radius.circular(cardW * 0.12);

  void card(double offsetX, double offsetY, double angle, bool isFront) {
    canvas.save();
    canvas.translate(cx + offsetX, cy + offsetY);
    canvas.rotate(angle);
    final rect =
        Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH);
    final rr = RRect.fromRectAndRadius(rect, radius);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, cardH * 0.02), radius),
      Paint()..color = Colors.black.withValues(alpha: 0.20),
    );

    canvas.drawRRect(rr, Paint()..color = Colors.white);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFF94A3B8).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cardW * 0.025,
    );

    if (!isFront) {
      final innerRect = Rect.fromCenter(
        center: Offset.zero,
        width: cardW * 0.78,
        height: cardH * 0.88,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(innerRect, Radius.circular(cardW * 0.06)),
        Paint()..color = const Color(0xFF4ADE80).withValues(alpha: 0.18),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(innerRect, Radius.circular(cardW * 0.06)),
        Paint()
          ..color = const Color(0xFF4ADE80).withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cardW * 0.02,
      );
    }
    canvas.restore();
  }

  card(-cardW * 0.40, cardH * 0.04, -0.28, false);
  card(cardW * 0.40, cardH * 0.04, 0.26, false);
  card(0, -cardH * 0.02, 0, true);

  canvas.save();
  canvas.translate(cx, cy - cardH * 0.02);

  final tp = TextPainter(
    text: TextSpan(
      text: 'A',
      style: TextStyle(
        color: const Color(0xFFEF4444),
        fontWeight: FontWeight.w900,
        fontSize: cardW * 0.28,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(
    canvas,
    Offset(-cardW * 0.5 + cardW * 0.10, -cardH * 0.5 + cardH * 0.06),
  );

  final smallHeartC = Offset(-cardW * 0.30, -cardH * 0.26);
  _heart(canvas, smallHeartC, cardW * 0.10, const Color(0xFFEF4444));

  _heart(canvas, Offset(0, cardH * 0.06), cardW * 0.32, const Color(0xFFEF4444));

  canvas.restore();
}

void _heart(Canvas canvas, Offset center, double s, Color color) {
  final p = Path();
  final top = center.dy - s * 0.30;
  p.moveTo(center.dx, center.dy + s * 0.5);
  p.cubicTo(
    center.dx - s * 0.8, center.dy - s * 0.05,
    center.dx - s * 0.55, top - s * 0.45,
    center.dx, top + s * 0.05,
  );
  p.cubicTo(
    center.dx + s * 0.55, top - s * 0.45,
    center.dx + s * 0.8, center.dy - s * 0.05,
    center.dx, center.dy + s * 0.5,
  );
  p.close();
  canvas.drawPath(p, Paint()..color = color);
}
