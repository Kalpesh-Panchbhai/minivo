import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/multiplayer/player_strip.dart';
import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_picker_scaffold.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../shared/animated_background.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_hud_bar.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_undo_button.dart';
import 'dots_and_boxes_logo.dart';
import 'dots_and_boxes_stats.dart';
import 'dots_and_boxes_tutorial.dart';

// ── Design tokens ────────────────────────────────────────────────────────────
const Color _kP1Color      = Color(0xFF4DABF7); // bright sky blue
const Color _kP2Color      = Color(0xFFFF6B6B); // coral red
const Color _kAccent       = Color(0xFF339AF0);
const Color _kBoardBg      = Color(0xFFF5F9FF); // soft off-white board
const Color _kBoardBorder  = Color(0xFFD0E4F8); // subtle blue border
const Color _kGhostLine    = Color(0xFFCBDEF7); // pale blue ghost lines
const Color _kDotColor     = Color(0xFF1D3D6B); // deep navy dots
const Color _kBgTop        = Color(0xFFF0F8FF);
const Color _kBgBot        = Color(0xFFE8F4FD);

// ── Enums ────────────────────────────────────────────────────────────────────
enum _Mode       { ai, twoPlayer }
enum _Difficulty { easy, medium, hard }
enum _LineType   { h, v }

// ── Grid helpers ─────────────────────────────────────────────────────────────
int _boxCount(_Difficulty d) => switch (d) {
      _Difficulty.easy   => 4,
      _Difficulty.medium => 5,
      _Difficulty.hard   => 6,
    };
int _dotsCount(_Difficulty d) => _boxCount(d) + 1;

// ════════════════════════════════════════════════════════════════════════════
// ROOT STATE
// ════════════════════════════════════════════════════════════════════════════

class DotsAndBoxesScreen extends StatefulWidget {
  const DotsAndBoxesScreen({super.key});
  @override
  State<DotsAndBoxesScreen> createState() => _DotsAndBoxesScreenState();
}

class _DotsAndBoxesScreenState extends State<DotsAndBoxesScreen>
    with TickerProviderStateMixin {

  _Mode?      _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  // -1 = undrawn, 0 = P1, 1 = P2
  late List<List<int>> _hOwner;
  late List<List<int>> _vOwner;
  late List<List<int>> _boxes;

  int  _currentPlayer  = 0;
  bool _gameOver       = false;
  bool _aiThinking     = false;
  int  _p1Score        = 0;
  int  _p2Score        = 0;
  bool _isFavorite     = false;

  // Key of the most recently drawn line — used to trigger draw animation
  String? _lastDrawnKey;

  // Undo support (AI mode only, 1 per game)
  bool _undoUsed = false;
  bool _inUndoWindow = false;
  _LineType? _undoLineType;
  int? _undoRow;
  int? _undoCol;
  int _undoClaimedCount = 0;
  List<(int, int)> _undoClaimedBoxes = [];

  final _audio = AudioService();
  final _rng   = math.Random();
  Timer? _aiTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kDotsAndBoxesGameId);
    _initBoard();
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  // ── Board init ────────────────────────────────────────────────────────────

  void _initBoard({bool notify = true}) {
    final dots  = _dotsCount(_difficulty);
    final boxes = _boxCount(_difficulty);
    _hOwner        = List.generate(dots,  (_) => List.filled(boxes, -1));
    _vOwner        = List.generate(boxes, (_) => List.filled(dots,  -1));
    _boxes         = List.generate(boxes, (_) => List.filled(boxes, -1));
    _currentPlayer = 0;
    _gameOver      = false;
    _aiThinking    = false;
    _p1Score       = 0;
    _p2Score       = 0;
    _lastDrawnKey  = null;
    _undoUsed      = false;
    _inUndoWindow  = false;
    _undoLineType  = null;
    _undoRow       = null;
    _undoCol       = null;
    _undoClaimedCount = 0;
    _undoClaimedBoxes = [];
    if (notify) setState(() {});
  }

  // ── Predicates ────────────────────────────────────────────────────────────

  bool _isBoxComplete(int r, int c) =>
      _hOwner[r][c]     != -1 && _hOwner[r + 1][c] != -1 &&
      _vOwner[r][c]     != -1 && _vOwner[r][c + 1] != -1;

  bool get _allBoxesFilled {
    final n = _boxCount(_difficulty);
    for (int r = 0; r < n; r++)
      for (int c = 0; c < n; c++)
        if (_boxes[r][c] == -1) return false;
    return true;
  }

  int _sidesOf(int r, int c) {
    int n = 0;
    if (_hOwner[r][c]     != -1) n++;
    if (_hOwner[r + 1][c] != -1) n++;
    if (_vOwner[r][c]     != -1) n++;
    if (_vOwner[r][c + 1] != -1) n++;
    return n;
  }

  // ── Claim boxes ───────────────────────────────────────────────────────────

  int _claimBoxes(int player) {
    int claimed = 0;
    final n = _boxCount(_difficulty);
    for (int r = 0; r < n; r++)
      for (int c = 0; c < n; c++)
        if (_boxes[r][c] == -1 && _isBoxComplete(r, c)) {
          _boxes[r][c] = player;
          claimed++;
        }
    return claimed;
  }

  // ── Undo support ─────────────────────────────────────────────────────────

  bool get _canUndo => _inUndoWindow && !_gameOver;

  void _onUndoExpired() {
    if (!mounted || _gameOver || !_inUndoWindow) return;
    setState(() => _inUndoWindow = false);
    _scheduleAiMove();
  }

  void _performUndo() {
    if (_undoLineType == null || _undoRow == null || _undoCol == null) return;
    setState(() {
      if (_undoLineType == _LineType.h) {
        _hOwner[_undoRow!][_undoCol!] = -1;
      } else {
        _vOwner[_undoRow!][_undoCol!] = -1;
      }
      for (final (r, c) in _undoClaimedBoxes) {
        _boxes[r][c] = -1;
      }
      _p1Score -= _undoClaimedCount;
      _currentPlayer = 0;
      _inUndoWindow = false;
      _undoUsed = true;
      _undoLineType = null;
      _undoRow = null;
      _undoCol = null;
      _undoClaimedCount = 0;
      _undoClaimedBoxes = [];
      _lastDrawnKey = null;
    });
  }

  // ── Line tap handlers ─────────────────────────────────────────────────────

  void _onHLineTap(int row, int col) {
    if (_gameOver || _hOwner[row][col] != -1) return;
    if (_mode == _Mode.ai && (_aiThinking || _inUndoWindow || _currentPlayer == 1)) return;
    setState(() {
      _hOwner[row][col] = _currentPlayer;
      _lastDrawnKey = 'h_${row}_$col';
    });
    _audio.playTap();
    if (_mode == _Mode.ai && _currentPlayer == 0) {
      _undoLineType = _LineType.h;
      _undoRow = row;
      _undoCol = col;
    }
    _afterMove();
  }

  void _onVLineTap(int row, int col) {
    if (_gameOver || _vOwner[row][col] != -1) return;
    if (_mode == _Mode.ai && (_aiThinking || _inUndoWindow || _currentPlayer == 1)) return;
    setState(() {
      _vOwner[row][col] = _currentPlayer;
      _lastDrawnKey = 'v_${row}_$col';
    });
    _audio.playTap();
    if (_mode == _Mode.ai && _currentPlayer == 0) {
      _undoLineType = _LineType.v;
      _undoRow = row;
      _undoCol = col;
    }
    _afterMove();
  }

  void _afterMove() {
    final n = _boxCount(_difficulty);
    final claimedBoxes = <(int, int)>[];
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_boxes[r][c] == -1 && _isBoxComplete(r, c)) {
          _boxes[r][c] = _currentPlayer;
          claimedBoxes.add((r, c));
        }
      }
    }
    final claimed = claimedBoxes.length;
    if (_currentPlayer == 0) {
      _p1Score += claimed;
      _undoClaimedCount = claimed;
      _undoClaimedBoxes = claimedBoxes;
    } else {
      _p2Score += claimed;
    }

    if (_allBoxesFilled) {
      setState(() {
        _gameOver = true;
        _undoLineType = null;
      });
      _onGameEnd();
      return;
    }

    if (claimed == 0) {
      setState(() => _currentPlayer = _currentPlayer == 0 ? 1 : 0);
    } else {
      _undoLineType = null;
      setState(() {});
    }

    if (!_gameOver && _mode == _Mode.ai && _currentPlayer == 1) {
      final undoAvailable = !_undoUsed && _undoLineType != null && AdsService().isRewardedReady;
      if (undoAvailable) {
        setState(() => _inUndoWindow = true);
      } else {
        _scheduleAiMove();
      }
    }
  }

  void _onGameEnd() {
    _audio.playSuccess();
    if (_mode == _Mode.ai) {
      final subKey = _aiSubKey();
      if (subKey != null && _p1Score > 0) {
        ScoreService().saveScore(kDotsAndBoxesGameId, _p1Score, subKey: subKey);
      }
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _wrapper.endGame();
    });
  }

  // ── AI ────────────────────────────────────────────────────────────────────

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    final ms = switch (_difficulty) {
      _Difficulty.easy   => 600,
      _Difficulty.medium => 800,
      _Difficulty.hard   => 1000,
    };
    _aiTimer?.cancel();
    _aiTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted || _gameOver) return;
      _doAiMove();
    });
  }

  void _doAiMove() {
    final move = _pickAiMove();
    setState(() {
      _aiThinking = false;
      _undoLineType = null;
      if (move.$1 == _LineType.h) {
        _hOwner[move.$2][move.$3] = 1;
        _lastDrawnKey = 'h_${move.$2}_${move.$3}';
      } else {
        _vOwner[move.$2][move.$3] = 1;
        _lastDrawnKey = 'v_${move.$2}_${move.$3}';
      }
    });
    _audio.playTap();
    _afterMove();
  }

  (_LineType, int, int) _pickAiMove() => switch (_difficulty) {
        _Difficulty.easy   => _randomMove(),
        _Difficulty.medium => _aiMediumMove(),
        _Difficulty.hard   => _aiHardMove(),
      };

  (_LineType, int, int) _aiMediumMove() =>
      _findCompletingMove() ?? _findSafeMove() ?? _randomMove();

  (_LineType, int, int) _aiHardMove() =>
      _findCompletingMove() ?? _findSmartMove() ?? _findSafeMove() ?? _randomMove();

  (_LineType, int, int)? _findCompletingMove() {
    final n = _boxCount(_difficulty);
    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (_boxes[r][c] != -1) continue;
        if (_sidesOf(r, c) == 3) {
          if (_hOwner[r][c]     == -1) return (_LineType.h, r,     c);
          if (_hOwner[r + 1][c] == -1) return (_LineType.h, r + 1, c);
          if (_vOwner[r][c]     == -1) return (_LineType.v, r,     c);
          if (_vOwner[r][c + 1] == -1) return (_LineType.v, r,     c + 1);
        }
      }
    }
    return null;
  }

  (_LineType, int, int)? _findSafeMove() {
    final safe = _allFreeLines().where((m) => !_wouldGiveBox(m)).toList();
    if (safe.isEmpty) return null;
    return safe[_rng.nextInt(safe.length)];
  }

  (_LineType, int, int)? _findSmartMove() {
    final preferred = _allFreeLines().where((m) {
      return _adjacentBoxes(m).every((rc) => _sidesOf(rc.$1, rc.$2) < 2);
    }).toList();
    if (preferred.isEmpty) return null;
    return preferred[_rng.nextInt(preferred.length)];
  }

  (_LineType, int, int) _randomMove() {
    final all = _allFreeLines();
    return all[_rng.nextInt(all.length)];
  }

  List<(_LineType, int, int)> _allFreeLines() {
    final dots  = _dotsCount(_difficulty);
    final boxes = _boxCount(_difficulty);
    final result = <(_LineType, int, int)>[];
    for (int r = 0; r < dots;  r++)
      for (int c = 0; c < boxes; c++)
        if (_hOwner[r][c] == -1) result.add((_LineType.h, r, c));
    for (int r = 0; r < boxes; r++)
      for (int c = 0; c < dots;  c++)
        if (_vOwner[r][c] == -1) result.add((_LineType.v, r, c));
    return result;
  }

  bool _wouldGiveBox((_LineType, int, int) move) {
    final n = _boxCount(_difficulty);
    final (type, row, col) = move;
    if (type == _LineType.h) _hOwner[row][col] = 1; else _vOwner[row][col] = 1;
    bool gives = false;
    for (int r = 0; r < n && !gives; r++)
      for (int c = 0; c < n && !gives; c++)
        if (_boxes[r][c] == -1 && _sidesOf(r, c) == 4) gives = true;
    if (type == _LineType.h) _hOwner[row][col] = -1; else _vOwner[row][col] = -1;
    return gives;
  }

  List<(int, int)> _adjacentBoxes((_LineType, int, int) move) {
    final n = _boxCount(_difficulty);
    final (type, row, col) = move;
    final result = <(int, int)>[];
    if (type == _LineType.h) {
      if (row > 0 && row - 1 < n && col < n) result.add((row - 1, col));
      if (row < n && col < n)                 result.add((row,     col));
    } else {
      if (col > 0 && col - 1 < n && row < n) result.add((row, col - 1));
      if (col < n && row < n)                 result.add((row, col));
    }
    return result.where((rc) => _boxes[rc.$1][rc.$2] == -1).toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _aiSubKey() => _mode != _Mode.ai ? null : switch (_difficulty) {
        _Difficulty.easy   => kDotsAndBoxesSubKeyEasy,
        _Difficulty.medium => kDotsAndBoxesSubKeyMedium,
        _Difficulty.hard   => kDotsAndBoxesSubKeyHard,
      };

  void _selectMode(_Mode mode) {
    setState(() { _mode = mode; _initBoard(notify: false); });
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: mode == _Mode.ai ? 'ai' : '2_player',
    );
    _wrapper.startGame();
  }

  void _changeMode() {
    setState(() { _mode = null; _initBoard(notify: false); });
    _wrapper.restartGame();
  }

  void _playAgain() {
    setState(() => _initBoard(notify: false));
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: _mode == _Mode.ai ? 'ai' : '2_player',
    );
    _wrapper.restartGame();
    _wrapper.startGame();
  }

  void _toggleFavorite() {
    setState(() { _isFavorite = !_isFavorite; });
    ScoreService().toggleFavorite(kDotsAndBoxesGameId);
    _audio.playTap();
  }

  void _backOrHome() {
    if (context.canPop()) context.pop(); else context.go('/home');
  }

  void _showHowToPlay(BuildContext ctx) {
    final game = GameRegistry.getById(kDotsAndBoxesGameId);
    if (game == null) return;
    showHowToPlaySheet(ctx, title: game.name, howToPlay: game.howToPlay,
        accent: _kAccent, steps: dotsAndBoxesSteps(), gameId: kDotsAndBoxesGameId);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = _wrapper.state;

    if (state == GameState.ready || _mode == null) {
      return _ModePickerScreen(
        difficulty: _difficulty,
        onDifficultyChanged: (d) => setState(() => _difficulty = d),
        isFavorite: _isFavorite,
        onFavoriteToggle: _toggleFavorite,
        onBack: _backOrHome,
        onPlayAi: () => _selectMode(_Mode.ai),
        onPlayFriend: () => _selectMode(_Mode.twoPlayer),
        onHelp: () => _showHowToPlay(context),
      );
    }

    if (state == GameState.gameOver) return _buildResult();

    return _BoardScreen(
      difficulty:    _difficulty,
      mode:          _mode!,
      hOwner:        _hOwner,
      vOwner:        _vOwner,
      boxes:         _boxes,
      currentPlayer: _currentPlayer,
      aiThinking:    _aiThinking,
      p1Score:       _p1Score,
      p2Score:       _p2Score,
      gameOver:      _gameOver,
      lastDrawnKey:  _lastDrawnKey,
      inUndoWindow:  _inUndoWindow,
      canUndo:       _canUndo,
      onUndo:        _performUndo,
      onUndoExpired: _onUndoExpired,
      onHLineTap:    _onHLineTap,
      onVLineTap:    _onVLineTap,
      onBack:        _backOrHome,
      onRestart:     _playAgain,
    );
  }

  Widget _buildResult() {
    final isAi = _mode == _Mode.ai;
    final String headline;
    final String badge;
    final Color badgeColor;

    if (_p1Score > _p2Score) {
      headline = isAi ? 'You Win! 🎉' : 'Player 1 Wins!';
      badge = '🏆'; badgeColor = _kP1Color;
    } else if (_p2Score > _p1Score) {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      badge = '🤖'; badgeColor = _kP2Color;
    } else {
      headline = "It's a Draw!";
      badge = '🤝'; badgeColor = const Color(0xFF868E96);
    }

    return game_result.GenericGameResultScreen(
      gameId: kDotsAndBoxesGameId,
      score: _p1Score,
      headline: headline,
      badgeContent: badge,
      badgeColor: badgeColor,
      showNewBestBadge: false,
      statsWidget: game_result.GameResultPlayersRow(
        p1Label: isAi ? 'YOU' : 'P1',
        p2Label: isAi ? 'AI'  : 'P2',
        p1Score: _p1Score, p2Score: _p2Score,
        p1Color: _kP1Color, p2Color: _kP2Color,
        p1IsWinner: _p1Score > _p2Score,
        p2IsWinner: _p2Score > _p1Score,
        scoreUnit: 'boxes',
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again', icon: Icons.refresh_rounded,
          onTap: _playAgain, filled: true, color: _kAccent,
          actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Mode', icon: Icons.swap_horiz_rounded, onTap: _changeMode,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home', icon: Icons.home_rounded, onTap: _backOrHome,
          actionId: 'home',
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MODE PICKER
// ════════════════════════════════════════════════════════════════════════════

class _ModePickerScreen extends StatelessWidget {
  final _Difficulty              difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final bool         isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onBack;
  final VoidCallback onPlayAi;
  final VoidCallback onPlayFriend;
  final VoidCallback onHelp;

  const _ModePickerScreen({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onBack,
    required this.onPlayAi,
    required this.onPlayFriend,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return GamePickerScaffold(
      bgColorTop:    _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => DotsAndBoxesBgPainter(t),
        period: const Duration(seconds: 10),
      ),
      iconRingColors: const [Color(0xFF339AF0), Color(0xFF1971C2), Color(0xFF339AF0)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kDotsAndBoxesGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(borderRadius: BorderRadius.circular(42), child: logo);
        }
        return const Icon(Icons.grid_4x4_rounded, size: 40, color: Color(0xFF339AF0));
      }),
      title:    'Dots & Boxes',
      subtitle: 'Draw lines, complete boxes, outsmart your opponent!',
      onBack:            onBack,
      isFavorite:        isFavorite,
      onFavoriteToggle:  onFavoriteToggle,
      onHowToPlay:       onHelp,
      gameId:            kDotsAndBoxesGameId,
      tallThreshold:     860,
      body: GameAiPickerBody(
        difficulties: _Difficulty.values.map((d) {
          final subKey = switch (d) {
            _Difficulty.easy   => kDotsAndBoxesSubKeyEasy,
            _Difficulty.medium => kDotsAndBoxesSubKeyMedium,
            _Difficulty.hard   => kDotsAndBoxesSubKeyHard,
          };
          return GameDifficultyData(
            label:     _diffLabel(d),
            color:     _diffColor(d),
            kind:      _diffKind(d),
            hint: switch (d) {
              _Difficulty.easy   => '4×4 boxes — great for learning.',
              _Difficulty.medium => '5×5 boxes — balanced challenge.',
              _Difficulty.hard   => '6×6 boxes — plan your chains carefully.',
            },
            bestScore: bestBoxes(subKey),
            bestLabel: (s) => 'Best $s boxes claimed',
          );
        }).toList(),
        activeIndex: _Difficulty.values.indexOf(difficulty),
        onChanged:   (i) => onDifficultyChanged(_Difficulty.values[i]),
        onPlayAi:        onPlayAi,
        onPlayFriend:    onPlayFriend,
        difficultyLabel: 'DIFFICULTY',
        aiGradient:      const [Color(0xFF339AF0), Color(0xFF74C0FC)],
        friendGradient:  const [Color(0xFFFF6B6B), Color(0xFFFF9999)],
      ),
    );
  }
}

String     _diffLabel(_Difficulty d) => switch (d) {
  _Difficulty.easy   => 'EASY',
  _Difficulty.medium => 'MEDIUM',
  _Difficulty.hard   => 'HARD',
};
Color      _diffColor(_Difficulty d) => switch (d) {
  _Difficulty.easy   => const Color(0xFF22C55E),
  _Difficulty.medium => const Color(0xFFF59E0B),
  _Difficulty.hard   => const Color(0xFFEF4444),
};
DifficultyKind _diffKind(_Difficulty d) => switch (d) {
  _Difficulty.easy   => DifficultyKind.easy,
  _Difficulty.medium => DifficultyKind.medium,
  _Difficulty.hard   => DifficultyKind.hard,
};

// ════════════════════════════════════════════════════════════════════════════
// BOARD SCREEN
// ════════════════════════════════════════════════════════════════════════════

class _BoardScreen extends StatelessWidget {
  final _Difficulty          difficulty;
  final _Mode                mode;
  final List<List<int>>      hOwner;
  final List<List<int>>      vOwner;
  final List<List<int>>      boxes;
  final int                  currentPlayer;
  final bool                 aiThinking;
  final int                  p1Score;
  final int                  p2Score;
  final bool                 gameOver;
  final String?              lastDrawnKey;
  final bool                 inUndoWindow;
  final bool                 canUndo;
  final VoidCallback         onUndo;
  final VoidCallback         onUndoExpired;
  final void Function(int, int) onHLineTap;
  final void Function(int, int) onVLineTap;
  final VoidCallback         onBack;
  final VoidCallback         onRestart;

  const _BoardScreen({
    required this.difficulty,
    required this.mode,
    required this.hOwner,
    required this.vOwner,
    required this.boxes,
    required this.currentPlayer,
    required this.aiThinking,
    required this.p1Score,
    required this.p2Score,
    required this.gameOver,
    required this.lastDrawnKey,
    required this.inUndoWindow,
    required this.canUndo,
    required this.onUndo,
    required this.onUndoExpired,
    required this.onHLineTap,
    required this.onVLineTap,
    required this.onBack,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final p1Turn    = (currentPlayer == 0 || inUndoWindow) && !gameOver;
    final topTarget = p1Turn ? const Color(0xFFDFF0FF) : const Color(0xFFFFECEC);
    final botTarget = p1Turn ? const Color(0xFFBEDDFA) : const Color(0xFFFFD4D4);

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 450),
      tween: ColorTween(end: topTarget),
      builder: (context, top, _) => TweenAnimationBuilder<Color?>(
        duration: const Duration(milliseconds: 450),
        tween: ColorTween(end: botTarget),
        builder: (context, bot, _) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [top ?? topTarget, bot ?? botTarget],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(children: [
              const SizedBox(height: 8),
              GameHudBar(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                leading: GameBackButton(onTap: onBack),
                centerContent: _ScorePill(
                  mode: mode, difficulty: difficulty,
                  p1Score: p1Score, p2Score: p2Score,
                ),
                trailing: GameRestartButton(
                  gameName: 'Dots & Boxes',
                  accentColor: _kAccent,
                  onRestart: onRestart,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PlayerStrip(
                  label:      mode == _Mode.ai ? 'AI' : 'P2',
                  mark:       '2',
                  color:      _kP2Color,
                  isActive:   currentPlayer == 1 && !inUndoWindow && !gameOver,
                  isThinking: aiThinking,
                  avatarIcon: mode == _Mode.ai ? Icons.smart_toy_rounded : null,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _DotsBoard(
                        difficulty:    difficulty,
                        mode:          mode,
                        hOwner:        hOwner,
                        vOwner:        vOwner,
                        boxes:         boxes,
                        currentPlayer: currentPlayer,
                        gameOver:      gameOver,
                        lastDrawnKey:  lastDrawnKey,
                        onHLineTap:    onHLineTap,
                        onVLineTap:    onVLineTap,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PlayerStrip(
                  label:     mode == _Mode.ai ? 'You' : 'P1',
                  mark:      '1',
                  color:     _kP1Color,
                  isActive:  (currentPlayer == 0 || inUndoWindow) && !gameOver,
                  isThinking: false,
                ),
              ),
              SizedBox(
                height: 44,
                child: canUndo
                    ? Center(
                        child: RewardedUndoButton(
                          key: ValueKey('undo_${lastDrawnKey ?? ''}'),
                          onUndo: onUndo,
                          onExpired: onUndoExpired,
                          accentColor: _kP1Color,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 4),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Score Pill ────────────────────────────────────────────────────────────────

class _ScorePill extends StatelessWidget {
  final _Mode _mode; final _Difficulty _diff;
  final int p1Score, p2Score;
  const _ScorePill({
    required _Mode mode, required _Difficulty difficulty,
    required this.p1Score, required this.p2Score,
  }) : _mode = mode, _diff = difficulty;

  @override
  Widget build(BuildContext context) {
    final isAi     = _mode == _Mode.ai;
    final tabColor = _diffColor(_diff);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: tabColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          boxShadow: [BoxShadow(color: tabColor.withValues(alpha: 0.30),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Text(isAi ? _diffLabel(_diff) : 'PASS & PLAY',
            style: const TextStyle(color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.12),
              blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _col(isAi ? 'YOU' : 'P1', p1Score, _kP1Color),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('VS', style: TextStyle(
                color: Colors.grey.shade400, fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 1.2))),
          _col(isAi ? 'AI' : 'P2', p2Score, _kP2Color),
        ]),
      ),
    ]);
  }

  Widget _col(String label, int value, Color color) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: TextStyle(color: color, fontSize: 11,
          fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      const SizedBox(height: 2),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child)),
        child: Text('$value', key: ValueKey<int>(value),
            style: TextStyle(color: color, fontSize: 22,
                fontWeight: FontWeight.w900, height: 1)),
      ),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════════════
// DOTS BOARD  (StatefulWidget — owns line-draw animations)
// ════════════════════════════════════════════════════════════════════════════

class _DotsBoard extends StatefulWidget {
  final _Difficulty          difficulty;
  final _Mode                mode;
  final List<List<int>>      hOwner;
  final List<List<int>>      vOwner;
  final List<List<int>>      boxes;
  final int                  currentPlayer;
  final bool                 gameOver;
  final String?              lastDrawnKey;
  final void Function(int, int) onHLineTap;
  final void Function(int, int) onVLineTap;

  const _DotsBoard({
    required this.difficulty,
    required this.mode,
    required this.hOwner,
    required this.vOwner,
    required this.boxes,
    required this.currentPlayer,
    required this.gameOver,
    required this.lastDrawnKey,
    required this.onHLineTap,
    required this.onVLineTap,
  });

  @override
  State<_DotsBoard> createState() => _DotsBoardState();
}

class _DotsBoardState extends State<_DotsBoard> with TickerProviderStateMixin {
  // key → AnimationController (0→1 for line draw progress)
  final Map<String, AnimationController> _lineAnims = {};

  @override
  void didUpdateWidget(_DotsBoard old) {
    super.didUpdateWidget(old);
    if (widget.lastDrawnKey != null &&
        widget.lastDrawnKey != old.lastDrawnKey) {
      _startLineAnim(widget.lastDrawnKey!);
    }
  }

  void _startLineAnim(String key) {
    _lineAnims[key]?.dispose();
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    ctrl.addListener(() { if (mounted) setState(() {}); });
    _lineAnims[key] = ctrl;
  }

  @override
  void dispose() {
    for (final c in _lineAnims.values) c.dispose();
    super.dispose();
  }

  // ── Tap handling ──────────────────────────────────────────────────────────

  void _handleTap(Offset pos, double step) {
    if (widget.gameOver) return;
    final dots     = _dotsCount(widget.difficulty);
    final boxCount = _boxCount(widget.difficulty);

    double bestDist = step * 0.45;
    _LineType? bestType;
    int bestR = -1, bestC = -1;

    for (int r = 0; r < dots; r++) {
      for (int c = 0; c < boxCount; c++) {
        if (widget.hOwner[r][c] != -1) continue;
        final cx = (c + 0.5) * step;
        final cy = r * step;
        final dx = (pos.dx - cx).abs();
        final dy = (pos.dy - cy).abs();
        if (dx <= step * 0.50 && dy <= step * 0.36) {
          final dist = math.sqrt(dx * dx + dy * dy);
          if (dist < bestDist) { bestDist = dist; bestType = _LineType.h; bestR = r; bestC = c; }
        }
      }
    }

    for (int r = 0; r < boxCount; r++) {
      for (int c = 0; c < dots; c++) {
        if (widget.vOwner[r][c] != -1) continue;
        final cx = c * step;
        final cy = (r + 0.5) * step;
        final dx = (pos.dx - cx).abs();
        final dy = (pos.dy - cy).abs();
        if (dx <= step * 0.36 && dy <= step * 0.50) {
          final dist = math.sqrt(dx * dx + dy * dy);
          if (dist < bestDist) { bestDist = dist; bestType = _LineType.v; bestR = r; bestC = c; }
        }
      }
    }

    if      (bestType == _LineType.h && bestR >= 0) widget.onHLineTap(bestR, bestC);
    else if (bestType == _LineType.v && bestR >= 0) widget.onVLineTap(bestR, bestC);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dots     = _dotsCount(widget.difficulty);
    final boxCount = _boxCount(widget.difficulty);

    return LayoutBuilder(builder: (ctx, constraints) {
      const pad  = 14.0;
      final outerSize = math.min(constraints.maxWidth, constraints.maxHeight);
      final inner = outerSize - pad * 2;
      final step  = inner / (dots - 1);
      final dotR  = (step * 0.095).clamp(5.0, 11.0);

      // Collect animation progress for each line
      final Map<String, double> lineProgress = {};
      for (final entry in _lineAnims.entries) {
        lineProgress[entry.key] = entry.value.value;
      }

      return GestureDetector(
        onTapDown: (d) => _handleTap(
          d.localPosition - const Offset(pad, pad), step),
        child: Container(
          width: outerSize, height: outerSize,
          decoration: BoxDecoration(
            color: _kBoardBg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _kBoardBorder, width: 1.5),
            boxShadow: [
              // Active player colored glow
              BoxShadow(
                  color: _kP1Color.withValues(alpha: widget.currentPlayer == 0 ? 0.20 : 0.04),
                  blurRadius: 40, spreadRadius: 4),
              BoxShadow(
                  color: _kP2Color.withValues(alpha: widget.currentPlayer == 1 ? 0.20 : 0.04),
                  blurRadius: 40, spreadRadius: 4),
              // Depth shadow
              BoxShadow(color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 24, offset: const Offset(0, 10)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          padding: const EdgeInsets.all(pad),
          child: SizedBox(
            width: inner, height: inner,
            child: Stack(clipBehavior: Clip.none, children: [
              // Lines + dots painter
              Positioned.fill(
                child: CustomPaint(
                  painter: _BoardPainter(
                    dots:         dots,
                    boxCount:     boxCount,
                    hOwner:       widget.hOwner,
                    vOwner:       widget.vOwner,
                    step:         step,
                    dotR:         dotR,
                    lineProgress: lineProgress,
                  ),
                ),
              ),
              // Animated box fills
              for (int r = 0; r < boxCount; r++)
                for (int c = 0; c < boxCount; c++)
                  if (widget.boxes[r][c] != -1)
                    Positioned(
                      left:   c * step + dotR * 1.1,
                      top:    r * step + dotR * 1.1,
                      width:  step - dotR * 2.2,
                      height: step - dotR * 2.2,
                      child: _BoxFill(
                        player: widget.boxes[r][c],
                        step:   step,
                        label:  widget.mode == _Mode.ai
                            ? (widget.boxes[r][c] == 0 ? 'YOU' : 'AI')
                            : (widget.boxes[r][c] == 0 ? 'P1'  : 'P2'),
                      ),
                    ),
            ]),
          ),
        ),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOARD PAINTER  — draws ghost lines, drawn lines (with animation), dots
// ════════════════════════════════════════════════════════════════════════════

class _BoardPainter extends CustomPainter {
  final int               dots;
  final int               boxCount;
  final List<List<int>>   hOwner;
  final List<List<int>>   vOwner;
  final double            step;
  final double            dotR;
  final Map<String, double> lineProgress;

  const _BoardPainter({
    required this.dots,
    required this.boxCount,
    required this.hOwner,
    required this.vOwner,
    required this.step,
    required this.dotR,
    required this.lineProgress,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _drawDashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 5.0;
    const gapLen  = 4.0;
    final dist = (p2 - p1).distance;
    if (dist == 0) return;
    final dir = (p2 - p1) / dist;
    var pos = 0.0;
    while (pos < dist) {
      final end = math.min(pos + dashLen, dist);
      canvas.drawLine(p1 + dir * pos, p1 + dir * end, paint);
      pos += dashLen + gapLen;
    }
  }

  void _drawLine(Canvas canvas, Offset p1, Offset p2, Color color,
      double thickness, double progress) {
    if (progress <= 0) return;
    final p = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final center  = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final half    = (p2 - p1) / 2;
    final start   = center - half * p;
    final end     = center + half * p;

    // Wide soft glow (outermost)
    canvas.drawLine(start, end, Paint()
      ..color       = color.withValues(alpha: 0.12)
      ..strokeWidth = thickness + 14
      ..strokeCap   = StrokeCap.round);
    // Medium glow
    canvas.drawLine(start, end, Paint()
      ..color       = color.withValues(alpha: 0.25)
      ..strokeWidth = thickness + 6
      ..strokeCap   = StrokeCap.round);
    // Main line
    canvas.drawLine(start, end, Paint()
      ..color       = color
      ..strokeWidth = thickness
      ..strokeCap   = StrokeCap.round);
    // Bright core highlight
    canvas.drawLine(start, end, Paint()
      ..color       = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = thickness * 0.35
      ..strokeCap   = StrokeCap.round);
  }

  // ── Paint ─────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final lineThickness = (step * 0.12).clamp(5.0, 13.0);

    final ghostPaint = Paint()
      ..color       = _kGhostLine
      ..strokeWidth = 2.0
      ..strokeCap   = StrokeCap.round;

    // ── Ghost lines (dashed) ─────────────────────────────────────────────
    for (int r = 0; r < dots; r++)
      for (int c = 0; c < boxCount; c++)
        if (hOwner[r][c] == -1)
          _drawDashed(canvas,
            Offset(c * step + dotR * 1.6, r * step),
            Offset((c + 1) * step - dotR * 1.6, r * step),
            ghostPaint);

    for (int r = 0; r < boxCount; r++)
      for (int c = 0; c < dots; c++)
        if (vOwner[r][c] == -1)
          _drawDashed(canvas,
            Offset(c * step, r * step + dotR * 1.6),
            Offset(c * step, (r + 1) * step - dotR * 1.6),
            ghostPaint);

    // ── Drawn H lines ────────────────────────────────────────────────────
    for (int r = 0; r < dots; r++) {
      for (int c = 0; c < boxCount; c++) {
        final owner = hOwner[r][c];
        if (owner == -1) continue;
        final color = owner == 0 ? _kP1Color : _kP2Color;
        final prog  = lineProgress['h_${r}_$c'] ?? 1.0;
        _drawLine(canvas,
          Offset(c * step, r * step), Offset((c + 1) * step, r * step),
          color, lineThickness, prog);
      }
    }

    // ── Drawn V lines ────────────────────────────────────────────────────
    for (int r = 0; r < boxCount; r++) {
      for (int c = 0; c < dots; c++) {
        final owner = vOwner[r][c];
        if (owner == -1) continue;
        final color = owner == 0 ? _kP1Color : _kP2Color;
        final prog  = lineProgress['v_${r}_$c'] ?? 1.0;
        _drawLine(canvas,
          Offset(c * step, r * step), Offset(c * step, (r + 1) * step),
          color, lineThickness, prog);
      }
    }

    // ── Dots (on top of everything) ──────────────────────────────────────
    for (int r = 0; r < dots; r++) {
      for (int c = 0; c < dots; c++) {
        final center = Offset(c * step, r * step);
        // Outer soft shadow ring
        canvas.drawCircle(center, dotR + 3.5,
            Paint()..color = _kDotColor.withValues(alpha: 0.12));
        // Drop shadow
        canvas.drawCircle(center + const Offset(0, 1.5), dotR,
            Paint()..color = _kDotColor.withValues(alpha: 0.30));
        // Body
        canvas.drawCircle(center, dotR,
            Paint()..color = _kDotColor);
        // Inner ring (lighter ring near edge)
        canvas.drawCircle(center, dotR * 0.70,
            Paint()..color = _kDotColor.withValues(alpha: 0.85));
        // Specular highlight
        canvas.drawCircle(
          center - Offset(dotR * 0.30, dotR * 0.32),
          dotR * 0.36,
          Paint()..color = Colors.white.withValues(alpha: 0.60),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}

// ════════════════════════════════════════════════════════════════════════════
// BOX FILL  — scale + fade pop animation when a box is claimed
// ════════════════════════════════════════════════════════════════════════════

class _BoxFill extends StatefulWidget {
  final int    player;
  final double step;
  final String label;

  const _BoxFill({
    required this.player,
    required this.step,
    required this.label,
  });

  @override
  State<_BoxFill> createState() => _BoxFillState();
}

class _BoxFillState extends State<_BoxFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380))..forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.player == 0 ? _kP1Color : _kP2Color;
    final scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    final fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.50), width: 1.8),
            boxShadow: [BoxShadow(
              color: color.withValues(alpha: 0.16),
              blurRadius: 8, spreadRadius: 0,
            )],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width:  (widget.step * 0.22).clamp(7.0, 16.0),
                height: (widget.step * 0.22).clamp(7.0, 16.0),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: color.withValues(alpha: 0.50),
                      blurRadius: 8, spreadRadius: 1)],
                ),
              ),
              SizedBox(height: (widget.step * 0.04).clamp(1.0, 4.0)),
              Text(
                widget.label,
                style: TextStyle(
                  color:      color,
                  fontSize:   (widget.step * 0.17).clamp(7.0, 13.0),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
