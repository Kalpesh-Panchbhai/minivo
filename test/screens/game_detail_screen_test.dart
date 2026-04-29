import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/games/shared/single_mode_game_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

/// Renders the screen with `disableAnimations: true` so the always-running
/// background animation doesn't trip up `pumpAndSettle`.
Future<void> _pumpDetail(WidgetTester tester, TestDevice device, String gameId) async {
  await pumpScreen(
    tester,
    device,
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: SingleModeGameScreen(gameId: gameId),
    ),
  );
}

void main() {
  for (final device in allTestDevices) {
    group('SingleModeGameScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await _pumpDetail(tester, device, 'flappy_tap');
        expectNoOverflow(device, 'SingleModeGameScreen');
        cleanUp(tester);
      });

      testWidgets('game name is visible', (tester) async {
        await _pumpDetail(tester, device, 'flappy_tap');
        expect(find.text('Flappy Tap'), findsWidgets);
        cleanUp(tester);
      });

      testWidgets('play now button visible', (tester) async {
        await _pumpDetail(tester, device, 'flappy_tap');
        expect(find.text('Play Now'), findsOneWidget);
        cleanUp(tester);
      });

      testWidgets('how to play icon visible', (tester) async {
        await _pumpDetail(tester, device, 'flappy_tap');
        // The HTP entry is now a `?` icon in the header (top-right).
        expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
        cleanUp(tester);
      });

      testWidgets('favorite button visible', (tester) async {
        await _pumpDetail(tester, device, 'flappy_tap');
        expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
        cleanUp(tester);
      });

      testWidgets('back button visible', (tester) async {
        await _pumpDetail(tester, device, 'flappy_tap');
        expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
        cleanUp(tester);
      });

      testWidgets('block_fit game renders without overflow', (tester) async {
        await _pumpDetail(tester, device, 'block_fit');
        expectNoOverflow(device, 'SingleModeGameScreen');
        cleanUp(tester);
      });
    });
  }
}
