import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';
import '../../lib/core/services/best_stats_registry.dart';
import '../../lib/core/services/score_service.dart';
import '../../lib/core/widgets/how_to_play_sheet.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/ludo/ludo_logo.dart';
import '../../lib/games/ludo/ludo_screen.dart';
import '../../lib/games/ludo/ludo_stats.dart';
import '../../lib/games/ludo/ludo_tutorial.dart';

import '../helpers/game_drivers.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _gameId = 'ludo';

Widget _build() =>
    GameWrapper(gameId: _gameId, child: GameRegistry.buildGame(_gameId));

LudoScreenState _state(WidgetTester tester) =>
    tester.state<LudoScreenState>(find.byType(LudoScreen));

GameWrapperState _wrapper(WidgetTester tester) =>
    tester.state<GameWrapperState>(find.byType(GameWrapper));

// Player path geometry constants (mirror ludo_screen.dart private consts).
const _trackSquares = 52;
const _startSquares = [0, 13, 26, 39];

/// pathIndex of [player] whose board square equals [square] (track squares
/// only, i.e. before the home lane). Inverse of `(start + i) % 52`.
int _pathIndexForSquare(int player, int square) {
  final start = _startSquares[player];
  return ((square - start) % _trackSquares + _trackSquares) % _trackSquares;
}

/// Pump in small steps so chained `Future.delayed` move/capture animations all
/// fire (a single big pump can skip timers scheduled mid-window).
Future<void> _flush(WidgetTester tester, [int ms = 2600]) async {
  for (int t = 0; t < ms; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Enter the live AI board through the REAL picker flow (clean reset).
Future<LudoScreenState> _enterAi(WidgetTester tester, {int stop = 1}) async {
  await selectDifficultyStop(tester, stop);
  await tapPlay(tester, 'Play vs. AI');
  return _state(tester);
}

/// Tap a picker button by its label text, scrolling it into view first.
Future<void> _tapText(WidgetTester tester, String label) async {
  final f = find.text(label);
  expect(f, findsWidgets, reason: '"$label" not found');
  try {
    await tester.ensureVisible(f.first);
    await tester.pump(const Duration(milliseconds: 100));
  } catch (_) {}
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Settle one-shot timers (incl. the 2.2s end-of-game banner timer scheduled
/// by [LudoScreenState._endGame]) before unmounting, so no Timer is left
/// pending; then unmount to dispose repeating tickers + AI timers, and stop
/// the overflow detector / reset the surface.
Future<void> _teardown(WidgetTester tester) async {
  await _flush(tester, 2400);
  await tester.pumpWidget(const SizedBox());
  cleanUp(tester);
}

void main() {
  // ─────────────────────────────── REGISTRY ───────────────────────────────
  group('Ludo registry', () {
    test('is registered with correct metadata', () {
      final info = GameRegistry.getById(_gameId);
      expect(info, isNotNull);
      expect(info!.name, 'Ludo');
      expect(info.category, GameCategory.board);
      expect(info.howToPlay, isNotEmpty);
      expect(info.customLogo, isNotNull);
    });

    test('builds a LudoScreen widget', () {
      expect(GameRegistry.hasGame(_gameId), isTrue);
      expect(GameRegistry.buildGame(_gameId), isA<LudoScreen>());
    });
  });

  // ──────────────────────────── BOARD GEOMETRY ────────────────────────────
  // Pure data — no widget needed.
  group('Ludo path geometry', () {
    test('each player path is 51 track + 6 home-lane squares', () {
      for (int p = 0; p < 4; p++) {
        final path = LudoScreenState.ludoPathForTest(p);
        expect(path.length, 57, reason: 'player $p path length');
      }
      expect(LudoScreenState.pathLengthForTest, 51);
      expect(LudoScreenState.homeLaneLengthForTest, 6);
      expect(LudoScreenState.maxPathIndexForTest, 56);
    });

    test('each player starts on its own coloured start square', () {
      expect(LudoScreenState.startSquaresForTest, [0, 13, 26, 39]);
      for (int p = 0; p < 4; p++) {
        expect(LudoScreenState.ludoPathForTest(p).first, _startSquares[p]);
      }
    });

    test('the main track wraps clockwise modulo 52', () {
      // Player 1 starts at 13; 39 steps later it crosses square 0.
      expect(LudoScreenState.ludoPathForTest(1)[39], 0);
      // Player 3 starts at 39; 13 steps later it crosses square 0.
      expect(LudoScreenState.ludoPathForTest(3)[13], 0);
    });

    test('the home lane uses per-player virtual square ids (100/110/120/130)',
        () {
      for (int p = 0; p < 4; p++) {
        final path = LudoScreenState.ludoPathForTest(p);
        expect(path[51], 100 + p * 10, reason: 'player $p first home-lane id');
        expect(path[56], 100 + p * 10 + 5, reason: 'player $p last home id');
      }
    });

    test('safe squares are the eight start + star squares', () {
      expect(LudoScreenState.safeSquaresForTest,
          {0, 8, 13, 21, 26, 34, 39, 47});
    });
  });

  // ───────────────────────────────── STATS ────────────────────────────────
  group('Ludo stats', () {
    setUp(() async {
      await initGameTest();
      registerLudoStats();
    });

    tearDown(() => BestStatsRegistry.unregister(_gameId));

    test('shows nothing until a streak is recorded', () {
      expect(bestLudoStreak(kLudoSubKeyEasy), 0);
      expect(BestStatsRegistry.statsFor(_gameId), isEmpty);
    });

    test('records per-difficulty best streaks independently', () async {
      await ScoreService().saveScore(_gameId, 4, subKey: kLudoSubKeyMedium);
      expect(bestLudoStreak(kLudoSubKeyMedium), 4);
      expect(bestLudoStreak(kLudoSubKeyEasy), 0);

      final rows = BestStatsRegistry.statsFor(_gameId);
      expect(rows.length, 3, reason: 'easy / medium / hard rows');
      // Medium row carries the streak; the others show the placeholder.
      expect(rows.any((r) => r.value == '4'), isTrue);
      expect(rows.where((r) => r.value == '—').length, 2);
    });

    test('saveScore only raises the best, never lowers it', () async {
      await ScoreService().saveScore(_gameId, 7, subKey: kLudoSubKeyHard);
      await ScoreService().saveScore(_gameId, 3, subKey: kLudoSubKeyHard);
      expect(bestLudoStreak(kLudoSubKeyHard), 7);
    });
  });

  // ───────────────────────────────── LOGO ─────────────────────────────────
  group('Ludo logo', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: buildLudoLogo(96))),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ─────────────────────────────── TUTORIAL ───────────────────────────────
  group('Ludo tutorial', () {
    test('exposes four how-to-play steps with text and a demo each', () {
      final steps = ludoSteps();
      expect(steps.length, 4);
      for (final step in steps) {
        expect(step, isA<GameHowToPlayStep>());
        expect(step.text, isNotEmpty);
        expect(step.demo, isNotNull);
      }
    });
  });

  // ───────────────────────────── PICKER RENDER ────────────────────────────
  group('Ludo picker — every device', () {
    for (final device in allTestDevices) {
      group('${device.name} (${device.width}x${device.height})', () {
        setUp(() async => initGameTest());

        testWidgets('renders the picker without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          expect(find.text('Ludo'), findsWidgets);
          expect(find.text('Play vs. AI'), findsOneWidget);
          expect(find.text('2P'), findsOneWidget);
          expect(find.text('3P'), findsOneWidget);
          expect(find.text('4P'), findsOneWidget);
          expect(find.text('MEDIUM'), findsWidgets,
              reason: 'medium is the default difficulty');
          expectNoOverflow(device, 'Ludo picker');
          await _teardown(tester);
        });

        testWidgets('renders the picker without overflow at 1.3x text scale',
            (tester) async {
          await pumpScreen(tester, device, _build(),
              settle: false, textScale: 1.3);
          expect(find.text('Ludo'), findsWidgets);
          expectNoOverflow(device, 'Ludo picker @1.3x');
          await _teardown(tester);
        });
      });
    }
  });

  // ───────────────────────────── BOARD RENDER ─────────────────────────────
  group('Ludo AI board — every device', () {
    for (final device in allTestDevices) {
      testWidgets('AI board renders without overflow on ${device.name}',
          (tester) async {
        await initGameTest();
        await pumpScreen(tester, device, _build(), settle: false);
        await _enterAi(tester, stop: 1);
        expect(find.text('Play vs. AI'), findsNothing,
            reason: 'left the picker');
        expect(find.text('YOU'), findsWidgets,
            reason: 'AI scoreboard shows YOU vs AI');
        expect(find.text('AI'), findsWidgets);
        await tester.pump(const Duration(milliseconds: 400));
        expectNoOverflow(device, 'Ludo AI board');
        await _teardown(tester);
      });
    }
  });

  group('Ludo AI board — each difficulty (tight devices)', () {
    const tight = [
      TestDevice(name: 'Small Android', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.android),
      TestDevice(name: 'iPhone SE', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.iOS),
    ];
    for (final device in tight) {
      for (int stop = 0; stop < 3; stop++) {
        final diff = const ['EASY', 'MEDIUM', 'HARD'][stop];
        testWidgets('$diff carries to the scoreboard with no overflow on '
            '${device.name}', (tester) async {
          await initGameTest();
          await pumpScreen(tester, device, _build(), settle: false);
          await _enterAi(tester, stop: stop);
          expect(find.text(diff), findsWidgets,
              reason: 'scoreboard pill reflects the chosen difficulty');
          await tester.pump(const Duration(milliseconds: 300));
          expectNoOverflow(device, 'Ludo AI $diff');
          await _teardown(tester);
        });
      }
    }
  });

  group('Ludo pass-and-play board — 2P / 3P / 4P', () {
    const devices = [
      TestDevice(name: 'Small Android', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.android),
      TestDevice(name: 'iPhone SE', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.iOS),
      TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android),
      TestDevice(name: 'iPad Pro', width: 1024, height: 1366, pixelRatio: 2.0, platform: TargetPlatform.iOS),
    ];
    for (final device in devices) {
      for (final players in const ['2P', '3P', '4P']) {
        testWidgets('$players board renders without overflow on ${device.name}',
            (tester) async {
          await initGameTest();
          await pumpScreen(tester, device, _build(), settle: false);
          await _tapText(tester, players);
          expect(find.text('Play vs. AI'), findsNothing);
          expect(find.text('PASS & PLAY'), findsWidgets,
              reason: 'multiplayer scoreboard label');
          await tester.pump(const Duration(milliseconds: 400));
          expectNoOverflow(device, 'Ludo $players board');
          await _teardown(tester);
        });
      }
    }
  });

  // ─────────────────── FRESH-BOARD GUARD (anti-debug canary) ───────────────
  group('Ludo fresh board', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    testWidgets('a freshly started AI game has 8 tokens home, no winner, no '
        'finishers', (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      final s = await _enterAi(tester, stop: 1);
      // AI mode = 2 players (Red vs Yellow) × 4 tokens = 8.
      expect(s.tokenCountForTest, 8);
      for (int i = 0; i < s.tokenCountForTest; i++) {
        expect(s.tokenIsHomeForTest(i), isTrue,
            reason: 'token $i must start home — guards against debug seeding '
                'in _resetBoard');
        expect(s.tokenFinishedForTest(i), isFalse);
      }
      expect(s.finishOrderForTest, isEmpty);
      expect(s.winnerForTest, isNull);
      expect(s.gameOverForTest, isFalse);
      expect(s.currentPlayerForTest, 0, reason: 'human (Red) moves first');
      await _teardown(tester);
    });
  });

  // ──────────────────────────── RULES: MOVEMENT ───────────────────────────
  group('Ludo rules — movable set', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<LudoScreenState> ready(WidgetTester tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      return _enterAi(tester, stop: 1);
    }

    testWidgets('a token can only leave home on a 6', (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: false); // Red moves, all home
      expect(s.movableForTest(5), isEmpty, reason: 'no 6 → nothing to move');
      expect(s.movableForTest(1), isEmpty);
      expect(s.movableForTest(6).length, 4,
          reason: 'all four home tokens become releasable on a 6');
      await _teardown(tester);
    });

    testWidgets('a token may not overshoot the final home square',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: false);
      s.setTokenForTest(0, pathIndex: 54); // 2 short of the finish (56)
      expect(s.movableForTest(2).contains(0), isTrue, reason: 'exact finish');
      expect(s.movableForTest(3).contains(0), isFalse, reason: 'would overshoot');
      await _teardown(tester);
    });
  });

  group('Ludo rules — moving a token', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<LudoScreenState> ready(WidgetTester tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterAi(tester, stop: 1);
      return _state(tester);
    }

    testWidgets('advancing a non-6 with no capture passes the turn',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: false); // pass-and-play [0, 2], Red to move
      s.setTokenForTest(0, pathIndex: 5);
      s.moveTokenForTest(0, 3);
      await _flush(tester);
      expect(s.tokenPathIndexForTest(0), 8);
      expect(s.tokenBoardSquareForTest(0), 8);
      expect(s.currentPlayerForTest, 2, reason: 'turn passed to Yellow');
      await _teardown(tester);
    });

    testWidgets('rolling a 6 grants an extra turn (player keeps the dice)',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: false);
      s.setTokenForTest(0, pathIndex: 5);
      s.moveTokenForTest(0, 6);
      await _flush(tester);
      expect(s.tokenPathIndexForTest(0), 11);
      expect(s.currentPlayerForTest, 0, reason: 'six keeps the turn');
      await _teardown(tester);
    });

    testWidgets('landing exactly on the last square finishes the token',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: false);
      s.setTokenForTest(0, pathIndex: 54);
      s.moveTokenForTest(0, 2);
      await _flush(tester);
      expect(s.tokenFinishedForTest(0), isTrue);
      expect(s.tokenPathIndexForTest(0), 56);
      await _teardown(tester);
    });
  });

  // ──────────────────────────── RULES: CAPTURE ────────────────────────────
  group('Ludo rules — capture', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<LudoScreenState> ready(WidgetTester tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterAi(tester, stop: 1);
      return _state(tester);
    }

    testWidgets('landing on an enemy on an open square sends it home + extra '
        'turn', (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: false); // [0, 2]; Red index 0..3, Yellow 4..7
      s.setTokenForTest(0, pathIndex: 6); // Red on square 6
      // Yellow token sitting on square 9 (open — not a safe star).
      s.setTokenForTest(4, pathIndex: _pathIndexForSquare(2, 9));
      expect(s.tokenBoardSquareForTest(4), 9);

      s.moveTokenForTest(0, 3); // Red 6 -> 9, lands on the Yellow token
      await _flush(tester);

      expect(s.tokenBoardSquareForTest(0), 9);
      expect(s.tokenIsHomeForTest(4), isTrue, reason: 'captured → back home');
      expect(s.tokenPathIndexForTest(4), -1);
      expect(s.currentPlayerForTest, 0, reason: 'capture grants an extra turn');
      await _teardown(tester);
    });

    testWidgets('an enemy on a safe star square is NOT captured', (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: false);
      s.setTokenForTest(0, pathIndex: 5); // Red on square 5
      // Yellow parked on square 8 (a safe star).
      s.setTokenForTest(4, pathIndex: _pathIndexForSquare(2, 8));
      expect(s.tokenBoardSquareForTest(4), 8);
      expect(LudoScreenState.safeSquaresForTest.contains(8), isTrue);

      s.moveTokenForTest(0, 3); // Red 5 -> 8 (safe), no capture
      await _flush(tester);

      expect(s.tokenBoardSquareForTest(0), 8);
      expect(s.tokenIsOnBoardForTest(4), isTrue, reason: 'safe → survives');
      expect(s.tokenIsHomeForTest(4), isFalse);
      expect(s.currentPlayerForTest, 2,
          reason: 'no capture + non-6 → turn passes');
      await _teardown(tester);
    });
  });

  // ─────────────────────────── RULES: TRIPLE SIX ──────────────────────────
  group('Ludo rules — three sixes forfeit the turn', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    testWidgets('a third consecutive six skips the move and passes the turn',
        (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      final s = await _enterAi(tester, stop: 1);
      s.configureForTest(ai: false); // [0, 2], Red to move, all home

      s.afterRollForTest(6);
      expect(s.consecutiveSixesForTest, 1);
      s.afterRollForTest(6);
      expect(s.consecutiveSixesForTest, 2);
      s.afterRollForTest(6); // third six → forfeit
      expect(s.consecutiveSixesForTest, 0);
      expect(s.currentPlayerForTest, 2, reason: 'turn forfeited to Yellow');
      await _teardown(tester);
    });
  });

  // ──────────────────────────── RULES: WINNING ────────────────────────────
  group('Ludo rules — win detection', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<LudoScreenState> ready(WidgetTester tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterAi(tester, stop: 1);
      return _state(tester);
    }

    testWidgets('first player to bring all four home wins a 2-player game',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: true, difficulty: 'medium'); // human vs AI
      s.finishAllTokensForTest(0); // Red (human) all home
      final over = s.checkWinForTest();
      expect(over, isTrue);
      expect(s.winnerForTest, 0);
      expect(s.finishOrderForTest, [0]);
      expect(s.gameOverForTest, isTrue);
      await _teardown(tester);
    });

    testWidgets('a 4-player game ends only when three players have finished, '
        'preserving finish order', (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: false, activePlayers: [0, 1, 2, 3]);

      s.finishAllTokensForTest(2); // Yellow finishes first
      expect(s.checkWinForTest(), isFalse);
      expect(s.finishOrderForTest, [2]);
      expect(s.winnerForTest, 2);

      s.finishAllTokensForTest(0); // Red second
      expect(s.checkWinForTest(), isFalse);
      expect(s.finishOrderForTest, [2, 0]);

      s.finishAllTokensForTest(1); // Green third → game ends (Blue is last)
      expect(s.checkWinForTest(), isTrue);
      expect(s.finishOrderForTest, [2, 0, 1]);
      expect(s.winnerForTest, 2, reason: 'winner is the first to finish');
      expect(s.gameOverForTest, isTrue);
      await _teardown(tester);
    });

    testWidgets('turn rotation skips a player who has already finished',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: false, activePlayers: [0, 1, 2, 3], currentPlayer: 0);
      s.finishAllTokensForTest(1); // Green is done
      s.checkWinForTest(); // registers Green in finishOrder (game not over)
      expect(s.gameOverForTest, isFalse);

      s.nextTurnForTest(); // from Red(0): would be Green(1), but it's finished
      expect(s.currentPlayerForTest, 2, reason: 'skips finished Green → Yellow');
      await _teardown(tester);
    });
  });

  // ─────────────────────── SCORE / STREAK PERSISTENCE ─────────────────────
  group('Ludo scoring — wins, losses, streaks', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<LudoScreenState> ready(WidgetTester tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterAi(tester, stop: 1);
      return _state(tester);
    }

    testWidgets('beating the AI banks a win, starts a streak, saves a best',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: true, difficulty: 'medium');
      s.finishAllTokensForTest(0); // human wins
      s.checkWinForTest();
      expect(s.winsForTest, 1);
      expect(s.lossesForTest, 0);
      expect(s.streakForTest, 1);
      expect(s.streakOwnerForTest, 'human');
      expect(s.wasNewBestForTest, isTrue);
      expect(bestLudoStreak(kLudoSubKeyMedium), 1);
      await _teardown(tester);
    });

    testWidgets('losing to the AI banks a loss and breaks the human streak',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: true, difficulty: 'medium');
      s.finishAllTokensForTest(2); // AI (Yellow) wins
      s.checkWinForTest();
      expect(s.winnerForTest, 2);
      expect(s.lossesForTest, 1);
      expect(s.winsForTest, 0);
      expect(s.streakOwnerForTest, 'ai');
      await _teardown(tester);
    });

    testWidgets('consecutive wins grow the streak and raise the best',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: true, difficulty: 'hard');

      s.finishAllTokensForTest(0);
      s.checkWinForTest(); // win #1
      expect(s.streakForTest, 1);

      s.resetTokensForTest(); // keeps wins/streak (a "play again")
      s.finishAllTokensForTest(0);
      s.checkWinForTest(); // win #2
      expect(s.streakForTest, 2);
      expect(s.winsForTest, 2);
      expect(bestLudoStreak(kLudoSubKeyHard), 2);
      await _teardown(tester);
    });
  });

  // ───────────────────────────── AI BEHAVIOUR ─────────────────────────────
  group('Ludo AI token choice', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<LudoScreenState> ready(WidgetTester tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterAi(tester, stop: 1);
      return _state(tester);
    }

    testWidgets('easy AI always picks a token from the movable set',
        (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: true, difficulty: 'easy', currentPlayer: 0);
      s.setTokenForTest(0, pathIndex: 3);
      s.setTokenForTest(1, pathIndex: 20);
      final movable = s.movableForTest(2);
      expect(movable, isNotEmpty);
      for (int n = 0; n < 8; n++) {
        expect(movable.contains(s.aiBestTokenForTest(movable, 2)), isTrue);
      }
      await _teardown(tester);
    });

    testWidgets('medium AI prefers the capturing move', (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: true, difficulty: 'medium', currentPlayer: 0);
      s.setTokenForTest(0, pathIndex: 6); // capturer: 6 -> 9 lands on enemy
      s.setTokenForTest(1, pathIndex: 0); // decoy: 0 -> 3, nothing there
      s.setTokenForTest(4, pathIndex: _pathIndexForSquare(2, 9)); // enemy @9
      final movable = s.movableForTest(3);
      expect(movable.toSet(), {0, 1});
      expect(s.aiBestTokenForTest(movable, 3), 0,
          reason: 'capturing token is the best move');
      await _teardown(tester);
    });

    testWidgets('hard AI prefers the move that finishes a token', (tester) async {
      final s = await ready(tester);
      s.configureForTest(ai: true, difficulty: 'hard', currentPlayer: 0);
      s.setTokenForTest(0, pathIndex: 54); // 54 -> 56 finishes
      s.setTokenForTest(1, pathIndex: 0); // decoy
      final movable = s.movableForTest(2);
      expect(movable.toSet(), {0, 1});
      expect(s.aiBestTokenForTest(movable, 2), 0,
          reason: 'finishing a token scores highest');
      await _teardown(tester);
    });
  });

  // ─────────────────────────────── UI STATES ──────────────────────────────
  group('Ludo UI states', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    testWidgets('a win shows the banner, then the result screen, no overflow',
        (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      final s = await _enterAi(tester, stop: 1);
      s.configureForTest(ai: true, difficulty: 'medium');
      s.finishAllTokensForTest(0);
      s.checkWinForTest();
      await tester.pump(); // banner setState
      expect(find.text('You Win!'), findsWidgets, reason: 'win banner');
      expectNoOverflow(device, 'Ludo win banner');

      await _flush(tester, 2800); // past the 2.2s banner timer + interstitial
      await tester.pump();
      expect(find.text('You Win!'), findsWidgets, reason: 'result headline');
      expect(find.text('Play Again'), findsWidgets);
      expectNoOverflow(device, 'Ludo result');
      await _teardown(tester);
    });

    testWidgets('pause overlay shows resume / restart / quit', (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterAi(tester, stop: 1);
      _wrapper(tester).pauseGame();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      expectNoOverflow(device, 'Ludo pause');
      await _teardown(tester);
    });
  });
}
