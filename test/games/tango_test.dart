import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/shared/spinning_slider.dart';

import '../helpers/game_drivers.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _gameId = 'tango';

Widget _build() =>
    GameWrapper(gameId: _gameId, child: GameRegistry.buildGame(_gameId));

void main() {
  group('Tango registry', () {
    test('is registered with correct metadata', () {
      final info = GameRegistry.getById(_gameId);
      expect(info, isNotNull);
      expect(info!.name, 'Tango');
      expect(info.category, GameCategory.puzzle);
      expect(info.howToPlay, isNotEmpty);
    });
  });

  group('Tango picker', () {
    for (final device in allTestDevices) {
      group('${device.name} (${device.width}x${device.height})', () {
        setUp(() async => initGameTest());

        testWidgets('renders picker without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          expect(find.text('Tango'), findsWidgets);
          expectNoOverflow(device, 'Tango picker');
          cleanUp(tester);
        });

        testWidgets('play button starts game', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Tango');
          expect(find.byType(SpinningSlider), findsNothing,
              reason: 'still on picker');
          expect(find.text('LEVEL'), findsOneWidget);
          expectNoOverflow(device, 'Tango playing');
          cleanUp(tester);
        });
      });
    }
  });

  group('Tango gameplay per difficulty', () {
    for (final device in allTestDevices) {
      for (int stop = 0; stop < 3; stop++) {
        final diff = const ['Easy', 'Medium', 'Hard'][stop];
        group('$diff on ${device.name}', () {
          setUp(() async => initGameTest());

          testWidgets('renders without overflow', (tester) async {
            await pumpScreen(tester, device, _build(), settle: false);
            await selectAndPlay(tester, stop, 'Play Tango');
            expect(find.byType(SpinningSlider), findsNothing);
            expect(find.text('LEVEL'), findsOneWidget);
            await tester.pump(const Duration(milliseconds: 400));
            expectNoOverflow(device, 'Tango $diff');
            cleanUp(tester);
          });
        });
      }
    }
  });

  group('Tango dynamic states', () {
    const tightDevices = [
      TestDevice(name: 'Small Android', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.android),
      TestDevice(name: 'iPhone SE', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.iOS),
    ];

    for (final device in tightDevices) {
      group('${device.name}', () {
        setUp(() async => initGameTest());

        testWidgets('hint button renders without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Tango');
          expect(find.text('HINT'), findsOneWidget);
          await tester.tap(find.text('HINT'), warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 300));
          expectNoOverflow(device, 'Tango hint');
          cleanUp(tester);
        });

        testWidgets('idle nudge appears without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Tango');
          await tester.pump(const Duration(seconds: 9));
          expect(find.text('Stuck? Try a hint!'), findsOneWidget);
          expectNoOverflow(device, 'Tango idle nudge');
          cleanUp(tester);
        });

        testWidgets('pause overlay renders without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await selectAndPlay(tester, 0, 'Play Tango');
          expect(find.text('LEVEL'), findsOneWidget);
          expectNoOverflow(device, 'Tango pause');
          cleanUp(tester);
        });
      });
    }
  });
}
