import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/widgets/section_header.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SectionHeader', () {
    testWidgets('shows title text', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'Trending')));
      expect(find.text('Trending'), findsOneWidget);
    });

    testWidgets('hides "See all" when onSeeAll is null', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader(title: 'X')));
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('shows "See all" and fires callback when provided',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(SectionHeader(
        title: 'X',
        onSeeAll: () => taps++,
      )));
      expect(find.text('See all'), findsOneWidget);
      await tester.tap(find.text('See all'));
      expect(taps, 1);
    });
  });
}
