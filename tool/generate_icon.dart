import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate app icon PNG', () async {
    const s = 1024;
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromLTWH(0, 0, s.toDouble(), s.toDouble()));

    _drawAppIcon(canvas, Size(s.toDouble(), s.toDouble()));

    final picture = recorder.endRecording();
    final image = await picture.toImage(s, s);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    final file = File('assets/icon/app_icon.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

void _drawAppIcon(Canvas canvas, Size size) {
  final s = size.width;
  final cx = s / 2;
  final cy = s / 2;

  final bgRect = Rect.fromLTWH(0, 0, s, s);
  canvas.drawRect(
    bgRect,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7B73FF), Color(0xFF5248E0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bgRect),
  );

  final dotPaint = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.04);
  for (var x = 0; x < 12; x++) {
    for (var y = 0; y < 12; y++) {
      canvas.drawCircle(
        Offset(s * 0.08 + x * s * 0.08, s * 0.08 + y * s * 0.08),
        s * 0.008,
        dotPaint,
      );
    }
  }

  final glowPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.06)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.15);
  canvas.drawCircle(Offset(cx, cy), s * 0.30, glowPaint);

  final bodyW = s * 0.54;
  final bodyH = s * 0.24;
  final bodyRect =
      Rect.fromCenter(center: Offset(cx, cy), width: bodyW, height: bodyH);

  final gripW = bodyW * 0.21;
  final gripH = bodyH * 1.20;
  for (final side in [-1.0, 1.0]) {
    final gripCx = cx + side * bodyW * 0.42;
    final gripCy = cy + bodyH * 0.20;
    final gripRect = Rect.fromCenter(
      center: Offset(gripCx, gripCy),
      width: gripW,
      height: gripH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          gripRect.shift(Offset(0, s * 0.006)),
          Radius.circular(gripW * 0.44)),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(gripRect, Radius.circular(gripW * 0.44)),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, const Color(0xFFF0F0F8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(gripRect),
    );
  }

  canvas.drawRRect(
    RRect.fromRectAndRadius(
        bodyRect.shift(Offset(0, s * 0.008)),
        Radius.circular(bodyH * 0.38)),
    Paint()..color = Colors.black.withValues(alpha: 0.15),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyH * 0.38)),
    Paint()
      ..shader = LinearGradient(
        colors: [Colors.white, const Color(0xFFF3F3FA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bodyRect),
  );

  final dpadX = cx - bodyW * 0.18;
  final dpadY = cy;
  final dpadArm = bodyH * 0.14;
  final dpadPaint = Paint()..color = const Color(0xFFCBCBDB);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(dpadX, dpadY),
          width: dpadArm,
          height: dpadArm * 2.8),
      Radius.circular(dpadArm * 0.28),
    ),
    dpadPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(dpadX, dpadY),
          width: dpadArm * 2.8,
          height: dpadArm),
      Radius.circular(dpadArm * 0.28),
    ),
    dpadPaint,
  );

  final btnX = cx + bodyW * 0.18;
  final btnY = cy;
  final btnR = bodyH * 0.09;
  final gap = btnR * 2.5;
  const colors = [
    Color(0xFFFF6B6B),
    Color(0xFF51CF66),
    Color(0xFFFFD43B),
    Color(0xFF339AF0),
  ];
  final offsets = [
    Offset(0, -gap),
    Offset(gap, 0),
    Offset(0, gap),
    Offset(-gap, 0),
  ];
  for (var i = 0; i < 4; i++) {
    canvas.drawCircle(
      Offset(btnX, btnY) + offsets[i],
      btnR,
      Paint()..color = colors[i],
    );
  }

  _drawStar(canvas, cx - s * 0.30, cy - s * 0.22, s * 0.04, const Color(0xFFFFD43B));
  _drawStar(canvas, cx + s * 0.32, cy - s * 0.20, s * 0.03, Colors.white.withValues(alpha: 0.7));
  _drawStar(canvas, cx - s * 0.28, cy + s * 0.24, s * 0.025, Colors.white.withValues(alpha: 0.5));
  _drawStar(canvas, cx + s * 0.30, cy + s * 0.22, s * 0.035, const Color(0xFFFFD43B).withValues(alpha: 0.8));

  final dotAccent = Paint()..color = Colors.white.withValues(alpha: 0.12);
  canvas.drawCircle(Offset(cx - s * 0.36, cy - s * 0.10), s * 0.012, dotAccent);
  canvas.drawCircle(Offset(cx + s * 0.38, cy + s * 0.08), s * 0.010, dotAccent);
  canvas.drawCircle(Offset(cx - s * 0.22, cy + s * 0.30), s * 0.008, dotAccent);
  canvas.drawCircle(Offset(cx + s * 0.24, cy - s * 0.28), s * 0.009, dotAccent);
}

void _drawStar(Canvas canvas, double cx, double cy, double r, Color color) {
  final path = Path();
  for (var i = 0; i < 5; i++) {
    final oa = (i * 72 - 90) * math.pi / 180;
    final ia = ((i * 72) + 36 - 90) * math.pi / 180;
    if (i == 0) {
      path.moveTo(cx + r * math.cos(oa), cy + r * math.sin(oa));
    } else {
      path.lineTo(cx + r * math.cos(oa), cy + r * math.sin(oa));
    }
    path.lineTo(cx + r * 0.4 * math.cos(ia), cy + r * 0.4 * math.sin(ia));
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}
