import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> patchesTutorialSteps() => [
      GameHowToPlayStep(
        text: 'Each clue shows a shape hint. The shape tells you if the patch is a square, wide, or tall rectangle.',
        demo: const _ShapeKeyDemo(),
      ),
      GameHowToPlayStep(
        text: 'If a clue has a number, the number is the area (cell count) of its patch.',
        demo: const _ClueDemo(),
      ),
      GameHowToPlayStep(
        text: 'Some harder clues hide the number — only the shape is shown. Use logic to deduce the size!',
        demo: const _HiddenClueDemo(),
      ),
      GameHowToPlayStep(
        text: 'Drag across cells to create a rectangular patch. Tap a patch to remove it.',
        demo: const _DragDemo(),
      ),
      GameHowToPlayStep(
        text: 'Cover every cell — no gaps, no overlaps. Each patch must contain exactly one clue.',
        demo: const _CoverageDemo(),
      ),
    ];

class _ShapeKeyDemo extends StatelessWidget {
  const _ShapeKeyDemo();
  @override
  Widget build(BuildContext context) {
    return FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        _shapeChip(28, 28, const Color(0xFF3B82F6), '4', 'Square'),
        const SizedBox(width: 12),
        _shapeChip(44, 24, const Color(0xFF22C55E), '6', 'Wide rect'),
      ]),
      const SizedBox(height: 8),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _shapeChip(22, 38, const Color(0xFF8B5CF6), '3', 'Tall rect'),
        const SizedBox(width: 12),
        _anyChip(28, 28, const Color(0xFF6B7280), '4', 'Any shape'),
      ]),
    ]));
  }

  Widget _shapeChip(double w, double h, Color color, String num, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CustomPaint(size: Size(w, h), painter: _DashedShapePainter(color: color)),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(num, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
      ]),
    ]);
  }

  Widget _anyChip(double w, double h, Color color, String num, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CustomPaint(size: Size(w, h), painter: _DashedShapePainter(color: color, hatched: true)),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(num, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
      ]),
    ]);
  }
}

class _ClueDemo extends StatelessWidget {
  const _ClueDemo();
  @override
  Widget build(BuildContext context) {
    return FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
      _examplePatch(56, 28, const Color(0xFF3B82F6), '2'),
      const SizedBox(width: 6),
      const Text('= 2 cells wide', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
      const SizedBox(width: 14),
      _examplePatch(24, 72, const Color(0xFFEF4444), '3'),
      const SizedBox(width: 6),
      const Text('= 3 cells tall', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
    ]));
  }

  Widget _examplePatch(double w, double h, Color color, String num) {
    return Container(width: w, height: h,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color, width: 2)),
      child: Center(child: Text(num, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color))));
  }
}

class _HiddenClueDemo extends StatelessWidget {
  const _HiddenClueDemo();
  @override
  Widget build(BuildContext context) {
    return FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
      Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 32, height: 32, child: CustomPaint(painter: _DashedShapePainter(color: const Color(0xFFEC4899)))),
        const SizedBox(height: 2),
        const Text('No number', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
      ]),
      const SizedBox(width: 10),
      const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF94A3B8)),
      const SizedBox(width: 10),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: const Color(0xFFEC4899).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(5),
            border: Border.all(color: const Color(0xFFEC4899), width: 2)),
          child: const Center(child: Text('4', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFEC4899))))),
        const SizedBox(height: 2),
        const Text('It was 4!', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF22C55E))),
      ]),
    ]));
  }
}

class _DragDemo extends StatefulWidget {
  const _DragDemo();
  @override
  State<_DragDemo> createState() => _DragDemoState();
}

class _DragDemoState extends State<_DragDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _ctrl, builder: (_, _) {
      final phase = _ctrl.value;
      final showPatch = phase > 0.4;
      const color = Color(0xFF3B82F6);
      return FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: 100, height: 60, child: Stack(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < 3; i++)
            Container(width: 28, height: 28, margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: showPatch && i < 2 ? color.withValues(alpha: 0.22) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: showPatch && i < 2 ? color : const Color(0xFFCBD5E1), width: showPatch && i < 2 ? 2 : 0.5),
              ),
              child: i == 0 && showPatch ? const Center(child: Text('2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF334155)))) : null),
        ]),
        if (!showPatch) Positioned(left: 4, top: 34, child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.touch_app_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 14, color: color.withValues(alpha: 0.6)),
        ])),
        if (showPatch) Positioned(left: 64, top: 8,
          child: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF22C55E))),
      ])));
    });
  }
}

class _CoverageDemo extends StatelessWidget {
  const _CoverageDemo();
  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF3B82F6), Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFF22C55E)];
    const sz = 24.0;
    return FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 0; i < 4; i++)
        Container(width: sz, height: sz, margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: colors[i].withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: colors[i], width: 1.5),
          )),
      const SizedBox(width: 8),
      const Text('100%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF22C55E))),
    ]));
  }
}

class _DashedShapePainter extends CustomPainter {
  final Color color;
  final bool hatched;
  _DashedShapePainter({required this.color, this.hatched = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(size.shortestSide * 0.15),
    );
    canvas.drawRRect(rr, Paint()..color = color.withValues(alpha: 0.16));
    if (hatched) {
      canvas.save();
      canvas.clipRRect(rr);
      final h = Paint()..color = color.withValues(alpha: 0.13)..strokeWidth = 1.0;
      for (double d = -size.height; d < size.width + size.height; d += 4.0) {
        canvas.drawLine(Offset(d, size.height - 1), Offset(d + size.height - 2, 1), h);
      }
      canvas.restore();
    }
    final dp = Paint()..color = color.withValues(alpha: 0.70)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final path = Path()..addRRect(rr);
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 3.5, m.length)), dp);
        d += 6.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedShapePainter old) =>
      old.color != color || old.hatched != hatched;
}
