import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';

GameInfo _make({int playCount = 0, String? iconAsset}) {
  return GameInfo(
    id: 't',
    name: 'Test',
    description: 'd',
    howToPlay: '1. Tap',
    category: GameCategory.action,
    icon: Icons.star,
    color: Colors.red,
    bgColor: Colors.white,
    playCount: playCount,
    iconAsset: iconAsset,
  );
}

void main() {
  group('GameInfo.playCountFormatted', () {
    test('formats below 1k as plain number', () {
      expect(_make(playCount: 0).playCountFormatted, '0');
      expect(_make(playCount: 999).playCountFormatted, '999');
    });

    test('formats thousands with K suffix and 1 decimal', () {
      expect(_make(playCount: 1000).playCountFormatted, '1.0K');
      expect(_make(playCount: 12500).playCountFormatted, '12.5K');
      expect(_make(playCount: 999999).playCountFormatted, '1000.0K');
    });

    test('formats millions with M suffix and 1 decimal', () {
      expect(_make(playCount: 1000000).playCountFormatted, '1.0M');
      expect(_make(playCount: 2_500_000).playCountFormatted, '2.5M');
    });
  });

  group('GameInfo.buildIcon', () {
    testWidgets('renders Icon when no iconAsset is provided', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: _make().buildIcon(size: 48)),
      ));
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('renders Image when iconAsset is provided', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _make(iconAsset: 'assets/missing.png').buildIcon(size: 48),
        ),
      ));
      // The Image widget is constructed even if the asset can't be resolved.
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
