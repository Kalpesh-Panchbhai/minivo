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
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_hud_bar.dart';
import '../shared/game_difficulty_picker.dart';
import 'checkers_stats.dart';
import 'checkers_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_undo_button.dart';

const Color _kRedColor = Color(0xFFE53935);
const Color _kBlackColor = Color(0xFF424242);
const Color _kDrawColor = Color(0xFFB6A5DD);
const Color _kAiColor = Color(0xFF8B5E3C);
const Color _kBgTop = Color(0xFFFFF8F0);
const Color _kBgBot = Color(0xFFF5EDE4);
const Color _kBoardDark = Color(0xFF5D4037);
const Color _kBoardLight = Color(0xFFF5DEB3);
const Color _kEasyColor = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor = Color(0xFFEF4444);

const Color _kTintRedTop = Color(0xFFFFF0EC);
const Color _kTintRedBot = Color(0xFFF5E4DE);
const Color _kTintBlackTop = Color(0xFFF0EDED);
const Color _kTintBlackBot = Color(0xFFE8E4E4);

enum _Mode { ai, twoPlayer }
enum _Difficulty { easy, medium, hard }

class CheckersScreen extends StatefulWidget {
  const CheckersScreen({super.key});
  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen>
    with TickerProviderStateMixin {
  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  // Board: 8x8, pieces: 0=empty, 1=red, 2=black, 3=red king, 4=black king
  List<int> _board = List.filled(64, 0);
  int _currentPlayer = 1; // 1=red (human/P1), 2=black (AI/P2)
  bool _gameOver = false;
  int? _winner; // 1=red, 2=black, null=draw
  bool _aiThinking = false;
  int? _selectedCell;
  List<int> _validMoves = [];
  List<int> _jumpMoves = [];
  int _redCount = 12;
  int _blackCount = 12;
  int _streak = 0;
  String? _streakOwner;
  bool _showStreakBadge = false;
  int _redWins = 0;
  int _blackWins = 0;
  int _draws = 0;
  bool _wasNewBest = false;
  bool _isFavorite = false;
  bool _firstRoundOfSession = true;
  String _starter = 'red';
  bool _celebrating = false;
  String? _bannerLabel;
  Color _bannerColor = _kDrawColor;
  bool _showWinBanner = false;

  bool _undoUsedThisRound = false;
  bool _inUndoWindow = false;
  List<int>? _boardBeforeHumanMove;
  int _redCountBeforeMove = 12;
  int _blackCountBeforeMove = 12;

  final _rng = math.Random();
  final _audio = AudioService();
  Timer? _aiMoveTimer;
  Timer? _endGameTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kCheckersGameId);
  }

  @override
  void dispose() {
    _aiMoveTimer?.cancel();
    _endGameTimer?.cancel();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  void _initBoard() {
    _board = List.filled(64, 0);
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c) % 2 == 1) _board[r * 8 + c] = 2;
      }
    }
    for (int r = 5; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c) % 2 == 1) _board[r * 8 + c] = 1;
      }
    }
    _redCount = 12;
    _blackCount = 12;
  }

  void _selectMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _redWins = 0;
      _blackWins = 0;
      _draws = 0;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _firstRoundOfSession = true;
    });
    _resetBoard();
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: mode == _Mode.ai ? 'ai' : '2_player',
      subKey: _aiSubKey(),
    );
    _wrapper.startGame();
  }

  void _changeMode() {
    setState(() {
      _mode = null;
      _redWins = 0;
      _blackWins = 0;
      _draws = 0;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _firstRoundOfSession = true;
    });
    _wrapper.restartGame();
  }

  void _playAgain() {
    _resetBoard();
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: _mode == _Mode.ai ? 'ai' : '2_player',
      subKey: _aiSubKey(),
    );
    _wrapper.restartGame();
    _wrapper.startGame();
  }

  void _resetBoard() {
    _aiMoveTimer?.cancel();
    _endGameTimer?.cancel();
    setState(() {
      _initBoard();
      if (_firstRoundOfSession) {
        _starter = _rng.nextBool() ? 'red' : 'black';
        _firstRoundOfSession = false;
      } else {
        _starter = _starter == 'red' ? 'black' : 'red';
      }
      _currentPlayer = _starter == 'red' ? 1 : 2;
      _gameOver = false;
      _winner = null;
      _aiThinking = false;
      _selectedCell = null;
      _validMoves = [];
      _jumpMoves = [];
      _wasNewBest = false;
      _showStreakBadge = false;
      _celebrating = false;
      _showWinBanner = false;
      _bannerLabel = null;
      _undoUsedThisRound = false;
      _inUndoWindow = false;
      _boardBeforeHumanMove = null;
    });
    if (_mode == _Mode.ai && _currentPlayer == 2) {
      _scheduleAiMove();
    }
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      ScoreService().toggleFavorite(kCheckersGameId);
    });
    _audio.playTap();
  }

  void _backOrHome() {
    _wrapper.handleExit(() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  void _showHelp() {
    final game = GameRegistry.getById(kCheckersGameId);
    if (game == null) return;
    showHowToPlaySheet(
      context,
      title: game.name,
      howToPlay: game.howToPlay,
      accent: _kAiColor,
      steps: checkersSteps(),
      gameId: kCheckersGameId,
    );
  }

  // ── Undo ──

  bool get _canUndo => _inUndoWindow && !_gameOver;

  void _onUndoExpired() {
    if (!mounted || _gameOver || !_inUndoWindow) return;
    setState(() => _inUndoWindow = false);
    _scheduleAiMove();
  }

  void _performUndo() {
    final saved = _boardBeforeHumanMove;
    if (saved == null) return;
    setState(() {
      _board = List.from(saved);
      _redCount = _redCountBeforeMove;
      _blackCount = _blackCountBeforeMove;
      _currentPlayer = 1;
      _inUndoWindow = false;
      _undoUsedThisRound = true;
      _boardBeforeHumanMove = null;
      _selectedCell = null;
      _validMoves = [];
      _jumpMoves = [];
    });
  }

  void _saveStateForUndo() {
    if (_mode != _Mode.ai || _undoUsedThisRound || _currentPlayer != 1) return;
    _boardBeforeHumanMove = List.from(_board);
    _redCountBeforeMove = _redCount;
    _blackCountBeforeMove = _blackCount;
  }

  // ── Game Logic ──

  bool _isPlayerPiece(int cell, int player) {
    if (player == 1) return cell == 1 || cell == 3;
    return cell == 2 || cell == 4;
  }

  List<int> _getValidMoves(int pos) {
    final piece = _board[pos];
    if (piece == 0) return [];
    final r = pos ~/ 8;
    final c = pos % 8;
    final moves = <int>[];
    final dirs = <List<int>>[];

    if (piece == 1 || piece == 3) dirs.addAll([[-1, -1], [-1, 1]]);
    if (piece == 2 || piece == 4) dirs.addAll([[1, -1], [1, 1]]);

    for (final d in dirs) {
      final nr = r + d[0];
      final nc = c + d[1];
      if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && _board[nr * 8 + nc] == 0) {
        moves.add(nr * 8 + nc);
      }
    }
    return moves;
  }

  List<int> _getJumpMoves(int pos) {
    final piece = _board[pos];
    if (piece == 0) return [];
    final r = pos ~/ 8;
    final c = pos % 8;
    final player = (piece == 1 || piece == 3) ? 1 : 2;
    final jumps = <int>[];
    final dirs = <List<int>>[];

    if (piece == 1 || piece == 3) dirs.addAll([[-1, -1], [-1, 1]]);
    if (piece == 2 || piece == 4) dirs.addAll([[1, -1], [1, 1]]);

    for (final d in dirs) {
      final mr = r + d[0];
      final mc = c + d[1];
      final jr = r + d[0] * 2;
      final jc = c + d[1] * 2;
      if (jr >= 0 && jr < 8 && jc >= 0 && jc < 8) {
        final mid = _board[mr * 8 + mc];
        if (mid != 0 && !_isPlayerPiece(mid, player) && _board[jr * 8 + jc] == 0) {
          jumps.add(jr * 8 + jc);
        }
      }
    }
    return jumps;
  }

  bool _playerHasJumps(int player) {
    for (int i = 0; i < 64; i++) {
      if (_isPlayerPiece(_board[i], player) && _getJumpMoves(i).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _playerHasMoves(int player) {
    for (int i = 0; i < 64; i++) {
      if (_isPlayerPiece(_board[i], player)) {
        if (_getValidMoves(i).isNotEmpty || _getJumpMoves(i).isNotEmpty) return true;
      }
    }
    return false;
  }

  void _onCellTap(int pos) {
    if (_gameOver || _aiThinking || _inUndoWindow) return;
    if (_mode == _Mode.ai && _currentPlayer == 2) return;

    final piece = _board[pos];
    final mustJump = _playerHasJumps(_currentPlayer);

    if (_isPlayerPiece(piece, _currentPlayer)) {
      final jumps = _getJumpMoves(pos);
      if (mustJump && jumps.isEmpty) return;
      setState(() {
        _selectedCell = pos;
        _jumpMoves = jumps;
        _validMoves = mustJump ? [] : _getValidMoves(pos);
      });
      _audio.playTap();
      return;
    }

    if (_selectedCell != null) {
      if (_jumpMoves.contains(pos)) {
        _saveStateForUndo();
        _performJump(_selectedCell!, pos, isHumanInitiated: _currentPlayer == 1);
      } else if (!mustJump && _validMoves.contains(pos)) {
        _saveStateForUndo();
        _performMove(_selectedCell!, pos, isHumanInitiated: true);
      }
    }
  }

  void _performMove(int from, int to, {bool isHumanInitiated = false}) {
    setState(() {
      _board[to] = _board[from];
      _board[from] = 0;
      _promoteIfNeeded(to);
      _selectedCell = null;
      _validMoves = [];
      _jumpMoves = [];
    });
    _audio.playTap();
    _checkGameEnd();
    if (!_gameOver) {
      _afterHumanMove(isHumanInitiated);
    }
  }

  void _performJump(int from, int to, {bool isHumanInitiated = false}) {
    final midR = (from ~/ 8 + to ~/ 8) ~/ 2;
    final midC = (from % 8 + to % 8) ~/ 2;
    final captured = _board[midR * 8 + midC];

    setState(() {
      _board[to] = _board[from];
      _board[from] = 0;
      _board[midR * 8 + midC] = 0;
      if (_isPlayerPiece(captured, 2)) {
        _blackCount--;
      } else {
        _redCount--;
      }
      _promoteIfNeeded(to);
    });
    _audio.playScore();

    final moreJumps = _getJumpMoves(to);
    if (moreJumps.isNotEmpty) {
      setState(() {
        _selectedCell = to;
        _jumpMoves = moreJumps;
        _validMoves = [];
      });
      if (_mode == _Mode.ai && _currentPlayer == 2) {
        _aiMoveTimer?.cancel();
        _aiMoveTimer = Timer(const Duration(milliseconds: 400), () {
          if (!mounted || _gameOver) return;
          _aiJumpChain(to);
        });
      }
      return;
    }

    setState(() {
      _selectedCell = null;
      _validMoves = [];
      _jumpMoves = [];
    });
    _checkGameEnd();
    if (!_gameOver) {
      _afterHumanMove(isHumanInitiated);
    }
  }

  void _afterHumanMove(bool isHumanInitiated) {
    if (isHumanInitiated && _mode == _Mode.ai) {
      final undoAvail = !_undoUsedThisRound && AdsService().isRewardedReady;
      if (undoAvail) {
        setState(() {
          _currentPlayer = 2;
          _inUndoWindow = true;
        });
        return;
      }
    }
    _switchTurn();
  }

  void _promoteIfNeeded(int pos) {
    final r = pos ~/ 8;
    if (_board[pos] == 1 && r == 0) _board[pos] = 3;
    if (_board[pos] == 2 && r == 7) _board[pos] = 4;
  }

  void _switchTurn() {
    setState(() {
      _currentPlayer = _currentPlayer == 1 ? 2 : 1;
    });
    if (_mode == _Mode.ai && _currentPlayer == 2 && !_gameOver) {
      _scheduleAiMove();
    }
  }

  void _checkGameEnd() {
    if (_redCount == 0) {
      _onWin(2);
    } else if (_blackCount == 0) {
      _onWin(1);
    } else if (!_playerHasMoves(1) && !_playerHasMoves(2)) {
      _onDraw();
    } else if (!_playerHasMoves(_currentPlayer == 1 ? 2 : 1) && _selectedCell == null) {
      // next player can't move
    } else if (!_playerHasMoves(_currentPlayer) && _selectedCell == null) {
      _onWin(_currentPlayer == 1 ? 2 : 1);
    }
  }

  void _onWin(int winner) {
    final isAi = _mode == _Mode.ai;
    final winnerLabel = winner == 1 ? 'red' : 'black';
    setState(() {
      _gameOver = true;
      _winner = winner;
      _showWinBanner = true;
      _celebrating = true;
      if (winner == 1) {
        _redWins++;
        _bannerLabel = isAi ? 'You Win!' : 'Player 1 Wins!';
        _bannerColor = _kRedColor;
      } else {
        _blackWins++;
        _bannerLabel = isAi ? 'AI Wins!' : 'Player 2 Wins!';
        _bannerColor = _kBlackColor;
      }
      if (_streakOwner == winnerLabel) {
        _streak++;
      } else {
        _streakOwner = winnerLabel;
        _streak = 1;
      }
      _showStreakBadge = _streak >= 2;
    });

    if (isAi && winner == 1) {
      final subKey = _aiSubKey();
      if (subKey != null) {
        ScoreService()
            .saveScore(kCheckersGameId, _streak, subKey: subKey)
            .then((isNew) {
          if (mounted && isNew) setState(() => _wasNewBest = true);
        });
      }
    } else {
      _wasNewBest = false;
    }

    if (isAi && winner == 1) _wrapper.updateScore(_streak);

    final gameResult = isAi ? (winner == 1 ? 'win' : 'loss') : 'win';
    _audio.playSuccess();
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) _wrapper.endGame(result: gameResult);
    });
  }

  void _onDraw() {
    setState(() {
      _gameOver = true;
      _winner = null;
      _wasNewBest = false;
      _draws++;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _showWinBanner = true;
      _bannerLabel = "It's a Draw!";
      _bannerColor = _kDrawColor;
    });
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _wrapper.endGame(result: 'draw');
    });
  }

  String? _aiSubKey() {
    if (_mode != _Mode.ai) return null;
    return switch (_difficulty) {
      _Difficulty.easy => kCheckersSubKeyEasy,
      _Difficulty.medium => kCheckersSubKeyMedium,
      _Difficulty.hard => kCheckersSubKeyHard,
    };
  }

  // ── AI ──

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    final thinkMs = switch (_difficulty) {
      _Difficulty.easy => 600,
      _Difficulty.medium => 900,
      _Difficulty.hard => 1200,
    };
    _aiMoveTimer?.cancel();
    _aiMoveTimer = Timer(Duration(milliseconds: thinkMs), () {
      if (!mounted || _gameOver) return;
      _performAiMove();
    });
  }

  void _performAiMove() {
    final mustJump = _playerHasJumps(2);
    final allMoves = <(int, int, bool)>[];

    for (int i = 0; i < 64; i++) {
      if (!_isPlayerPiece(_board[i], 2)) continue;
      if (mustJump) {
        for (final j in _getJumpMoves(i)) {
          allMoves.add((i, j, true));
        }
      } else {
        for (final m in _getValidMoves(i)) {
          allMoves.add((i, m, false));
        }
      }
    }

    if (allMoves.isEmpty) {
      setState(() => _aiThinking = false);
      _onWin(1);
      return;
    }

    (int, int, bool) chosen;
    switch (_difficulty) {
      case _Difficulty.easy:
        chosen = allMoves[_rng.nextInt(allMoves.length)];
      case _Difficulty.medium:
        chosen = _pickSmartMove(allMoves, randomFactor: 0.3);
      case _Difficulty.hard:
        chosen = _pickSmartMove(allMoves, randomFactor: 0.1);
    }

    setState(() => _aiThinking = false);

    if (chosen.$3) {
      _performJump(chosen.$1, chosen.$2);
    } else {
      _performMove(chosen.$1, chosen.$2);
    }
  }

  void _aiJumpChain(int pos) {
    final jumps = _getJumpMoves(pos);
    if (jumps.isEmpty) {
      setState(() {
        _selectedCell = null;
        _validMoves = [];
        _jumpMoves = [];
      });
      _checkGameEnd();
      if (!_gameOver) _switchTurn();
      return;
    }
    final target = jumps[_rng.nextInt(jumps.length)];
    _performJump(pos, target);
  }

  (int, int, bool) _pickSmartMove(List<(int, int, bool)> moves, {required double randomFactor}) {
    if (_rng.nextDouble() < randomFactor) {
      return moves[_rng.nextInt(moves.length)];
    }

    int bestScore = -9999;
    var bestMove = moves.first;

    for (final move in moves) {
      int score = 0;
      final (from, to, isJump) = move;
      if (isJump) score += 10;
      final toR = to ~/ 8;
      if (toR == 7) score += 15;
      if (_board[from] == 4) score += 3;
      final toC = to % 8;
      if (toC == 0 || toC == 7) score += 2;
      if (toR == 0 || toR == 7) score += 2;
      score += _rng.nextInt(3);

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    return bestMove;
  }

  // ── Helpers ──

  String _diffLabel(_Difficulty d) => switch (d) {
    _Difficulty.easy => 'EASY',
    _Difficulty.medium => 'MEDIUM',
    _Difficulty.hard => 'HARD',
  };

  Color _diffColor(_Difficulty d) => switch (d) {
    _Difficulty.easy => _kEasyColor,
    _Difficulty.medium => _kMediumColor,
    _Difficulty.hard => _kHardColor,
  };

  DifficultyKind _kindFor(_Difficulty d) => switch (d) {
    _Difficulty.easy => DifficultyKind.easy,
    _Difficulty.medium => DifficultyKind.medium,
    _Difficulty.hard => DifficultyKind.hard,
  };

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final state = _wrapper.state;
    if (state == GameState.ready || _mode == null) return _buildPicker();
    if (state == GameState.gameOver) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAiColor, icon: Icons.grid_on_rounded),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [Color(0xFF8B5E3C), Color(0xFFE53935), Color(0xFF8B5E3C)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kCheckersGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(borderRadius: BorderRadius.circular(42), child: logo);
        }
        return const Icon(Icons.grid_on_rounded, size: 40, color: _kAiColor);
      }),
      title: 'Checkers',
      subtitle: 'Jump, capture, and crown your kings!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kCheckersGameId,
      body: GameAiPickerBody(
        difficulties: _Difficulty.values.map((d) {
          final subKey = switch (d) {
            _Difficulty.easy => kCheckersSubKeyEasy,
            _Difficulty.medium => kCheckersSubKeyMedium,
            _Difficulty.hard => kCheckersSubKeyHard,
          };
          return GameDifficultyData(
            label: _diffLabel(d),
            color: _diffColor(d),
            kind: _kindFor(d),
            hint: switch (d) {
              _Difficulty.easy => 'Mostly random — easy to beat.',
              _Difficulty.medium => 'Picks smart captures when possible.',
              _Difficulty.hard => 'Aggressive and strategic — good luck!',
            },
            bestScore: bestCheckersStreak(subKey),
            bestLabel: (s) => 'Best $s in a row',
          );
        }).toList(),
        activeIndex: _Difficulty.values.indexOf(_difficulty),
        onChanged: (i) => setState(() => _difficulty = _Difficulty.values[i]),
        onPlayAi: () => _selectMode(_Mode.ai),
        onPlayFriend: () => _selectMode(_Mode.twoPlayer),
        aiGradient: const [Color(0xFF8B5E3C), Color(0xFFA97B5C)],
        friendGradient: const [Color(0xFFE53935), Color(0xFFFF6F61)],
      ),
    );
  }

  Widget _buildGame() {
    final isAi = _mode == _Mode.ai;
    final isRedTurn = _currentPlayer == 1 || _inUndoWindow;
    final topColor = _showWinBanner ? _kBgTop : (isRedTurn ? _kTintRedTop : _kTintBlackTop);
    final botColor = _showWinBanner ? _kBgBot : (isRedTurn ? _kTintRedBot : _kTintBlackBot);

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      tween: ColorTween(end: topColor),
      builder: (context, animTop, _) {
        return TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          tween: ColorTween(end: botColor),
          builder: (context, animBot, _) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [animTop ?? topColor, animBot ?? botColor],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    GameHudBar(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      leading: GameBackButton(onTap: _backOrHome),
                      centerContent: _ScoreBoardPill(
                        mode: _mode!,
                        difficulty: _difficulty,
                        redWins: _redWins,
                        blackWins: _blackWins,
                      ),
                      trailing: GameRestartButton(
                        gameName: 'Checkers',
                        accentColor: _kAiColor,
                        onRestart: _playAgain,
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: _showStreakBadge
                          ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _StreakBadge(streak: _streak),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PlayerStrip(
                        label: isAi ? 'AI' : 'Player 2',
                        mark: '●',
                        color: _kBlackColor,
                        isActive: _currentPlayer == 2 && !_inUndoWindow && !_showWinBanner,
                        isThinking: _aiThinking,
                        avatarIcon: isAi ? Icons.smart_toy_rounded : null,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final boardSize = constraints.maxWidth;
                                return Stack(
                                  children: [
                                    _BoardWidget(
                                      board: _board,
                                      boardSize: boardSize,
                                      selectedCell: _selectedCell,
                                      validMoves: _validMoves,
                                      jumpMoves: _jumpMoves,
                                      onCellTap: _onCellTap,
                                    ),
                                    if (_celebrating)
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: _Confetti(color: _bannerColor),
                                        ),
                                      ),
                                    if (_showWinBanner && _bannerLabel != null)
                                      Positioned.fill(
                                        child: Center(
                                          child: _WinBanner(
                                            label: _bannerLabel!,
                                            color: _bannerColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PlayerStrip(
                        label: isAi ? 'You' : 'Player 1',
                        mark: '●',
                        color: _kRedColor,
                        isActive: (_currentPlayer == 1 || _inUndoWindow) && !_showWinBanner,
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: _canUndo
                          ? Center(
                              child: RewardedUndoButton(
                                key: ValueKey('undo_${_board.join()}'),
                                onUndo: _performUndo,
                                onExpired: _onUndoExpired,
                                accentColor: _kRedColor,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResult() {
    final isAi = _mode == _Mode.ai;
    String headline;
    String big;
    Color bigColor;
    if (_winner == 1) {
      headline = isAi ? 'You Win!' : 'Player 1 Wins!';
      big = '🏆';
      bigColor = _kRedColor;
    } else if (_winner == 2) {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = '🤖';
      bigColor = _kBlackColor;
    } else {
      headline = "It's a Draw!";
      big = '=';
      bigColor = _kDrawColor;
    }

    final showStreak = _streak >= 2 && ((_winner == 1 && _streakOwner == 'red') || (_winner == 2 && _streakOwner == 'black'));
    final extraBadges = <Widget>[
      if (showStreak) _StreakBadge(streak: _streak),
      if (_wasNewBest) const _NewBestBadge(),
    ];

    return game_result.GenericGameResultScreen(
      gameId: kCheckersGameId,
      score: _streak,
      headline: headline,
      badgeContent: big,
      badgeColor: bigColor,
      showNewBestBadge: false,
      extraBadges: extraBadges,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: isAi ? 'YOU' : 'P1', value: _redWins, color: _kRedColor),
          game_result.StatItem(label: 'DRAWS', value: _draws, color: const Color(0xFF8B7BA7)),
          game_result.StatItem(label: isAi ? 'AI' : 'P2', value: _blackWins, color: _kBlackColor),
          if (isAi)
            game_result.StatItem(
              label: 'BEST',
              value: ScoreService().getHighScore(kCheckersGameId, subKey: _aiSubKey()),
              color: const Color(0xFF6C63FF),
            ),
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _playAgain,
          filled: true,
          color: _kAiColor,
          actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Mode',
          icon: Icons.swap_horiz_rounded,
          onTap: _changeMode,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: _backOrHome,
          actionId: 'home',
        ),
      ],
    );
  }
}

// ── Score Board Pill (with difficulty tab) ──

class _ScoreBoardPill extends StatelessWidget {
  final _Mode mode;
  final _Difficulty difficulty;
  final int redWins;
  final int blackWins;

  const _ScoreBoardPill({
    required this.mode,
    required this.difficulty,
    required this.redWins,
    required this.blackWins,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
    final leftLabel = isAi ? 'YOU' : 'P1';
    final rightLabel = isAi ? 'AI' : 'P2';
    final tabLabel = isAi
        ? switch (difficulty) {
            _Difficulty.easy => 'EASY',
            _Difficulty.medium => 'MEDIUM',
            _Difficulty.hard => 'HARD',
          }
        : 'PASS & PLAY';
    final tabColor = isAi
        ? switch (difficulty) {
            _Difficulty.easy => _kEasyColor,
            _Difficulty.medium => _kMediumColor,
            _Difficulty.hard => _kHardColor,
          }
        : const Color(0xFF8B7558);
    final diffKind = switch (difficulty) {
      _Difficulty.easy => DifficultyKind.easy,
      _Difficulty.medium => DifficultyKind.medium,
      _Difficulty.hard => DifficultyKind.hard,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: tabColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(
                color: tabColor.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAi) ...[
                AnimatedDifficultyIcon(kind: diffKind, size: 14, prominent: false),
                const SizedBox(width: 6),
              ],
              Text(
                tabLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kAiColor.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _scoreColumn(leftLabel, redWins, _kRedColor),
                  const SizedBox(width: 14),
                  const Text('VS', style: TextStyle(color: Color(0xFF8B7BA7), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(width: 14),
                  _scoreColumn(rightLabel, blackWins, _kBlackColor),
                ],
              ),
              if (isAi) _bestLabel(difficulty),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bestLabel(_Difficulty d) {
    final subKey = switch (d) {
      _Difficulty.easy => kCheckersSubKeyEasy,
      _Difficulty.medium => kCheckersSubKeyMedium,
      _Difficulty.hard => kCheckersSubKeyHard,
    };
    final best = ScoreService().getHighScore(kCheckersGameId, subKey: subKey);
    if (best <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('best $best',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _scoreColumn(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '$value',
            key: ValueKey<int>(value),
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, height: 1),
          ),
        ),
      ],
    );
  }
}

// ── Streak Badge ──

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFB36B), Color(0xFFFF7A89)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFFFF7A89).withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text('Streak $streak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}

// ── New Best Badge ──

class _NewBestBadge extends StatelessWidget {
  const _NewBestBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFC233), Color(0xFFFF8A00)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFFFF9500).withValues(alpha: 0.40), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
          SizedBox(width: 6),
          Text('New best!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}

// ── Win Banner ──

class _WinBanner extends StatelessWidget {
  final String label;
  final Color color;
  const _WinBanner({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
    );
  }
}

// ── Confetti burst on win ──

class _Confetti extends StatefulWidget {
  final Color color;
  const _Confetti({required this.color});
  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_ConfettiParticle> _particles;
  static final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _particles = List.generate(36, (i) {
      return _ConfettiParticle(
        angle: (i / 36) * math.pi * 2 + _rng.nextDouble() * 0.5,
        speed: 0.55 + _rng.nextDouble() * 0.35,
        size: 3.0 + _rng.nextDouble() * 4.0,
        hueShift: _rng.nextDouble(),
      );
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        painter: _ConfettiPainter(progress: _ctrl.value, particles: _particles, baseColor: widget.color),
      ),
    );
  }
}

class _ConfettiParticle {
  final double angle, speed, size, hueShift;
  _ConfettiParticle({required this.angle, required this.speed, required this.size, required this.hueShift});
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;
  final Color baseColor;
  _ConfettiPainter({required this.progress, required this.particles, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide * 0.55;
    final eased = Curves.easeOutCubic.transform(progress.clamp(0, 1));
    final alpha = (1 - progress).clamp(0.0, 1.0);
    for (final p in particles) {
      final r = maxR * eased * p.speed;
      final pos = center + Offset(math.cos(p.angle), math.sin(p.angle)) * r;
      final hsl = HSLColor.fromColor(baseColor);
      final colored = hsl.withLightness((hsl.lightness + (p.hueShift - 0.5) * 0.35).clamp(0.35, 0.85)).toColor().withValues(alpha: alpha);
      canvas.drawCircle(pos, p.size * (0.5 + alpha * 0.5), Paint()..color = colored);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}

// ── Board Widget ──

class _BoardWidget extends StatelessWidget {
  final List<int> board;
  final double boardSize;
  final int? selectedCell;
  final List<int> validMoves;
  final List<int> jumpMoves;
  final ValueChanged<int> onCellTap;

  const _BoardWidget({
    required this.board,
    required this.boardSize,
    required this.selectedCell,
    required this.validMoves,
    required this.jumpMoves,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final cellSize = boardSize / 8;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3E2723), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: boardSize,
          height: boardSize,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(boardSize, boardSize),
                painter: _BoardBgPainter(
                  selectedCell: selectedCell,
                  validMoves: validMoves,
                  jumpMoves: jumpMoves,
                ),
              ),
              for (int i = 0; i < 64; i++)
                if (board[i] != 0)
                  _AnimatedPiece(
                    key: ValueKey('piece_${board[i]}_$i'),
                    cellSize: cellSize,
                    pos: i,
                    piece: board[i],
                    isSelected: selectedCell == i,
                  ),
              for (int i = 0; i < 64; i++)
                Positioned(
                  left: (i % 8) * cellSize,
                  top: (i ~/ 8) * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: GestureDetector(
                    onTap: () => onCellTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated Piece ──

class _AnimatedPiece extends StatelessWidget {
  final double cellSize;
  final int pos;
  final int piece;
  final bool isSelected;

  const _AnimatedPiece({
    super.key,
    required this.cellSize,
    required this.pos,
    required this.piece,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final r = pos ~/ 8;
    final c = pos % 8;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      left: c * cellSize,
      top: r * cellSize,
      width: cellSize,
      height: cellSize,
      child: AnimatedScale(
        scale: isSelected ? 1.12 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Center(
          child: SizedBox(
            width: cellSize * 0.78,
            height: cellSize * 0.78,
            child: CustomPaint(
              painter: _PiecePainter(
                color: (piece == 1 || piece == 3) ? _kRedColor : const Color(0xFF333333),
                isKing: piece == 3 || piece == 4,
                isSelected: isSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PiecePainter extends CustomPainter {
  final Color color;
  final bool isKing;
  final bool isSelected;
  _PiecePainter({required this.color, required this.isKing, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.42;

    if (isSelected) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius + 3,
        Paint()
          ..color = Colors.amber.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.drawCircle(Offset(cx, cy + 2.5), radius, Paint()..color = Colors.black.withValues(alpha: 0.22));

    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      colors: [
        Color.lerp(color, Colors.white, 0.25)!,
        color,
        Color.lerp(color, Colors.black, 0.15)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()..shader = gradient.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.72,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(
      Offset(cx - radius * 0.25, cy - radius * 0.3),
      radius * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    if (isKing) {
      final crownPaint = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final s = radius * 0.45;
      canvas.drawLine(Offset(cx - s, cy + s * 0.2), Offset(cx - s * 0.5, cy - s * 0.5), crownPaint);
      canvas.drawLine(Offset(cx - s * 0.5, cy - s * 0.5), Offset(cx, cy + s * 0.2), crownPaint);
      canvas.drawLine(Offset(cx, cy + s * 0.2), Offset(cx + s * 0.5, cy - s * 0.5), crownPaint);
      canvas.drawLine(Offset(cx + s * 0.5, cy - s * 0.5), Offset(cx + s, cy + s * 0.2), crownPaint);
    }
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.color != color || old.isKing != isKing || old.isSelected != isSelected;
}

// ── Board Background Painter (squares + move hints, no pieces) ──

class _BoardBgPainter extends CustomPainter {
  final int? selectedCell;
  final List<int> validMoves;
  final List<int> jumpMoves;

  _BoardBgPainter({
    required this.selectedCell,
    required this.validMoves,
    required this.jumpMoves,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 8;

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final isDark = (r + c) % 2 == 1;
        final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
        canvas.drawRect(rect, Paint()..color = isDark ? _kBoardDark : _kBoardLight);
      }
    }

    if (selectedCell != null) {
      final r = selectedCell! ~/ 8;
      final c = selectedCell! % 8;
      final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, Paint()..color = Colors.amber.withValues(alpha: 0.35));
    }

    for (final m in validMoves) {
      final r = m ~/ 8;
      final c = m % 8;
      final cx = (c + 0.5) * cellSize;
      final cy = (r + 0.5) * cellSize;
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.16, Paint()..color = Colors.green.withValues(alpha: 0.5));
    }

    for (final m in jumpMoves) {
      final r = m ~/ 8;
      final c = m % 8;
      final cx = (c + 0.5) * cellSize;
      final cy = (r + 0.5) * cellSize;
      canvas.drawCircle(Offset(cx, cy), cellSize * 0.16, Paint()..color = Colors.orange.withValues(alpha: 0.55));
      canvas.drawCircle(
        Offset(cx, cy),
        cellSize * 0.22,
        Paint()
          ..color = Colors.orange.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_BoardBgPainter old) => true;
}
