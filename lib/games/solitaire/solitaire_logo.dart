import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildSolitaireLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Solitaire',
      bg: const [Color(0xFF14532D), Color(0xFF052E16)],
      accent: const Color(0xFF34D399),
      art: _solitaireArt,
    );

void _solitaireArt(Canvas canvas, Rect zone) {
  final cardW = zone.width * 0.46;
  final cardH = cardW * 1.42;
  final radius = Radius.circular(cardW * 0.14);
  final cx = zone.center.dx;
  final cy = zone.center.dy;

  void card(double offsetX, double offsetY, double angle) {
    canvas.save();
    canvas.translate(cx + offsetX, cy + offsetY);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH);
    final rr = RRect.fromRectAndRadius(rect, radius);
    // soft shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(0, cardH * 0.025), radius),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    // white face
    canvas.drawRRect(rr, Paint()..color = Colors.white);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFF94A3B8).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cardW * 0.03,
    );
    canvas.restore();
  }

  // three fanned cards: back-left, center, top-right
  card(-cardW * 0.54, cardH * 0.04, -0.34);
  card(0, -cardH * 0.01, -0.03);
  card(cardW * 0.52, cardH * 0.03, 0.30);

  // black spade pip on the back-left card
  canvas.save();
  canvas.translate(cx - cardW * 0.54, cy + cardH * 0.04);
  canvas.rotate(-0.34);
  _spade(canvas, Offset.zero, cardW * 0.34, const Color(0xFF111827));
  canvas.restore();

  // top-right card: red heart pip + corner "A"
  canvas.save();
  canvas.translate(cx + cardW * 0.52, cy + cardH * 0.03);
  canvas.rotate(0.30);
  _heart(canvas, Offset(0, cardH * 0.06), cardW * 0.36, const Color(0xFFEF4444));
  final cornerA = TextPainter(
    text: TextSpan(
      text: 'A',
      style: TextStyle(
        color: const Color(0xFFEF4444),
        fontWeight: FontWeight.w900,
        fontSize: cardW * 0.32,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  cornerA.paint(canvas,
      Offset(-cardW * 0.5 + cardW * 0.09, -cardH * 0.5 + cardH * 0.06));
  _heart(canvas, Offset(-cardW * 0.32, -cardH * 0.27), cardW * 0.12,
      const Color(0xFFEF4444));
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

void _spade(Canvas canvas, Offset center, double s, Color color) {
  final paint = Paint()..color = color;
  final p = Path();
  final top = center.dy - s * 0.45;
  p.moveTo(center.dx, top);
  p.cubicTo(
    center.dx + s * 0.62, center.dy + s * 0.05,
    center.dx + s * 0.62, center.dy + s * 0.45,
    center.dx + s * 0.18, center.dy + s * 0.45,
  );
  p.cubicTo(
    center.dx + s * 0.05, center.dy + s * 0.45,
    center.dx + s * 0.02, center.dy + s * 0.40,
    center.dx, center.dy + s * 0.36,
  );
  p.cubicTo(
    center.dx - s * 0.02, center.dy + s * 0.40,
    center.dx - s * 0.05, center.dy + s * 0.45,
    center.dx - s * 0.18, center.dy + s * 0.45,
  );
  p.cubicTo(
    center.dx - s * 0.62, center.dy + s * 0.45,
    center.dx - s * 0.62, center.dy + s * 0.05,
    center.dx, top,
  );
  p.close();
  canvas.drawPath(p, paint);
  // stem
  final stem = Path()
    ..moveTo(center.dx - s * 0.16, center.dy + s * 0.62)
    ..lineTo(center.dx + s * 0.16, center.dy + s * 0.62)
    ..lineTo(center.dx + s * 0.05, center.dy + s * 0.40)
    ..lineTo(center.dx - s * 0.05, center.dy + s * 0.40)
    ..close();
  canvas.drawPath(stem, paint);
}
