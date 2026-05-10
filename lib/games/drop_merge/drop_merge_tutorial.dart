import 'package:flutter/material.dart';
import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> dropMergeSteps() {
  return const [
    GameHowToPlayStep(
      text: '👇  Tap a column to drop the current tile. '
          'It falls to the lowest empty row in that column.',
      demo: _Step1Demo(),
    ),
    GameHowToPlayStep(
      text: '🔢  Matching tiles merge! Two 2s become a 4, '
          'two 4s become an 8 — and so on.',
      demo: _Step2Demo(),
    ),
    GameHowToPlayStep(
      text: '⛓️  Chain reactions score bonus points! '
          'Each extra merge adds a ×0.5 multiplier.',
      demo: _Step3Demo(),
    ),
    GameHowToPlayStep(
      text: '⚠️  Board fills up fast — plan where to drop each tile. '
          'Game over when no moves remain!',
      demo: _Step4Demo(),
    ),
  ];
}

// ── Demo widgets ──────────────────────────────────────────────────────────────

class _Step1Demo extends StatelessWidget {
  const _Step1Demo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _DropPainter()),
    );
  }
}

class _DropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileColor = Color(0xFFFFE066);
    const colW = 28.0;
    const tileH = 28.0;
    final startX = size.width / 2 - colW / 2;

    // Column background
    final colPaint = Paint()..color = const Color(0xFFF0F0F0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, 20, colW, size.height - 24),
        const Radius.circular(6),
      ),
      colPaint,
    );

    // Tile at top (current tile)
    final tilePaint = Paint()..color = tileColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, 0, colW, tileH),
        const Radius.circular(5),
      ),
      tilePaint,
    );
    _drawNumber(canvas, '2', Offset(startX + colW / 2, tileH / 2), 13, Colors.black);

    // Arrow
    final arrowPaint = Paint()
      ..color = const Color(0xFFFF922B)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final midX = startX + colW / 2;
    canvas.drawLine(Offset(midX, tileH + 3), Offset(midX, tileH + 16), arrowPaint);
    canvas.drawLine(Offset(midX - 5, tileH + 10), Offset(midX, tileH + 16), arrowPaint);
    canvas.drawLine(Offset(midX + 5, tileH + 10), Offset(midX, tileH + 16), arrowPaint);

    // Tile landed at bottom
    final bottomY = size.height - 4 - tileH;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, bottomY, colW, tileH),
        const Radius.circular(5),
      ),
      Paint()..color = tileColor.withValues(alpha: 0.55),
    );
    _drawNumber(canvas, '2', Offset(startX + colW / 2, bottomY + tileH / 2), 13,
        Colors.black.withValues(alpha: 0.55));

    // Ghost dash line
    final dashPaint = Paint()
      ..color = const Color(0xFFFF922B).withValues(alpha: 0.40)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    double y = tileH + 20;
    while (y < bottomY - 4) {
      canvas.drawLine(Offset(midX, y), Offset(midX, y + 5), dashPaint);
      y += 9;
    }
  }

  void _drawNumber(Canvas canvas, String text, Offset center, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DropPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────

class _Step2Demo extends StatelessWidget {
  const _Step2Demo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _MergePainter()),
    );
  }
}

class _MergePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileH = 28.0;
    const tileW = 30.0;
    const gapX  = 6.0;

    final y = size.height / 2 - tileH / 2;

    // Left tile (2)
    _drawTile(canvas, Rect.fromLTWH(6, y, tileW, tileH), const Color(0xFFFFE066), '2', Colors.black);

    // Plus sign
    _drawText(canvas, '+', Offset(6 + tileW + gapX, y + tileH / 2), 18, const Color(0xFF888888));

    // Right tile (2)
    final tile2x = 6 + tileW + gapX * 2 + 12;
    _drawTile(canvas, Rect.fromLTWH(tile2x, y, tileW, tileH), const Color(0xFFFFE066), '2', Colors.black);

    // Equals
    _drawText(canvas, '=', Offset(tile2x + tileW + gapX, y + tileH / 2), 18, const Color(0xFF888888));

    // Result tile (4)
    const resultColor = Color(0xFFFFD700);
    final res4x = tile2x + tileW + gapX * 2 + 12;
    _drawTile(canvas, Rect.fromLTWH(res4x, y, tileW, tileH), resultColor, '4', Colors.black);

    // Glow ring around result
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(res4x - 3, y - 3, tileW + 6, tileH + 6),
        const Radius.circular(9),
      ),
      Paint()
        ..color = resultColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Label below
    _drawText(canvas, 'merge!', Offset(size.width / 2, y + tileH + 14), 11, const Color(0xFFFF922B));
  }

  void _drawTile(Canvas canvas, Rect rect, Color color, String text, Color textColor) {
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawText(Canvas canvas, String text, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_MergePainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────

class _Step3Demo extends StatelessWidget {
  const _Step3Demo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _ChainPainter()),
    );
  }
}

class _ChainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileW = 26.0;
    const tileH = 22.0;
    const gapX  = 4.0;

    // Row of merging tiles showing chain: 2+2=4, 4+4=8
    final tiles = <(String, Color, Color)>[
      ('2', Color(0xFFFFE066), Colors.black),
      ('2', Color(0xFFFFE066), Colors.black),
      ('4', Color(0xFFFFD700), Colors.black),
      ('4', Color(0xFFFFD700), Colors.black),
      ('8', Color(0xFFFFA94D), Colors.white),
    ];

    final totalW = tiles.length * tileW + (tiles.length - 1) * gapX;
    var x = (size.width - totalW) / 2;
    const y = 8.0;

    for (int i = 0; i < tiles.length; i++) {
      final (label, bg, fg) = tiles[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, tileW, tileH), const Radius.circular(5)),
        Paint()..color = bg,
      );
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + tileW / 2 - tp.width / 2, y + tileH / 2 - tp.height / 2));
      x += tileW + gapX;
    }

    // Chain arrows
    final arrowPaint = Paint()
      ..color = const Color(0xFFFF922B)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final arrow1x = (size.width - totalW) / 2 + tileW + gapX / 2;
    final arrow2x = arrow1x + (tileW + gapX) * 2;
    const arrowY = y + tileH + 8;

    for (final ax in [arrow1x, arrow2x]) {
      canvas.drawLine(Offset(ax - 10, arrowY), Offset(ax + 10, arrowY), arrowPaint);
      canvas.drawLine(Offset(ax + 4, arrowY - 5), Offset(ax + 10, arrowY), arrowPaint);
      canvas.drawLine(Offset(ax + 4, arrowY + 5), Offset(ax + 10, arrowY), arrowPaint);
    }

    // Multiplier badge
    final badgePaint = Paint()..color = const Color(0xFFFF922B);
    const badgeY = y + tileH + 26;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width / 2 - 28, badgeY, 56, 20),
        const Radius.circular(10),
      ),
      badgePaint,
    );
    final tp2 = TextPainter(
      text: const TextSpan(
          text: '×1.5 chain!',
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, Offset(size.width / 2 - tp2.width / 2, badgeY + 10 - tp2.height / 2));

    // Score
    final tp3 = TextPainter(
      text: const TextSpan(
          text: 'Score ×1.5!',
          style: TextStyle(color: Color(0xFF888888), fontSize: 10, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp3.paint(canvas, Offset(size.width / 2 - tp3.width / 2, badgeY + 26));
  }

  @override
  bool shouldRepaint(_ChainPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────

class _Step4Demo extends StatelessWidget {
  const _Step4Demo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _FullBoardPainter()),
    );
  }
}

class _FullBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cols = 4;
    const rows = 4;
    const pad  = 4.0;
    final cellW = (size.width - pad * 2 - 3) / cols;
    final cellH = (size.height - pad * 2 - 3) / rows;

    final grid = [
      [2, 4, 2, 8],
      [8, 2, 16, 4],
      [4, 8, 4, 2],
      [2, 16, 8, 4],
    ];

    final colors = {
      2:  const Color(0xFFFFE066),
      4:  const Color(0xFFFFD700),
      8:  const Color(0xFFFFA94D),
      16: const Color(0xFFFF6B6B),
    };

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final val = grid[r][c];
        final color = colors[val] ?? const Color(0xFFFF922B);
        final x = pad + c * (cellW + 1);
        final y = pad + r * (cellH + 1);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, cellW, cellH), const Radius.circular(4)),
          Paint()..color = color,
        );
        final tp = TextPainter(
          text: TextSpan(
              text: '$val',
              style: TextStyle(
                  color: val >= 8 ? Colors.white : Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + cellW / 2 - tp.width / 2, y + cellH / 2 - tp.height / 2));
      }
    }

    // "FULL" overlay
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2),
          const Radius.circular(6)),
      overlayPaint,
    );
    final tp = TextPainter(
      text: const TextSpan(
          text: 'GAME\nOVER',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width);
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_FullBoardPainter old) => false;
}
