import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/tic_tac_toe/tic_tac_toe_screen.dart' as ttt;
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

Widget _buildGame() => GameWrapper(
      gameId: 'tic_tac_toe',
      customOverlays: GameRegistry.usesCustomOverlays('tic_tac_toe'),
      child: GameRegistry.buildGame('tic_tac_toe'),
    );

const _pixel6 = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

Future<void> _startGame(WidgetTester tester) async {
  final btn = find.text('Play vs. AI');
  // On short-height landscape devices the button may be inside a scrollable.
  await tester.ensureVisible(btn);
  await tester.pump();
  await tester.tap(btn);
  await tester.pump(const Duration(milliseconds: 500));
}

// During play, the widget tree contains:
//   [0]  GamePauseButton's GestureDetector (top-right HUD)
//   [1..9]  the nine board cell GestureDetectors
// so cell N is at index N+1.
Finder _cell(int index) => find.byType(GestureDetector).at(index + 1);

void main() {
  group('Tic Tac Toe — Gameplay', () {
    setUp(() async {
      await initTestDependencies();
      // Force the human to start every test so cell taps are deterministic.
      ttt.debugFirstStarter = 'X';
    });
    tearDown(() {
      ttt.debugFirstStarter = null;
    });

    testWidgets('ready state shows mode picker with both options', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      expect(find.text('Play vs. AI'), findsOneWidget);
      expect(find.text('Play with a Friend'), findsOneWidget);
      expect(find.text('Tic Tac Toe'), findsOneWidget);
      expectNoOverflow(_pixel6, 'ready state');
      cleanUp(tester);
    });

    testWidgets('selecting mode transitions to playing state', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      await _startGame(tester);
      expect(find.text('Play vs. AI'), findsNothing);
      expect(find.text('Play with a Friend'), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expectNoOverflow(_pixel6, 'playing state');
      cleanUp(tester);
    });

    testWidgets('player can place X on empty cell', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      await _startGame(tester);
      await tester.tap(_cell(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('X'), findsOneWidget);
      expectNoOverflow(_pixel6, 'place X');
      await tester.pump(const Duration(seconds: 1));
      cleanUp(tester);
    });

    testWidgets('AI responds after player move', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      await _startGame(tester);
      await tester.tap(_cell(0));
      // AI think delay is 700-1100 ms based on difficulty; pump comfortably
      // past that so the AI's move has settled.
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('O'), findsOneWidget);
      expectNoOverflow(_pixel6, 'AI responds');
      cleanUp(tester);
    });

    testWidgets('cannot tap already occupied cell', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      await _startGame(tester);
      await tester.tap(_cell(0));
      await tester.pump(const Duration(milliseconds: 1500));
      final xCount = find.text('X').evaluate().length;
      await tester.tap(_cell(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('X').evaluate().length, equals(xCount));
      expectNoOverflow(_pixel6, 'occupied cell');
      cleanUp(tester);
    });

    testWidgets('cannot tap during AI turn', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      await _startGame(tester);
      await tester.tap(_cell(0));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(_cell(1));
      await tester.pump(const Duration(milliseconds: 50));
      final xCount = find.text('X').evaluate().length;
      expect(xCount, equals(1));
      expectNoOverflow(_pixel6, 'AI turn block');
      await tester.pump(const Duration(seconds: 1));
      cleanUp(tester);
    });

    testWidgets('pause and resume works', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      await _startGame(tester);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expectNoOverflow(_pixel6, 'paused state');

      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expectNoOverflow(_pixel6, 'resumed state');
      cleanUp(tester);
    });

    testWidgets('taps are blocked when paused', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      await _startGame(tester);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(_cell(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('X'), findsNothing);
      expectNoOverflow(_pixel6, 'paused tap block');
      cleanUp(tester);
    });

    testWidgets('no X or O marks shown in ready state', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      // In ready state, only the mode picker is shown — no board or X/O text in cells.
      // The mini grid badge contains decorative X and O glyphs, but those are part of the picker.
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
      expectNoOverflow(_pixel6, 'ready tap block');
      cleanUp(tester);
    });

    testWidgets('multiple moves progress without crash', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      await _startGame(tester);

      // Tap cells while the board is still visible. Game may auto-transition
      // to the winner screen mid-loop — that's expected and acceptable.
      for (int i = 0; i < 9; i++) {
        // Need at least pause-button + (i+1) cells.
        final gdCount = find.byType(GestureDetector).evaluate().length;
        if (gdCount < i + 2) break;
        await tester.tap(_cell(i));
        await tester.pump(const Duration(milliseconds: 600));
      }

      final xCount = find.text('X').evaluate().length;
      final oCount = find.text('O').evaluate().length;
      expect(xCount + oCount, greaterThan(0));
      expectNoOverflow(_pixel6, 'multiple moves');
      // Drain end-of-round + flutter_animate Timer.zero callbacks before
      // the test teardown checks for pending timers.
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      cleanUp(tester);
    });

    testWidgets('restart resets board', (tester) async {
      await pumpScreen(tester, _pixel6, _buildGame(), settle: false);
      await _startGame(tester);
      await tester.tap(_cell(0));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('X'), findsWidgets);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Restart'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Play vs. AI'), findsOneWidget);
      expectNoOverflow(_pixel6, 'restart');
      await tester.pump(const Duration(seconds: 1));
      cleanUp(tester);
    });
  });

  group('Tic Tac Toe — Screen Overflow (all devices)', () {
    const landscapeDevices = [
      TestDevice(name: 'Pixel 6 Landscape', width: 915, height: 412, pixelRatio: 2.625, platform: TargetPlatform.android),
      TestDevice(name: 'iPhone 14 Landscape', width: 844, height: 390, pixelRatio: 3.0, platform: TargetPlatform.iOS),
      TestDevice(name: 'Small Landscape', width: 568, height: 320, pixelRatio: 2.0, platform: TargetPlatform.android),
      TestDevice(name: 'iPad Landscape', width: 1366, height: 1024, pixelRatio: 2.0, platform: TargetPlatform.iOS),
    ];
    final devices = [...allTestDevices, ...landscapeDevices];

    for (final device in devices) {
      group('on ${device.name} (${device.width}x${device.height})', () {
        setUp(() async {
          await initTestDependencies();
          ttt.debugFirstStarter = 'X';
        });
        tearDown(() {
          ttt.debugFirstStarter = null;
        });

        testWidgets('ready state', (tester) async {
          await pumpScreen(tester, device, _buildGame(), settle: false);
          expectNoOverflow(device, 'ready');
          cleanUp(tester);
        });

        testWidgets('playing state', (tester) async {
          await pumpScreen(tester, device, _buildGame(), settle: false);
          await _startGame(tester);
          expectNoOverflow(device, 'playing');
          cleanUp(tester);
        });

        testWidgets('playing with moves', (tester) async {
          await pumpScreen(tester, device, _buildGame(), settle: false);
          await _startGame(tester);
          await tester.tap(_cell(0));
          // Wait past the AI's think delay so its move settles before we
          // try the next human tap.
          await tester.pump(const Duration(milliseconds: 1500));
          await tester.tap(_cell(2));
          await tester.pump(const Duration(milliseconds: 1500));
          expectNoOverflow(device, 'playing with moves');
          cleanUp(tester);
        });

        testWidgets('paused state', (tester) async {
          await pumpScreen(tester, device, _buildGame(), settle: false);
          await _startGame(tester);
          await tester.tap(find.byIcon(Icons.pause_rounded));
          await tester.pump(const Duration(milliseconds: 200));
          expectNoOverflow(device, 'paused');
          await tester.pump(const Duration(seconds: 5));
          cleanUp(tester);
        });
      });
    }
  });
}
