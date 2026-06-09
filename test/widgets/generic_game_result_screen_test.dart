import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/services/score_service.dart';
import '../../lib/games/shared/generic_game_result_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

Widget _buildResult({
  String headline = 'Game Over',
  String badgeContent = '🏆',
  Color badgeColor = Colors.amber,
  bool showNewBestBadge = false,
  int actionCount = 3,
  Widget? statsWidget,
}) {
  bool tapped = false;
  return GenericGameResultScreen(
    headline: headline,
    badgeContent: badgeContent,
    badgeColor: badgeColor,
    showNewBestBadge: showNewBestBadge,
    statsWidget: statsWidget,
    actions: List.generate(
      actionCount,
      (i) => GameResultAction(
        label: ['Play Again', 'Change Mode', 'Home'][i % 3],
        icon: [Icons.refresh_rounded, Icons.swap_horiz_rounded, Icons.home_rounded][i % 3],
        onTap: () => tapped = true,
        filled: i == 0,
        color: Colors.blue,
        actionId: ['play_again', 'change_mode', 'home'][i % 3],
      ),
    ),
    gameId: 'tic_tac_toe',
    score: 42,
  );
}

void main() {
  group('GenericGameResultScreen', () {
    setUp(() async => initTestDependencies());

    testWidgets('renders headline text', (tester) async {
      await pumpScreen(tester, allTestDevices.first, _buildResult(headline: 'You Win!'));
      expect(find.text('You Win!'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('renders badge content', (tester) async {
      await pumpScreen(tester, allTestDevices.first, _buildResult(badgeContent: '🎉'));
      expect(find.text('🎉'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('shows New High Score badge when enabled', (tester) async {
      await pumpScreen(tester, allTestDevices.first, _buildResult(showNewBestBadge: true));
      expect(find.text('New High Score!'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('hides New High Score badge when disabled', (tester) async {
      await pumpScreen(tester, allTestDevices.first, _buildResult(showNewBestBadge: false));
      expect(find.text('New High Score!'), findsNothing);
      cleanUp(tester);
    });

    testWidgets('renders all action buttons', (tester) async {
      await pumpScreen(tester, allTestDevices.first, _buildResult(actionCount: 3));
      expect(find.text('Play Again'), findsOneWidget);
      expect(find.text('Change Mode'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('renders Share Score button when gameId is set', (tester) async {
      await pumpScreen(tester, allTestDevices.first, _buildResult());
      expect(find.textContaining('Share Score'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('renders stats widget when provided', (tester) async {
      await pumpScreen(
        tester,
        allTestDevices.first,
        _buildResult(
          statsWidget: GameResultStatsRow(
            stats: [
              StatItem(label: 'SCORE', value: 100, color: Colors.blue),
              StatItem(label: 'BEST', value: 200, color: Colors.grey),
            ],
          ),
        ),
      );
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('BEST'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      cleanUp(tester);
    });

    testWidgets('renders PlayersRow stats', (tester) async {
      await pumpScreen(
        tester,
        allTestDevices.first,
        _buildResult(
          statsWidget: GameResultPlayersRow(
            p1Label: 'YOU',
            p2Label: 'AI',
            p1Score: 5,
            p2Score: 3,
            p1Color: Colors.red,
            p2Color: Colors.blue,
            p1IsWinner: true,
            p2IsWinner: false,
            scoreUnit: 'boxes',
          ),
        ),
      );
      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('boxes'), findsNWidgets(2));
      cleanUp(tester);
    });

    for (final device in allTestDevices) {
      testWidgets('renders without overflow on ${device.name}', (tester) async {
        await pumpScreen(tester, device, _buildResult());
        expectNoOverflow(device, 'GenericGameResultScreen');
        cleanUp(tester);
      });
    }
  });
}
