import 'package:flutter/material.dart';

Widget buildMemoryMatchLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF4C3F91), Color(0xFF1971C2), Color(0xFF0D47A1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _MemoryMatchLogoPainter(),
    ),
  );
}

class _MemoryMatchLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Subtle radial glow at center-top
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF74C0FC).withValues(alpha: 0.28),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.30), radius: w * 0.55));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);

    // 2×2 card grid layout — cards occupy top ~72% of height, text gets bottom 25%
    final gap = w * 0.065;
    final cardW = (w * 0.50 - gap) / 2;
    final cardH = cardW * 1.22;
    final gridLeft = (w - (cardW * 2 + gap)) / 2;
    final gridTop = h * 0.05;

    // Draw matched-pair glow under top-left and top-right cards
    _drawMatchGlow(canvas, gridLeft, gridTop, cardW, cardH, gap);

    // Top-left: face-up star (matched pair)
    _drawCard(canvas, gridLeft, gridTop, cardW, cardH, faceUp: true, emoji: '⭐', matched: true);
    // Top-right: face-up star (matched pair)
    _drawCard(canvas, gridLeft + cardW + gap, gridTop, cardW, cardH, faceUp: true, emoji: '⭐', matched: true);
    // Bottom-left: face-down with 3D depth tilt
    _drawCard(canvas, gridLeft, gridTop + cardH + gap, cardW, cardH, faceUp: false, tiltAngle: -0.05);
    // Bottom-right: face-down partially flipped (revealing)
    _drawPartialFlip(canvas, gridLeft + cardW + gap, gridTop + cardH + gap, cardW, cardH);

    // "MEMORY MATCH" text at bottom with shadow
    _drawGameName(canvas, w, h);
  }

  void _drawMatchGlow(Canvas canvas, double gridLeft, double gridTop, double cardW, double cardH, double gap) {
    // Green glow behind the matched pair (top row)
    for (final xOffset in [0.0, cardW + gap]) {
      final glowPaint = Paint()
        ..color = const Color(0xFF22C55E).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(gridLeft + xOffset - 4, gridTop - 4, cardW + 8, cardH + 8),
          Radius.circular(cardW * 0.15),
        ),
        glowPaint,
      );
    }
  }

  void _drawCard(
    Canvas canvas,
    double x,
    double y,
    double cardW,
    double cardH, {
    required bool faceUp,
    String? emoji,
    bool matched = false,
    double tiltAngle = 0.0,
  }) {
    canvas.save();

    if (tiltAngle != 0.0) {
      canvas.translate(x + cardW / 2, y + cardH / 2);
      canvas.rotate(tiltAngle);
      canvas.translate(-(x + cardW / 2), -(y + cardH / 2));
    }

    final rect = Rect.fromLTWH(x, y, cardW, cardH);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(cardW * 0.13));

    // Drop shadow for 3D depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.translate(2, 4),
        Radius.circular(cardW * 0.13),
      ),
      shadowPaint,
    );

    if (faceUp) {
      // Face-up: cream/white background with inner glow
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF0F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);
      canvas.drawRRect(rr, bgPaint);

      // Inner subtle border glow for matched
      if (matched) {
        canvas.drawRRect(
          rr,
          Paint()
            ..color = const Color(0xFF22C55E).withValues(alpha: 0.80)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // Emoji
      if (emoji != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: emoji,
            style: TextStyle(fontSize: cardW * 0.48),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(x + (cardW - tp.width) / 2, y + (cardH - tp.height) / 2),
        );
      }
    } else {
      // Face-down: deep blue/purple gradient
      final bgPaint = Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFF5C6BC0), Color(0xFF3949AB), Color(0xFF1A237E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);
      canvas.drawRRect(rr, bgPaint);

      // Subtle dot pattern
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      const cols = 3;
      const rows = 4;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          final dx = x + cardW * (c + 1) / (cols + 1);
          final dy = y + cardH * (r + 1) / (rows + 1);
          canvas.drawCircle(Offset(dx, dy), cardW * 0.055, dotPaint);
        }
      }

      // Question mark
      final qp = TextPainter(
        text: TextSpan(
          text: '?',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.60),
            fontSize: cardW * 0.40,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      qp.paint(
        canvas,
        Offset(x + (cardW - qp.width) / 2, y + (cardH - qp.height) / 2),
      );

      // Highlight edge (3D top edge)
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(rr, highlightPaint);
    }

    canvas.restore();
  }

  /// Draws a card that looks like it's mid-flip (partially revealed)
  void _drawPartialFlip(Canvas canvas, double x, double y, double cardW, double cardH) {
    // Simulate a card at ~30% of its flip (scaleX = 0.4 from back side)
    const scaleX = 0.40;
    final rect = Rect.fromLTWH(x, y, cardW, cardH);
    final scaledW = cardW * scaleX;
    final scaledRect = Rect.fromLTWH(x + (cardW - scaledW) / 2, y, scaledW, cardH);
    final rr = RRect.fromRectAndRadius(scaledRect, Radius.circular(scaledW * 0.13));

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect.translate(2, 4), Radius.circular(scaledW * 0.13)),
      shadowPaint,
    );

    // Deep blue back (mid-flip still showing back)
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF5C6BC0), Color(0xFF3949AB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(rr, bgPaint);

    // Edge highlight
    canvas.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Small "?" scaled with card
    final qp = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.50),
          fontSize: scaledW * 0.40,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (qp.width < scaledW) {
      qp.paint(
        canvas,
        Offset(scaledRect.left + (scaledW - qp.width) / 2, y + (cardH - qp.height) / 2),
      );
    }
  }

  void _drawGameName(Canvas canvas, double w, double h) {
    // Shadow for text
    void paintText(String text, double fontSize, Color color, double yPos, {double letterSpacing = 0.5}) {
      // Shadow pass
      final shadow = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.40),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: letterSpacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      shadow.paint(canvas, Offset((w - shadow.width) / 2 + 1, yPos + 1.5));

      // Actual text
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: letterSpacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, yPos));
    }

    // Position text in bottom 26% of the logo
    final baseY = h * 0.73;
    final lineH = w * 0.12;

    paintText('MEMORY', lineH, Colors.white, baseY, letterSpacing: 0.8);
    paintText('MATCH', lineH, Colors.white.withValues(alpha: 0.92), baseY + lineH + 3, letterSpacing: 2.0);
  }

  @override
  bool shouldRepaint(_MemoryMatchLogoPainter old) => false;
}

