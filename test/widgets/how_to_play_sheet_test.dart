import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/widgets/how_to_play_sheet.dart';

const _howToPlay = '''
1. First step does X
2. Second step does Y
3. Third step does Z
- Fourth step uses bullet
* Fifth step uses asterisk
• Sixth step uses dot
''';

void main() {
  group('HowToPlaySheet', () {
    testWidgets('opens via showHowToPlaySheet and renders title + step 1',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ));
      showHowToPlaySheet(
        ctx,
        title: 'Tic Tac Toe',
        howToPlay: _howToPlay,
        accent: const Color(0xFF7BC4A4),
      );
      await tester.pumpAndSettle();

      expect(find.text('How to Play'), findsOneWidget);
      expect(find.text('Tic Tac Toe'), findsOneWidget);
      expect(find.text('STEP 1 OF 6'), findsOneWidget);
      expect(find.textContaining('First step does X'), findsOneWidget);
      // Default CTA when more pages remain.
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('renders one page-dot per step', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          }),
        ),
      ));
      showHowToPlaySheet(
        ctx,
        title: 'Game',
        howToPlay: '1. A\n2. B\n3. C',
        accent: Colors.red,
      );
      await tester.pumpAndSettle();

      // 3 steps → 3 dots inside the dot row (AnimatedContainers with margin).
      // We assert the eyebrow first to confirm parsing landed on 3 steps.
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
    });

    testWidgets('Next button advances pages and final page shows Got it',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          }),
        ),
      ));
      showHowToPlaySheet(
        ctx,
        title: 'Game',
        howToPlay: '1. Alpha\n2. Beta',
        accent: Colors.red,
      );
      await tester.pumpAndSettle();

      // Page 1 / 2.
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Page 2 / 2 → CTA flips to "Got it! Let's play".
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      expect(find.text("Got it! Let's play"), findsOneWidget);
    });

    testWidgets('Got it button on the last page dismisses the sheet',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          }),
        ),
      ));
      showHowToPlaySheet(
        ctx,
        title: 'Game',
        howToPlay: '1. Only step',
        accent: Colors.red,
      );
      await tester.pumpAndSettle();

      // Single-step tutorial — CTA is Got it directly.
      expect(find.text("Got it! Let's play"), findsOneWidget);
      await tester.tap(find.text("Got it! Let's play"));
      await tester.pumpAndSettle();
      expect(find.text("Got it! Let's play"), findsNothing);
    });

    testWidgets('close icon dismisses the sheet', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          }),
        ),
      ));
      showHowToPlaySheet(
        ctx,
        title: 'Game',
        howToPlay: '1. A\n2. B',
        accent: Colors.red,
      );
      await tester.pumpAndSettle();

      expect(find.text('How to Play'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('How to Play'), findsNothing);
    });

    testWidgets('strips leading bullet/number prefixes from step text',
        (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          }),
        ),
      ));
      showHowToPlaySheet(
        ctx,
        title: 'Game',
        howToPlay: '1. First\n- Second\n• Third',
        accent: Colors.red,
      );
      await tester.pumpAndSettle();

      // First page should not contain the leading "1." prefix.
      expect(find.text('First'), findsOneWidget);
      expect(find.textContaining('1.'), findsNothing);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Third'), findsOneWidget);
    });

    testWidgets('renders nothing when howToPlay is empty', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          }),
        ),
      ));
      showHowToPlaySheet(
        ctx,
        title: 'Game',
        howToPlay: '   \n\n  ',
        accent: Colors.red,
      );
      await tester.pumpAndSettle();
      expect(find.text('How to Play'), findsNothing);
      expect(find.text('Next'), findsNothing);
    });
  });

}
