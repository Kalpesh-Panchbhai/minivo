import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../helpers/game_drivers.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

// ---------------------------------------------------------------------------
// Full device matrix for Frame Rush: every key screen STATE (difficulty
// picker + live game) on ALL 14 supported sizes (iPhone SE 320px → iPad Pro
// 12.9"), iOS + Android, at BOTH normal and 1.3× system text.
//
// games_overflow_test sweeps overflow at 1.0× and a11y/games_text_scaling
// sweeps 4 narrow devices at 1.3× — this fills the gap (all 14 × 1.3×) AND
// asserts the real elements are present, not just "no overflow".
// ---------------------------------------------------------------------------

const _gameId = 'frame_rush';
const _scales = [1.0, 1.3];

Widget _build() => GameWrapper(
      gameId: _gameId,
      child: GameRegistry.buildGame(_gameId),
    );

void main() {
  for (final device in allTestDevices) {
    for (final scale in _scales) {
      group('Frame Rush · ${device.name} · ${scale}x', () {
        setUp(() async => initGameTest());

        testWidgets('picker shows all elements without overflow', (tester) async {
          await pumpScreen(tester, device, _build(),
              settle: false, textScale: scale);
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('Frame Rush'), findsWidgets); // title
          expect(find.text('Play Frame Rush'), findsOneWidget); // play button
          expect(find.text('MEDIUM'), findsOneWidget); // default difficulty
          expectNoOverflow(device, 'Frame Rush picker @${scale}x');
          cleanUp(tester);
        });

        testWidgets('live game shows HUD + slow-mo button without overflow',
            (tester) async {
          await pumpScreen(tester, device, _build(),
              settle: false, textScale: scale);
          await tapPlay(tester, gamePlayButton[_gameId]!);
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.textContaining('LEVEL'), findsWidgets); // level HUD pill
          expect(find.text('SLOW-MO'), findsOneWidget); // rewarded ad button
          expectNoOverflow(device, 'Frame Rush playing @${scale}x');

          // Advance to the "stuck" nudge and re-check the densest in-game state.
          await tester.pump(const Duration(seconds: 16));
          expect(find.text('Too fast? Slow it down!'), findsOneWidget);
          expectNoOverflow(device, 'Frame Rush stuck nudge @${scale}x');
          cleanUp(tester);
        });
      });
    }
  }
}
