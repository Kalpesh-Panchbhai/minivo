import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/multiplayer/player_strip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('PlayerStrip', () {
    testWidgets('shows label text', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlayerStrip(label: 'You', mark: 'X', color: Colors.red, isActive: true),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('shows YOUR TURN when active', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlayerStrip(label: 'You', mark: 'X', color: Colors.red, isActive: true),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('YOUR TURN'), findsOneWidget);
    });

    testWidgets('shows WAITING when not active', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlayerStrip(label: 'AI', mark: 'O', color: Colors.blue, isActive: false),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('WAITING'), findsOneWidget);
    });

    testWidgets('shows THINKING… when isThinking is true', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlayerStrip(
          label: 'AI', mark: 'O', color: Colors.blue,
          isActive: false, isThinking: true,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('THINKING…'), findsOneWidget);
    });

    testWidgets('active strip has full opacity', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlayerStrip(label: 'You', mark: 'X', color: Colors.red, isActive: true),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first);
      expect(opacity.opacity, 1.0);
    });

    testWidgets('inactive strip has reduced opacity', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlayerStrip(label: 'AI', mark: 'O', color: Colors.blue, isActive: false),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first);
      expect(opacity.opacity, 0.28);
    });

    testWidgets('shows avatar icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlayerStrip(
          label: 'AI', mark: 'O', color: Colors.blue,
          isActive: true, avatarIcon: Icons.smart_toy_rounded,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
    });

    testWidgets('shows mark icon when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const PlayerStrip(
          label: 'You', mark: 'X', color: Colors.red,
          isActive: true, markIcon: Icons.close_rounded,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('transitions between active and inactive', (tester) async {
      bool active = false;
      await tester.pumpWidget(_wrap(
        StatefulBuilder(builder: (ctx, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerStrip(label: 'You', mark: 'X', color: Colors.red, isActive: active),
              TextButton(
                onPressed: () => setState(() => active = !active),
                child: const Text('Toggle'),
              ),
            ],
          );
        }),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('WAITING'), findsOneWidget);

      await tester.tap(find.text('Toggle'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('YOUR TURN'), findsOneWidget);
    });
  });
}
