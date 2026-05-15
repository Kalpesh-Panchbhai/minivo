import 'dart:math' as math;

import 'package:flutter/material.dart';

Widget buildWhackAMoleLogo(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      size: Size(size, size),
      painter: _WhackAMoleLogoPainter(),
    ),
  );
}

class _WhackAMoleLogoPainter extends CustomPainter {
  static const _kGrassLight = Color(0xFF66BB6A);
  static const _kGrassDark  = Color(0xFF388E3C);
  static const _kBrown      = Color(0xFF8B6914);
  static const _kDarkHole   = Color(0xFF3D2B1F);
  static const _kAccent     = Color(0xFF66BB6A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bgRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bgRect),
    );

    canvas.drawCircle(
      Offset(w * 0.5, h * 0.38),
      w * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _kGrassLight.withValues(alpha: 0.20),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.38), radius: w * 0.45)),
    );

    final holes = [
      Offset(w * 0.25, h * 0.32),
      Offset(w * 0.75, h * 0.32),
      Offset(w * 0.50, h * 0.50),
    ];
    for (final pos in holes) {
      canvas.drawOval(
        Rect.fromCenter(center: pos, width: w * 0.28, height: h * 0.09),
        Paint()..color = _kDarkHole,
      );
    }

    _drawMole(canvas, holes[2].dx, holes[2].dy - h * 0.02, w * 0.10, 1.0);
    _drawMole(canvas, holes[0].dx, holes[0].dy - h * 0.02, w * 0.08, 0.5);

    _drawHammer(canvas, w * 0.72, h * 0.18, w * 0.18, -math.pi / 6);

    final starsY = h * 0.16;
    for (int i = 0; i < 3; i++) {
      final sx = w * 0.30 + i * w * 0.20;
      _drawStar(canvas, sx, starsY - (i == 1 ? 6 : 0), 6, const Color(0xFFFFD700));
    }

    final textY = h - h * 0.18;
    final pillH = h * 0.16;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, textY), width: w * 0.92, height: pillH),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..shader = LinearGradient(
          colors: [_kAccent, _kGrassDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(pillRect.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pillRect.left, pillRect.top, pillRect.width, pillH * 0.45),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'WHACK-A-MOLE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: w * 0.095,
          letterSpacing: 0.4,
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
    tp.paint(canvas, Offset((w - tp.width) / 2, textY - tp.height / 2));
  }

  void _drawMole(Canvas canvas, double cx, double cy, double r, double popUp) {
    final bodyH = r * 2.2 * popUp;
    if (bodyH <= 0) return;
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy - bodyH / 2),
      width: r * 2,
      height: bodyH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(r)),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(_kBrown, Colors.white, 0.30)!,
            _kBrown,
            Color.lerp(_kBrown, Colors.black, 0.18)!,
          ],
          stops: const [0.0, 0.5, 1.0],
          center: const Alignment(-0.3, -0.3),
        ).createShader(bodyRect),
    );
    if (popUp > 0.4) {
      final eyeY = cy - bodyH * 0.65;
      canvas.drawCircle(Offset(cx - r * 0.4, eyeY), r * 0.22, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(cx + r * 0.4, eyeY), r * 0.22, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(cx - r * 0.4, eyeY), r * 0.12, Paint()..color = Colors.black);
      canvas.drawCircle(Offset(cx + r * 0.4, eyeY), r * 0.12, Paint()..color = Colors.black);
    }
  }

  void _drawHammer(Canvas canvas, double cx, double cy, double len, double angle) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, len * 0.25), width: len * 0.22, height: len),
        Radius.circular(len * 0.08),
      ),
      Paint()..color = const Color(0xFF795548),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -len * 0.30), width: len * 0.55, height: len * 0.32),
        Radius.circular(len * 0.06),
      ),
      Paint()..color = const Color(0xFF9E9E9E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -len * 0.30), width: len * 0.55, height: len * 0.16),
        Radius.circular(len * 0.04),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    canvas.restore();
  }

  void _drawStar(Canvas canvas, double cx, double cy, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -math.pi / 2 + i * 2 * math.pi / 5;
      final innerAngle = outerAngle + math.pi / 5;
      final outerPt = Offset(cx + math.cos(outerAngle) * r, cy + math.sin(outerAngle) * r);
      final innerPt = Offset(cx + math.cos(innerAngle) * r * 0.45, cy + math.sin(innerAngle) * r * 0.45);
      if (i == 0) {
        path.moveTo(outerPt.dx, outerPt.dy);
      } else {
        path.lineTo(outerPt.dx, outerPt.dy);
      }
      path.lineTo(innerPt.dx, innerPt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.30));
  }

  @override
  bool shouldRepaint(_WhackAMoleLogoPainter old) => false;
}
