import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/home/home_screen.dart';
import '../../lib/core/widgets/mosaic_game_tile.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';
import '../helpers/overflow_detector.dart';

// The home header was redesigned to a game-style dark gradient (no app bar,
// no search icon). Top-bar elements verified: MINIVO wordmark, trophy
// button (Icons.emoji_events_rounded), settings gear. Body sections:
// category chips → optional recently-played row → trending → masonry grid.
void main() {
  for (final device in allTestDevices) {
    group('HomeScreen on ${device.name} (${device.width}x${device.height})', () {
      setUp(() async {
        await initTestDependencies();
      });

      testWidgets('renders without overflow', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('header wordmark visible', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        expect(find.text('MINIVO'), findsOneWidget);
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('header action icons visible', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        // Trophy (placeholder leaderboard) + settings gear
        expect(find.byIcon(Icons.emoji_events_rounded), findsWidgets);
        expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('trending section exists', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        expect(find.text('Trending'), findsOneWidget);
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('mosaic game tiles rendered', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        expect(find.byType(MosaicGameTile), findsWidgets);
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('can scroll without overflow', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        final scrollable = find.byType(Scrollable).first;
        await tester.drag(scrollable, const Offset(0, -300));
        // Bounded pump — pumpAndSettle hangs when animated icons / glow
        // effects loop forever. Inspecting overflow doesn't need a fully
        // quiescent tree; one frame after the drag is enough.
        await tester.pump(const Duration(milliseconds: 300));
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });

      testWidgets('category chips visible', (tester) async {
        await pumpScreen(tester, device, const HomeScreen());
        // CategoryChip renders GameCategory.label. "Action" is one of them.
        expect(find.text('Action'), findsWidgets);
        expectNoOverflow(device, 'HomeScreen');
        cleanUp(tester);
      });
    });
  }
}
