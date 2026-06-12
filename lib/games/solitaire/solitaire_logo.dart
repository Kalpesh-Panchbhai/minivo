import 'package:flutter/material.dart';

Widget buildSolitaireLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _SolitaireLogoPainter(),
    ),
  );
}

class _SolitaireLogoPainter extends CustomPainter {
  static const _kBg1 = Color(0xFF0B3D2E);
  static const _kBg2 = Color(0xFF06291E);
  static const _kRed = Color(0xFFE53E3E);
  static const _kBlack = Color(0xFF1A1A2E);
  static const _kCard = Color(0xFFF9FAFB);
  static const _kAccent = Color(0xFF22C55E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(bgRect, Paint()
      ..shader = const LinearGradient(colors: [_kBg1, _kBg2], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(bgRect));

    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.4,
      Paint()..shader = RadialGradient(colors: [_kAccent.withValues(alpha: 0.12), Colors.transparent])
        .createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.4), radius: w * 0.4)));

    final cardW = w * 0.26;
    final cardH = cardW * 1.45;

    void drawCard(double cx, double cy, double angle, String symbol, Color suitColor, {bool faceDown = false}) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
        Radius.circular(cardW * 0.12),
      );
      canvas.drawRRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.25));

      if (faceDown) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, -1), width: cardW, height: cardH),
            Radius.circular(cardW * 0.12),
          ),
          Paint()..shader = const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]).createShader(rect.outerRect),
        );
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 4; j++) {
            canvas.drawCircle(
              Offset(-cardW * 0.3 + i * cardW * 0.3, -cardH * 0.35 + j * cardH * 0.23),
              1.5,
              Paint()..color = Colors.white.withValues(alpha: 0.15),
            );
          }
        }
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(0, -1), width: cardW, height: cardH),
            Radius.circular(cardW * 0.12),
          ),
          Paint()..color = _kCard,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: symbol,
            style: TextStyle(color: suitColor, fontSize: cardW * 0.55, fontWeight: FontWeight.w900),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      }
      canvas.restore();
    }

    drawCard(w * 0.28, h * 0.30, -0.15, '♠', _kBlack);
    drawCard(w * 0.50, h * 0.28, 0.0, '♥', _kRed);
    drawCard(w * 0.72, h * 0.32, 0.12, '♦', _kRed);
    drawCard(w * 0.22, h * 0.55, -0.08, '', Colors.transparent, faceDown: true);
    drawCard(w * 0.62, h * 0.56, 0.06, 'A', _kBlack);

    final textY = h - h * 0.18;
    final pillH = h * 0.16;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, textY), width: w * 0.92, height: pillH),
      const Radius.circular(8),
    );
    canvas.drawRRect(pillRect, Paint()
      ..shader = const LinearGradient(colors: [_kAccent, Color(0xFF16A34A)]).createShader(pillRect.outerRect));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(pillRect.left, pillRect.top, pillRect.width, pillH * 0.45), const Radius.circular(8)),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: 'SOLITAIRE',
        style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900, fontSize: w * 0.11, letterSpacing: 0.8,
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.30), offset: const Offset(0, 1), blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SolitaireLogoPainter old) => false;
}
