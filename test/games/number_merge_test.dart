import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

Widget _build() => GameWrapper(
      gameId: 'number_merge',
      child: GameRegistry.buildGame('number_merge'),
    );

Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.text('Tap to Start'));
  await tester.pump(const Duration(milliseconds: 250));
}

/// The 4×4 board is rendered as 16 cells inside the play area. Find the cell
/// container by walking the grid columns/rows. We just need a Finder we can
/// drag from to simulate a swipe.
Finder _board() {
  // The board fills most of the screen; pumping center-anchored gestures from
  // it is reliable.
  return find.byType(GestureDetector).first;
}

void main() {
  group('Number Merge — gameplay', () {
    setUp(() async => initTestDependencies());

    testWidgets('ready overlay shows Tap to Start', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Tap to Start'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
    });

    testWidgets('start transitions to playing and shows score 0', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await _start(tester);
      expect(find.text('0'), findsWidgets);
      expect(find.text('Tap to Start'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('swipe gesture does not crash and keeps game playing',
        (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await _start(tester);

      // Swipe up from board center.
      final center = tester.getCenter(_board());
      await tester.dragFrom(center, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 200));

      // Game should still be playing — no game-over overlay yet.
      expect(find.text('Game Over'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('pause + resume works mid-game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await _start(tester);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Paused'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Paused'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('multiple swipes do not produce overflow or exceptions',
        (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await _start(tester);

      final center = tester.getCenter(_board());
      for (final dir in <Offset>[
        const Offset(0, -300),
        const Offset(300, 0),
        const Offset(0, 300),
        const Offset(-300, 0),
      ]) {
        await tester.dragFrom(center, dir);
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
