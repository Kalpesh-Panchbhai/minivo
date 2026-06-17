---
description: Add a new mini game to Minivo — scaffolds all files, registers the game, and wires analytics/tutorials
---

# Add a New Game to Minivo

When the user requests a new game, follow these steps **in order**. Every game MUST follow the existing patterns exactly.

## Speed-Run Checklist (TL;DR)

For experienced use — execute these in order, refer to sections below only when needed:

1. **Pick reference game** from decision tree below based on game type
2. **Read the reference game's screen file** end-to-end as your template
3. **Create folder** `lib/games/<game_id>/` with 4 files:
   - `<game_id>_screen.dart` — copy reference, replace game logic
   - `<game_id>_logo.dart` — CustomPaint logo
   - `<game_id>_tutorial.dart` — 2-4 animated steps
   - `<game_id>_stats.dart` — stats builder
4. **Register in `game_registry.dart`** — add imports, builder, GameInfo (at correct trending position)
5. **Register stats in `game_stats_bootstrap.dart`** — add import + call
6. **Update tests:**
   - `test/games/game_registry_test.dart` — add ID to expectedIds, bump count to N+1
   - `test/screens/games_overflow_test.dart` — add ID to _gameIds + _playButtonText
   - Create `test/games/<game_id>_test.dart` from template below
7. **Run:** `flutter analyze lib/` then `flutter test --reporter compact`
8. **Never commit** — user handles git

## Quick Reference — Game Type Decision Tree

Pick the reference game based on game type:

| Game Type | Reference Game | Key Service | Score Pattern | Example |
|-----------|---------------|-------------|---------------|---------|
| **Score-based action** | `snake_classic/` | `ScoreService` | High score per difficulty | Snake, Flappy Tap, Dino Run |
| **Score-based arcade** | `color_tap/` | `ScoreService` | High score per difficulty | Color Tap, Whack-a-Mole |
| **Score-based puzzle** | `number_merge/` | `ScoreService` | High score per difficulty | 2048, Drop Merge |
| **Level-based puzzle** | `water_sort/` | `LevelProgressService` | Level progress per difficulty | Water Sort |
| **Board game (AI + 2P)** | `checkers/` | `ScoreService` | Win streak per AI difficulty | Checkers, Reversi, Go |
| **Card game** | `solitaire/` | `ScoreService` | High score per difficulty | Solitaire |
| **Timed puzzle** | `sudoku/` | `ScoreService` | Best time per difficulty | Sudoku, Minesweeper |

## Naming Convention Cheat Sheet

For a game called "Brick Breaker" with ID `brick_breaker`:

| Item | Convention | Example |
|------|-----------|---------|
| Folder | `lib/games/<game_id>/` | `lib/games/brick_breaker/` |
| Screen class | `<PascalName>Screen` | `BrickBreakerScreen` |
| Game ID constant | `k<PascalName>GameId` | `kBrickBreakerGameId` |
| Logo builder | `build<PascalName>Logo` | `buildBrickBreakerLogo` |
| Stats register fn | `register<PascalName>Stats` | `registerBrickBreakerStats` |
| Tutorial steps fn | `<camelName>Steps()` | `brickBreakerSteps()` |
| Stats sub-keys | `k<Abbrev>SubKeyEasy` etc. | `kBBSubKeyEasy` |
| Test file | `test/games/<game_id>_test.dart` | `test/games/brick_breaker_test.dart` |

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
- `lib/core/models/best_stat.dart` — BestStat model for stats
- `lib/core/services/best_stats_registry.dart` — stats registry
- `lib/core/services/ads_service.dart` — AdsService (rewarded ads, interstitials)
- `lib/games/game_stats_bootstrap.dart` — where stats are registered
- Use an existing game as a template (e.g. `lib/games/color_tap/` for arcade, `lib/games/number_merge/` for puzzle, `lib/games/tic_tac_toe/` for board)

## Step 1: Create Game Folder

Create `lib/games/<game_id>/` with these files:
- `<game_id>_screen.dart` — main screen (picker + game + game over)
- `<game_id>_logo.dart` — custom logo widget for home tiles
- `<game_id>_tutorial.dart` — animated tutorial steps (optional but recommended)
- `<game_id>_stats.dart` — stats builder for leaderboard/profile screens

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

4. **_toggleFavorite** — call `ScoreService().toggleFavorite(kMyGameId)` and setState (fires `favorite_toggled` analytics automatically)

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
   GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
   GameWrapper.of(context).startGame();
   GameWrapper.of(context).updateScore(0);
   ```
   This fires `difficulty_selected` and `game_start` analytics events automatically.

7. **_newGame** / **_backOrHome** — restart / exit game:
   The back button during gameplay MUST always exit the game entirely (navigate out of GamePlayScreen). It must NOT go back to a difficulty picker.
   ```dart
   void _backOrHome() {
     final wrapper = GameWrapper.of(context);
     wrapper.handleExit(() {
       // stop any tickers/timers before navigating
       if (context.canPop()) context.pop(); else context.go('/home');
     });
   }
   ```
   `handleExit` bumps the interstitial ad counter and shows an interstitial if eligible (cooldown passed), then calls the navigate callback.
   
   The "Change Mode" / "Change Difficulty" action on the result screen should also use `_backOrHome`.

7b. **Rewarded continue** (for applicable games):
   ```dart
   void _continueGame() {
     GameWrapper.of(context).continueAfterGameOver();
     setState(() { _gameOver = false; /* restore game state */ });
   }
   ```

7c. **Rewarded undo** (for multiplayer board games with AI mode — e.g. tic_tac_toe, checkers, connect_four, reversi, go, gomoku):
   The undo feature lets the player undo their last move by watching a rewarded ad. It is available **once per round, only in AI mode**, and only if `AdsService().isRewardedReady` is true. The flow:
   1. After the human makes a move (before the AI responds), check if undo is available.
   2. If available, enter an "undo window" — set `_inUndoWindow = true` and pause the AI move.
   3. Show `RewardedUndoButton` in the UI (below the board, in a 44px-high `SizedBox`).
   4. If the player taps undo and watches the ad, restore the board to the saved snapshot and let the player move again.
   5. If the undo timer expires (`onExpired`), set `_inUndoWindow = false` and schedule the AI move.
   6. Block all cell taps while `_inUndoWindow` is true.
   
   Required state fields:
   ```dart
   bool _undoUsedThisRound = false;
   bool _inUndoWindow = false;
   List<int>? _boardBeforeHumanMove;  // snapshot of board before move
   // + any other state to restore (e.g. piece counts, score)
   ```
   
   Required methods:
   ```dart
   bool get _canUndo => _inUndoWindow && !_gameOver;

   void _saveStateForUndo() {
     if (_mode != _Mode.ai || _undoUsedThisRound || _currentPlayer != humanPlayer) return;
     _boardBeforeHumanMove = List.from(_board);
     // save any other state needed to restore
   }

   void _performUndo() {
     // restore board and state from snapshot
     setState(() { _inUndoWindow = false; _undoUsedThisRound = true; });
   }

   void _onUndoExpired() {
     if (!mounted || _gameOver || !_inUndoWindow) return;
     setState(() => _inUndoWindow = false);
     _scheduleAiMove();
   }
   ```
   
   In `_onCellTap`, block taps when `_inUndoWindow`.
   In the move handler, after the human moves, call `_saveStateForUndo()` before the move, then:
   ```dart
   if (!_undoUsedThisRound && AdsService().isRewardedReady) {
     setState(() { _currentPlayer = aiPlayer; _inUndoWindow = true; });
     return; // don't schedule AI yet
   }
   _switchTurn(); // normal flow
   ```
   
   In `_buildGame`, show the undo button:
   ```dart
   SizedBox(
     height: 44,
     child: _canUndo
         ? Center(child: RewardedUndoButton(
             key: ValueKey('undo_${_board.join()}'),
             onUndo: _performUndo,
             onExpired: _onUndoExpired,
             accentColor: _kPlayerColor,
           ))
         : const SizedBox.shrink(),
   ),
   ```
   
   Import: `import '../shared/rewarded_undo_button.dart';`
   
   Reset `_undoUsedThisRound`, `_inUndoWindow`, and `_boardBeforeHumanMove` in `_resetBoard()`.
   
   **Undo window player strip UX:** During the undo window, the turn indicator (PlayerStrip) MUST show the human player as active, NOT the AI. Apply these rules to `isActive`:
   ```dart
   // AI player strip — NOT active during undo window
   isActive: _currentPlayer == aiPlayer && !_inUndoWindow && !_gameOver,
   // Human player strip — IS active during undo window
   isActive: (_currentPlayer == humanPlayer || _inUndoWindow) && !_gameOver,
   ```
   
   Reference: `lib/games/tic_tac_toe/tic_tac_toe_screen.dart` and `lib/games/checkers/checkers_screen.dart`.

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

### Score Board Pill (Multiplayer Board Games)
For multiplayer board games (AI + 2P modes), the HUD center content MUST use a `_ScoreBoardPill` with a **difficulty/mode tab** above the score body. The rule:
- **AI mode** → tab shows the difficulty level (`EASY` / `MEDIUM` / `HARD`) with `AnimatedDifficultyIcon` and the difficulty color
- **Friend mode** → tab shows `PASS & PLAY` with a neutral color

This is **mandatory** for consistency. Never show a plain score pill without the tab on multiplayer games.

Reference implementations: `tic_tac_toe_screen.dart`, `checkers_screen.dart`, `connect_four_screen.dart`, `reversi_screen.dart`, `dots_and_boxes_screen.dart`, `go_screen.dart`, `gomoku_screen.dart`, `mancala_screen.dart`.

11. **_buildGameOverScreen** — uses `GenericGameResultScreen` with:
    - `gameId: kMyGameId` — **required** for `result_action` and share analytics
    - `score:` — pass current score
    - `showNewBestBadge:` — pass `_isNewBest` / `_wasNewBest` (see "New High Score" section)
    - `rewardedContinueAction` (if applicable)
    - Play Again, Change Mode, Home actions — **each with `actionId:`** for analytics
    - Stats row
    - Calls `GameWrapper.of(context).endGame(result: ...)` when game ends — pass `'win'`, `'loss'`, or `'draw'`

### Score Handling & High Score
- **Pass `subKey` to `setDifficultyAndMode`** — this is **mandatory** so the wrapper loads the correct high score for the active difficulty:
  ```dart
  // Board games (AI mode):
  _wrapper.setDifficultyAndMode(
    difficulty: _diffLabel(_difficulty),
    mode: mode == _Mode.ai ? 'ai' : '2_player',
    subKey: _aiSubKey(),  // returns null for 2P → wrapper uses bare key
  );
  // Single-player games:
  GameWrapper.of(context).setDifficultyAndMode(
    difficulty: diff.label,
    subKey: diff.subKey,
  );
  ```
- **Call `updateScore`** whenever the score changes so the wrapper tracks it for `endGame()`:
  - Single-player: `GameWrapper.of(context).updateScore(_score)` after each point change
  - Board games (AI win): `_wrapper.updateScore(_streak)` before `endGame()` fires
- Save scores: `ScoreService().saveScore(kMyGameId, score, subKey: diff.subKey)`
- On game over: `GameWrapper.of(context).endGame(result: 'win')` or `endGame(result: 'loss')` or `endGame(result: 'draw')` — this triggers interstitial ad + analytics with the correct game outcome
- Play sound on score: `AudioService().playScore()`
- Play sound on game over: handled automatically by `GameWrapper.endGame()`
- **Do NOT call** `ScoreService().incrementGamePlayCount()` directly — `GameWrapper.endGame()` already handles this centrally

Without `subKey` and `updateScore`, the high score will always show as 0 in the wrapper.

### Analytics Events (all centralized — no manual calls needed)
The following events are fired automatically by the architecture. New games get them for free as long as they use the standard patterns:

| Event | Fired by | Requirement |
|---|---|---|
| `game_open` | `GamePlayScreen.initState()` | Automatic |
| `difficulty_selected` | `GameWrapper.setDifficultyAndMode()` | Call `setDifficultyAndMode` with difficulty |
| `game_start` | `GameWrapper.startGame()` | Call `startGame()` |
| `game_end` | `GameWrapper.endGame()` | Call `endGame(result: 'win'/'loss'/'draw')` |
| `game_restart` | `GameWrapper.restartGame()` | Call `restartGame()` |
| `result_action` | `GenericGameResultScreen` | Pass `actionId` on every `GameResultAction` |
| `favorite_toggled` | `ScoreService.toggleFavorite()` | Wire up favorite button |
| `tutorial_started/completed` | `showHowToPlaySheet()` | Pass `gameId:` to `showHowToPlaySheet()` |
| `ad_shown/completed/skipped/failed` | `AdsService` | Automatic via `endGame()` |

**Result values for `endGame(result:)`:**
- Single-player (dies): `'loss'` (default)
- Single-player (completes/solves): `'win'`
- Board game AI mode: `'win'` if human wins, `'loss'` if AI wins, `'draw'` if draw
- Board game Pass & Play: `'win'` (someone always wins)
- Timer-based games (ends on timer): `'loss'` (default)

### "New High Score" / "New Best" Badge
Every game MUST show a **"New High Score"** or **"New Best"** indicator on the result screen when the player beats their previous best — but **only in AI mode (board games) or single-player mode**. Never in Pass & Play / friend mode.

**Single-player games:**
- Track `_isNewBest` (or `_isNewBestScore`) — set to `true` when `_score > _bestScore`
- Pass `showNewBestBadge: _isNewBest` to `GenericGameResultScreen`
- Show a `StatItem(label: 'BEST', value: _bestScore)` in the result stats row

**Board games (AI mode):**
- Track `_wasNewBest` — set via `ScoreService().saveScore(...).then((isNew) { if (isNew) _wasNewBest = true; })`
- Only set `_wasNewBest = true` when `isAi && winner == humanPlayer` (never in 2P mode)
- Reset `_wasNewBest = false` in `_initBoard()` / `_resetBoard()` and on AI win / draw
- Display via either:
  - `showNewBestBadge: _wasNewBest` on `GenericGameResultScreen`, OR
  - Custom `_NewBestBadge` / `_NewBestChip` widget in `extraBadges` list
- Gate the display: `_wasNewBest && isAi` (optionally `&& playerWins`)

**Hangman (single-player streak game):**
- Same as board games: `showNewBestBadge: _wasNewBest`, set only on win

### "BEST" Stat in Result Screen
Every board game and multiplayer game with AI mode MUST show a **BEST** stat in the result screen (AI mode only). This tells the player their best win streak or score at the current difficulty.

**Games using `GameResultStatsRow` (tic_tac_toe, checkers, connect_four, reversi, go, gomoku, hangman):**
```dart
statsWidget: game_result.GameResultStatsRow(
  stats: [
    game_result.StatItem(label: isAi ? 'YOU' : 'P1', value: _p1Wins, color: _kP1Color),
    game_result.StatItem(label: 'DRAWS', value: _draws, color: const Color(0xFF8B7BA7)),
    game_result.StatItem(label: isAi ? 'AI' : 'P2', value: _p2Wins, color: _kP2Color),
    if (isAi)
      game_result.StatItem(
        label: 'BEST',
        value: ScoreService().getHighScore(kMyGameId, subKey: _aiSubKey()),
        color: const Color(0xFF6C63FF),
      ),
  ],
),
```

**Games using `GameResultPlayersRow` (mancala, dots_and_boxes, memory_match):**
```dart
statsWidget: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    game_result.GameResultPlayersRow(...),
    if (isAi) ...[
      const SizedBox(height: 12),
      game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(
            label: 'BEST',
            value: ScoreService().getHighScore(kMyGameId, subKey: _aiSubKey()),
            color: const Color(0xFF6C63FF),
          ),
        ],
      ),
    ],
  ],
),
```

### "best X" in HUD Score Pill
Board games and multiplayer AI games MUST show a small `best X` label inside the HUD score pill (below the VS row) when in AI mode and the player has a previous high score.

```dart
Widget _bestLabel(_Difficulty d) {
  final subKey = switch (d) {
    _Difficulty.easy => kMyGameSubKeyEasy,
    _Difficulty.medium => kMyGameSubKeyMedium,
    _Difficulty.hard => kMyGameSubKeyHard,
  };
  final best = ScoreService().getHighScore(kMyGameId, subKey: subKey);
  if (best <= 0) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text('best $best',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 10,
            fontWeight: FontWeight.w600)),
  );
}
```
Wrap the existing `Row(children: [_scoreCol(...), VS, _scoreCol(...)])` inside a `Column` and add `if (isAi) _bestLabel(difficulty)` below.

### Auto-Pause (Real-Time Games Only)
For games with timers/animation controllers (snake, dino, etc.), add `WidgetsBindingObserver`:
```dart
class _MyGameScreenState extends State<MyGameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _activeDifficulty != null && !_gameOver) {
      // Pause animation controller or timer
    }
  }
}
```
This is NOT needed for turn-based games (sudoku, tic-tac-toe, memory match, etc.).

### Level-Based Games (Water Sort pattern)

Level-based games differ from score-based games in these ways:

1. **Use `LevelProgressService`** instead of (or alongside) `ScoreService` for level tracking:
   ```dart
   import '../../core/services/level_progress_service.dart';
   ```

2. **Level state fields** (replace score fields):
   ```dart
   int _currentLevel = 1;
   int _totalLevels = 1000; // per difficulty
   bool _levelComplete = false;
   ```

3. **Level progression**: On level complete, increment level and show `LevelCompleteOverlay`:
   ```dart
   void _onLevelComplete() {
     LevelProgressService().saveLevel(kMyGameId, _difficulty.subKey, _currentLevel);
     setState(() => _levelComplete = true);
   }
   ```

4. **HUD shows level instead of score**: `GameHudBar` center shows `Level $_currentLevel` or progress bar

5. **Result screen**: Shows levels completed, not score. Use `game_result.GenericGameResultScreen` with level-specific stats.

6. **Rewarded continue**: Typically "extra space" or "undo last move" rather than "continue from score"

Reference: Study `lib/games/water_sort/water_sort_screen.dart` for the full pattern.

### AnimatedDifficultyIcon in Picker

Every picker screen should use `AnimatedDifficultyIcon` as the mascot/icon ring. It animates on difficulty change:

```dart
AnimatedDifficultyIcon(
  difficulty: _pickerDifficulty.kind,
  child: build<PascalName>Logo(80),
)
```

Import: `import '../shared/animated_difficulty_icon.dart';`

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

## Step 5: Create Stats File (`<game_id>_stats.dart`)

Every game needs a stats file for the leaderboard/profile screen:

```dart
import 'package:flutter/material.dart';
import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';

const String kMyGameId = '<game_id>';

void registerMyGameStats() {
  BestStatsRegistry.register(kMyGameId, _buildStats);
}

List<BestStat> _buildStats() {
  final easy   = ScoreService().getHighScore(kMyGameId, subKey: 'easy');
  final medium = ScoreService().getHighScore(kMyGameId, subKey: 'medium');
  final hard   = ScoreService().getHighScore(kMyGameId, subKey: 'hard');

  if (easy == 0 && medium == 0 && hard == 0) return const [];

  return [
    if (easy   > 0) BestStat(label: '🌱  EASY',   value: '$easy',   sublabel: '...', icon: Icons.emoji_events_rounded, color: Color(0xFF22C55E)),
    if (medium > 0) BestStat(label: '🔥  MEDIUM', value: '$medium', sublabel: '...', icon: Icons.emoji_events_rounded, color: Color(0xFFF59E0B)),
    if (hard   > 0) BestStat(label: '💀  HARD',   value: '$hard',   sublabel: '...', icon: Icons.emoji_events_rounded, color: Color(0xFFEF4444)),
  ];
}
```

The sublabel should describe the scoring metric (e.g. '10 pts/apple', 'time-based').

## Step 6: Register in GameRegistry

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

3. **Add GameInfo** to `allGames` list.
   
   **Ordering:** The `allGames` list is ordered by global trending popularity (descending). Insert the new game at the appropriate position based on how popular the game genre is globally. The `playCount` values serve as a static popularity seed for the home screen ranking algorithm — they are NOT real play counts.
   
   **Current `playCount` range:** 52000 (Solitaire, #1) → 1000 (Gomoku, #25). Space new games proportionally.
   
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
     playCount: <number>,            // see ordering note above
     customLogo: buildMyGameLogo,
   ),
   ```
   
   **Optional fields:**
   - `isFeatured: true` — set for top ~7 most popular games (appears in featured carousel on home screen)
   - `hidden: true` — set for WIP games that are not ready for release; hidden from home, search, leaderboard, and trending but code remains intact. Remove when ready to release.
   - `iconAsset: 'assets/images/<game_id>_logo.png'` — use for PNG/JPG logos instead of `customLogo`

## Step 7: Register Stats

In `lib/games/game_stats_bootstrap.dart`:

1. **Add import** at top:
   ```dart
   import '<game_id>/<game_id>_stats.dart';
   ```

2. **Add call** inside `registerAllGameStats()`:
   ```dart
   registerMyGameStats();
   ```

## Step 8: Verify

// turbo
1. Run `flutter analyze lib/` — must have zero errors
2. Confirm the game appears on the home screen
3. Confirm picker → game → game over → result screen flow works
4. Confirm tutorial shows on first visit
5. Verify all analytics events fire correctly:
   - `game_open` — automatic when game screen opens
   - `difficulty_selected` — when calling `setDifficultyAndMode(difficulty:, subKey:)`
   - `game_start` — when calling `startGame()`
   - `game_end` — when calling `endGame(result: 'win'/'loss'/'draw')` with correct result
   - `game_restart` — when calling `restartGame()` or `continueAfterGameOver()`
   - `result_action` — every `GameResultAction` must have `actionId:` (`'play_again'`, `'change_mode'`, `'home'`)
   - `favorite_toggled` — favorite button calls `ScoreService().toggleFavorite()`
   - `tutorial_started/completed` — `showHowToPlaySheet()` passes `gameId:`
   - Ad events — automatic via `endGame()` interstitial + rewarded continue/undo

## Step 9: Add Test Coverage

Every new game MUST be wired into **three** test files. Forgetting any of them means regressions go undetected.

### 9a. Update `test/games/game_registry_test.dart`

1. Add `'<game_id>'` to the `expectedIds` list (keep alphabetical order).
2. Bump the count in `allGames count matches builder count` from N to N+1.

**Note:** Tests for `trending` and `search` use `GameRegistry.visibleGames.length` (excludes hidden games). Tests for `allGames` count use `GameRegistry.allGames.length` (includes hidden). If the new game is `hidden: true`, only the `allGames` count changes.

### 9b. Update `test/screens/games_overflow_test.dart`

This file tests every game's ready and playing states across **14 device sizes** (iPhone SE through iPad Pro 12.9"). Two changes are needed:

1. Add `'<game_id>'` to the `_gameIds` list (keep alphabetical order).
2. Add a case to the `_playButtonText` switch expression:
   ```dart
   '<game_id>' => 'Play <Game Name>',
   ```
   For **multiplayer** games that use `Play vs. AI` / `Play with a Friend` instead of a single Play button, use the fallthrough default `'Tap to Start'` — the test handles "button not found" gracefully.

### 9c. Create `test/games/<game_id>_test.dart`

Create the per-game test file. Use the appropriate template below depending on whether the game is **single-player** or **multiplayer (AI + 2P)**.

### Single-Player Game Template (e.g. dino_run, flappy_tap, color_tap)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/games/game_registry.dart';
import '../../lib/games/game_wrapper.dart';
import '../helpers/screen_sizes.dart';
import '../helpers/test_helpers.dart';

const _device = TestDevice(
  name: 'Pixel 6',
  width: 412,
  height: 915,
  pixelRatio: 2.625,
  platform: TargetPlatform.android,
);

Widget _build() => GameWrapper(
      gameId: '<game_id>',
      child: GameRegistry.buildGame('<game_id>'),
    );

void main() {
  group('<Game Name>', () {
    setUp(() async => initTestDependencies());

    // 1. Registry metadata
    testWidgets('registry metadata is correct', (_) async {
      final game = GameRegistry.getById('<game_id>')!;
      expect(game.id, '<game_id>');
      expect(game.name.isNotEmpty, isTrue);
      expect(game.howToPlay.isNotEmpty, isTrue);
      expect(game.category, isNotNull);
    });

    // 2. Ready state — title visible
    testWidgets('ready state shows game title', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('<Game Name>'), findsWidgets);
      cleanUp(tester);
    });

    // 3. Ready state — Play button visible
    testWidgets('ready state shows Play button', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('Play <Game Name>'), findsOneWidget);
      expectNoOverflow(_device, '<Game Name> ready');
      cleanUp(tester);
    });

    // 4. Difficulty picker default
    testWidgets('difficulty picker shows default MEDIUM label', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('MEDIUM'), findsOneWidget);
      cleanUp(tester);
    });

    // 5. Play transition
    testWidgets('tapping Play starts game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play <Game Name>'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play <Game Name>'), findsNothing);
      expectNoOverflow(_device, '<Game Name> playing');
      cleanUp(tester);
    });

    // 6. HUD elements — adapt labels to game (SCORE/BEST, TIME/BEST, TURNS/BEST, etc.)
    testWidgets('playing state shows SCORE and BEST HUD', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play <Game Name>'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('BEST'), findsOneWidget);
      cleanUp(tester);
    });

    // 7. Pause and resume
    testWidgets('pause and resume works', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play <Game Name>'));
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
      state.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    // 8. Pause overlay icons
    testWidgets('pause overlay shows correct icons', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play <Game Name>'));
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
      state.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
      expect(find.byIcon(Icons.refresh_rounded), findsWidgets);
      expect(find.byIcon(Icons.home_rounded), findsWidgets);
      await tester.pump(const Duration(seconds: 5));
      cleanUp(tester);
    });

    // 9+ Add game-specific tests here (e.g. LIVES label, SKIP button, TIME HUD, grid rendering)

  });
}
```

### Multiplayer Game Template (e.g. connect_four, reversi, dots_and_boxes, memory_match)

Use the single-player template above as a base, but replace tests 3/5/6/7/8 with the following expanded set:

```dart
    // 3. Ready state — mode picker
    testWidgets('ready state shows mode picker', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      expect(find.text('<Game Name>'), findsWidgets);
      expect(find.text('Play vs. AI'), findsOneWidget);
      expect(find.text('Play with a Friend'), findsOneWidget);
      expectNoOverflow(_device, '<Game Name> ready');
      cleanUp(tester);
    });

    // 5a. Play AI transition
    testWidgets('tapping Play vs. AI starts game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play vs. AI'), findsNothing);
      expect(find.text('Play with a Friend'), findsNothing);
      expectNoOverflow(_device, '<Game Name> AI playing');
      cleanUp(tester);
    });

    // 5b. Play 2P transition
    testWidgets('tapping Play with a Friend starts 2P game', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Play vs. AI'), findsNothing);
      expect(find.text('Play with a Friend'), findsNothing);
      expectNoOverflow(_device, '<Game Name> 2P playing');
      cleanUp(tester);
    });

    // 6a. AI mode player strips
    testWidgets('AI mode shows player strips', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('You'), findsOneWidget);
      expect(find.text('AI'), findsWidgets);
      expectNoOverflow(_device, '<Game Name> AI strips');
      cleanUp(tester);
    });

    // 6b. 2P mode player strips
    testWidgets('2P mode shows P1 and P2 strips', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('P1'), findsWidgets);
      expect(find.text('P2'), findsWidgets);
      expectNoOverflow(_device, '<Game Name> 2P strips');
      cleanUp(tester);
    });

    // 7a. Pause/resume in AI mode
    testWidgets('pause and resume works in AI mode', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
      state.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.text('Quit'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsNothing);
      cleanUp(tester);
    });

    // 7b. Pause/resume in 2P mode
    testWidgets('pause and resume works in 2P mode', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      final state = tester.state<GameWrapperState>(find.byType(GameWrapper));
      state.pauseGame();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Paused'), findsNothing);
      cleanUp(tester);
    });

    // 8. Board rendering
    testWidgets('board renders without overflow in AI mode', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play vs. AI'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GestureDetector), findsWidgets);
      expectNoOverflow(_device, '<Game Name> board AI');
      cleanUp(tester);
    });

    testWidgets('board renders without overflow in 2P mode', (tester) async {
      await pumpScreen(tester, _device, _build(), settle: false);
      await tester.tap(find.text('Play with a Friend'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(GestureDetector), findsWidgets);
      expectNoOverflow(_device, '<Game Name> board 2P');
      cleanUp(tester);
    });
```

### Required Test Categories (minimum)

Every game test file MUST cover at least these categories:

| # | Category | Description |
|---|----------|-------------|
| 1 | **Registry metadata** | Game ID, name, howToPlay, category are populated |
| 2 | **Ready state title** | Game title is visible in picker screen |
| 3 | **Ready state play button** | Play button (or mode picker for multiplayer) is visible |
| 4 | **Difficulty picker** | Default MEDIUM label shown |
| 5 | **Play transition** | Tapping Play hides picker, no overflow |
| 6 | **HUD elements** | Game-specific HUD labels visible (SCORE/BEST, TIME/BEST, TURNS/BEST, LIVES, etc.) |
| 7 | **Pause/resume** | Pause shows overlay with Paused/Resume/Restart/Quit, resume dismisses it |
| 8 | **Pause icons** | Play/refresh/home icons present in pause overlay |

For **multiplayer games**, tests 3/5/6/7/8 must cover **both AI and 2P modes** separately.

### Important Test Rules

- Use `settle: false` in `pumpScreen` — games use animation controllers that never settle
- Add `await tester.pump(const Duration(seconds: 5))` before `cleanUp(tester)` if the game uses timers (flutter_animate, card flip timers, AI turn timers)
- For games using `compute()` isolates (e.g. Sudoku), use `tester.runAsync()` to allow the isolate to complete
- Use `findsWidgets` instead of `findsOneWidget` for labels that appear in multiple UI elements (e.g. 'AI', 'P1', 'P2', game title, icons)
- Always call `cleanUp(tester)` at end of each testWidgets
- NEVER weaken tests to fix failures — always fix the game code instead

### Run Tests

// turbo
After creating/updating all three test files, run them in this order:

1. Per-game test:
```bash
flutter test test/games/<game_id>_test.dart --reporter compact
```

2. Registry test (validates game count and IDs):
```bash
flutter test test/games/game_registry_test.dart --reporter compact
```

3. Multi-device overflow test (validates ready + playing state on 14 devices):
```bash
flutter test test/screens/games_overflow_test.dart --reporter compact
```

4. Full test suite (ensures nothing else broke):
```bash
flutter test --reporter compact
```

All tests MUST pass at every step. If any fail, fix the game code (not the tests) until they pass.

## Checklist

- [ ] Folder `lib/games/<game_id>/` created
- [ ] `<game_id>_screen.dart` — picker + game + game over
- [ ] `<game_id>_logo.dart` — custom painted logo
- [ ] `<game_id>_tutorial.dart` — animated tutorial steps
- [ ] `<game_id>_stats.dart` — stats builder for leaderboard/profile
- [ ] Registered in `GameRegistry._builders`
- [ ] `GameInfo` added to `GameRegistry.allGames` at correct trending position with appropriate `playCount`
- [ ] Stats registered in `game_stats_bootstrap.dart`
- [ ] `GameWrapper` lifecycle wired (startGame, endGame, updateScore, setDifficultyAndMode)
- [ ] Back button (`_backOrHome`) exits game entirely via `handleExit` — does NOT go to picker
- [ ] `GameWrapper.continueAfterGameOver()` wired if rewarded continue used
- [ ] Rewarded undo wired (multiplayer board games with AI mode only — see step 7c)
- [ ] Undo window PlayerStrip UX: human `isActive` during undo window, AI NOT active
- [ ] `ScoreService` wired (saveScore, getHighScore, isFavorite)
- [ ] `AudioService().playScore()` on point gain
- [ ] Tutorial wired (showHowToPlaySheet with gameId)
- [ ] `endGame(result:)` passes correct result — `'win'`/`'loss'`/`'draw'` (not bare `endGame()`)
- [ ] Every `GameResultAction` has an `actionId:` (e.g. `'play_again'`, `'change_mode'`, `'home'`)
- [ ] `GenericGameResultScreen` passes `gameId:` and `score:` for share/analytics
- [ ] `showNewBestBadge:` wired correctly (AI/single-player mode only)
- [ ] BEST stat shown in result screen (AI mode for board games, always for hangman)
- [ ] `best X` label shown in HUD score pill (AI mode, board/multiplayer games)
- [ ] Analytics wired (difficulty passed to setDifficultyAndMode)
- [ ] WidgetsBindingObserver added (real-time games only)
- [ ] No hardcoded strings — use AppStrings where applicable
- [ ] No hardcoded colors — use AppColors or game-specific constants
- [ ] `flutter analyze` passes with zero errors
- [ ] `test/games/game_registry_test.dart` updated — add `<game_id>` to `expectedIds` and bump count
- [ ] `test/screens/games_overflow_test.dart` updated — add `<game_id>` to `_gameIds` and `_playButtonText`
- [ ] `test/games/<game_id>_test.dart` created with all required test cases (registry, title, play, difficulty, HUD, pause/resume, pause icons)
- [ ] All tests pass: `flutter test --reporter compact` (full suite, not just game tests)

## Important

- **NEVER commit or push** as part of this workflow. The user will handle git operations separately.

## Key Rules

- Portrait orientation only
- Minimum tap target: 44x44
- Use rounded corners (14-16px), subtle shadows, pastel accents
- Swipe gestures (if any) must work on the FULL screen, not just the board
- Font: Poppins via Google Fonts (inherited from AppTheme)
- Keep it lightweight — no heavy assets, pure Flutter widgets or CustomPaint
- Game logic MUST be self-contained in the game folder
- Reuse shared widgets: GamePickerScaffold, GameHudBar, GameSinglePickerBody, GenericGameResultScreen, AnimatedBackground, RewardedContinueAction

## Current Game Roster (ordered by trending popularity)

For reference, the current `allGames` order and `playCount` values:

| # | Game | ID | Category | playCount |
|---|------|----|----------|-----------|
| 1 | Solitaire | `solitaire` | card | 52000 |
| 2 | 2048 Merge | `number_merge` | puzzle | 48000 |
| 3 | Water Sort | `water_sort` | puzzle | 45000 |
| 4 | Sudoku | `sudoku` | puzzle | 42000 |
| 5 | Snake Classic | `snake_classic` | action | 38000 |
| 6 | Minesweeper | `minesweeper` | puzzle | 35000 |
| 7 | Flappy Tap | `flappy_tap` | action | 32000 |
| 8 | Dino Run | `dino_run` | action | 28000 |
| 9 | Checkers | `checkers` | board | 25000 |
| 10 | Tic Tac Toe | `tic_tac_toe` | board | 22000 |
| 11 | Memory Match | `memory_match` | puzzle | 19000 |
| 12 | Connect Four | `connect_four` | board | 17000 |
| 13 | Hangman | `hangman` | puzzle | 15000 |
| 14 | Sliding Puzzle | `sliding_puzzle` | puzzle | 13000 |
| 15 | Whack-a-Mole | `whack_a_mole` | arcade | 11000 |
| 16 | Color Tap | `color_tap` | arcade | 9500 |
| 17 | Reversi | `reversi` | board | 8000 |
| 18 | Drop Merge | `drop_merge` | puzzle | 7000 |
| 19 | Dots & Boxes | `dots_and_boxes` | board | 5500 |
| 20 | Dodge Ball | `dodge_ball` | action | 4000 |
| 21 | Tap Tap Dash | `tap_tap_dash` | action | 3200 |
| 22 | Number Sequence | `number_sequence` | puzzle | 2500 |
| 23 | Go | `go` | board | 2000 |
| 24 | Mancala | `mancala` | board | 1500 |
| 25 | Gomoku | `gomoku` | board | 1000 |
| 26 | Arrow Puzzle | `arrow_puzzle` | puzzle | 800 |

When adding a new game, estimate its global popularity relative to this list and insert at the appropriate position with a `playCount` between its neighbors.
