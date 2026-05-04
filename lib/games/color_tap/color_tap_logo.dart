import 'dart:math' as math;

import 'package:flutter/material.dart';

Widget buildColorTapLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _ColorTapLogoPainter(),
    ),
  );
}

class _ColorTapLogoPainter extends CustomPainter {
  // Vivid game colors
  static const _palette = [
    Color(0xFFEF4444), // red
    Color(0xFF3B82F6), // blue
    Color(0xFF22C55E), // green
    Color(0xFFEAB308), // yellow
    Color(0xFF8B5CF6), // purple
    Color(0xFFF97316), // orange
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.43;
    final r = size.width * 0.26;

    // ── Background gradient fill for the whole tile ──────────────────
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1A0500), Color(0xFF2D0B00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // ── Subtle radial glow behind circle cluster ─────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      r * 2.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6B35).withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 2.2)),
    );

    // ── Overlapping colored rings (depth effect) ──────────────────────
    // Draw 6 overlapping colored circles in a flower/cluster pattern
    const ringCount = 6;
    final ringR = r * 0.62;
    final orbitR = r * 0.80;

    // Shadow pass (draw all shadows first for depth)
    for (int i = 0; i < ringCount; i++) {
      final angle = (i / ringCount) * 2 * math.pi - math.pi / 2;
      final dx = cx + math.cos(angle) * orbitR;
      final dy = cy + math.sin(angle) * orbitR;
      canvas.drawCircle(
        Offset(dx, dy + 3),
        ringR,
        Paint()..color = Colors.black.withValues(alpha: 0.30),
      );
    }

    // Colored rings pass with gradient fills and glows
    for (int i = 0; i < ringCount; i++) {
      final angle = (i / ringCount) * 2 * math.pi - math.pi / 2;
      final dx = cx + math.cos(angle) * orbitR;
      final dy = cy + math.sin(angle) * orbitR;
      final col = _palette[i];

      // Outer glow
      canvas.drawCircle(
        Offset(dx, dy),
        ringR * 1.30,
        Paint()
          ..shader = RadialGradient(
            colors: [col.withValues(alpha: 0.40), Colors.transparent],
          ).createShader(
              Rect.fromCircle(center: Offset(dx, dy), radius: ringR * 1.30)),
      );

      // Main circle with radial gradient (light center → vivid edge)
      canvas.drawCircle(
        Offset(dx, dy),
        ringR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color.lerp(col, Colors.white, 0.42)!,
              col,
              Color.lerp(col, Colors.black, 0.22)!,
            ],
            stops: const [0.0, 0.55, 1.0],
            center: const Alignment(-0.35, -0.35),
          ).createShader(Rect.fromCircle(center: Offset(dx, dy), radius: ringR)),
      );

      // Thin colored ring outline for definition
      canvas.drawCircle(
        Offset(dx, dy),
        ringR,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Specular highlight (glossy top-left spot)
      canvas.drawCircle(
        Offset(dx - ringR * 0.28, dy - ringR * 0.28),
        ringR * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // ── Center hub circle ──────────────────────────────────────────────
    // A bright white hub sits on top of all rings
    canvas.drawCircle(
      Offset(cx, cy + 1.5),
      r * 0.38,
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.38,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, const Color(0xFFFFE8D5)],
          center: const Alignment(-0.3, -0.3),
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.38)),
    );

    // Tap ripple rings emanating from center hub
    for (int j = 1; j <= 2; j++) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * 0.38 + j * r * 0.22,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10 / j)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 - j * 0.4,
      );
    }

    // Finger-tap dot in the hub center
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.12,
      Paint()..color = const Color(0xFFFF6B35),
    );

    // ── "COLOR TAP" label at bottom ────────────────────────────────────
    // Background pill for text legibility
    final textY = size.height - size.height * 0.20;
    final pillH = size.height * 0.175;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, textY), width: size.width * 0.90, height: pillH),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF922B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(pillRect.outerRect),
    );

    // Subtle shine strip on pill
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            pillRect.left, pillRect.top, pillRect.width, pillH * 0.45),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'COLOR TAP',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size.width * 0.125,
          letterSpacing: 0.6,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.30),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, textY - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_ColorTapLogoPainter old) => false;
}
