import 'package:flutter/material.dart';

import '../../core/widgets/how_to_play_sheet.dart';

List<GameHowToPlayStep> tangoTutorialSteps() => [
      GameHowToPlayStep(
        text: 'Tap a cell to place a Sun ☀️. Tap again for Moon 🌙. Tap once more to clear.',
        demo: const _TapCycleDemo(),
      ),
      GameHowToPlayStep(
        text: 'Every row and column must have an equal number of Suns and Moons.',
        demo: const _BalanceDemo(),
      ),
      GameHowToPlayStep(
        text: 'No three identical symbols in a row — horizontally or vertically!',
        demo: const _NoTripleDemo(),
      ),
      GameHowToPlayStep(
        text: '"=" means the two cells must match. "×" means they must differ.',
        demo: const _ClueDemo(),
      ),
    ];

class _TapCycleDemo extends StatefulWidget {
  const _TapCycleDemo();
  @override
  State<_TapCycleDemo> createState() => _TapCycleDemoState();
}

class _TapCycleDemoState extends State<_TapCycleDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _ctrl, builder: (_, _) {
      final phase = (_ctrl.value * 3).floor() % 3;
      return Container(
        width: 56, height: 56,
        decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD4C5A0), width: 1.5)),
        child: Center(child: phase == 0
          ? const SizedBox.shrink()
          : phase == 1
            ? const Icon(Icons.wb_sunny_rounded, size: 32, color: Color(0xFFFFA726))
            : const Icon(Icons.nightlight_round, size: 30, color: Color(0xFF7C4DFF))),
      );
    });
  }
}

class _BalanceDemo extends StatelessWidget {
  const _BalanceDemo();
  @override
  Widget build(BuildContext context) {
    const sz = 28.0;
    final icons = [
      const Icon(Icons.wb_sunny_rounded, size: 20, color: Color(0xFFFFA726)),
      const Icon(Icons.nightlight_round, size: 18, color: Color(0xFF7C4DFF)),
      const Icon(Icons.wb_sunny_rounded, size: 20, color: Color(0xFFFFA726)),
      const Icon(Icons.nightlight_round, size: 18, color: Color(0xFF7C4DFF)),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < 4; i++)
          Container(width: sz, height: sz, margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFD4C5A0))),
            child: Center(child: icons[i])),
        const SizedBox(width: 8),
        const Text('2☀️ = 2🌙', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B7355))),
      ]),
    );
  }
}

class _NoTripleDemo extends StatelessWidget {
  const _NoTripleDemo();
  @override
  Widget build(BuildContext context) {
    const sz = 28.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 0; i < 3; i++)
        Container(width: sz, height: sz, margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFCDD2), borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.red, width: 1.5)),
          child: const Center(child: Icon(Icons.wb_sunny_rounded, size: 20, color: Color(0xFFFFA726)))),
      const SizedBox(width: 8),
      const Icon(Icons.close_rounded, size: 20, color: Colors.red),
    ]);
  }
}

class _ClueDemo extends StatelessWidget {
  const _ClueDemo();
  @override
  Widget build(BuildContext context) {
    const sz = 34.0;
    const clueSz = 18.0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: sz, height: sz,
          decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4C5A0))),
          child: const Center(child: Icon(Icons.wb_sunny_rounded, size: 22, color: Color(0xFFFFA726)))),
        Container(width: clueSz, height: clueSz,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF8B7355), width: 1)),
          child: const Center(child: Text('=', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF8B7355), height: 1.1)))),
        Container(width: sz, height: sz,
          decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4C5A0))),
          child: const Center(child: Icon(Icons.wb_sunny_rounded, size: 22, color: Color(0xFFFFA726)))),
        const SizedBox(width: 14),
        Container(width: sz, height: sz,
          decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4C5A0))),
          child: const Center(child: Icon(Icons.wb_sunny_rounded, size: 22, color: Color(0xFFFFA726)))),
        Container(width: clueSz, height: clueSz,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF8B7355), width: 1)),
          child: const Center(child: Text('×', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF8B7355), height: 1.1)))),
        Container(width: sz, height: sz,
          decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4C5A0))),
          child: const Center(child: Icon(Icons.nightlight_round, size: 20, color: Color(0xFF7C4DFF)))),
      ]),
    );
  }
}
