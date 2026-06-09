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
    final wrapper = GameWrapper.of(context);
    final isReady = wrapper.state == GameState.ready;
    return GestureDetector(
      onTap: isReady ? wrapper.startGame : null,
      child: Container(
        color: Colors.blue,
        child: Center(
          child: isReady
              ? const Text('Start')
              : const Text('Playing'),
        ),
      ),
    );
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
        expect(find.byType(GameWrapper), findsOneWidget);
        expectNoOverflow(device, 'GameWrapper');
        cleanUp(tester);
      });

      testWidgets('initial state is ready', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Paused'), findsNothing);
        expectNoOverflow(device, 'GameWrapper');
        cleanUp(tester);
      });

      testWidgets('startGame transitions to playing', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Playing'), findsOneWidget);
        expectNoOverflow(device, 'GameWrapper');
        cleanUp(tester);
      });

      testWidgets('pause overlay shows when paused', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
        state.pauseGame();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Paused'), findsOneWidget);
        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('Restart'), findsOneWidget);
        expect(find.text('Quit'), findsOneWidget);
        expectNoOverflow(device, 'GameWrapper');
        await tester.pump(const Duration(seconds: 5));
        cleanUp(tester);
      });

      testWidgets('pause overlay icons are present', (tester) async {
        await pumpScreen(
          tester,
          device,
          const GameWrapper(gameId: 'flappy_tap', child: _DummyGame()),
          settle: false,
        );
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
        state.pauseGame();
        await tester.pump(const Duration(milliseconds: 500));
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
        await tester.tap(find.text('Start'));
        await tester.pump(const Duration(milliseconds: 100));
        final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
        state.pauseGame();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Resume'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Paused'), findsNothing);
        expect(find.text('Playing'), findsOneWidget);
        expectNoOverflow(device, 'GameWrapper');
        await tester.pump(const Duration(seconds: 5));
        cleanUp(tester);
      });
    });
  }
}
