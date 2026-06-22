import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';
import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../../lib/games/chess/chess_screen.dart';

import '../helpers/game_drivers.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _gameId = 'chess';

Widget _build() =>
    GameWrapper(gameId: _gameId, child: GameRegistry.buildGame(_gameId));

ChessScreenState _state(WidgetTester tester) =>
    tester.state<ChessScreenState>(find.byType(ChessScreen));

/// Algebraic square -> board index (0 = a8 top-left, 63 = h1 bottom-right).
int _sq(String a) {
  final col = a.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = a.codeUnitAt(1) - '0'.codeUnitAt(0);
  return (8 - rank) * 8 + col;
}

/// Piece codes: 1=K 2=Q 3=R 4=B 5=N 6=P (white +, black -).
List<int> _emptyBoard() => List<int>.filled(64, 0);

List<int> _initialBoard() {
  final b = _emptyBoard();
  const back = [3, 5, 4, 2, 1, 4, 5, 3];
  for (int c = 0; c < 8; c++) {
    b[c] = -back[c];
    b[8 + c] = -6;
    b[48 + c] = 6;
    b[56 + c] = back[c];
  }
  return b;
}

Future<void> _enterAi(WidgetTester tester, int stop) async {
  await selectDifficultyStop(tester, stop);
  await tapPlay(tester, 'Play vs. AI');
}

Future<void> _enterTwoPlayer(WidgetTester tester) async {
  await tapPlay(tester, 'Play with a Friend');
}

/// Tidy up: first pump a beat so any just-created one-shot `flutter_animate`
/// timers (pause overlay, result screen) fire instead of lingering, then unmount
/// so the repeating check-pulse ticker + AI/end-game timers are disposed.
Future<void> _teardown(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpWidget(const SizedBox());
  cleanUp(tester);
}

void main() {
  group('Chess registry', () {
    test('is registered with correct metadata', () {
      final info = GameRegistry.getById(_gameId);
      expect(info, isNotNull);
      expect(info!.name, 'Chess');
      expect(info.category, GameCategory.board);
      expect(info.howToPlay, isNotEmpty);
    });
  });

  // ───────────────────────────── RENDER / OVERFLOW ─────────────────────────
  group('Chess picker — every device', () {
    for (final device in allTestDevices) {
      group('${device.name} (${device.width}x${device.height})', () {
        setUp(() async => initGameTest());

        testWidgets('renders picker without overflow', (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          expect(find.text('Chess'), findsWidgets);
          expect(find.text('Play vs. AI'), findsOneWidget);
          expect(find.text('Play with a Friend'), findsOneWidget);
          expectNoOverflow(device, 'Chess picker');
          await _teardown(tester);
        });
      });
    }
  });

  group('Chess board render — every device', () {
    for (final device in allTestDevices) {
      group('${device.name} (${device.width}x${device.height})', () {
        setUp(() async => initGameTest());

        testWidgets('AI board renders 64 squares without overflow',
            (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await _enterAi(tester, 1); // medium
          expect(find.byKey(const ValueKey('sq_0')), findsOneWidget);
          expect(find.byKey(const ValueKey('sq_63')), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 300));
          expectNoOverflow(device, 'Chess AI board');
          await _teardown(tester);
        });

        testWidgets('two-player board renders without overflow',
            (tester) async {
          await pumpScreen(tester, device, _build(), settle: false);
          await _enterTwoPlayer(tester);
          expect(find.byKey(const ValueKey('sq_0')), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 300));
          expectNoOverflow(device, 'Chess 2P board');
          await _teardown(tester);
        });
      });
    }
  });

  group('Chess board render — each AI difficulty (tight devices)', () {
    const tight = [
      TestDevice(name: 'Small Android', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.android),
      TestDevice(name: 'iPhone SE', width: 320, height: 568, pixelRatio: 2.0, platform: TargetPlatform.iOS),
    ];
    for (final device in tight) {
      for (int stop = 0; stop < 3; stop++) {
        final diff = const ['Easy', 'Medium', 'Hard'][stop];
        testWidgets('$diff board on ${device.name} no overflow', (tester) async {
          await initGameTest();
          await pumpScreen(tester, device, _build(), settle: false);
          await _enterAi(tester, stop);
          expect(find.byKey(const ValueKey('sq_0')), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 300));
          expectNoOverflow(device, 'Chess $diff');
          await _teardown(tester);
        });
      }
    }
  });

  // ───────────────────────────── PICKER FLOW ──────────────────────────────
  group('Chess flow', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);
    setUp(() async => initGameTest());

    testWidgets('selecting Hard carries into the in-game scoreboard',
        (tester) async {
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterAi(tester, 2); // hard
      expect(find.text('HARD'), findsWidgets,
          reason: 'scoreboard pill reflects the chosen difficulty');
      await _teardown(tester);
    });

    testWidgets('Play vs AI enters board with YOU/AI strips', (tester) async {
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterAi(tester, 0);
      expect(find.text('You'), findsWidgets);
      expect(find.text('AI'), findsWidgets);
      expect(_state(tester).turnToMove, 1);
      await _teardown(tester);
    });

    testWidgets('Play with a Friend enters board with P1/P2 strips',
        (tester) async {
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterTwoPlayer(tester);
      expect(find.text('Player 1'), findsWidgets);
      expect(find.text('Player 2'), findsWidgets);
      await _teardown(tester);
    });
  });

  // ─────────────────────────── ENGINE: MOVE GEN ───────────────────────────
  group('Chess engine — move generation', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<ChessScreenState> ready(WidgetTester tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterTwoPlayer(tester);
      return _state(tester);
    }

    testWidgets('initial position: 20 legal moves per side', (tester) async {
      final s = await ready(tester);
      s.loadPosition(_initialBoard(), turn: 1);
      await tester.pump();
      expect(s.allLegalMovesForTest(1).length, 20);
      expect(s.allLegalMovesForTest(-1).length, 20);
      await _teardown(tester);
    });

    testWidgets('pawn double-step only from start rank', (tester) async {
      final s = await ready(tester);
      s.loadPosition(_initialBoard(), turn: 1);
      await tester.pump();
      // e2 pawn: e3 and e4.
      final e2 = s.legalMovesForTest(_sq('e2'));
      expect(e2.toSet(), {_sq('e3'), _sq('e4')});
      // Advance the pawn, then it may only step one.
      s.loadPosition(_initialBoard()..[_sq('e2')] = 0..[_sq('e4')] = 6, turn: 1);
      await tester.pump();
      expect(s.legalMovesForTest(_sq('e4')), [_sq('e5')]);
      await _teardown(tester);
    });

    testWidgets('knight from a corner has 2 moves', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('a1')] = 5
        ..[_sq('e1')] = 1
        ..[_sq('e8')] = -1;
      s.loadPosition(b, turn: 1);
      await tester.pump();
      expect(s.legalMovesForTest(_sq('a1')).toSet(), {_sq('b3'), _sq('c2')});
      await _teardown(tester);
    });

    testWidgets('bishop is blocked by its own pieces', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('c1')] = 4
        ..[_sq('e3')] = 6 // own pawn blocks the a-h diagonal beyond e3
        ..[_sq('e1')] = 1
        ..[_sq('e8')] = -1;
      s.loadPosition(b, turn: 1);
      await tester.pump();
      final moves = s.legalMovesForTest(_sq('c1')).toSet();
      expect(moves.contains(_sq('d2')), isTrue);
      expect(moves.contains(_sq('e3')), isFalse); // own pawn
      expect(moves.contains(_sq('f4')), isFalse); // blocked beyond
      expect(moves.contains(_sq('b2')), isTrue);
      await _teardown(tester);
    });

    testWidgets('a pinned piece cannot abandon the pin line', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e1')] = 1 // white king
        ..[_sq('e2')] = 3 // white rook, pinned on the e-file
        ..[_sq('e8')] = -3 // black rook pins
        ..[_sq('a8')] = -1; // black king
      s.loadPosition(b, turn: 1);
      await tester.pump();
      final moves = s.legalMovesForTest(_sq('e2'));
      expect(moves.every((m) => m % 8 == 4), isTrue,
          reason: 'pinned rook may only move along the e-file: $moves');
      expect(moves.contains(_sq('d2')), isFalse);
      expect(moves.contains(_sq('e8')), isTrue, reason: 'may capture the pinner');
      await _teardown(tester);
    });

    testWidgets('king may not move into check', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e1')] = 1
        ..[_sq('a8')] = -1
        ..[_sq('d8')] = -3; // black rook controls the d-file
      s.loadPosition(b, turn: 1);
      await tester.pump();
      final moves = s.legalMovesForTest(_sq('e1')).toSet();
      expect(moves.contains(_sq('d1')), isFalse, reason: 'd1 is attacked');
      expect(moves.contains(_sq('d2')), isFalse, reason: 'd2 is attacked');
      expect(moves.contains(_sq('e2')), isTrue);
      expect(moves.contains(_sq('f1')), isTrue);
      await _teardown(tester);
    });
  });

  // ─────────────────────────── ENGINE: SPECIAL MOVES ──────────────────────
  group('Chess engine — special moves', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<ChessScreenState> ready(WidgetTester tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterTwoPlayer(tester);
      return _state(tester);
    }

    testWidgets('kingside castling moves king and rook', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e1')] = 1
        ..[_sq('h1')] = 3
        ..[_sq('e8')] = -1;
      s.loadPosition(b, turn: 1, whiteKingMoved: false, whiteRookHMoved: false);
      await tester.pump();
      expect(s.legalMovesForTest(_sq('e1')).contains(_sq('g1')), isTrue);
      s.doMoveForTest(_sq('e1'), _sq('g1'));
      await tester.pump();
      expect(s.board[_sq('g1')], 1, reason: 'king on g1');
      expect(s.board[_sq('f1')], 3, reason: 'rook hopped to f1');
      expect(s.board[_sq('e1')], 0);
      expect(s.board[_sq('h1')], 0);
      await _teardown(tester);
    });

    testWidgets('queenside castling moves king and rook', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e1')] = 1
        ..[_sq('a1')] = 3
        ..[_sq('e8')] = -1;
      s.loadPosition(b, turn: 1, whiteKingMoved: false, whiteRookAMoved: false);
      await tester.pump();
      expect(s.legalMovesForTest(_sq('e1')).contains(_sq('c1')), isTrue);
      s.doMoveForTest(_sq('e1'), _sq('c1'));
      await tester.pump();
      expect(s.board[_sq('c1')], 1);
      expect(s.board[_sq('d1')], 3);
      expect(s.board[_sq('a1')], 0);
      await _teardown(tester);
    });

    testWidgets('cannot castle through an attacked square', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e1')] = 1
        ..[_sq('h1')] = 3
        ..[_sq('f8')] = -3 // black rook attacks f1 (king would pass through)
        ..[_sq('a8')] = -1;
      s.loadPosition(b, turn: 1, whiteKingMoved: false, whiteRookHMoved: false);
      await tester.pump();
      expect(s.legalMovesForTest(_sq('e1')).contains(_sq('g1')), isFalse);
      await _teardown(tester);
    });

    testWidgets('cannot castle while in check', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e1')] = 1
        ..[_sq('h1')] = 3
        ..[_sq('e8')] = -3 // checks the king on the e-file
        ..[_sq('a8')] = -1;
      s.loadPosition(b, turn: 1, whiteKingMoved: false, whiteRookHMoved: false);
      await tester.pump();
      expect(s.inCheck, isTrue);
      expect(s.legalMovesForTest(_sq('e1')).contains(_sq('g1')), isFalse);
      await _teardown(tester);
    });

    testWidgets('en passant captures the passed pawn', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e5')] = 6 // white pawn
        ..[_sq('d5')] = -6 // black pawn that just double-stepped
        ..[_sq('e1')] = 1
        ..[_sq('e8')] = -1;
      s.loadPosition(b, turn: 1, enPassantTarget: _sq('d6'));
      await tester.pump();
      expect(s.legalMovesForTest(_sq('e5')).contains(_sq('d6')), isTrue);
      s.doMoveForTest(_sq('e5'), _sq('d6'));
      await tester.pump();
      expect(s.board[_sq('d6')], 6, reason: 'white pawn advanced to d6');
      expect(s.board[_sq('d5')], 0, reason: 'black pawn captured en passant');
      expect(s.board[_sq('e5')], 0);
      expect(find.text('♟'), findsOneWidget,
          reason: 'captured black pawn shows in the captured row');
      await _teardown(tester);
    });

    testWidgets('pawn promotes to a queen on the last rank', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('a7')] = 6
        ..[_sq('e1')] = 1
        ..[_sq('e8')] = -1;
      s.loadPosition(b, turn: 1);
      await tester.pump();
      expect(s.legalMovesForTest(_sq('a7')).contains(_sq('a8')), isTrue);
      s.doMoveForTest(_sq('a7'), _sq('a8'));
      await tester.pump();
      expect(s.board[_sq('a8')], 2, reason: 'promoted to white queen');
      await _teardown(tester);
    });
  });

  // ─────────────────────────── ENGINE: GAME END ───────────────────────────
  group('Chess engine — checkmate / stalemate / draws', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<ChessScreenState> ready(WidgetTester tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterTwoPlayer(tester);
      return _state(tester);
    }

    testWidgets('delivering mate ends the game with the right winner',
        (tester) async {
      final s = await ready(tester);
      // White: Kf6, Qg1, Black: Kh8. Qg1-g7 is mate.
      final b = _emptyBoard()
        ..[_sq('f6')] = 1
        ..[_sq('g1')] = 2
        ..[_sq('h8')] = -1;
      s.loadPosition(b, turn: 1);
      await tester.pump();
      s.doMoveForTest(_sq('g1'), _sq('g7'));
      expect(s.isGameOver, isTrue);
      expect(s.winner, 1, reason: 'white delivered checkmate');
      expect(s.allLegalMovesForTest(-1), isEmpty);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Player 1 Wins!'), findsWidgets);
      await _teardown(tester);
    });

    testWidgets('a checking move that is not mate keeps the game going',
        (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e1')] = 1
        ..[_sq('h5')] = 2
        ..[_sq('e8')] = -1;
      s.loadPosition(b, turn: 1);
      await tester.pump();
      s.doMoveForTest(_sq('h5'), _sq('e5')); // Qe5+ along the e-file
      await tester.pump();
      expect(s.inCheck, isTrue);
      expect(s.isGameOver, isFalse);
      expect(s.allLegalMovesForTest(-1), isNotEmpty);
      await _teardown(tester);
    });

    testWidgets('stalemate is detected as a draw', (tester) async {
      final s = await ready(tester);
      // Black Kh8 to move after White Qc6-g6: not in check, no legal move.
      final b = _emptyBoard()
        ..[_sq('h8')] = -1
        ..[_sq('f7')] = 1
        ..[_sq('c6')] = 2;
      s.loadPosition(b, turn: 1);
      await tester.pump();
      s.doMoveForTest(_sq('c6'), _sq('g6'));
      expect(s.isGameOver, isTrue);
      expect(s.winner, isNull, reason: 'stalemate is a draw');
      expect(s.inCheck, isFalse);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Draw'), findsWidgets);
      await _teardown(tester);
    });

    testWidgets('insufficient material is classified correctly', (tester) async {
      final s = await ready(tester);
      base() => _emptyBoard()..[_sq('e1')] = 1..[_sq('e8')] = -1;

      s.loadPosition(base(), turn: 1);
      await tester.pump();
      expect(s.isInsufficientMaterialForTest(), isTrue, reason: 'K vs K');

      s.loadPosition(base()..[_sq('c1')] = 4, turn: 1);
      await tester.pump();
      expect(s.isInsufficientMaterialForTest(), isTrue, reason: 'K+B vs K');

      s.loadPosition(base()..[_sq('b1')] = 5, turn: 1);
      await tester.pump();
      expect(s.isInsufficientMaterialForTest(), isTrue, reason: 'K+N vs K');

      s.loadPosition(base()..[_sq('d1')] = 2, turn: 1);
      await tester.pump();
      expect(s.isInsufficientMaterialForTest(), isFalse, reason: 'K+Q vs K');
      await _teardown(tester);
    });

    testWidgets('capturing into a lone-kings position draws', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e4')] = 1 // white king
        ..[_sq('d5')] = -4 // black bishop (last non-king piece)
        ..[_sq('h8')] = -1;
      s.loadPosition(b, turn: 1);
      await tester.pump();
      s.doMoveForTest(_sq('e4'), _sq('d5')); // Kxd5 -> only two kings remain
      expect(s.isGameOver, isTrue);
      expect(s.winner, isNull);
      await _teardown(tester);
    });

    testWidgets('the 50-move rule draws', (tester) async {
      final s = await ready(tester);
      final b = _emptyBoard()
        ..[_sq('e1')] = 1
        ..[_sq('a1')] = 3
        ..[_sq('e8')] = -1;
      s.loadPosition(b, turn: 1, halfMoveClock: 99);
      await tester.pump();
      s.doMoveForTest(_sq('a1'), _sq('a2')); // 100th half-move, no capture/pawn
      expect(s.isGameOver, isTrue);
      expect(s.winner, isNull);
      await _teardown(tester);
    });

    testWidgets('threefold repetition draws', (tester) async {
      final s = await ready(tester);
      s.loadPosition(_initialBoard(), turn: 1);
      await tester.pump();
      // Shuffle both knights out and back twice -> start position thrice.
      const moves = [
        ['g1', 'f3'], ['g8', 'f6'], ['f3', 'g1'], ['f6', 'g8'],
        ['g1', 'f3'], ['g8', 'f6'], ['f3', 'g1'], ['f6', 'g8'],
      ];
      for (final m in moves) {
        s.doMoveForTest(_sq(m[0]), _sq(m[1]));
      }
      expect(s.isGameOver, isTrue);
      expect(s.winner, isNull, reason: 'threefold repetition');
      await _teardown(tester);
    });
  });

  // ─────────────────────── TAP-DRIVEN REAL GAME (full path) ────────────────
  group('Chess tap-driven play', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    Future<void> tapSq(WidgetTester tester, int i) async {
      await tester.tap(find.byKey(ValueKey('sq_$i')));
      await tester.pump(const Duration(milliseconds: 60));
    }

    testWidgets('selecting then moving a pawn advances the turn',
        (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterTwoPlayer(tester);
      final s = _state(tester);
      expect(s.turnToMove, 1);
      await tapSq(tester, _sq('e2')); // select
      await tapSq(tester, _sq('e4')); // move
      expect(s.board[_sq('e4')], 6);
      expect(s.board[_sq('e2')], 0);
      expect(s.turnToMove, -1, reason: 'turn passes to black');
      expectNoOverflow(device, 'Chess after move');
      await _teardown(tester);
    });

    testWidgets("Fool's mate via taps ends the game (Player 2 Wins)",
        (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterTwoPlayer(tester);
      final s = _state(tester);
      // 1. f3 e5  2. g4 Qh4#
      for (final m in const [
        ['f2', 'f3'], ['e7', 'e5'], ['g2', 'g4'], ['d8', 'h4'],
      ]) {
        await tapSq(tester, _sq(m[0]));
        await tapSq(tester, _sq(m[1]));
      }
      expect(s.isGameOver, isTrue);
      expect(s.winner, -1, reason: 'black checkmates');
      expect(find.text('Player 2 Wins!'), findsWidgets);
      // Result screen after the banner timer.
      await tester.pump(const Duration(milliseconds: 1800));
      expect(find.text('Player 2 Wins!'), findsWidgets);
      expectNoOverflow(device, 'Chess result');
      await _teardown(tester);
    });

    testWidgets('tapping a square with no selection does nothing harmful',
        (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterTwoPlayer(tester);
      final s = _state(tester);
      await tapSq(tester, _sq('e4')); // empty square, nothing selected
      expect(s.turnToMove, 1);
      expect(s.board, _initialBoard());
      await _teardown(tester);
    });
  });

  // ─────────────────────────────── AI BEHAVIOUR ───────────────────────────
  group('Chess AI', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    for (final (stop, diff, waitMs) in const [
      (0, 'Easy', 1200),
      (1, 'Medium', 2500),
    ]) {
      testWidgets('$diff AI replies with a legal move and keeps playing',
          (tester) async {
        await initGameTest();
        await pumpScreen(tester, device, _build(), settle: false);
        await _enterAi(tester, stop);
        final s = _state(tester);
        // Human (white) plays e2-e4 through the real pipeline; AI is scheduled.
        s.doMoveForTest(_sq('e2'), _sq('e4'));
        expect(s.turnToMove, -1, reason: 'black (AI) to move');
        await tester.pump(Duration(milliseconds: waitMs));
        expect(s.turnToMove, 1, reason: 'AI moved, back to white');
        expect(s.isGameOver, isFalse);
        // AI actually changed the position (some black piece moved).
        expect(s.board, isNot(equals(_initialBoard()..[_sq('e2')] = 0..[_sq('e4')] = 6)));
        await _teardown(tester);
      });
    }
  });

  // ─────────────────────────────── UI STATES ──────────────────────────────
  group('Chess UI states', () {
    const device = TestDevice(name: 'Pixel 6', width: 412, height: 915, pixelRatio: 2.625, platform: TargetPlatform.android);

    testWidgets('pause overlay shows resume / restart / quit', (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterTwoPlayer(tester);
      final wrapper = tester.state<GameWrapperState>(find.byType(GameWrapper));
      wrapper.pauseGame();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      expectNoOverflow(device, 'Chess pause');
      await _teardown(tester);
    });

    testWidgets('capturing shows the piece in the captured row', (tester) async {
      await initGameTest();
      await pumpScreen(tester, device, _build(), settle: false);
      await _enterTwoPlayer(tester);
      final s = _state(tester);
      // White rook captures a lone black knight.
      final b = _emptyBoard()
        ..[_sq('a1')] = 3
        ..[_sq('a8')] = -5
        ..[_sq('e1')] = 1
        ..[_sq('h8')] = -1;
      s.loadPosition(b, turn: 1);
      await tester.pump();
      s.doMoveForTest(_sq('a1'), _sq('a8')); // Rxa8
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.board[_sq('a8')], 3);
      expect(find.text('♞'), findsOneWidget,
          reason: 'captured black knight glyph in the captured row');
      await _teardown(tester);
    });
  });
}
