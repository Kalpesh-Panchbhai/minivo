import 'package:flutter/material.dart';

import '../shared/game_logo_scaffold.dart';

Widget buildMancalaLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'Mancala',
      bg: const [Color(0xFF44271A), Color(0xFF2A1810)],
      accent: const Color(0xFFCD7F32),
      art: _mancalaArt,
    );

void _mancalaArt(Canvas canvas, Rect zone) {
  final w = zone.width;
  final h = zone.height;

  final boardRect = Rect.fromCenter(
    center: zone.center,
    width: w * 0.98,
    height: h * 0.58,
  );
  final boardRR = RRect.fromRectAndRadius(
    boardRect,
    Radius.circular(boardRect.height * 0.45),
  );
  canvas.drawRRect(
    boardRR,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFFBB8844), Color(0xFF8A5B2E)],
      ).createShader(boardRect),
  );
  canvas.drawRRect(
    boardRR,
    Paint()
      ..color = const Color(0xFF5C3316)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025,
  );

  final pitPaint = Paint()..color = const Color(0xFF4A2A10);
  final pitRim = Paint()
    ..color = const Color(0xFF3A1E08)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.012;
  final stonePaint = Paint()..color = const Color(0xFFCD7F32);
  final stoneHi = Paint()..color = Colors.white.withValues(alpha: 0.40);

  final storeW = boardRect.width * 0.11;
  final storeH = boardRect.height * 0.72;

  final leftStore = Rect.fromCenter(
    center: Offset(boardRect.left + boardRect.width * 0.09, boardRect.center.dy),
    width: storeW,
    height: storeH,
  );
  final leftStoreRR = RRect.fromRectAndRadius(leftStore, Radius.circular(storeW * 0.48));
  canvas.drawRRect(leftStoreRR, pitPaint);
  canvas.drawRRect(leftStoreRR, pitRim);

  final rightStore = Rect.fromCenter(
    center: Offset(boardRect.right - boardRect.width * 0.09, boardRect.center.dy),
    width: storeW,
    height: storeH,
  );
  final rightStoreRR = RRect.fromRectAndRadius(rightStore, Radius.circular(storeW * 0.48));
  canvas.drawRRect(rightStoreRR, pitPaint);
  canvas.drawRRect(rightStoreRR, pitRim);

  final pitR = boardRect.height * 0.16;
  final rowTop = boardRect.center.dy - boardRect.height * 0.18;
  final rowBot = boardRect.center.dy + boardRect.height * 0.18;
  final pitLeft = boardRect.left + boardRect.width * 0.25;
  final pitRight = boardRect.right - boardRect.width * 0.25;

  final stoneR = pitR * 0.28;
  const seedCounts = [3, 2, 4, 1, 3, 2];
  int idx = 0;

  for (int row = 0; row < 2; row++) {
    final cy = row == 0 ? rowTop : rowBot;
    for (int col = 0; col < 3; col++) {
      final t = col / 2.0;
      final cx = pitLeft + (pitRight - pitLeft) * t;
      final c = Offset(cx, cy);
      canvas.drawCircle(c, pitR, pitPaint);
      canvas.drawCircle(c, pitR, pitRim);

      final count = seedCounts[idx % seedCounts.length];
      idx++;
      for (int s = 0; s < count; s++) {
        final dist = count == 1 ? 0.0 : pitR * 0.45;
        final stoneOff = Offset(
          c.dx + dist * ((s / count) - 0.5) * 0.8,
          c.dy + (s.isEven ? -pitR * 0.25 : pitR * 0.25),
        );
        canvas.drawCircle(stoneOff, stoneR, stonePaint);
        canvas.drawCircle(
          stoneOff.translate(-stoneR * 0.25, -stoneR * 0.25),
          stoneR * 0.3,
          stoneHi,
        );
      }
    }
  }

  final lsr = storeW * 0.16;
  for (final dy in [-storeH * 0.2, 0.0, storeH * 0.15]) {
    final sc = leftStore.center.translate(0, dy);
    canvas.drawCircle(sc, lsr, stonePaint);
    canvas.drawCircle(sc.translate(-lsr * 0.2, -lsr * 0.2), lsr * 0.3, stoneHi);
  }
  for (final dy in [-storeH * 0.15, storeH * 0.1]) {
    final sc = rightStore.center.translate(0, dy);
    canvas.drawCircle(sc, lsr, stonePaint);
    canvas.drawCircle(sc.translate(-lsr * 0.2, -lsr * 0.2), lsr * 0.3, stoneHi);
  }
}
