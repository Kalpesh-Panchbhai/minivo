import 'package:flutter/material.dart';

Widget buildMemoryMatchLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF339AF0), Color(0xFF1971C2)],
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

    // 2x2 card grid — cards arranged with gap
    final gap = w * 0.06;
    final cardW = (w * 0.76 - gap) / 2;
    final cardH = cardW * 1.25;
    final gridLeft = (w - (cardW * 2 + gap)) / 2;
    final gridTop = h * 0.10;

    void drawCard(double x, double y, bool faceUp, String? emoji) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, cardW, cardH),
        Radius.circular(cardW * 0.12),
      );

      if (faceUp) {
        // Face-up card: white bg + emoji
        canvas.drawRRect(rect, Paint()..color = Colors.white);
        // Emoji text
        if (emoji != null) {
          final tp = TextPainter(
            text: TextSpan(
              text: emoji,
              style: TextStyle(fontSize: cardW * 0.52),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            Offset(x + (cardW - tp.width) / 2, y + (cardH - tp.height) / 2),
          );
        }
      } else {
        // Face-down: blue gradient + pattern
        final bgPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF4DABF7),
              const Color(0xFF339AF0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromLTWH(x, y, cardW, cardH));
        canvas.drawRRect(rect, bgPaint);

        // Small dots pattern on back
        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        final dotR = cardW * 0.06;
        const cols = 3;
        const rows = 4;
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            final dx = x + cardW * (c + 1) / (cols + 1);
            final dy = y + cardH * (r + 1) / (rows + 1);
            canvas.drawCircle(Offset(dx, dy), dotR, dotPaint);
          }
        }

        // Question mark
        final qp = TextPainter(
          text: TextSpan(
            text: '?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: cardW * 0.42,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        qp.paint(
          canvas,
          Offset(x + (cardW - qp.width) / 2, y + (cardH - qp.height) / 2),
        );
      }

      // Border
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Top-left: face-up dog
    drawCard(gridLeft, gridTop, true, '🐶');
    // Top-right: face-up dog (matching pair)
    drawCard(gridLeft + cardW + gap, gridTop, true, '🐶');
    // Bottom-left: face-down
    drawCard(gridLeft, gridTop + cardH + gap, false, null);
    // Bottom-right: face-down
    drawCard(gridLeft + cardW + gap, gridTop + cardH + gap, false, null);

    // "MEMORY MATCH" text at bottom
    final tp = TextPainter(
      text: TextSpan(
        text: 'MEMORY',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.14,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h - tp.height * 2.1 - h * 0.02));

    final tp2 = TextPainter(
      text: TextSpan(
        text: 'MATCH',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontWeight: FontWeight.w900,
          fontSize: w * 0.14,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset((w - tp2.width) / 2, h - tp2.height - h * 0.03));
  }

  @override
  bool shouldRepaint(_MemoryMatchLogoPainter old) => false;
}
