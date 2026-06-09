import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

// Contract: every game in [GameRegistry] must build successfully on each
// supported portrait device, including foldables and 7"+ tablets. We
// don't measure the board's pixel size (that varies wildly by game) —
// we just verify the GameWrapper renders SOMETHING, the screen contains
// a Scaffold, and no widgets overflow.
//
// This catches the class of regression where a new game ships with a
// hardcoded board size that breaks on extreme aspect ratios (20:9 phones,
// foldables, iPads). Pair with `games_overflow_test.dart` for a deeper
// playing-state sweep.

const _devices = [
  TestDevice(
    name: 'Small Android (320×568)',
    width: 320,
    height: 568,
    pixelRatio: 2.0,
    platform: TargetPlatform.android,
  ),
  TestDevice(
    name: 'iPhone 14 (390×844)',
    width: 390,
    height: 844,
    pixelRatio: 3.0,
    platform: TargetPlatform.iOS,
  ),
  TestDevice(
    name: 'Pixel Fold open (841×701)',
    width: 841,
    height: 701,
    pixelRatio: 2.0,
    platform: TargetPlatform.android,
  ),
  TestDevice(
    name: 'iPad Pro 12.9 (1024×1366)',
    width: 1024,
    height: 1366,
    pixelRatio: 2.0,
    platform: TargetPlatform.iOS,
  ),
];

void main() {
  for (final game in GameRegistry.allGames) {
    for (final device in _devices) {
      group('${game.name} on ${device.name}', () {
        setUp(() async {
          await initTestDependencies();
        });

        testWidgets('builds without throwing', (tester) async {
          await pumpScreen(
            tester,
            device,
            GameWrapper(
              gameId: game.id,
              child: GameRegistry.buildGame(game.id),
            ),
            settle: false,
          );
          expect(find.byType(GameWrapper), findsOneWidget);
          expect(find.byType(Scaffold), findsWidgets);
          cleanUp(tester);
        });
      });
    }
  }
}
