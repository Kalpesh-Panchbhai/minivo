import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildNumberSequenceLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Number Sequence',
      bg: const [Color(0xFF312E81), Color(0xFF1E1B4B)],
      accent: const Color(0xFF818CF8),
      art: _NumberSequenceArt,
    );

// ignore: non_constant_identifier_names
void _NumberSequenceArt(Canvas canvas, Rect zone) {
  const accent = Color(0xFF818CF8);
  const labels = ['1', '2', '3', '4'];

  // Four circles laid out in a 2x2 grid, connected 1 -> 2 -> 3 -> 4.
  final r = zone.width * 0.16;
  final cxL = zone.left + zone.width * 0.30;
  final cxR = zone.left + zone.width * 0.70;
  final cyT = zone.top + zone.height * 0.30;
  final cyB = zone.top + zone.height * 0.70;

  final centers = <Offset>[
    Offset(cxL, cyT), // 1
    Offset(cxR, cyT), // 2
    Offset(cxL, cyB), // 3
    Offset(cxR, cyB), // 4
  ];

  // Connecting arrows: 1->2 (right), 2->3 (diagonal down-left), 3->4 (right).
  final arrowPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = zone.width * 0.022
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void arrow(Offset from, Offset to) {
    final dir = (to - from);
    final len = dir.distance;
    if (len == 0) return;
    final unit = Offset(dir.dx / len, dir.dy / len);
    // Trim the segment so it starts/ends at the circle edges, not centers.
    final start = from + unit * (r + zone.width * 0.02);
    final end = to - unit * (r + zone.width * 0.045);
    canvas.drawLine(start, end, arrowPaint);
    // Arrow head.
    final ah = zone.width * 0.06;
    final perp = Offset(-unit.dy, unit.dx);
    final base = end - unit * ah;
    final head = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(base.dx + perp.dx * ah * 0.5, base.dy + perp.dy * ah * 0.5)
      ..lineTo(base.dx - perp.dx * ah * 0.5, base.dy - perp.dy * ah * 0.5)
      ..close();
    canvas.drawPath(head, Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  arrow(centers[0], centers[1]);
  arrow(centers[1], centers[2]);
  arrow(centers[2], centers[3]);

  for (int i = 0; i < centers.length; i++) {
    final c = centers[i];
    final highlighted = i == 0;
    // Contact shadow.
    canvas.drawCircle(
        c.translate(0, 2), r, Paint()..color = Colors.black.withValues(alpha: 0.22));
    // Fill.
    canvas.drawCircle(
      c,
      r,
      Paint()..color = highlighted ? accent : const Color(0xFF312E81),
    );
    // Ring.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = highlighted
            ? Colors.white.withValues(alpha: 0.9)
            : accent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = zone.width * 0.018,
    );
    // Digit.
    final tp = TextPainter(
      text: TextSpan(
        text: labels[i],
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: r * 1.05,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }
}
