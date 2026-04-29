import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';
import '../../lib/core/widgets/game_card.dart';

GameInfo _game() => const GameInfo(
      id: 't',
      name: 'Sample Game',
      description: 'd',
      howToPlay: '1. Play',
      category: GameCategory.puzzle,
      icon: Icons.extension_rounded,
      color: Color(0xFF1976D2),
      bgColor: Color(0xFFE3F2FD),
      playCount: 1500,
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 320, height: 320, child: Center(child: child)),
      ),
    );

void main() {
  group('GameCard (full)', () {
    testWidgets('shows game name', (tester) async {
      await tester.pumpWidget(_wrap(GameCard(game: _game(), onTap: () {})));
      expect(find.text('Sample Game'), findsOneWidget);
    });

    testWidgets('invokes onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(GameCard(game: _game(), onTap: () => taps++)));
      await tester.tap(find.byType(GameCard));
      expect(taps, 1);
    });

    testWidgets('respects width override', (tester) async {
      await tester.pumpWidget(_wrap(GameCard(
        game: _game(),
        width: 180,
        onTap: () {},
      )));
      // The size constraint flows through Container; we sanity-check by
      // confirming the card paints without overflow at this width.
      expect(tester.takeException(), isNull);
    });
  });

  group('GameCard (compact)', () {
    testWidgets('shows name in compact mode', (tester) async {
      await tester.pumpWidget(_wrap(GameCard(
        game: _game(),
        compact: true,
        onTap: () {},
      )));
      expect(find.text('Sample Game'), findsOneWidget);
    });

    testWidgets('invokes onTap in compact mode', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(GameCard(
        game: _game(),
        compact: true,
        onTap: () => taps++,
      )));
      // Compact card uses a Column with deferToChild hit-testing; tap the
      // icon child directly so the hit isn't lost in surrounding whitespace.
      await tester.tap(find.byIcon(Icons.extension_rounded));
      expect(taps, 1);
    });
  });
}
