import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/core/services/level_progress_service.dart';
import '../../lib/core/services/score_service.dart';
import '../../lib/games/shared/spinning_slider.dart';

// ---------------------------------------------------------------------------
// Drivers for pushing a game to its DENSEST possible render so overflow /
// layout / sizing regressions surface on the smallest supported devices.
//
// Every game's start screen is a difficulty picker built on [SpinningSlider]
// (lib/games/shared/spinning_slider.dart). The slider snaps to the nearest
// stop on tap-down (`_snapTap` -> `onChanged(i)`), so tapping near a stop's
// x-position selects that difficulty. The level-based games (zip, water_sort,
// arrow_puzzle) additionally read LevelProgressService().getCurrentLevel,
// which we pre-seed via SharedPreferences before pump.
// ---------------------------------------------------------------------------

/// Every gameId in GameRegistry. Used to suppress the how-to-play tutorial
/// sheet (keyed `tutorial_seen_<id>`) for ALL games, so the picker is the
/// first interactive surface in every test.
const allGameIds = <String>[
  'arrow_puzzle',
  'checkers',
  'color_tap',
  'connect_four',
  'dino_run',
  'dodge_ball',
  'dots_and_boxes',
  'drop_merge',
  'flappy_tap',
  'go',
  'gomoku',
  'hangman',
  'mancala',
  'memory_match',
  'minesweeper',
  'number_merge',
  'number_sequence',
  'queens_puzzle',
  'reversi',
  'sliding_puzzle',
  'snake_classic',
  'solitaire',
  'sudoku',
  'tap_tap_dash',
  'tic_tac_toe',
  'water_sort',
  'whack_a_mole',
  'zip',
];

/// Primary "start playing" button label per game (the button that leaves the
/// picker and builds the live board). Two-player/AI games start via
/// "Play vs. AI"; single-player games use their named play button.
const gamePlayButton = <String, String>{
  'arrow_puzzle': 'Play Arrow Puzzle',
  'checkers': 'Play vs. AI',
  'color_tap': 'Play Color Tap',
  'connect_four': 'Play vs. AI',
  'dino_run': 'Play Dino Run',
  'dodge_ball': 'Play Dodge Ball',
  'dots_and_boxes': 'Play vs. AI',
  'drop_merge': 'Play Drop Merge',
  'flappy_tap': 'Play Flappy Tap',
  'go': 'Play vs. AI',
  'gomoku': 'Play vs. AI',
  'hangman': 'Play Hangman',
  'mancala': 'Play vs. AI',
  'memory_match': 'Play vs. AI',
  'minesweeper': 'Play Minesweeper',
  'number_merge': 'Play Classic',
  'number_sequence': 'Play Number Sequence',
  'queens_puzzle': 'Play Queens',
  'reversi': 'Play vs. AI',
  'sliding_puzzle': 'Play Sliding Puzzle',
  'snake_classic': 'Play Snake',
  'solitaire': 'Play Solitaire',
  'sudoku': 'Play Sudoku',
  'tap_tap_dash': 'Play Tap Tap Dash',
  'tic_tac_toe': 'Play vs. AI',
  'water_sort': 'Play Water Sort',
  'whack_a_mole': 'Play Whack-a-Mole',
  'zip': 'Play Zip',
};

/// LevelProgressService key for the "current level" of a (game, difficulty).
/// Mirrors LevelProgressService._key(gameId, difficulty, 'current').
String levelCurrentKey(String gameId, String subKey) =>
    'level_${gameId}_${subKey}_current';

/// Initialise mock prefs (all tutorials suppressed) + the singleton services.
/// Pass [extra] to pre-seed level progress, e.g.
/// `{levelCurrentKey('zip','hard'): 13}`.
Future<void> initGameTest({Map<String, Object> extra = const {}}) async {
  SharedPreferences.setMockInitialValues({
    for (final id in allGameIds) 'tutorial_seen_$id': true,
    ...extra,
  });
  await ScoreService().init();
  await LevelProgressService().init();
}

/// Tap the SpinningSlider at the x-position of stop [stopIndex] (0-based),
/// firing `onChanged(stopIndex)`. No-op if the picker isn't present (some
/// games may not show a slider). Returns true if a slider was found & tapped.
Future<bool> selectDifficultyStop(WidgetTester tester, int stopIndex) async {
  final slider = find.byType(SpinningSlider);
  if (!tester.any(slider)) return false;
  final box = tester.getRect(slider.first);
  // Stops are evenly spaced from knobR to width-knobR (knobSize default 36 ->
  // r = 18). Reproduce SpinningSlider._stops geometry to land dead-on a stop.
  const r = 18.0;
  // Read the actual stopCount off the widget so multi-stop (4-option AI)
  // pickers map correctly.
  final widget = tester.widget<SpinningSlider>(slider.first);
  final n = widget.stopCount;
  final span = box.width - 2 * r;
  final localX = n <= 1 ? box.width / 2 : r + span * stopIndex / (n - 1);
  await tester.tapAt(Offset(box.left + localX, box.center.dy));
  // Let the snap + AnimatedSwitcher label settle (but not the repeating
  // background animations).
  await tester.pump(const Duration(milliseconds: 350));
  return true;
}

/// Tap a play button by its exact label text. Pumps a bounded amount so the
/// fade-in animated GamePickerButton registers the tap and the game builds.
Future<void> tapPlay(WidgetTester tester, String playLabel) async {
  final play = find.text(playLabel);
  expect(play, findsWidgets,
      reason: 'play button "$playLabel" not found on picker');
  // Short devices render the picker in a SingleChildScrollView
  // (game_picker_scaffold tallThreshold = 800), so the play button can sit
  // below the fold. Scroll it into view before tapping; on tall devices
  // (no Scrollable) ensureVisible throws — harmless, ignore.
  try {
    await tester.ensureVisible(play.first);
    await tester.pump(const Duration(milliseconds: 100));
  } catch (_) {}
  await tester.tap(play.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Convenience: select [stopIndex] difficulty then tap [playLabel].
Future<void> selectAndPlay(
  WidgetTester tester,
  int stopIndex,
  String playLabel,
) async {
  await selectDifficultyStop(tester, stopIndex);
  await tapPlay(tester, playLabel);
}
