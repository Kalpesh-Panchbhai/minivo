---
description: Add a new mini game to Minivo — scaffolds all files, registers the game, and wires analytics/tutorials
---

# Add a New Game to Minivo

When the user requests a new game, follow these steps **in order**. Every game MUST follow the existing patterns exactly.

## Prerequisites — Read Before Starting

Before writing any code, read these reference files to understand the patterns:
- `lib/games/game_registry.dart` — registration pattern
- `lib/games/game_play_screen.dart` — how GameWrapper wraps every game
- `lib/games/game_wrapper.dart` — lifecycle (startGame, endGame, updateScore, setDifficultyAndMode)
- `lib/games/game_picker_scaffold.dart` — picker screen pattern
- `lib/games/shared/game_difficulty_picker.dart` — difficulty picker pattern (GameDifficultyData, GameSinglePickerBody)
- `lib/games/shared/generic_game_result_screen.dart` — game over screen pattern
- `lib/games/shared/game_hud_bar.dart` — in-game HUD pattern
- `lib/games/shared/game_control_buttons.dart` — GameBackButton, GameRestartButton
- `lib/core/models/game_info.dart` — GameInfo model and GameCategory enum
- `lib/core/widgets/how_to_play_sheet.dart` — tutorial system (GameHowToPlayStep)
- Use an existing game as a template (e.g. `lib/games/color_tap/` for arcade, `lib/games/number_merge/` for puzzle, `lib/games/tic_tac_toe/` for board)

## Step 1: Create Game Folder

Create `lib/games/<game_id>/` with these files:
- `<game_id>_screen.dart` — main screen (picker + game + game over)
- `<game_id>_logo.dart` — custom logo widget for home tiles
- `<game_id>_tutorial.dart` — animated tutorial steps (optional but recommended)

The `<game_id>` must be snake_case (e.g. `minesweeper`, `word_search`, `brick_breaker`).

## Step 2: Create the Screen File (`<game_id>_screen.dart`)

The screen file follows this structure (study existing games for exact patterns):

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../game_picker_scaffold.dart';
import '../shared/animated_background.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_continue_action.dart';
import '<game_id>_logo.dart';
import '<game_id>_tutorial.dart';
```

### Required Constants
```dart
const kMyGameId = '<game_id>';  // must match GameRegistry id
```

### Required Structure
The screen MUST be a `StatefulWidget` with these sections:

1. **Difficulty enum** (if applicable):
   ```dart
   enum _Difficulty { easy, medium, hard }
   extension _DifficultyX on _Difficulty {
     String get label => ['EASY', 'MEDIUM', 'HARD'][index];
     Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
     DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
     String get hint => ['...', '...', '...'][index];
     String get subKey => ['easy', 'medium', 'hard'][index];
   }
   ```

2. **State fields**:
   - `_Difficulty? _activeDifficulty;` — null = picker view, non-null = game view
   - `_Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];`
   - `bool _isFavorite = false;`
   - `int _score = 0;`
   - `int _bestScore = 0;`
   - `bool _isNewBestScore = false;`
   - `bool _gameOver = false;`

3. **initState** — load favorite:
   ```dart
   _isFavorite = ScoreService().isFavorite(kMyGameId);
   ```

4. **_toggleFavorite** — toggle and setState

5. **_showHelp** — show tutorial:
   ```dart
   void _showHelp() {
     final info = GameRegistry.getById(kMyGameId);
     if (info == null) return;
     showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
       accent: <accentColor>, steps: myGameSteps(), gameId: kMyGameId);
   }
   ```

6. **_startGame(_Difficulty diff)** — MUST call:
   ```dart
   GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label);
   GameWrapper.of(context).startGame();
   GameWrapper.of(context).updateScore(0);
   ```

7. **_newGame** / **_backToPicker** — restart / return to picker

8. **build** — returns `_activeDifficulty == null ? _buildPicker() : _buildGame()`

9. **_buildPicker** — uses `GamePickerScaffold` with:
   - Background gradient + AnimatedBackground
   - Icon ring with branded logo
   - Title + subtitle
   - `GameSinglePickerBody` for difficulty selection
   - `onHowToPlay: _showHelp`
   - `gameId: kMyGameId`

10. **_buildGame** — game view with:
    - Background gradient + AnimatedBackground
    - `GameHudBar` with back/score/restart buttons
    - Game board/canvas
    - If game over → `_buildGameOverScreen()`

11. **_buildGameOverScreen** — uses `GenericGameResultScreen` with:
    - `rewardedContinueAction` (if applicable)
    - Play Again, Change Mode, Home actions
    - Stats row
    - Calls `GameWrapper.of(context).endGame()` when game ends

### Score Handling
- Save scores: `ScoreService().saveScore(kMyGameId, score, subKey: diff.subKey)`
- Update wrapper: `GameWrapper.of(context).updateScore(score)`
- On game over: `GameWrapper.of(context).endGame()` (this triggers interstitial ad)

## Step 3: Create the Logo File (`<game_id>_logo.dart`)

```dart
Widget buildMyGameLogo(double size) {
  return SizedBox(
    width: size, height: size,
    child: CustomPaint(size: Size(size, size), painter: _MyGameLogoPainter()),
  );
}
```

The logo is a `CustomPainter` that fills the given square. It appears on home screen tiles. Study existing logos for style (gradient bg, themed icons, game name at bottom).

## Step 4: Create Tutorial File (`<game_id>_tutorial.dart`)

```dart
List<GameHowToPlayStep> myGameSteps() => [
  GameHowToPlayStep(
    text: 'Step 1 description',
    demo: AnimatedDemo(
      period: const Duration(seconds: 3),
      painter: (t) => _Step1Painter(t),
      canvasSize: const Size(180, 150),
    ),
  ),
  // ... more steps
];
```

Each step has text + an animated demo CustomPainter. 2-4 steps is ideal.

## Step 5: Register in GameRegistry

In `lib/games/game_registry.dart`:

1. **Add imports** at top:
   ```dart
   import '<game_id>/<game_id>_logo.dart';
   import '<game_id>/<game_id>_screen.dart';
   ```

2. **Add builder** to `_builders` map:
   ```dart
   '<game_id>': () => const MyGameScreen(),
   ```

3. **Add GameInfo** to `allGames` list:
   ```dart
   const GameInfo(
     id: '<game_id>',
     name: 'My Game',
     description: 'Short compelling description',
     howToPlay: 'Multi-line how-to-play text...',
     category: GameCategory.puzzle,  // action | puzzle | board | card | sports | arcade
     icon: Icons.some_icon_rounded,
     color: Color(0xFF...),          // primary accent color
     bgColor: Color(0xFF...),        // light pastel background
     playCount: 0,
     customLogo: buildMyGameLogo,
   ),
   ```

## Step 6: Verify

// turbo
1. Run `flutter analyze lib/` — must have zero errors
2. Confirm the game appears on the home screen
3. Confirm picker → game → game over → result screen flow works
4. Confirm tutorial shows on first visit
5. Confirm analytics fires (game_start, game_end with difficulty, score, duration)

## Checklist

- [ ] Folder `lib/games/<game_id>/` created
- [ ] `<game_id>_screen.dart` — picker + game + game over
- [ ] `<game_id>_logo.dart` — custom painted logo
- [ ] `<game_id>_tutorial.dart` — animated tutorial steps
- [ ] Registered in `GameRegistry._builders`
- [ ] `GameInfo` added to `GameRegistry.allGames`
- [ ] `GameWrapper` lifecycle wired (startGame, endGame, updateScore, setDifficultyAndMode)
- [ ] `ScoreService` wired (saveScore, getHighScore, isFavorite)
- [ ] Tutorial wired (showHowToPlaySheet with gameId)
- [ ] Analytics wired (difficulty passed to setDifficultyAndMode)
- [ ] No hardcoded strings — use AppStrings where applicable
- [ ] No hardcoded colors — use AppColors or game-specific constants
- [ ] `flutter analyze` passes with zero errors

## Key Rules

- Portrait orientation only
- Minimum tap target: 44x44
- Use rounded corners (14-16px), subtle shadows, pastel accents
- Swipe gestures (if any) must work on the FULL screen, not just the board
- Font: Poppins via Google Fonts (inherited from AppTheme)
- Keep it lightweight — no heavy assets, pure Flutter widgets or CustomPaint
- Game logic MUST be self-contained in the game folder
- Reuse shared widgets: GamePickerScaffold, GameHudBar, GameSinglePickerBody, GenericGameResultScreen, AnimatedBackground, RewardedContinueAction
