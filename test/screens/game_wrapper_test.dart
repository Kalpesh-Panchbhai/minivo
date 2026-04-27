import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/games/game_wrapper.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

class _DummyGame extends StatelessWidget {
  const _DummyGame();

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.blue);
  }
}

void main() {
  for (final device in allTestDevices) {
    group('GameWrapper on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders ready state without overflow', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        expectNoOverflow(device, 'GameWrapper');
        cleanUp(tester);
      });

      testWidgets('tap to start text visible in ready state', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        expect(find.text('Tap to Start'), findsOneWidget);
        expectNoOverflow(device, 'GameWrapper');
        cleanUp(tester);
      });

      testWidgets('touch icon visible in ready state', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
        expectNoOverflow(device, 'GameWrapper');
        cleanUp(tester);
      });

      testWidgets('tapping starts game and shows HUD', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        await tester.tap(find.text('Tap to Start'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expectNoOverflow(device, 'GameWrapper');
        cleanUp(tester);
      });

      testWidgets('pause button works', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        await tester.tap(find.text('Tap to Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Paused'), findsOneWidget);
        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('Restart'), findsOneWidget);
        expect(find.text('Quit'), findsOneWidget);
        expectNoOverflow(device, 'GameWrapper');
        await tester.pump(const Duration(seconds: 5));
        cleanUp(tester);
      });

      testWidgets('pause overlay buttons meet layout', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        await tester.tap(find.text('Tap to Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(find.byIcon(Icons.home_rounded), findsOneWidget);
        expectNoOverflow(device, 'GameWrapper');
        await tester.pump(const Duration(seconds: 5));
        cleanUp(tester);
      });

      testWidgets('resume from pause works', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        await tester.tap(find.text('Tap to Start'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Resume'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(find.text('Paused'), findsNothing);
        expectNoOverflow(device, 'GameWrapper');
        await tester.pump(const Duration(seconds: 5));
        cleanUp(tester);
      });
    });
  }
}
