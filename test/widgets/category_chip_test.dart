import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/models/game_info.dart';
import '../../lib/core/widgets/category_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('CategoryChip', () {
    testWidgets('renders label and icon for category', (tester) async {
      await tester.pumpWidget(_wrap(CategoryChip(
        category: GameCategory.action,
        onTap: () {},
      )));
      expect(find.text('Action'), findsOneWidget);
      expect(find.byIcon(GameCategory.action.icon), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(CategoryChip(
        category: GameCategory.puzzle,
        onTap: () => taps++,
      )));
      await tester.tap(find.byType(CategoryChip));
      expect(taps, 1);
    });

    testWidgets('selected variant uses tinted background', (tester) async {
      await tester.pumpWidget(_wrap(CategoryChip(
        category: GameCategory.puzzle,
        selected: true,
        onTap: () {},
      )));
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(CategoryChip),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      // Selected chips render a non-white tinted background.
      expect(decoration.color, isNot(Colors.white));
    });

    testWidgets('unselected variant uses white background', (tester) async {
      await tester.pumpWidget(_wrap(CategoryChip(
        category: GameCategory.puzzle,
        onTap: () {},
      )));
      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(CategoryChip),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
    });
  });
}
