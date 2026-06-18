import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/services/score_service.dart';
import '../../lib/games/shared/generic_game_result_screen.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

// ---------------------------------------------------------------------------
// Worst-case render of the shared game-result screen used by ~all games.
// The existing test sweeps devices with DEFAULT data; this stresses the
// extremes that actually break layout: long headline/subtitle, the maximum
// realistic stat count with wide values, long button labels, the New-Best
// badge — at normal AND 1.3x text scale, on every device.
// ---------------------------------------------------------------------------

Widget _worstCaseResult() {
  return GenericGameResultScreen(
    headline: 'PASS & PLAY DRAW — NOBODY WINS!',
    subtitle: 'A hard-fought match that came down to the very last move',
    badgeContent: '🏆',
    badgeColor: Colors.amber,
    showNewBestBadge: true,
    gameId: 'number_sequence',
    score: 9999999,
    stars: 3,
    statsWidget: GameResultStatsRow(
      stats: [
        StatItem(label: 'SCORE', value: 9999999, displayValue: '9,999,999', color: Colors.blue),
        StatItem(label: 'TIME', value: 5999, displayValue: '99:59', color: Colors.teal),
        StatItem(label: 'MOVES', value: 123456, displayValue: '123,456', color: Colors.purple),
        StatItem(label: 'BEST', value: 9999999, displayValue: '9,999,999', color: Colors.amber),
      ],
    ),
    actions: [
      GameResultAction(
        label: 'Play Again',
        icon: Icons.refresh_rounded,
        onTap: () {},
        filled: true,
        color: Colors.blue,
        actionId: 'play_again',
      ),
      GameResultAction(
        label: 'Change Difficulty',
        icon: Icons.swap_horiz_rounded,
        onTap: () {},
        color: Colors.blue,
        actionId: 'change',
      ),
      GameResultAction(
        label: 'Back to Home',
        icon: Icons.home_rounded,
        onTap: () {},
        color: Colors.blue,
        actionId: 'home',
      ),
    ],
  );
}

Future<void> _init() async {
  SharedPreferences.setMockInitialValues({});
  await ScoreService().init();
}

void main() {
  group('GenericGameResultScreen worst-case', () {
    setUp(_init);

    for (final device in allTestDevices) {
      testWidgets('no overflow @1.0x on ${device.name}', (tester) async {
        await pumpScreen(tester, device, _worstCaseResult());
        expectNoOverflow(device, 'Result worst-case 1.0x');
        cleanUp(tester);
      });

      testWidgets('no overflow @1.3x on ${device.name}', (tester) async {
        await pumpScreen(tester, device, _worstCaseResult(), textScale: 1.3);
        expectNoOverflow(device, 'Result worst-case 1.3x');
        cleanUp(tester);
      });
    }
  });
}
