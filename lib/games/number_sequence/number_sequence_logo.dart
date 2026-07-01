import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildNumberSequenceLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Number Sequence',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      art: _numberSequenceArt,
    );

void _numberSequenceArt(Canvas canvas, Rect zone) {
  const accent = Color(0xFF818CF8);
  const labels = ['1', '2', '3', '?'];
  final count = labels.length;

  final r = zone.width * 0.10;
  final totalSpan = zone.width * 0.88;
  final spacing = totalSpan / (count - 1);
  final cy = zone.top + zone.height * 0.50;
  final startX = zone.left + (zone.width - totalSpan) / 2;

  final centers = <Offset>[
    for (int i = 0; i < count; i++) Offset(startX + i * spacing, cy),
  ];

  final linePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.50)
    ..style = PaintingStyle.stroke
    ..strokeWidth = zone.width * 0.022
    ..strokeCap = StrokeCap.round;

  for (int i = 0; i < count - 1; i++) {
    final from = centers[i];
    final to = centers[i + 1];
    final dir = (to - from);
    final len = dir.distance;
    final unit = Offset(dir.dx / len, dir.dy / len);
    final start = from + unit * (r + zone.width * 0.015);
    final end = to - unit * (r + zone.width * 0.04);
    canvas.drawLine(start, end, linePaint);

    final ah = zone.width * 0.045;
    final perp = Offset(-unit.dy, unit.dx);
    final arrowHead = Path()
      ..moveTo(end.dx + unit.dx * ah * 0.3, end.dy + unit.dy * ah * 0.3)
      ..lineTo(end.dx - unit.dx * ah + perp.dx * ah * 0.5,
          end.dy - unit.dy * ah + perp.dy * ah * 0.5)
      ..lineTo(end.dx - unit.dx * ah - perp.dx * ah * 0.5,
          end.dy - unit.dy * ah - perp.dy * ah * 0.5)
      ..close();
    canvas.drawPath(
      arrowHead,
      Paint()..color = Colors.white.withValues(alpha: 0.60),
    );
  }

  for (int i = 0; i < count; i++) {
    final c = centers[i];
    final isQuestion = i == count - 1;

    canvas.drawCircle(
      c.translate(0, 2),
      r,
      Paint()..color = Colors.black.withValues(alpha: 0.20),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()..color = isQuestion ? const Color(0xFF4338CA) : accent,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = isQuestion
            ? const Color(0xFFFBBF24)
            : Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = zone.width * 0.018,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: labels[i],
        style: TextStyle(
          color: isQuestion ? const Color(0xFFFBBF24) : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: r * 1.1,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }
}
