---
name: add-game
description: Add a new mini game to Minivo — scaffolds all files, registers the game, and wires analytics/tutorials
---

# Add a New Game to Minivo

When the user requests a new game, follow these steps **in order**. Every game MUST follow the existing patterns exactly.

## The Production Bar (read first — this is the quality target)

You are shipping a game to a published app that already has 27 polished games.
"Done" means ALL of the following, with NO human follow-up:

- **Looks/feels like the other 27.** Reuse the shared scaffolds (`GamePickerScaffold`,
  `GameDifficultyCard`/`SpinningSlider`, `GameHudBar`, `GenericGameResultScreen`,
  `LevelCompleteOverlay`, `AnimatedBackground`) and the shared logo
  (`buildGlassSpotlightLogo`). Never invent parallel UI — match existing games.
- **Best-in-class UX.** Difficulty picker → game → result loop; a short animated
  tutorial; haptic feedback (`AudioService`, no audio); a personal best; smooth animations; an empty/
  win/lose state. The first frame must look intentional.
- **You decide the scoring model yourself** from the game's nature using the
  decision tree below (high-score per difficulty / best-time / win-streak /
  level-progress). Wire it through `ScoreService` or `LevelProgressService` and the
  result screen + leaderboard/profile stats — don't ask the user which to use.
- **Level games are bullet-proof:** 10,000 unique levels × 3 difficulties, every
  one **strictly solvable (exactly one solution)** and **unique within its
  difficulty**, generated offline and replayed on device with NO runtime solver.
  See "Level-Based Games — full architecture". This is non-negotiable.
- **Cannot break in production on any device.** No overflow, no jank, on all 14
  supported sizes (iPhone SE 320px → iPad Pro 12.9"), portrait, iOS + Android, at
  up to 1.3× system font. The overflow/responsive/perf test fleet (Step 9d) MUST
  include the new game and pass.
- **Fully integrated:** registered in `game_registry.dart` + `game_stats_bootstrap.dart`,
  full test suite green (`flutter analyze` clean, `flutter test` all pass).

If a test reveals a layout/logic problem, FIX THE GAME CODE and re-run — never
weaken a test. Never commit; the user handles git.

## Speed-Run Checklist (TL;DR)

For experienced use — execute these in order, refer to sections below only when needed:

1. **Pick reference game** from decision tree below based on game type (and the
   scoring model that fits — high-score / best-time / win-streak / level-progress)
2. **Read the reference game's screen file** end-to-end as your template
3. **Create folder** `lib/games/<game_id>/` with the 4 core files:
   - `<game_id>_screen.dart` — copy reference, replace game logic
   - `<game_id>_logo.dart` — uses shared `buildGlassSpotlightLogo` (Step 3)
   - `<game_id>_tutorial.dart` — 2-4 animated steps
   - `<game_id>_stats.dart` — stats builder
   - **Level games add 3 more:** `<game_id>_level_gen.dart`, the GENERATED
     `<game_id>_seeds.g.dart`, and `test/solvability/generate_<game_id>_seeds.dart`
     — then run `dart run test/solvability/generate_<game_id>_seeds.dart` to bake
     30k verified levels (see "Level-Based Games — full architecture")
4. **Register in `game_registry.dart`** — add imports, builder, GameInfo (at correct trending position)
5. **Register stats in `game_stats_bootstrap.dart`** — add import + call
6. **Update tests:**
   - `test/games/game_registry_test.dart` — add ID to expectedIds, bump count to N+1
   - `test/screens/games_overflow_test.dart` — add ID to _gameIds + REAL _playButtonText
   - Create `test/games/<game_id>_test.dart` from template below
   - Wire into the responsive/overflow/text-scale/perf fleet (Step 9d)
   - Create `test/games/<game_id>_devicematrix_test.dart` (Step 9e) — every element of every screen state on all 14 devices (iOS + Android), normal + 1.3× text
   - Level games: create `test/games/<game_id>_solvability_test.dart` (10k×3 strict + unique)
7. **Run:** `flutter analyze lib/` then `flutter test` — all must pass
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
- `lib/games/shared/game_logo_scaffold.dart` — the shared "Glass Spotlight" logo every tile uses (Step 3)
- `lib/core/services/level_progress_service.dart` + `lib/games/shared/level_complete_overlay.dart` — LEVEL games
- `lib/games/zip/zip_level_gen.dart` + `lib/games/zip/zip_seeds.g.dart` + `test/solvability/generate_zip_seeds.dart` + `test/games/zip_solvability_test.dart` — the canonical LEVEL-game pipeline (study end-to-end before building one)
- `test/helpers/game_drivers.dart` + `test/helpers/screen_sizes.dart` — the device/overflow test fleet helpers (Step 9d)
- Use an existing game as a template (e.g. `lib/games/color_tap/` for arcade, `lib/games/number_merge/` for puzzle, `lib/games/tic_tac_toe/` for board, `lib/games/zip/` for a level puzzle)

## Step 1: Create Game Folder

Create `lib/games/<game_id>/` with these files:
- `<game_id>_screen.dart` — main screen (picker + game + game over)
- `<game_id>_logo.dart` — logo widget for home tiles (shared scaffold, Step 3)
- `<game_id>_tutorial.dart` — animated tutorial steps (optional but recommended)
- `<game_id>_stats.dart` — stats builder for leaderboard/profile screens

**LEVEL-based games additionally create** (see "Level-Based Games — full architecture"):
- `<game_id>_level_gen.dart` — deterministic engine + solver
- `<game_id>_seeds.g.dart` — GENERATED salt table (do not hand-edit)
- `test/solvability/generate_<game_id>_seeds.dart` — offline 30k-level generator
- `test/games/<game_id>_solvability_test.dart` — verifies strict solvability + uniqueness

The `<game_id>` must be snake_case (e.g. `minesweeper`, `word_search`, `brick_breaker`).

## Step 2: Create the Screen File (`<game_id>_screen.dart`)

The screen file follows this structure (study existing games for exact patterns):

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart'; // haptic feedback (no audio)
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
- **NO audio or music, but YES haptic feedback.** The app plays no sound/music and ships no audio assets — never add an `audioplayers`-style package or play a sound file. It DOES use tactile (vibration) feedback via `AudioService` (named "Audio" for historical reasons; it is purely `HapticFeedback`). Wire haptics on the meaningful events:
  - `AudioService().playTap()` — the primary user action (tap / move / place / flip), when that action doesn't already trigger another haptic.
  - `AudioService().playScore()` — on scoring / progress (point, merge, match, capture).
  - `AudioService().playSuccess()` — on win / solve / level-complete.
  - LOSS / game-over is fired centrally by `GameWrapper.endGame()` — do NOT add a per-game game-over haptic (double-fire).
  - Do NOT fire a haptic every frame/tick in real-time loops (snake step, dino frame) — only on discrete events. Match the haptic density of existing games.
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

### Level-Based Games — full architecture (zip / water_sort / arrow_puzzle pattern)

A level-based game is a PUZZLE with a guaranteed-solvable, hand-quality
progression: **10,000 distinct levels per difficulty × 3 difficulties = 30,000
puzzles**, every one verified offline to be **strictly solvable** and **unique
across its difficulty**, then replayed byte-for-byte on device with **no solver
running at runtime**. Levels past 10,000 wrap (level 10001 == level 1) while the
displayed counter keeps climbing. This is mandatory — never ship a level game
that generates puzzles live on device or that can produce an unsolvable level.

Study all three reference implementations end-to-end before writing anything:
- `lib/games/zip/` (Hamiltonian-path puzzle — clean reference)
- `lib/games/water_sort/` (state-space puzzle)
- `lib/games/arrow_puzzle/` (geometric puzzle)
and their tests `test/games/<game>_solvability_test.dart` + generators
`test/solvability/generate_<game>_seeds.dart`.

**A level game adds three files to `lib/games/<game_id>/` beyond the usual four:**

1. **`<game_id>_level_gen.dart`** — the pure, deterministic engine. It MUST expose:
   - `<Game>LevelResult` — an immutable value holding the puzzle (grid dims,
     layout, the stored canonical solution, any walls/constraints).
   - `generate<Game>LevelWithSalt(int level, int diffIndex, int salt)` — builds a
     candidate puzzle purely from `(level, diffIndex, salt)` using a **seeded**
     `math.Random(...)` ONLY (never `Random()` without a seed, never
     `DateTime.now()`/wall-clock — generation must be 100% reproducible).
   - `count<Game>Solutions(result, {int cap = 2})` — the SOLVER. Counts distinct
     valid solutions, short-circuiting at `cap`. "Strictly solvable" ==
     `count...Solutions(r, cap: 2) == 1` (exactly one solution). Used offline and
     in tests only.
   - `generate<Game>Level(int level, int diffIndex)` — the **on-device** entry
     point. Computes `eff = (level - 1) % <game>LevelsPerDifficulty + 1`, looks up
     the baked salt via `<game>SaltFor(eff, diffIndex)`, and rebuilds with that
     salt. **No solver call here.** The result is identical to the offline-verified
     puzzle.
   - A difficulty curve: a function mapping `(level, diffIndex)` to the puzzle
     SIZE/complexity (grid size, element count, constraint count). Make it ramp
     smoothly and cap (e.g. zip grid 5→9, water_sort 4→14 colours). Harder
     difficulty = larger caps.

2. **`<game_id>_seeds.g.dart`** — GENERATED, do not hand-edit. Contains
   `const int <game>LevelsPerDifficulty = 10000;`, a base64-packed `Uint16` salt
   table (3 × 10000), and `<game>SaltFor(level, diffIndex)`. Produced by the
   generator below.

3. **`test/solvability/generate_<game>_seeds.dart`** — the offline generator
   (copy `generate_zip_seeds.dart` and adapt). For each difficulty × level it
   searches salts `0.._maxSalt` for the FIRST salt that yields a puzzle that is
   (a) strictly solvable (`count...Solutions == 1`) and (b) whose `signatureOf(r)`
   (a canonical string of the layout) is not already used by another level in that
   difficulty — guaranteeing cross-level uniqueness. It runs across
   `Platform.numberOfProcessors` isolates, resolves signature collisions serially,
   ABORTS without writing if any level fails, and packs the winning salts into
   `<game_id>_seeds.g.dart`. Run it from the repo root:
   ```
   dart run test/solvability/generate_<game>_seeds.dart
   ```
   (Generating 30k verified levels takes minutes — that's expected.)

**Wire-up in the screen (`LevelProgressService`, exact API):**
```dart
import '../../core/services/level_progress_service.dart';
import '../shared/continue_dialog.dart';
import '../shared/level_complete_overlay.dart';

final lps = LevelProgressService();
// Start: read the player's current level for this difficulty (defaults to 1).
_level = lps.getCurrentLevel(kMyGameId, diff.subKey);
final result = generate<Game>Level(_level, diff.index); // trust result.gridSize etc.
// On solve:
lps.advanceLevel(kMyGameId, diff.subKey);        // current+1, bumps highest
lps.saveLevelBest(kMyGameId, diff.subKey, _level, _moves); // optional best-per-level
```
The picker's play sub-label shows the next level:
`'Level ${lps.getCurrentLevel(kMyGameId, _pickerDifficulty.subKey)}'`.

### Game State Persistence & Continue Dialog (mandatory for all level games)

Every level-based game MUST persist its in-progress state so the player can
resume exactly where they left off. The four rules:

1. **Save after every user activity** — any move, hint, tube unlock, path draw,
   arrow freed, etc. Call `_saveState()` immediately after each activity, not
   just on exit.
2. **Show a Continue Dialog on re-entry** — if saved state exists for the
   current level+difficulty, prompt the user to "Continue" or "Start Fresh"
   using `showContinueDialog`. If "Start Fresh", clear the saved state.
3. **On continue, restore the full state** — board, moves, hints used, freed
   pieces, color scheme, extra slots — everything the user would expect.
4. **On win or restart, clear saved state** — call `lps.clearGameState(...)`.
   Reset all per-level counters (`_hintsUsed = 0`, `_moves = 0`, extra
   slots = 0, etc.) in both `_restartLevel()` and `_nextLevel()`.

**What to save:** Every piece of game-visible state that changes through user
interaction. Common fields across existing games:

| Game | Saved Fields |
|------|-------------|
| Queens Puzzle | playerQueens, xMarkers, hintsUsed |
| Water Sort | tubes, moves, extraTubeSlots, completedTubes |
| Zip | playerPath, moves, hintsUsed, hue (color scheme) |
| Arrow Puzzle | taps, freedCount, hintsUsed, freedArrowIds |

**Activity check:** `_saveState()` must skip saving if the user hasn't done
anything meaningful yet (just opened and closed = no save). Check for actual
activity: `if (_moves == 0 && _extraSlots == 0) return;` or
`if (_playerPath.isEmpty) return;` etc.

**`_startGame` pattern (with continue dialog):**
```dart
void _startGame(_Difficulty diff) async {
  final lps = LevelProgressService();
  _level = lps.getCurrentLevel(kMyGameId, diff.subKey);

  // Check for saved state
  final saved = lps.getGameState(kMyGameId, diff.subKey);
  final hasSave = saved != null && saved['level'] == _level;

  bool shouldContinue = false;
  if (hasSave) {
    shouldContinue = await showContinueDialog(
      context,
      gameName: 'My Game',
      accentColor: diff.color,
      level: _level,
    );
    if (!mounted) return;
  }

  // Reset all state
  _gameOver = false;
  _won = false;
  _moves = 0;
  _hintsUsed = 0;
  _generateLevel(diff);

  // Restore saved state if continuing
  if (hasSave && shouldContinue) {
    _moves = saved['moves'] as int;
    _hintsUsed = (saved['hintsUsed'] as int?) ?? 0;
    // ... restore all other saved fields
  } else {
    if (hasSave) lps.clearGameState(kMyGameId, diff.subKey);
  }

  setState(() => _activeDifficulty = diff);
  GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
  GameWrapper.of(context).startGame();
  GameWrapper.of(context).updateScore(_level);
}
```

**`_saveState` pattern (called after EVERY activity):**
```dart
void _saveState() {
  final diff = _activeDifficulty;
  if (diff == null || _gameOver || _won) return;
  // Activity check — skip if no user interaction yet
  if (_moves == 0 && _extraSlots == 0) return;
  LevelProgressService().saveGameState(kMyGameId, diff.subKey, {
    'level': _level,
    'moves': _moves,
    'hintsUsed': _hintsUsed,
    // ... all game-specific state
  });
}
```

**Where to call `_saveState()`:** After every user-triggered state change:
- After placing/removing a piece (`_onCellTap`, `_onCellLongPress`)
- After a pour/move completes
- After a hint is applied (`_applyHint`)
- After unlocking an extra slot (rewarded ad callback)
- After freeing an arrow / drawing a path cell / backtracking
- In `_backOrHome()` and `_backToPicker()` (safety net)

**Clear state on win (`_endGame`):**
```dart
lps.advanceLevel(kMyGameId, diff.subKey);
lps.clearGameState(kMyGameId, diff.subKey);
```

**Reset everything on restart (`_restartLevel`):**
```dart
void _restartLevel() {
  setState(() {
    _moves = 0;
    _gameOver = false;
    _won = false;
    _hintsUsed = 0;          // MUST reset hint count
    _extraSlots = 0;          // MUST reset extra slots/tubes
    // ... reset all game-specific state
  });
  if (_activeDifficulty != null) {
    LevelProgressService().clearGameState(kMyGameId, _activeDifficulty!.subKey);
  }
}
```

**Reset everything on next level (`_nextLevel`):**
```dart
void _nextLevel() {
  setState(() {
    _level++;
    _moves = 0;
    _hintsUsed = 0;           // MUST reset hint count
    _extraSlots = 0;           // MUST reset extra slots
    _gameOver = false;
    _won = false;
  });
  _generateLevel(_activeDifficulty!);
  // ... restart game wrapper
}
```

Import: `import '../shared/continue_dialog.dart';`

Reference implementations: `queens_puzzle_screen.dart`, `water_sort_screen.dart`,
`zip_screen.dart`, `arrow_puzzle_screen.dart`.

**Level-complete flow:** show `LevelCompleteOverlay`, then advance via the
rewarded gate so progression and the interstitial cadence stay centralized:
```dart
GameWrapper.of(context).completeLevelWithAd(onComplete: () { if (mounted) _nextLevel(); });
```
`_nextLevel()` re-reads `getCurrentLevel`, regenerates, and resets per-level state.

**HUD** shows `LEVEL <n>` (not a score). **Result screen** headline is
`'Level $_level Complete!'` with level-specific stats (moves/time). **Rewarded
continue** for level games is usually "extra space"/"undo last move", not
"continue from score".

**Mandatory level-game tests** (in addition to the standard suite):
`test/games/<game>_solvability_test.dart` (copy `zip_solvability_test.dart`) must
assert, for all 10,000 levels × 3 difficulties:
- `<game>LevelsPerDifficulty == 10000` (seed table fully populated),
- every level strictly solvable (`count...Solutions(r, cap: 2) == 1`),
- cross-level uniqueness (all signatures distinct, count == 10000),
- determinism (same `(level, diff)` rebuilds identically),
- wrap-around (level `10000+k` equals level `k`, still strictly solvable).
These run long; tag them with `timeout: Timeout(Duration(minutes: 30))`.

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

Every one of the 27 games uses ONE shared logo system — the "Glass Spotlight"
scaffold in `lib/games/shared/game_logo_scaffold.dart`. You MUST use it so the
new tile is visually consistent (themed gradient bg, accent spotlight, centered
hero art, frosted name bar). Do NOT hand-roll a bespoke `CustomPainter` card.

The game supplies only four things: a 2-tone background gradient, an accent
colour, the title, and an `art(canvas, zone)` painter that draws the game's
hero icon inside the given square `zone` (centered, upper-middle of the card).
Draw the art relative to `zone` (use `zone.center`, `zone.width`, etc.) so it
scales with the tile.

```dart
import 'package:flutter/material.dart';
import '../shared/game_logo_scaffold.dart';

const _bg = [Color(0xFF...), Color(0xFF...)]; // top→bottom gradient (themed)
const _accent = Color(0xFF...);               // matches the game's accent

Widget buildMyGameLogo(double size) => buildGlassSpotlightLogo(
      size: size,
      title: 'My Game',
      bg: _bg,
      accent: _accent,
      art: _drawArt,
    );

void _drawArt(Canvas canvas, Rect zone) {
  // Draw the game's signature icon inside `zone` (a square). Keep it simple,
  // bold, and high-contrast — it renders as small as ~64px on home tiles.
  // e.g. canvas.drawRRect(...), canvas.drawPath(...), a few shapes that read
  // instantly. Study existing `<game>_logo.dart` files for the art level.
}
```

The same `buildMyGameLogo` builder feeds both the home-screen tile and the
picker mascot. Pick `bg`/`accent` to match the game's in-screen accent colours
so the tile, picker, and gameplay feel like one product. The title auto-fits a
single line; no need to size text yourself.

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
2. Add a case to the `_playButtonText` switch expression with the REAL start
   button so the PLAYING state is actually exercised (not just the picker):
   ```dart
   '<game_id>' => 'Play <Game Name>',          // single-player games
   '<game_id>' => 'Play vs. AI',               // AI / two-player board games
   ```
   Do NOT leave multiplayer games on the `'Tap to Start'` default — that label
   doesn't exist on their picker, so the tap is skipped and the board is never
   rendered (a real coverage hole that previously hid playing-state overflows).

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

### 9d. Wire into the responsive / overflow / accessibility fleet

The repo has a device-matrix test fleet that guarantees NO game breaks (overflow,
slowness) on ANY supported device. A new game MUST be added to it — these catch
the prod-breaking layout bugs the per-game test above does not.

Shared driver: `test/helpers/game_drivers.dart` — `initGameTest()`, the
`gamePlayButton` map (gameId → primary start button), `selectDifficultyStop`
(drives the `SpinningSlider` to a difficulty), `tapPlay`, and `levelCurrentKey`
(seeds a level for level games). `test/helpers/screen_sizes.dart` defines the 14
supported devices; `pumpScreen(..., textScale:)` renders at a font scale.

Required edits/additions:
1. **`test/helpers/game_drivers.dart`** — add `'<game_id>'` to `allGameIds` and to
   the `gamePlayButton` map (`'Play vs. AI'` for two-player, else `'Play <Name>'`).
2. **`test/games/max_board_overflow_test.dart`** — if the board size scales with
   difficulty or level, add a `_MaxConfig` driving it to its DENSEST render (HARD +,
   for level games, the level that maxes the grid via `levelCurrentKey`). Asserts
   no overflow on all 14 devices.
3. **`test/games/difficulty_sweep_overflow_test.dart`** — if board geometry differs
   per difficulty, add `[gameId, name, playText]` so every difficulty is rendered.
4. **`test/games/two_player_playing_overflow_test.dart`** — if it's an AI/two-player
   board game, add `[gameId, name]` so the live board is swept on all devices.
5. **`test/games/level_boundary_overflow_test.dart`** — LEVEL games only: add a
   `_LevelGame` with a level spread crossing every grid-size transition + a wrapped
   level (e.g. `[1, 5, 13, 100, 9999, 10013]`).
6. **`test/a11y/games_text_scaling_test.dart`** — automatically covers every id in
   `allGameIds` at 1.3× text scale (picker + playing); just ensure step 1 is done.
7. **`test/performance/level_gen_perf_test.dart`** — LEVEL games only: add a group
   asserting `generate<Game>Level(maxLevel, diff)` stays under the per-level time
   budget (guards against accidental on-device solving / slowness).

The universal invariant these assert is **no overflow + the board actually
rendered**, on every device, at every difficulty/level, at normal and large text.
If a new game trips one, FIX THE GAME LAYOUT (responsive sizing via
`LayoutBuilder`, `FittedBox(scaleDown)` on fixed HUD rows, scroll views) — never
weaken the test.

### 9e. Exhaustive per-element coverage across the FULL device matrix (mandatory)

Beyond "no overflow", every game ships with a dedicated test file
`test/games/<game_id>_devicematrix_test.dart` that verifies **every element of
every screen state, on every supported device, on both platforms, at normal and
large text**. This is what guarantees the game cannot break in production.

**The device matrix already covers both platforms.** `allTestDevices`
(`test/helpers/screen_sizes.dart`) is 14 devices = **7 Android + 7 iOS**, from the
smallest phone (320×568) through foldables and tablets to iPad Pro 12.9
(1024×1366), each with its real `devicePixelRatio` and `TargetPlatform`.
`pumpScreen` applies platform-correct safe-area insets (iOS notch top 47 / home
indicator 34; Android status bar 24) and themes with the device's platform — so
iterating `allTestDevices` IS testing iOS + Android. Do not hardcode one size.

For EACH game state, loop over ALL `allTestDevices` (and rerun the critical ones
at `textScale: 1.3`) and assert every element individually:

| State | How to reach it | Assert (per device) |
|-------|-----------------|---------------------|
| **Picker** | initial frame | back button, help/`?`, favorite heart, mascot/logo, title, difficulty label, `SpinningSlider`, hint text, best pill, every play button — all present, no overflow |
| **Playing** | `selectDifficultyStop` + `tapPlay` | every HUD element (each score/level/time/best label + value), back button, restart button, the full board (every cell/tile/pit/column hit-testable), any hint nudge / mode toggle — present, inside `SafeArea`, no overflow |
| **Paused** | `GameWrapper.of(ctx).pauseGame()` via the game's pause affordance | overlay shows Paused + Resume + Restart + Quit (+ their icons); resume dismisses it |
| **Game over / result** | drive to a real win AND a real loss/draw | headline, badge, every stat column, every `GameResultAction` button (correct labels), New-Best badge when applicable — present, no overflow |
| **Level complete** (level games) | solve a level | `LevelCompleteOverlay` + next-level action present, no overflow |

Element-level checks every device-matrix test MUST include:
1. **Presence** — each element found (`findsOneWidget` / `findsWidgets` for repeated labels).
2. **No overflow** — `expectNoOverflow(device, '<state>')` after every state (the `OverflowDetector` is already armed by `pumpScreen`).
3. **Corners / edges within SafeArea** — edge-anchored controls (back top-left, restart top-right, hint/mode bottom) must render fully on notched iOS and cutout Android. Assert their `tester.getRect(...)` sits inside the device's safe area (top/bottom insets above), so nothing hides under a notch/home-indicator.
4. **Tap targets ≥ 44×44** — for every interactive control, `expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(44))` (the project minimum; see `test/a11y/tap_targets_test.dart`).
5. **Board completeness** — for grid/board games, assert the rendered interactive cell count equals the expected dimension (e.g. 81 for 9×9) on every device, and that the densest difficulty/level still fits (driven via the Step-9d fleet).
6. **Large text** — repeat presence + no-overflow at `textScale: 1.3` on the narrow devices (the game is auto-covered by `games_text_scaling_test.dart`, but assert your game-specific HUD labels survive scaling too).

Reuse the helpers (`initGameTest`, `pumpScreen`, `selectDifficultyStop`, `tapPlay`,
`expectNoOverflow`, `cleanUp`, `allTestDevices`) — do not reinvent the harness.
This file will contain many tests (states × 14 devices × elements); that volume is
intended. If any assertion fails, FIX THE GAME, never the test.

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
After creating/updating the test files, run them in this order:

0. **LEVEL games only — bake & verify the 30k levels FIRST** (the screen won't
   work until the seed table exists):
```bash
dart run test/solvability/generate_<game_id>_seeds.dart   # writes <game_id>_seeds.g.dart
flutter test test/games/<game_id>_solvability_test.dart   # all 10k×3 strict + unique
```
   The generator must finish with zero failures; the solvability test must be all
   green. If a level fails to find a unique-solution salt, fix the difficulty curve
   / generator in `<game_id>_level_gen.dart` and regenerate — never relax the test.

1. Per-game test:
```bash
flutter test test/games/<game_id>_test.dart --reporter compact
```

2. Registry test (validates game count and IDs):
```bash
flutter test test/games/game_registry_test.dart --reporter compact
```

3. Device/overflow fleet + the per-element device-matrix file (ready + playing + paused + result + every element on all 14 devices, iOS + Android, normal + 1.3× text):
```bash
flutter test test/games/<game_id>_devicematrix_test.dart test/screens/games_overflow_test.dart \
  test/games/max_board_overflow_test.dart test/games/difficulty_sweep_overflow_test.dart \
  test/games/two_player_playing_overflow_test.dart test/a11y/games_text_scaling_test.dart --reporter compact
# LEVEL games also: test/games/level_boundary_overflow_test.dart test/performance/level_gen_perf_test.dart
```

4. Full test suite (ensures nothing else broke):
```bash
flutter test --reporter compact
```

All tests MUST pass at every step. If any fail, fix the game code (not the tests) until they pass.

## Checklist

- [ ] Folder `lib/games/<game_id>/` created
- [ ] `<game_id>_screen.dart` — picker + game + game over
- [ ] `<game_id>_logo.dart` — uses shared `buildGlassSpotlightLogo` (consistent with all 27 games)
- [ ] `<game_id>_tutorial.dart` — animated tutorial steps
- [ ] `<game_id>_stats.dart` — stats builder for leaderboard/profile
- [ ] Scoring model chosen to fit the game (high-score / best-time / win-streak / level-progress) and wired through result + stats
- [ ] Registered in `GameRegistry._builders`
- [ ] `GameInfo` added to `GameRegistry.allGames` at correct trending position with appropriate `playCount`
- [ ] Stats registered in `game_stats_bootstrap.dart`
- [ ] `GameWrapper` lifecycle wired (startGame, endGame, updateScore, setDifficultyAndMode)
- [ ] Back button (`_backOrHome`) exits game entirely via `handleExit` — does NOT go to picker
- [ ] `GameWrapper.continueAfterGameOver()` wired if rewarded continue used
- [ ] Rewarded undo wired (multiplayer board games with AI mode only — see step 7c)
- [ ] Undo window PlayerStrip UX: human `isActive` during undo window, AI NOT active
- [ ] `ScoreService` wired (saveScore, getHighScore, isFavorite)
- [ ] Haptic feedback wired via `AudioService` — `playTap` (primary action), `playScore` (progress), `playSuccess` (win/solve/level-complete); NO audio/music or audio assets; game-over haptic left to `GameWrapper.endGame()`
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
- [ ] Wired into the device fleet (Step 9d): `test/helpers/game_drivers.dart` (`allGameIds` + `gamePlayButton`), and the relevant overflow/difficulty/text-scale tests
- [ ] `test/games/<game_id>_devicematrix_test.dart` created (Step 9e): every element of every state (picker, playing, paused, result, level-complete) asserted present + no-overflow + within SafeArea + tap-target ≥44px on ALL 14 devices (7 iOS + 7 Android) at normal + 1.3× text
- [ ] **LEVEL games:** `<game_id>_level_gen.dart` (seeded generation + solver), `<game_id>_seeds.g.dart` generated, `generate_<game_id>_seeds.dart` runs with zero failures
- [ ] **LEVEL games:** `<game_id>_solvability_test.dart` green — all 10,000×3 strictly solvable (1 solution) + unique + deterministic + wrap-around; perf budget test added
- [ ] All tests pass: `flutter test --reporter compact` (full suite, not just game tests)

## Important

- **NEVER commit or push** as part of this workflow. The user will handle git operations separately.

## Key Rules

- Portrait orientation only
- **No audio or music** (no sound files / audio packages), but DO add **haptic feedback** via `AudioService` (`playTap`/`playScore`/`playSuccess`) on the primary action, scoring, and win/solve — matching existing games
- Minimum tap target: 44x44
- Use rounded corners (14-16px), subtle shadows, pastel accents
- Swipe gestures (if any) must work on the FULL screen, not just the board
- Font: Poppins via Google Fonts (inherited from AppTheme)
- Keep it lightweight — no heavy assets, pure Flutter widgets or CustomPaint
- Game logic MUST be self-contained in the game folder
- Reuse shared widgets: GamePickerScaffold, GameHudBar, GameSinglePickerBody/GameAiPickerBody, GameDifficultyCard/SpinningSlider, GenericGameResultScreen, LevelCompleteOverlay, AnimatedBackground, RewardedContinueAction, and `buildGlassSpotlightLogo` for the tile/logo
- Decide the scoring model from the game itself (don't ask): high-score per difficulty / best-time / win-streak / level-progress — wire via ScoreService or LevelProgressService
- LEVEL games: 10,000 unique, strictly-solvable levels × 3 difficulties, generated offline, replayed on device (no runtime solver). Never generate puzzles live or ship an unsolvable level.

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
