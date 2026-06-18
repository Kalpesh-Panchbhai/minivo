import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildMemoryMatchLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Memory Match',
      bg: const [Color(0xFF1E40AF), Color(0xFF0B1E4D)],
      accent: const Color(0xFF60A5FA),
      art: _memoryMatchArt,
    );

void _memoryMatchArt(Canvas canvas, Rect zone) {
  const n = 2;
  final gap = zone.width * 0.09;
  final card = (zone.width - gap) / n;
  final radius = Radius.circular(card * 0.2);

  Rect cardRect(int r, int c) => Rect.fromLTWH(
      zone.left + c * (card + gap), zone.top + r * (card + gap), card, card);

  void drawCard(Rect rect, Color fill) {
    final rr = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(rr.shift(const Offset(0, 1.5)),
        Paint()..color = Colors.black.withValues(alpha: 0.22));
    canvas.drawRRect(rr, Paint()..color = fill);
    canvas.drawRRect(
        rr,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = card * 0.04);
  }

  void drawStar(Offset c, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.42;
      final angle = -math.pi / 2 + i * (math.pi / 5);
      final p =
          Offset(c.dx + radius * math.cos(angle), c.dy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void drawQuestion(Rect rect) {
    final tp = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w900,
            fontSize: card * 0.58,
            height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
  }

  // Top-left & bottom-right: face-up matched pair (same star).
  const faceUp = Color(0xFFEFF6FF);
  final faceUpA = cardRect(0, 0);
  final faceUpB = cardRect(1, 1);
  drawCard(faceUpA, faceUp);
  drawCard(faceUpB, faceUp);
  drawStar(faceUpA.center, card * 0.3, const Color(0xFFFBBF24));
  drawStar(faceUpB.center, card * 0.3, const Color(0xFFFBBF24));

  // Top-right & bottom-left: face-down (? pattern).
  const faceDown = Color(0xFF2563EB);
  final faceDownA = cardRect(0, 1);
  final faceDownB = cardRect(1, 0);
  drawCard(faceDownA, faceDown);
  drawCard(faceDownB, faceDown);
  drawQuestion(faceDownA);
  drawQuestion(faceDownB);
}
