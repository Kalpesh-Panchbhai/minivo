import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/animated_demo.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> ludoSteps() => [
      GameHowToPlayStep(
        text: 'Roll a 6 to release a token from your home area onto the board.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3500),
          painter: (t) => _ReleasePainter(t),
          canvasSize: const Size(200, 200),
        ),
      ),
      GameHowToPlayStep(
        text: 'Roll the die and move your token clockwise by that many spaces.',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3500),
          painter: (t) => _MovePainter(t),
          canvasSize: const Size(200, 200),
        ),
      ),
      GameHowToPlayStep(
        text: 'Land on an opponent to send them home!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 3500),
          painter: (t) => _CapturePainter(t),
          canvasSize: const Size(200, 200),
        ),
      ),
      GameHowToPlayStep(
        text: 'Get all 4 tokens to the center finish area to win!',
        demo: AnimatedDemo(
          period: const Duration(milliseconds: 4000),
          painter: (t) => _WinPainter(t),
          canvasSize: const Size(200, 200),
        ),
      ),
    ];

const _kRed = Color(0xFFE53935);
const _kGreen = Color(0xFF43A047);
const _kYellow = Color(0xFFFDD835);
const _kBlue = Color(0xFF1E88E5);
const _kBoardBg = Color(0xFFF5F0E1);
const _kArm = Color(0xFFD7CFC0);

void _drawLudoBoard(Canvas canvas, Size size) {
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoardBg);

  final s = math.min(size.width, size.height) * 0.88;
  final ox = (size.width - s) / 2;
  final oy = (size.height - s) / 2;
  final u = s / 15;

  final boardRect = RRect.fromRectAndRadius(
    Rect.fromLTWH(ox, oy, s, s),
    Radius.circular(u * 0.6),
  );
  canvas.drawRRect(boardRect, Paint()..color = Colors.white);
  canvas.drawRRect(
    boardRect,
    Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );

  void drawHome(double x, double y, Color color) {
    final rect = Rect.fromLTWH(ox + x * u, oy + y * u, 6 * u, 6 * u);
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final inner = Rect.fromLTWH(
      rect.left + u * 0.8, rect.top + u * 0.8,
      rect.width - u * 1.6, rect.height - u * 1.6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, Radius.circular(u * 0.5)),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  drawHome(0, 0, _kRed);
  drawHome(9, 0, _kGreen);
  drawHome(0, 9, _kBlue);
  drawHome(9, 9, _kYellow);

  void drawArm(double x, double y, double w, double h, Color safeColor) {
    final rect = Rect.fromLTWH(ox + x * u, oy + y * u, w * u, h * u);
    canvas.drawRect(rect, Paint()..color = _kArm.withValues(alpha: 0.3));
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  drawArm(6, 0, 3, 6, _kRed);
  drawArm(9, 6, 6, 3, _kGreen);
  drawArm(6, 9, 3, 6, _kYellow);
  drawArm(0, 6, 6, 3, _kBlue);

  void drawHomeArrow(double cx, double cy, double dx, double dy, Color color) {
    for (int i = 1; i <= 5; i++) {
      final rect = Rect.fromCenter(
        center: Offset(ox + (cx + dx * i) * u, oy + (cy + dy * i) * u),
        width: u * 0.7,
        height: u * 0.7,
      );
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: 0.12 + i * 0.06),
      );
    }
  }

  drawHomeArrow(7.5, 1, 0, 1, _kRed);
  drawHomeArrow(13, 7.5, -1, 0, _kGreen);
  drawHomeArrow(7.5, 13, 0, -1, _kYellow);
  drawHomeArrow(1, 7.5, 1, 0, _kBlue);

  final center = Rect.fromCenter(
    center: Offset(ox + 7.5 * u, oy + 7.5 * u),
    width: 3 * u,
    height: 3 * u,
  );
  final colors = [_kRed, _kGreen, _kYellow, _kBlue];
  for (int i = 0; i < 4; i++) {
    final angle = (i * math.pi / 2) - math.pi / 4;
    final path = Path()
      ..moveTo(center.center.dx, center.center.dy)
      ..lineTo(
        center.center.dx + math.cos(angle - 0.6) * u * 2.0,
        center.center.dy + math.sin(angle - 0.6) * u * 2.0,
      )
      ..lineTo(
        center.center.dx + math.cos(angle + 0.6) * u * 2.0,
        center.center.dy + math.sin(angle + 0.6) * u * 2.0,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = colors[i].withValues(alpha: 0.35));
  }
}

void _drawToken(Canvas canvas, double cx, double cy, double r, Color color,
    {double alpha = 1.0}) {
  if (alpha <= 0) return;
  canvas.drawCircle(
    Offset(cx, cy + r * 0.12),
    r,
    Paint()..color = Colors.black.withValues(alpha: 0.18 * alpha),
  );
  canvas.drawCircle(Offset(cx, cy), r, Paint()..color = color.withValues(alpha: alpha));
  canvas.drawCircle(
    Offset(cx, cy),
    r * 0.55,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.3 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

void _drawDie(Canvas canvas, double cx, double cy, double s, int value) {
  final rect = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(cx, cy), width: s, height: s),
    Radius.circular(s * 0.15),
  );
  canvas.drawRRect(
    rect.shift(const Offset(0, 1.5)),
    Paint()..color = Colors.black.withValues(alpha: 0.12),
  );
  canvas.drawRRect(rect, Paint()..color = Colors.white);
  canvas.drawRRect(
    rect,
    Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );
  final dotR = s * 0.08;
  final dotP = Paint()..color = const Color(0xFF2C3E50);
  final sp = s * 0.25;
  final positions = <Offset>[];
  switch (value) {
    case 1:
      positions.add(Offset(cx, cy));
    case 2:
      positions.addAll([Offset(cx - sp, cy - sp), Offset(cx + sp, cy + sp)]);
    case 3:
      positions.addAll([Offset(cx - sp, cy + sp), Offset(cx, cy), Offset(cx + sp, cy - sp)]);
    case 4:
      positions.addAll([
        Offset(cx - sp, cy - sp), Offset(cx + sp, cy - sp),
        Offset(cx - sp, cy + sp), Offset(cx + sp, cy + sp),
      ]);
    case 5:
      positions.addAll([
        Offset(cx - sp, cy - sp), Offset(cx + sp, cy - sp), Offset(cx, cy),
        Offset(cx - sp, cy + sp), Offset(cx + sp, cy + sp),
      ]);
    case 6:
      positions.addAll([
        Offset(cx - sp, cy - sp), Offset(cx + sp, cy - sp),
        Offset(cx - sp, cy), Offset(cx + sp, cy),
        Offset(cx - sp, cy + sp), Offset(cx + sp, cy + sp),
      ]);
  }
  for (final p in positions) {
    canvas.drawCircle(p, dotR, dotP);
  }
}

Offset _boardPos(Size size, double col, double row) {
  final s = math.min(size.width, size.height) * 0.88;
  final ox = (size.width - s) / 2;
  final oy = (size.height - s) / 2;
  final u = s / 15;
  return Offset(ox + col * u, oy + row * u);
}

class _ReleasePainter extends CustomPainter {
  final double t;
  const _ReleasePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawLudoBoard(canvas, size);

    final dieT = (t * 3).clamp(0.0, 1.0);
    final dieValue = dieT < 0.7 ? (1 + (dieT * 12).toInt() % 6) : 6;
    final diePos = _boardPos(size, 12.5, 2.5);
    _drawDie(canvas, diePos.dx, diePos.dy, 28, dieValue);

    final homePos = _boardPos(size, 3.0, 3.0);
    final startPos = _boardPos(size, 6.5, 1.5);
    final moveT = ((t - 0.35) * 2.5).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(moveT);
    final cx = homePos.dx + (startPos.dx - homePos.dx) * eased;
    final cy = homePos.dy + (startPos.dy - homePos.dy) * eased;
    _drawToken(canvas, cx, cy, 7, _kRed);

    _drawToken(canvas, homePos.dx + 12, homePos.dy + 12, 5, _kRed.withValues(alpha: 0.4));
    _drawToken(canvas, homePos.dx - 8, homePos.dy + 10, 5, _kRed.withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(_ReleasePainter old) => old.t != t;
}

class _MovePainter extends CustomPainter {
  final double t;
  const _MovePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawLudoBoard(canvas, size);

    final diePos = _boardPos(size, 12.5, 2.5);
    _drawDie(canvas, diePos.dx, diePos.dy, 28, 3);

    final path = [
      _boardPos(size, 6.5, 1.5),
      _boardPos(size, 6.5, 2.5),
      _boardPos(size, 6.5, 3.5),
      _boardPos(size, 6.5, 4.5),
    ];

    final moveT = (t * 2.0).clamp(0.0, 1.0);

    for (int i = 0; i < path.length; i++) {
      final p = path[i];
      final isTarget = i > 0 && i <= 3;
      if (isTarget) {
        final reached = moveT >= i / 3.0;
        if (reached) {
          canvas.drawCircle(
            p,
            6,
            Paint()..color = _kBlue.withValues(alpha: 0.12),
          );
        }
      }
    }

    final seg = (moveT * 3).clamp(0.0, 3.0);
    final segIdx = seg.floor().clamp(0, 2);
    final segFrac = Curves.easeInOut.transform((seg - segIdx).clamp(0.0, 1.0));
    final from = path[segIdx];
    final to = path[(segIdx + 1).clamp(0, 3)];
    final cx = from.dx + (to.dx - from.dx) * segFrac;
    final cy = from.dy + (to.dy - from.dy) * segFrac;
    _drawToken(canvas, cx, cy, 7, _kBlue);
  }

  @override
  bool shouldRepaint(_MovePainter old) => old.t != t;
}

class _CapturePainter extends CustomPainter {
  final double t;
  const _CapturePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawLudoBoard(canvas, size);

    final targetPos = _boardPos(size, 8.5, 1.5);
    final greenHomePos = _boardPos(size, 12.0, 3.0);

    final moveT = (t * 2.0).clamp(0.0, 1.0);
    final eased = Curves.easeInOut.transform(moveT);

    final captureT = moveT > 0.6 ? ((moveT - 0.6) * 2.5).clamp(0.0, 1.0) : 0.0;
    final greenAlpha = 1.0 - captureT;

    if (greenAlpha > 0) {
      final gx = targetPos.dx + (greenHomePos.dx - targetPos.dx) * captureT;
      final gy = targetPos.dy + (greenHomePos.dy - targetPos.dy) * captureT;
      _drawToken(canvas, gx, gy, 7, _kGreen, alpha: greenAlpha);
    }

    final startPos = _boardPos(size, 6.5, 1.5);
    final bounceY = -math.sin(eased * math.pi) * 12;
    final cx = startPos.dx + (targetPos.dx - startPos.dx) * eased;
    final cy = startPos.dy + bounceY;
    _drawToken(canvas, cx, cy, 7, _kRed);

    if (moveT > 0.75) {
      final alpha = ((moveT - 0.75) * 4).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'SENT HOME!',
          style: TextStyle(
            color: _kRed.withValues(alpha: alpha),
            fontWeight: FontWeight.w900,
            fontSize: 12,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.2 * alpha), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.88));
    }
  }

  @override
  bool shouldRepaint(_CapturePainter old) => old.t != t;
}

class _WinPainter extends CustomPainter {
  final double t;
  const _WinPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawLudoBoard(canvas, size);

    final center = _boardPos(size, 7.5, 7.5);
    final colors = [_kRed, _kGreen, _kYellow, _kBlue];
    final tokenR = 6.0;

    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * math.pi * 2 - math.pi / 2;
      final arriveT = ((t * 2.2) - i * 0.15).clamp(0.0, 1.0);
      final eased = Curves.easeOutBack.transform(arriveT);
      final startDist = 50.0;
      final endDist = 12.0;
      final dist = startDist - (startDist - endDist) * eased;
      final tx = center.dx + math.cos(angle) * dist;
      final ty = center.dy + math.sin(angle) * dist;
      _drawToken(canvas, tx, ty, tokenR, colors[i]);
    }

    if (t > 0.55) {
      final celebT = ((t - 0.55) * 2.5).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'YOU WIN!',
          style: TextStyle(
            color: Colors.amber.withValues(alpha: celebT),
            fontWeight: FontWeight.w900,
            fontSize: 16,
            shadows: [Shadow(color: Colors.black.withValues(alpha: 0.3 * celebT), blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.88));
    }
  }

  @override
  bool shouldRepaint(_WinPainter old) => old.t != t;
}
