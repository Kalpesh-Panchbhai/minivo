import 'package:flutter/material.dart';

Widget buildDinoRunLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF7F7F7), Color(0xFFE8E8E8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: ClipRect(
      child: CustomPaint(
        size: Size(size, size),
        painter: _DinoRunLogoPainter(),
      ),
    ),
  );
}

class _DinoRunLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cs = size.width / 6;

    _drawGround(canvas, size, cs);
    _drawCactus(canvas, size, cs);
    _drawDino(canvas, size, cs);
    _drawLabel(canvas, size);
  }

  void _drawGround(Canvas canvas, Size size, double cs) {
    final groundY = size.height * 0.78;
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = const Color(0xFF535353)
        ..strokeWidth = 1.5,
    );
    final dirtPaint = Paint()
      ..color = const Color(0xFF535353).withValues(alpha: 0.3)
      ..strokeWidth = 1;
    for (double x = cs * 0.5; x < size.width; x += cs * 1.2) {
      canvas.drawLine(
        Offset(x, groundY + 4),
        Offset(x + cs * 0.4, groundY + 4),
        dirtPaint,
      );
    }
  }

  void _drawCactus(Canvas canvas, Size size, double cs) {
    final groundY = size.height * 0.78;
    final cx = size.width * 0.72;
    final paint = Paint()..color = const Color(0xFF535353);

    final trunkW = cs * 0.22;
    final trunkH = cs * 1.1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - trunkW / 2, groundY - trunkH, trunkW, trunkH),
        Radius.circular(trunkW * 0.3),
      ),
      paint,
    );

    final armW = cs * 0.18;
    final armH = cs * 0.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + trunkW / 2, groundY - trunkH * 0.7, armW, armH),
        Radius.circular(armW * 0.4),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - trunkW / 2 - armW, groundY - trunkH * 0.5, armW, armH * 0.7),
        Radius.circular(armW * 0.4),
      ),
      paint,
    );
  }

  void _drawDino(Canvas canvas, Size size, double cs) {
    final groundY = size.height * 0.78;
    final cx = size.width * 0.28;
    drawPixelDino(canvas, cx, groundY, cs * 0.14, const Color(0xFF535353), const Color(0xFFF7F7F7));
  }

  void _drawLabel(Canvas canvas, Size size) {
    final fontSize = size.width * 0.125;
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'DINO RUN',
        style: TextStyle(
          color: const Color(0xFF535353),
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        size.height - textPainter.height - size.height * 0.03,
      ),
    );
  }

  @override
  bool shouldRepaint(_DinoRunLogoPainter old) => false;
}

void drawPixelDino(Canvas canvas, double x, double groundY, double s,
    Color fg, Color bg,
    {bool dead = false, bool blink = false,
     double? legPhase, bool inAir = false}) {

  const body = [
    8,0, 9,0, 10,0, 11,0, 12,0, 13,0,
    7,1, 8,1, 9,1, 10,1, 11,1, 12,1, 13,1, 14,1,
    7,2, 8,2, 9,2, 10,2, 11,2, 12,2, 13,2, 14,2,
    7,3, 8,3, 9,3, 10,3, 11,3, 12,3, 13,3, 14,3,
    7,4, 8,4, 9,4, 10,4, 11,4, 12,4, 13,4, 14,4,
    7,5, 8,5, 9,5, 10,5, 11,5, 12,5, 13,5, 14,5,
    7,6, 8,6, 9,6, 10,6, 11,6,
    6,7, 7,7, 8,7, 9,7, 10,7, 11,7, 12,7, 13,7, 14,7, 15,7,
    5,8, 6,8, 7,8, 8,8, 9,8, 10,8,
    4,9, 5,9, 6,9, 7,9, 8,9, 9,9, 10,9, 13,9, 14,9,
    3,10, 4,10, 5,10, 6,10, 7,10, 8,10, 9,10, 10,10, 13,10,
    2,11, 3,11, 4,11, 5,11, 6,11, 7,11, 8,11, 9,11, 10,11, 11,11,
    1,12, 2,12, 3,12, 4,12, 5,12, 6,12, 7,12, 8,12, 9,12, 10,12, 11,12,
    0,13, 1,13, 2,13, 3,13, 4,13, 5,13, 6,13, 7,13, 8,13, 9,13, 10,13,
    0,14, 1,14, 2,14, 3,14, 4,14, 5,14, 6,14, 7,14, 8,14, 9,14, 10,14, 11,14,
    1,15, 2,15, 3,15, 4,15, 5,15, 6,15, 7,15, 8,15, 9,15, 10,15,
    2,16, 3,16, 5,16, 6,16, 7,16, 8,16, 9,16,
    3,17, 5,17, 6,17, 7,17, 8,17,
  ];

  const legsStand = [6,18, 7,18, 6,19, 7,19, 6,20, 9,18, 10,18, 9,19, 10,19, 10,20];
  const legsA     = [6,18, 7,18, 6,19, 7,19, 6,20, 7,20, 9,18, 10,18, 10,19];
  const legsB     = [6,18, 7,18, 7,19, 9,18, 10,18, 9,19, 10,19, 9,20, 10,20];

  final path = Path();
  for (int i = 0; i < body.length; i += 2) {
    path.addRect(Rect.fromLTWH(x + body[i] * s, groundY - (21 - body[i + 1]) * s, s, s));
  }

  final legs = (inAir || legPhase == null)
      ? legsStand
      : ((legPhase % 6.2832) < 3.1416 ? legsA : legsB);
  for (int i = 0; i < legs.length; i += 2) {
    path.addRect(Rect.fromLTWH(x + legs[i] * s, groundY - (21 - legs[i + 1]) * s, s, s));
  }

  canvas.drawPath(path, Paint()..color = fg);

  const eyeX = 13, eyeY = 1;
  final ex = x + eyeX * s;
  final ey = groundY - (21 - eyeY) * s;
  if (dead) {
    final xp = Paint()..color = bg..strokeWidth = s * 0.6..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(ex, ey), Offset(ex + s, ey + s), xp);
    canvas.drawLine(Offset(ex + s, ey), Offset(ex, ey + s), xp);
  } else if (blink) {
    canvas.drawRect(Rect.fromLTWH(ex, ey + s * 0.4, s, s * 0.2), Paint()..color = bg);
  } else {
    canvas.drawRect(Rect.fromLTWH(ex, ey, s, s), Paint()..color = bg);
  }
}
