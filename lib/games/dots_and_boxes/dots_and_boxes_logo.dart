import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../shared/animated_background.dart';

const Color _kP1Color = Color(0xFF4DABF7);
const Color _kP2Color = Color(0xFFFF6B6B);

Widget buildDotsAndBoxesLogo(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF74C0FC), Color(0xFF339AF0), Color(0xFF1971C2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: CustomPaint(
      size: Size(size, size),
      painter: _DotsAndBoxesLogoPainter(),
    ),
  );
}

class _DotsAndBoxesLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 3×3 dot grid → 2×2 box grid, shifted up to leave room for label
    final gridSize = w * 0.62;
    final left = (w - gridSize) / 2;
    final top  = h * 0.07;
    final step = gridSize / 2;

    Offset dot(int col, int row) =>
        Offset(left + col * step, top + row * step);

    // ── Box fills ──────────────────────────────────────────────
    // Top-left box: P1 blue
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dot(0, 0).dx + 2, dot(0, 0).dy + 2, step - 4, step - 4),
        const Radius.circular(5),
      ),
      Paint()..color = _kP1Color.withValues(alpha: 0.55),
    );
    // Bottom-right box: P2 coral
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dot(1, 1).dx + 2, dot(1, 1).dy + 2, step - 4, step - 4),
        const Radius.circular(5),
      ),
      Paint()..color = _kP2Color.withValues(alpha: 0.55),
    );

    // ── Lines ─────────────────────────────────────────────────
    final lineW = (w * 0.048).clamp(3.0, 8.0);

    void drawLine(Offset a, Offset b, Color color) {
      // glow
      canvas.drawLine(a, b, Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = lineW + 5
        ..strokeCap = StrokeCap.round);
      // solid
      canvas.drawLine(a, b, Paint()
        ..color = color
        ..strokeWidth = lineW
        ..strokeCap = StrokeCap.round);
      // white core
      canvas.drawLine(a, b, Paint()
        ..color = Colors.white.withValues(alpha: 0.50)
        ..strokeWidth = lineW * 0.32
        ..strokeCap = StrokeCap.round);
    }

    // P1 (blue) — forms the top-left box
    drawLine(dot(0, 0), dot(1, 0), _kP1Color);
    drawLine(dot(0, 0), dot(0, 1), _kP1Color);
    drawLine(dot(1, 0), dot(1, 1), _kP1Color);
    drawLine(dot(0, 1), dot(1, 1), _kP1Color);

    // P2 (coral) — forms the bottom-right box
    drawLine(dot(1, 1), dot(2, 1), _kP2Color);
    drawLine(dot(1, 1), dot(1, 2), _kP2Color);
    drawLine(dot(2, 1), dot(2, 2), _kP2Color);
    drawLine(dot(1, 2), dot(2, 2), _kP2Color);

    // Shared / neutral divider lines (white, thinner)
    final neutralPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = lineW * 0.55
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(dot(1, 0), dot(2, 0), neutralPaint);
    canvas.drawLine(dot(2, 0), dot(2, 1), neutralPaint);
    canvas.drawLine(dot(0, 1), dot(0, 2), neutralPaint);
    canvas.drawLine(dot(0, 2), dot(1, 2), neutralPaint);

    // ── Dots ──────────────────────────────────────────────────
    final dotR = (w * 0.060).clamp(4.0, 10.0);
    for (int r = 0; r <= 2; r++) {
      for (int c = 0; c <= 2; c++) {
        final center = dot(c, r);
        // soft glow
        canvas.drawCircle(center, dotR + 3,
            Paint()..color = Colors.white.withValues(alpha: 0.18));
        // body
        canvas.drawCircle(center, dotR,
            Paint()..color = Colors.white);
        // specular
        canvas.drawCircle(
          center - Offset(dotR * 0.28, dotR * 0.30),
          dotR * 0.32,
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
      }
    }

    // ── "DOTS & BOXES" label at bottom ────────────────────────
    final fontSize = (w * 0.115).clamp(8.0, 18.0);
    final tp = TextPainter(
      text: TextSpan(
        text: 'DOTS & BOXES',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 0.5,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h - tp.height - h * 0.06));
  }

  @override
  bool shouldRepaint(_DotsAndBoxesLogoPainter old) => false;
}

// ── Animated background painter for the picker screen ─────────────────────

class DotsAndBoxesBgPainter extends AnimatedBgPainter {
  const DotsAndBoxesBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = const Color(0xFF339AF0).withValues(alpha: 0.09)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF339AF0).withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    final boxPaint1 = Paint()
      ..color = _kP1Color.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final boxPaint2 = Paint()
      ..color = _kP2Color.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final clusters = [
      (0.08, 0.10, 22.0, 0.0, true),
      (0.82, 0.06, 18.0, 0.8, false),
      (0.15, 0.58, 15.0, 1.6, true),
      (0.88, 0.45, 20.0, 2.4, false),
      (0.05, 0.82, 17.0, 3.2, true),
      (0.72, 0.88, 14.0, 4.0, false),
      (0.50, 0.02, 12.0, 4.8, true),
      (0.40, 0.96, 16.0, 5.6, false),
    ];

    for (final (xRel, yRel, step, itemPhase, useP1) in clusters) {
      final bobY = math.sin(phase + itemPhase * 0.5) * (step * 0.20);
      final cx = w * xRel;
      final cy = h * yRel + bobY;
      final rot = math.sin(phase + itemPhase) * 0.10;

      canvas.save();
      canvas.translate(cx + step, cy + step);
      canvas.rotate(rot);
      canvas.translate(-(cx + step), -(cy + step));

      final bx = useP1 ? boxPaint1 : boxPaint2;
      canvas.drawRect(Rect.fromLTWH(cx, cy, step, step), bx);
      canvas.drawLine(Offset(cx, cy), Offset(cx + step, cy), linePaint);
      canvas.drawLine(Offset(cx + step, cy), Offset(cx + step, cy + step), linePaint);
      canvas.drawLine(Offset(cx + step, cy + step), Offset(cx, cy + step), linePaint);
      canvas.drawLine(Offset(cx, cy + step), Offset(cx, cy), linePaint);

      final dr = step * 0.14;
      for (final (dx, dy) in [(0.0, 0.0), (step, 0.0), (0.0, step), (step, step)]) {
        canvas.drawCircle(Offset(cx + dx, cy + dy), dr, dotPaint);
      }

      canvas.restore();
    }
  }
}
