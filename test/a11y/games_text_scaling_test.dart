import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_wrapper.dart';
import '../../lib/games/game_registry.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/game_drivers.dart';

// ---------------------------------------------------------------------------
// LARGE-TEXT (1.3x) overflow for every game.
//
// a11y/text_scaling_test covers the app-shell screens at 1.3x but NOT the
// games. Players who bump their system font size hit the games too — the
// picker (difficulty label, hint, best pill) and the in-game HUD (score/level
// pills, difficulty tags) are full of fixed-size Text that can overflow when
// scaled. This sweeps both the READY picker and the PLAYING board of all 27
// games at 1.3x on the narrow/short devices where large text is tightest.
// ---------------------------------------------------------------------------

const _scale = 1.3;

const _devices = [
  TestDevice(
      name: 'Small Android (320x568)',
      width: 320,
      height: 568,
      pixelRatio: 2.0,
      platform: TargetPlatform.android),
  TestDevice(
      name: 'Nexus 5 (360x640)',
      width: 360,
      height: 640,
      pixelRatio: 3.0,
      platform: TargetPlatform.android),
  TestDevice(
      name: 'iPhone SE 3rd (375x667)',
      width: 375,
      height: 667,
      pixelRatio: 2.0,
      platform: TargetPlatform.iOS),
  TestDevice(
      name: 'iPhone 13 (390x844)',
      width: 390,
      height: 844,
      pixelRatio: 3.0,
      platform: TargetPlatform.iOS),
];

void main() {
  for (final gameId in allGameIds) {
    final game = GameRegistry.allGames.firstWhere((g) => g.id == gameId);
    final playText = gamePlayButton[gameId]!;
    for (final device in _devices) {
      group('${game.name} @${_scale}x on ${device.name}', () {
        setUp(() async {
          await initGameTest();
        });

        testWidgets('picker renders without overflow', (tester) async {
          await pumpScreen(
            tester,
            device,
            GameWrapper(gameId: gameId, child: GameRegistry.buildGame(gameId)),
            settle: false,
            textScale: _scale,
          );
          await tester.pump(const Duration(milliseconds: 300));
          expectNoOverflow(device, '${game.name} picker @${_scale}x');
          cleanUp(tester);
        });

        testWidgets('playing renders without overflow', (tester) async {
          await pumpScreen(
            tester,
            device,
            GameWrapper(gameId: gameId, child: GameRegistry.buildGame(gameId)),
            settle: false,
            textScale: _scale,
          );
          await tapPlay(tester, playText);
          await tester.pump(const Duration(milliseconds: 500));
          expectNoOverflow(device, '${game.name} playing @${_scale}x');
          cleanUp(tester);
        });
      });
    }
  }
}
