import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';
import '../../lib/core/widgets/mosaic_game_tile.dart';

GameInfo _gameNoAsset() => const GameInfo(
      id: 't',
      name: 'Test Game',
      description: 'd',
      howToPlay: '1. Play',
      category: GameCategory.action,
      icon: Icons.flash_on_rounded,
      color: Color(0xFFFF0000),
      bgColor: Color(0xFFFFFFFF),
      playCount: 100,
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 200, height: 200, child: child),
      ),
    );

void main() {
  group('MosaicGameTile', () {
    testWidgets('small tile renders without exceptions', (tester) async {
      await tester.pumpWidget(_wrap(MosaicGameTile(
        game: _gameNoAsset(),
      )));
      expect(find.byType(MosaicGameTile), findsOneWidget);
    });

    testWidgets('medium tile renders without exceptions', (tester) async {
      await tester.pumpWidget(_wrap(MosaicGameTile(
        game: _gameNoAsset(),
        tileSize: TileSize.medium,
      )));
      expect(find.byType(MosaicGameTile), findsOneWidget);
    });

    testWidgets('large tile renders without exceptions', (tester) async {
      await tester.pumpWidget(_wrap(MosaicGameTile(
        game: _gameNoAsset(),
        tileSize: TileSize.large,
      )));
      expect(find.byType(MosaicGameTile), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(MosaicGameTile(
        game: _gameNoAsset(),
        onTap: () => taps++,
      )));
      await tester.tap(find.byType(MosaicGameTile));
      expect(taps, 1);
    });

    test('TileSize spans match column / row counts', () {
      expect(TileSize.small.colSpan, 1);
      expect(TileSize.small.rowSpan, 1);
      expect(TileSize.medium.colSpan, 2);
      expect(TileSize.medium.rowSpan, 2);
      expect(TileSize.large.colSpan, 3);
      expect(TileSize.large.rowSpan, 3);
    });
  });
}
