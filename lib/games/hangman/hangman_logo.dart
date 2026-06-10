import 'package:flutter/material.dart';

Widget buildHangmanLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF5046E5), Color(0xFF3730A3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _HangmanLogoPainter(),
    ),
  );
}

class _HangmanLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = (w * 0.03).clamp(2.0, 6.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Gallows
    final baseY = h * 0.65;
    final postX = w * 0.25;
    final topY = h * 0.10;
    final beamEndX = w * 0.55;

    canvas.drawLine(Offset(w * 0.15, baseY), Offset(w * 0.45, baseY), paint); // base
    canvas.drawLine(Offset(postX, baseY), Offset(postX, topY), paint);         // pole
    canvas.drawLine(Offset(postX, topY), Offset(beamEndX, topY), paint);       // beam
    canvas.drawLine(Offset(beamEndX, topY), Offset(beamEndX, topY + h * 0.08), paint); // rope

    // Person
    final headCx = beamEndX;
    final headCy = topY + h * 0.08 + h * 0.06;
    final headR = h * 0.06;
    canvas.drawCircle(Offset(headCx, headCy), headR, paint); // head

    final bodyTop = headCy + headR;
    final bodyBot = bodyTop + h * 0.16;
    canvas.drawLine(Offset(headCx, bodyTop), Offset(headCx, bodyBot), paint); // body

    final armY = bodyTop + h * 0.06;
    canvas.drawLine(Offset(headCx, armY), Offset(headCx - w * 0.08, armY + h * 0.08), paint); // left arm
    canvas.drawLine(Offset(headCx, armY), Offset(headCx + w * 0.08, armY + h * 0.08), paint); // right arm

    canvas.drawLine(Offset(headCx, bodyBot), Offset(headCx - w * 0.06, bodyBot + h * 0.12), paint); // left leg
    canvas.drawLine(Offset(headCx, bodyBot), Offset(headCx + w * 0.06, bodyBot + h * 0.12), paint); // right leg

    // Letter blanks
    final blankY = h * 0.78;
    final blankPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = (w * 0.025).clamp(1.5, 4.0)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final bx = w * 0.22 + i * w * 0.12;
      canvas.drawLine(Offset(bx, blankY), Offset(bx + w * 0.08, blankY), blankPaint);
    }

    final fontSize = w * 0.10;
    final tp = TextPainter(
      text: TextSpan(
        text: 'HANGMAN',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 1,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h - tp.height - h * 0.02));
  }

  @override
  bool shouldRepaint(_HangmanLogoPainter old) => false;
}
