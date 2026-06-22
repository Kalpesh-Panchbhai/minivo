import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
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
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/game_picker_button.dart';
import 'ludo_stats.dart';
import 'ludo_tutorial.dart';

const Color _kRed = Color(0xFFE74C3C);
const Color _kGreen = Color(0xFF27AE60);
const Color _kBlue = Color(0xFF2980B9);
const Color _kYellow = Color(0xFFF1C40F);
const Color _kBgTop = Color(0xFFF8F6FF);
const Color _kBgBot = Color(0xFFEDE8F5);
const Color _kAccent = Color(0xFF6C5CE7);
const Color _kBoardBg = Color(0xFFF5F0E1);
const Color _kEasyColor = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor = Color(0xFFEF4444);

// Player indices: 0=Red(bottom-left), 1=Green(top-left), 2=Yellow(top-right), 3=Blue(bottom-right)
// AI mode: You=Red(0) vs AI=Yellow(2) — diagonal
const _kPlayerColors = [_kRed, _kGreen, _kYellow, _kBlue];
const _kPlayerNames = ['Red', 'Green', 'Yellow', 'Blue'];

enum _Mode { ai, multiplayer }
enum _Difficulty { easy, medium, hard }

const _kSafeSquares = <int>{0, 8, 13, 21, 26, 34, 39, 47};

const _kStartSquares = [0, 13, 26, 39];

const _kTrackSquares = 52;
const _kPathLength = 51;
const _kHomeLaneLength = 6;

List<int> _buildPath(int playerIndex) {
  final start = _kStartSquares[playerIndex];
  final mainPath = <int>[];
  for (int i = 0; i < _kPathLength; i++) {
    mainPath.add((start + i) % _kTrackSquares);
  }
  for (int i = 0; i < _kHomeLaneLength; i++) {
    mainPath.add(100 + playerIndex * 10 + i);
  }
  return mainPath;
}

final _kPaths = List.generate(4, _buildPath);

// Board square coordinates: (col, row) on 15x15 grid.
// Square 0 = Red start (col6,row13), clockwise around the board.
const _kSquareCoords = <List<int>>[
  [6, 13], [6, 12], [6, 11], [6, 10], [6, 9],
  [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8],
  [0, 7], [0, 6],
  [1, 6], [2, 6], [3, 6], [4, 6], [5, 6],
  [6, 5], [6, 4], [6, 3], [6, 2], [6, 1], [6, 0],
  [7, 0], [8, 0],
  [8, 1], [8, 2], [8, 3], [8, 4], [8, 5],
  [9, 6], [10, 6], [11, 6], [12, 6], [13, 6], [14, 6],
  [14, 7], [14, 8],
  [13, 8], [12, 8], [11, 8], [10, 8], [9, 8],
  [8, 9], [8, 10], [8, 11], [8, 12], [8, 13], [8, 14],
  [7, 14], [6, 14],
];

List<Offset> _homeSlotCenters(int player, double cell) {
  const homeOrigins = {0: [0.0, 9.0], 1: [0.0, 0.0], 2: [9.0, 0.0], 3: [9.0, 9.0]};
  final o = homeOrigins[player]!;
  final hx = o[0] * cell;
  final hy = o[1] * cell;
  final homeSize = cell * 6;
  final pad = homeSize * 0.15;
  final innerW = homeSize - pad * 2;
  return [
    Offset(hx + pad + innerW * 0.30, hy + pad + innerW * 0.30),
    Offset(hx + pad + innerW * 0.70, hy + pad + innerW * 0.30),
    Offset(hx + pad + innerW * 0.30, hy + pad + innerW * 0.70),
    Offset(hx + pad + innerW * 0.70, hy + pad + innerW * 0.70),
  ];
}

Offset _boardSquareCenter(int sq, double boardSize) {
  final cell = boardSize / 15;
  if (sq >= 100) {
    final player = (sq - 100) ~/ 10;
    final step = (sq - 100) % 10;
    // Home lanes lead toward center
    switch (player) {
      case 0: // Red: bottom-left, lane goes up col7
        return Offset(7 * cell + cell / 2, (13 - step) * cell + cell / 2);
      case 1: // Green: top-left, lane goes right row7
        return Offset((1 + step) * cell + cell / 2, 7 * cell + cell / 2);
      case 2: // Yellow: top-right, lane goes down col7
        return Offset(7 * cell + cell / 2, (1 + step) * cell + cell / 2);
      case 3: // Blue: bottom-right, lane goes left row7
        return Offset((13 - step) * cell + cell / 2, 7 * cell + cell / 2);
    }
  }

  if (sq < 0 || sq >= _kSquareCoords.length) {
    return Offset(7 * cell + cell / 2, 7 * cell + cell / 2);
  }
  final c = _kSquareCoords[sq][0];
  final r = _kSquareCoords[sq][1];
  return Offset(c * cell + cell / 2, r * cell + cell / 2);
}

class _Token {
  int player;
  int pathIndex;
  bool finished;
  int homeSlot;
  _Token(this.player, this.homeSlot) : pathIndex = -1, finished = false;

  bool get isHome => pathIndex == -1;
  bool get isOnBoard => pathIndex >= 0 && !finished;

  int get boardSquare {
    if (isHome || finished) return -1;
    return _kPaths[player][pathIndex];
  }
}

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});
  @override
  State<LudoScreen> createState() => LudoScreenState();
}

class LudoScreenState extends State<LudoScreen>
    with TickerProviderStateMixin {
  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  int _playerCount = 2;
  List<int> _activePlayers = [0, 2];

  late List<_Token> _tokens;
  int _currentPlayer = 0;
  bool _gameOver = false;
  int? _winner;
  List<int> _finishOrder = [];
  bool _aiThinking = false;
  int _dieValue = 0;
  bool _dieRolled = false;
  bool _rolling = false;
  int _consecutiveSixes = 0;
  List<int> _movableTokens = [];
  bool _isFavorite = false;
  int _streak = 0;
  String? _streakOwner;
  bool _wasNewBest = false;
  int _wins = 0;
  int _losses = 0;
  bool _celebrating = false;
  String? _bannerLabel;
  Color _bannerColor = _kAccent;
  bool _showWinBanner = false;
  final bool _triplesSixRule = true;

  final _rng = math.Random();
  final _audio = AudioService();
  Timer? _aiTimer;
  Timer? _endTimer;
  Timer? _rollAnimTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kLudoGameId);
    _tokens = [];
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _endTimer?.cancel();
    _rollAnimTimer?.cancel();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  bool _animating = false;

  void _initTokens() {
    _tokens = [];
    for (final p in _activePlayers) {
      for (int i = 0; i < 4; i++) {
        _tokens.add(_Token(p, i));
      }
    }
  }

  List<_Token> _tokensOf(int player) => _tokens.where((t) => t.player == player).toList();

  void _selectMode(_Mode mode, {int players = 2}) {
    setState(() {
      _mode = mode;
      if (mode == _Mode.ai) {
        _playerCount = 2;
        _activePlayers = [0, 2];
      } else {
        _playerCount = players;
        _activePlayers = switch (players) {
          2 => [0, 2],
          3 => [0, 1, 2],
          _ => [0, 1, 2, 3],
        };
      }
      _wins = 0;
      _losses = 0;
      _streak = 0;
      _streakOwner = null;
      _finishOrder = [];
    });
    _resetBoard();
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: mode == _Mode.ai ? 'ai' : '${players}p',
      subKey: _aiSubKey(),
    );
    _wrapper.startGame();
  }

  void _changeMode() {
    setState(() {
      _mode = null;
      _wins = 0;
      _losses = 0;
      _streak = 0;
      _streakOwner = null;
      _finishOrder = [];
    });
    _wrapper.restartGame();
  }

  void _playAgain() {
    _resetBoard();
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: _mode == _Mode.ai ? 'ai' : '${_playerCount}p',
      subKey: _aiSubKey(),
    );
    _wrapper.restartGame();
    _wrapper.startGame();
  }

  void _resetBoard() {
    _aiTimer?.cancel();
    _endTimer?.cancel();
    _rollAnimTimer?.cancel();
    setState(() {
      _initTokens();
      _currentPlayer = 0;
      _gameOver = false;
      _winner = null;
      _finishOrder = [];
      _aiThinking = false;
      _dieValue = 0;
      _dieRolled = false;
      _rolling = false;
      _consecutiveSixes = 0;
      _movableTokens = [];
      _animating = false;
      _wasNewBest = false;
      _celebrating = false;
      _showWinBanner = false;
      _bannerLabel = null;
    });
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      ScoreService().toggleFavorite(kLudoGameId);
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
    final game = GameRegistry.getById(kLudoGameId);
    if (game == null) return;
    showHowToPlaySheet(
      context,
      title: game.name,
      howToPlay: game.howToPlay,
      accent: _kAccent,
      steps: ludoSteps(),
      gameId: kLudoGameId,
    );
  }

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

  String _aiSubKey() => switch (_difficulty) {
    _Difficulty.easy => kLudoSubKeyEasy,
    _Difficulty.medium => kLudoSubKeyMedium,
    _Difficulty.hard => kLudoSubKeyHard,
  };

  bool get _isHumanTurn {
    if (_mode == _Mode.multiplayer) return true;
    return _currentPlayer == 0;
  }

  void _rollDie() {
    if (_rolling || _dieRolled || _gameOver || _animating) return;
    _rolling = true;
    _audio.playTap();
    final finalValue = 1 + _rng.nextInt(6);
    int ticks = 0;
    const totalTicks = 12;
    void doTick() {
      ticks++;
      if (ticks >= totalTicks) {
        setState(() {
          _dieValue = finalValue;
          _dieRolled = true;
          _rolling = false;
        });
        _afterRoll(finalValue);
        return;
      }
      setState(() => _dieValue = 1 + _rng.nextInt(6));
      final delay = 50 + (ticks * ticks * 2);
      _rollAnimTimer = Timer(Duration(milliseconds: delay), doTick);
    }
    doTick();
  }

  void _afterRoll(int value) {
    if (value == 6) {
      _consecutiveSixes++;
      if (_triplesSixRule && _consecutiveSixes >= 3) {
        setState(() {
          _consecutiveSixes = 0;
          _dieRolled = false;
          _dieValue = 0;
          _movableTokens = [];
        });
        _nextTurn();
        return;
      }
    } else {
      _consecutiveSixes = 0;
    }

    final movable = _getMovableTokenIndices(value);
    if (movable.isEmpty) {
      setState(() => _movableTokens = []);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || _gameOver) return;
        if (value != 6) {
          _nextTurn();
        } else {
          setState(() {
            _dieRolled = false;
            _dieValue = 0;
          });
        }
      });
      return;
    }

    if (movable.length == 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted || _gameOver) return;
        _moveToken(movable.first, value);
      });
      return;
    }

    setState(() => _movableTokens = movable);
    if (!_isHumanTurn) {
      _aiPickToken(movable, value);
    }
  }

  List<int> _getMovableTokenIndices(int dieValue) {
    final playerTokens = <int>[];
    for (int i = 0; i < _tokens.length; i++) {
      if (_tokens[i].player != _currentPlayer || _tokens[i].finished) continue;
      if (_tokens[i].isHome) {
        if (dieValue == 6) playerTokens.add(i);
      } else {
        final newIdx = _tokens[i].pathIndex + dieValue;
        final maxIdx = _kPathLength + _kHomeLaneLength - 1;
        if (newIdx <= maxIdx) {
          playerTokens.add(i);
        }
      }
    }
    return playerTokens;
  }

  void _onTokenTap(int tokenIndex) {
    if (_gameOver || !_dieRolled || _rolling || _animating) return;
    if (!_isHumanTurn) return;
    if (!_movableTokens.contains(tokenIndex)) return;
    _moveToken(tokenIndex, _dieValue);
  }

  Future<void> _moveToken(int tokenIndex, int dieValue) async {
    final token = _tokens[tokenIndex];

    setState(() {
      _movableTokens = [];
      _animating = true;
    });

    if (token.isHome && dieValue == 6) {
      token.pathIndex = 0;
      _audio.playTap();
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted || _gameOver) return;
      final captured = await _checkCaptureAnimated(token);
      _finishMove(token, dieValue, captured);
    } else if (token.isOnBoard) {
      final startIdx = token.pathIndex;
      final targetIdx = startIdx + dieValue;
      final maxIdx = _kPathLength + _kHomeLaneLength - 1;

      for (int step = startIdx + 1; step <= targetIdx && step <= maxIdx; step++) {
        token.pathIndex = step;
        _audio.playTap();
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 160));
        if (!mounted || _gameOver) return;
      }

      if (token.pathIndex == maxIdx) {
        token.finished = true;
        _audio.playScore();
        setState(() {});
        _finishMove(token, dieValue, false);
      } else {
        final captured = await _checkCaptureAnimated(token);
        _finishMove(token, dieValue, captured);
      }
    }
  }

  void _finishMove(_Token token, int dieValue, bool captured) {
    setState(() {
      _animating = false;
      _dieRolled = false;
      _dieValue = 0;
    });

    if (_checkWin()) return;

    final gotExtraTurn = dieValue == 6 || captured;
    if (gotExtraTurn) {
      setState(() => _dieRolled = false);
      if (!_isHumanTurn) {
        _scheduleAiRoll();
      }
    } else {
      _nextTurn();
    }
  }

  Future<bool> _checkCaptureAnimated(_Token mover) async {
    if (mover.finished || mover.isHome) return false;
    final sq = mover.boardSquare;
    if (sq >= 100) return false;
    if (_kSafeSquares.contains(sq)) return false;

    final victims = <_Token>[];
    for (final t in _tokens) {
      if (t.player == mover.player || t.finished || t.isHome) continue;
      if (t.boardSquare == sq) {
        victims.add(t);
      }
    }
    if (victims.isEmpty) return false;

    _audio.playScore();
    for (final v in victims) {
      final startIdx = v.pathIndex;
      for (int step = startIdx - 1; step >= 0; step -= 2) {
        v.pathIndex = step;
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return true;
      }
      v.pathIndex = -1;
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return true;
  }

  bool _checkWin() {
    for (final p in _activePlayers) {
      if (_finishOrder.contains(p)) continue;
      final allDone = _tokensOf(p).every((t) => t.finished);
      if (allDone) {
        _finishOrder.add(p);
        if (_finishOrder.length == 1) {
          _winner = p;
        }
      }
    }

    final total = _activePlayers.length;
    if (_finishOrder.length >= total - 1 || (_finishOrder.isNotEmpty && total == 2)) {
      _endGame();
      return true;
    }
    return false;
  }

  void _endGame() {
    _gameOver = true;
    final isAi = _mode == _Mode.ai;
    final humanWon = _winner == 0;

    if (isAi) {
      if (humanWon) {
        _wins++;
        if (_streakOwner == 'human') {
          _streak++;
        } else {
          _streakOwner = 'human';
          _streak = 1;
        }
        final subKey = _aiSubKey();
        final prev = ScoreService().getHighScore(kLudoGameId, subKey: subKey);
        if (_streak > prev) {
          ScoreService().saveScore(kLudoGameId, _streak, subKey: subKey);
          _wasNewBest = true;
        }
      } else {
        _losses++;
        _streakOwner = 'ai';
        _streak = 1;
      }
    }

    final label = humanWon
        ? (isAi ? 'You Win!' : '${_kPlayerNames[_winner!]} Wins!')
        : (isAi ? 'AI Wins!' : '${_kPlayerNames[_winner!]} Wins!');
    final color = _kPlayerColors[_winner ?? 0];

    setState(() {
      _bannerLabel = label;
      _bannerColor = color;
      _showWinBanner = true;
      _celebrating = true;
    });

    _endTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        _celebrating = false;
        _showWinBanner = false;
      });
      _wrapper.endGame(result: humanWon ? 'win' : 'loss');
    });
  }

  void _nextTurn() {
    if (_gameOver) return;
    final curIdx = _activePlayers.indexOf(_currentPlayer);
    int nextIdx = (curIdx + 1) % _activePlayers.length;
    int next = _activePlayers[nextIdx];
    while (_finishOrder.contains(next)) {
      nextIdx = (nextIdx + 1) % _activePlayers.length;
      next = _activePlayers[nextIdx];
      if (next == _currentPlayer) break;
    }
    setState(() {
      _currentPlayer = next;
      _dieRolled = false;
      _dieValue = 0;
      _consecutiveSixes = 0;
      _movableTokens = [];
    });
    if (!_isHumanTurn) {
      _scheduleAiRoll();
    }
  }

  void _scheduleAiRoll() {
    if (_gameOver) return;
    setState(() => _aiThinking = true);
    final delay = switch (_difficulty) {
      _Difficulty.easy => 700,
      _Difficulty.medium => 500,
      _Difficulty.hard => 400,
    };
    _aiTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _gameOver) return;
      setState(() => _aiThinking = false);
      _rollDie();
    });
  }

  void _aiPickToken(List<int> movable, int dieValue) {
    _aiTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _gameOver) return;
      final pick = _aiBestToken(movable, dieValue);
      _moveToken(pick, dieValue);
    });
  }

  int _aiBestToken(List<int> movable, int dieValue) {
    if (_difficulty == _Difficulty.easy) {
      return movable[_rng.nextInt(movable.length)];
    }

    int bestIdx = movable.first;
    int bestScore = -9999;

    for (final idx in movable) {
      final token = _tokens[idx];
      int score = 0;

      if (token.isHome && dieValue == 6) {
        score += 50;
      } else if (token.isOnBoard) {
        final newPathIdx = token.pathIndex + dieValue;
        final maxIdx = _kPathLength + _kHomeLaneLength - 1;

        if (newPathIdx == maxIdx) {
          score += 200;
        }

        if (newPathIdx < _kPathLength) {
          final newSq = _kPaths[token.player][newPathIdx];
          for (final t in _tokens) {
            if (t.player == token.player || t.finished || t.isHome) continue;
            if (t.boardSquare == newSq && !_kSafeSquares.contains(newSq)) {
              score += 100;
            }
          }
        }

        if (_difficulty == _Difficulty.hard) {
          if (newPathIdx >= _kPathLength) {
            score += 60;
          }
          final currentSq = token.boardSquare;
          if (currentSq < 100) {
            for (final t in _tokens) {
              if (t.player == token.player || t.finished || t.isHome) continue;
              if (t.boardSquare < 100) {
                final enemyPath = _kPaths[t.player];
                final enemyIdx = t.pathIndex;
                for (int d = 1; d <= 6; d++) {
                  if (enemyIdx + d < enemyPath.length && enemyPath[enemyIdx + d] == currentSq) {
                    score += 40;
                    break;
                  }
                }
              }
            }
          }
        }

        score += newPathIdx;
      }

      if (score > bestScore) {
        bestScore = score;
        bestIdx = idx;
      }
    }
    return bestIdx;
  }

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
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.casino_rounded),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [Color(0xFFE74C3C), Color(0xFF2980B9), Color(0xFFF1C40F)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kLudoGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) return logo;
        return const Icon(Icons.casino_rounded, size: 40, color: _kAccent);
      }),
      title: 'Ludo',
      subtitle: 'Roll, race, and conquer!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kLudoGameId,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameDifficultyCard(
            difficulties: _Difficulty.values.map((d) {
              final subKey = switch (d) {
                _Difficulty.easy => kLudoSubKeyEasy,
                _Difficulty.medium => kLudoSubKeyMedium,
                _Difficulty.hard => kLudoSubKeyHard,
              };
              return GameDifficultyData(
                label: _diffLabel(d),
                color: _diffColor(d),
                kind: _kindFor(d),
                hint: switch (d) {
                  _Difficulty.easy => 'AI picks randomly.',
                  _Difficulty.medium => 'AI plays smart.',
                  _Difficulty.hard => 'AI plays to win — good luck!',
                },
                bestScore: bestLudoStreak(subKey),
                bestLabel: (s) => 'Best $s in a row',
              );
            }).toList(),
            activeIndex: _Difficulty.values.indexOf(_difficulty),
            onChanged: (i) => setState(() => _difficulty = _Difficulty.values[i]),
            eyebrowIcon: Icons.tune_rounded,
            eyebrowLabel: 'AI DIFFICULTY',
            accentColor: _kAccent,
          ),
          GamePickerButton(
            label: 'Play vs. AI',
            sublabel: 'Single player',
            icon: Icons.smart_toy_rounded,
            gradientColors: const [Color(0xFF6C5CE7), Color(0xFF8B72F8)],
            onTap: () => _selectMode(_Mode.ai),
            topRadius: 0,
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 320.ms)
              .slideY(begin: 0.08, end: 0, duration: 320.ms),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniPickerButton(
                  label: '2P',
                  icon: Icons.people_alt_rounded,
                  color: _kRed,
                  onTap: () => _selectMode(_Mode.multiplayer, players: 2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniPickerButton(
                  label: '3P',
                  icon: Icons.groups_2_rounded,
                  color: _kGreen,
                  onTap: () => _selectMode(_Mode.multiplayer, players: 3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniPickerButton(
                  label: '4P',
                  icon: Icons.groups_3_rounded,
                  color: _kBlue,
                  onTap: () => _selectMode(_Mode.multiplayer, players: 4),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(delay: 280.ms, duration: 320.ms)
              .slideY(begin: 0.08, end: 0, duration: 320.ms),
        ],
      ),
    );
  }

  bool get _isDiceTop => _currentPlayer == 1 || _currentPlayer == 2;

  Alignment _diceAlignment(int player) => switch (player) {
    0 => Alignment.centerLeft,
    1 => Alignment.centerLeft,
    2 => Alignment.centerRight,
    3 => Alignment.centerRight,
    _ => Alignment.center,
  };

  Widget _buildDice() {
    final color = _kPlayerColors[_currentPlayer];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: _diceAlignment(_currentPlayer),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: SizedBox(
            key: ValueKey(_currentPlayer),
            width: 48,
            height: 48,
            child: _DieWidget(
              value: _dieValue,
              rolling: _rolling,
              canRoll: _isHumanTurn && !_dieRolled && !_rolling && !_gameOver && !_aiThinking && !_animating,
              onRoll: _rollDie,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBgTop, _kBgBot],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 4),
            GameHudBar(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              leading: GameBackButton(onTap: _backOrHome),
              centerContent: _ScorePill(
                mode: _mode!,
                difficulty: _difficulty,
                wins: _wins,
                losses: _losses,
              ),
              trailing: GameRestartButton(
                gameName: 'Ludo',
                accentColor: _kAccent,
                onRestart: _playAgain,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Two 48px dice rows + their 4px gaps sit above and below
                      // the square board. Size the board to the SMALLER of the
                      // available width (capped at 600) and the leftover height
                      // so the column never overflows on short/wide screens
                      // (e.g. unfolded foldables) or small phones.
                      const diceReserve = 48.0 * 2 + 4.0 * 2;
                      final maxW = math.min(constraints.maxWidth, 600.0);
                      final boardSize = math
                          .max(0.0, math.min(maxW, constraints.maxHeight - diceReserve));
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedOpacity(
                            opacity: _isDiceTop ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: IgnorePointer(
                              ignoring: !_isDiceTop,
                              child: _buildDice(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: boardSize,
                            height: boardSize,
                            child: Stack(
                              children: [
                                CustomPaint(
                                  size: Size(boardSize, boardSize),
                                  painter: _LudoBoardPainter(_finishOrder),
                                ),
                                ..._buildTokenWidgets(boardSize),
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
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedOpacity(
                            opacity: !_isDiceTop ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: IgnorePointer(
                              ignoring: _isDiceTop,
                              child: _buildDice(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Offset _stackOffset(int myIdx, int total, double cell) {
    if (total <= 1) return Offset.zero;
    final d = cell * 0.22;
    if (total == 2) {
      return [Offset(-d, 0), Offset(d, 0)][myIdx];
    }
    if (total == 3) {
      return [Offset(-d, d * 0.4), Offset(d, d * 0.4), Offset(0, -d * 0.6)][myIdx];
    }
    return [Offset(-d, -d * 0.5), Offset(d, -d * 0.5), Offset(-d, d * 0.5), Offset(d, d * 0.5)][myIdx.clamp(0, 3)];
  }

  List<Offset> _finishedSlots(int player, double cell) {
    final cx = 7.5 * cell;
    final cy = 7.5 * cell;
    final d = cell * 0.38;
    final s = cell * 0.32;
    return switch (player) {
      0 => [ // Red — bottom triangle
        Offset(cx - s, cy + d), Offset(cx + s, cy + d),
        Offset(cx - s, cy + d + s * 1.2), Offset(cx + s, cy + d + s * 1.2),
      ],
      1 => [ // Green — left triangle
        Offset(cx - d, cy - s), Offset(cx - d, cy + s),
        Offset(cx - d - s * 1.2, cy - s), Offset(cx - d - s * 1.2, cy + s),
      ],
      2 => [ // Yellow — top triangle
        Offset(cx - s, cy - d), Offset(cx + s, cy - d),
        Offset(cx - s, cy - d - s * 1.2), Offset(cx + s, cy - d - s * 1.2),
      ],
      3 => [ // Blue — right triangle
        Offset(cx + d, cy - s), Offset(cx + d, cy + s),
        Offset(cx + d + s * 1.2, cy - s), Offset(cx + d + s * 1.2, cy + s),
      ],
      _ => [Offset(cx, cy), Offset(cx, cy), Offset(cx, cy), Offset(cx, cy)],
    };
  }

  List<Widget> _buildTokenWidgets(double boardSize) {
    final cell = boardSize / 15;
    final tokenW = cell * 0.65;
    final tokenH = cell * 0.85;
    final widgets = <Widget>[];

    final finishedByPlayer = <int, int>{};
    for (final t in _tokens) {
      if (t.finished) {
        finishedByPlayer[t.player] = (finishedByPlayer[t.player] ?? 0) + 1;
      }
    }
    for (final entry in finishedByPlayer.entries) {
      final player = entry.key;
      final count = entry.value;
      final color = _kPlayerColors[player];
      final slots = _finishedSlots(player, cell);
      for (int j = 0; j < count; j++) {
        final pos = slots[j.clamp(0, 3)];
        final fw = tokenW * 0.55;
        final fh = tokenH * 0.55;
        widgets.add(
          Positioned(
            key: ValueKey('fin_${player}_$j'),
            left: pos.dx - fw / 2,
            top: pos.dy - fh * 0.55,
            width: fw,
            height: fh,
            child: _TokenWidget(color: color, isHighlighted: false),
          ),
        );
      }
    }

    for (int i = 0; i < _tokens.length; i++) {
      final token = _tokens[i];
      final color = _kPlayerColors[token.player];
      final isMovable = _movableTokens.contains(i) && _isHumanTurn;

      if (token.finished) continue;

      Offset pos;
      if (token.isHome) {
        pos = _homeTokenPosition(token.player, token.homeSlot, boardSize);
      } else {
        pos = _boardSquareCenter(token.boardSquare, boardSize);
        final allAtSquare = <int>[];
        for (int j = 0; j < _tokens.length; j++) {
          final t = _tokens[j];
          if (!t.finished && t.isOnBoard && t.boardSquare == token.boardSquare) {
            allAtSquare.add(j);
          }
        }
        if (allAtSquare.length > 1) {
          final myIdx = allAtSquare.indexOf(i);
          pos += _stackOffset(myIdx, allAtSquare.length, cell);
        }
      }

      final sameCount = token.isHome ? 0 : _tokens.where((t) => t != token && !t.finished && t.isOnBoard && t.boardSquare == token.boardSquare).length;
      final scale = sameCount > 0 ? 0.68 : 1.0;
      final tw = tokenW * scale;
      final th = tokenH * scale;

      widgets.add(
        AnimatedPositioned(
          key: ValueKey('token_${token.player}_$i'),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          left: pos.dx - tw / 2,
          top: pos.dy - th * 0.55,
          width: tw,
          height: th,
          child: GestureDetector(
            onTap: isMovable ? () => _onTokenTap(i) : null,
            child: _TokenWidget(
              color: color,
              isHighlighted: isMovable,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Offset _homeTokenPosition(int player, int idx, double boardSize) {
    final cell = boardSize / 15;
    final centers = _homeSlotCenters(player, cell);
    return centers[idx.clamp(0, 3)];
  }

  Widget _buildResult() {
    final isAi = _mode == _Mode.ai;
    final humanWon = _winner == 0;
    String headline;
    String big;
    Color bigColor;

    if (isAi) {
      headline = humanWon ? 'You Win!' : 'AI Wins!';
      big = humanWon ? '🏆' : '🤖';
      bigColor = humanWon ? _kPlayerColors[0] : _kPlayerColors[1];
    } else {
      headline = '${_kPlayerNames[_winner ?? 0]} Wins!';
      big = '🏆';
      bigColor = _kPlayerColors[_winner ?? 0];
    }

    final showStreak = isAi && _streak >= 2 && _streakOwner == 'human';
    final extraBadges = <Widget>[
      if (showStreak) _StreakBadge(streak: _streak),
      if (_wasNewBest) const _NewBestBadge(),
    ];

    return game_result.GenericGameResultScreen(
      gameId: kLudoGameId,
      score: _streak,
      headline: headline,
      badgeContent: big,
      badgeColor: bigColor,
      showNewBestBadge: false,
      extraBadges: extraBadges,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          if (isAi) ...[
            game_result.StatItem(label: 'WINS', value: _wins, color: _kPlayerColors[0]),
            game_result.StatItem(label: 'LOSSES', value: _losses, color: _kPlayerColors[1]),
            game_result.StatItem(
              label: 'BEST',
              value: ScoreService().getHighScore(kLudoGameId, subKey: _aiSubKey()),
              color: const Color(0xFF6C63FF),
            ),
          ],
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _playAgain,
          filled: true,
          color: _kAccent,
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

  // ---------------------------------------------------------------------------
  // Test hooks (@visibleForTesting — never called by the running app). Dice is
  // random and moves are animated, so widget taps can't deterministically
  // exercise the rules. These expose live token/turn state and let tests drive
  // the SHIPPED rule code (movable-set, capture, finish, win detection, turn
  // rotation, AI scoring) on any hand-built position. [configureForTest] and
  // [resetTokensForTest] build a CLEAN board so logic tests stay independent of
  // [_resetBoard].
  // ---------------------------------------------------------------------------

  @visibleForTesting
  static List<int> ludoPathForTest(int player) =>
      List.unmodifiable(_kPaths[player]);
  @visibleForTesting
  static Set<int> get safeSquaresForTest => _kSafeSquares;
  @visibleForTesting
  static List<int> get startSquaresForTest => List.unmodifiable(_kStartSquares);
  @visibleForTesting
  static int get pathLengthForTest => _kPathLength;
  @visibleForTesting
  static int get homeLaneLengthForTest => _kHomeLaneLength;
  @visibleForTesting
  static int get maxPathIndexForTest => _kPathLength + _kHomeLaneLength - 1;

  @visibleForTesting
  int get currentPlayerForTest => _currentPlayer;
  @visibleForTesting
  bool get gameOverForTest => _gameOver;
  @visibleForTesting
  int? get winnerForTest => _winner;
  @visibleForTesting
  List<int> get finishOrderForTest => List.unmodifiable(_finishOrder);
  @visibleForTesting
  int get consecutiveSixesForTest => _consecutiveSixes;
  @visibleForTesting
  List<int> get movableTokensForTest => List.unmodifiable(_movableTokens);
  @visibleForTesting
  List<int> get activePlayersForTest => List.unmodifiable(_activePlayers);
  @visibleForTesting
  int get winsForTest => _wins;
  @visibleForTesting
  int get lossesForTest => _losses;
  @visibleForTesting
  int get streakForTest => _streak;
  @visibleForTesting
  String? get streakOwnerForTest => _streakOwner;
  @visibleForTesting
  bool get wasNewBestForTest => _wasNewBest;
  @visibleForTesting
  int get dieValueForTest => _dieValue;
  @visibleForTesting
  bool get isAiModeForTest => _mode == _Mode.ai;

  @visibleForTesting
  int get tokenCountForTest => _tokens.length;
  @visibleForTesting
  int tokenPlayerForTest(int i) => _tokens[i].player;
  @visibleForTesting
  int tokenPathIndexForTest(int i) => _tokens[i].pathIndex;
  @visibleForTesting
  bool tokenFinishedForTest(int i) => _tokens[i].finished;
  @visibleForTesting
  bool tokenIsHomeForTest(int i) => _tokens[i].isHome;
  @visibleForTesting
  bool tokenIsOnBoardForTest(int i) => _tokens[i].isOnBoard;
  @visibleForTesting
  int tokenBoardSquareForTest(int i) => _tokens[i].boardSquare;
  @visibleForTesting
  List<int> tokenIndicesForPlayerForTest(int player) =>
      [for (int i = 0; i < _tokens.length; i++) if (_tokens[i].player == player) i];

  /// Build a clean board for [activePlayers] in AI or pass-and-play mode. All
  /// tokens start home; every per-game flag is reset. Bypasses [_resetBoard]
  /// so tests never depend on its contents.
  @visibleForTesting
  void configureForTest({
    required bool ai,
    List<int>? activePlayers,
    String difficulty = 'medium',
    int? currentPlayer,
  }) {
    _mode = ai ? _Mode.ai : _Mode.multiplayer;
    _activePlayers = activePlayers ?? const [0, 2];
    _playerCount = _activePlayers.length;
    _difficulty = switch (difficulty) {
      'easy' => _Difficulty.easy,
      'hard' => _Difficulty.hard,
      _ => _Difficulty.medium,
    };
    _wins = 0;
    _losses = 0;
    _streak = 0;
    _streakOwner = null;
    resetTokensForTest(currentPlayer: currentPlayer);
  }

  /// Fresh tokens + cleared round state, preserving wins/losses/streak — what a
  /// real "play again" does. For multi-game streak assertions.
  @visibleForTesting
  void resetTokensForTest({int? currentPlayer}) {
    _initTokens();
    _currentPlayer = currentPlayer ?? _activePlayers.first;
    _gameOver = false;
    _winner = null;
    _finishOrder = [];
    _dieValue = 0;
    _dieRolled = false;
    _rolling = false;
    _consecutiveSixes = 0;
    _movableTokens = [];
    _animating = false;
    _wasNewBest = false;
    _celebrating = false;
    _showWinBanner = false;
    _bannerLabel = null;
  }

  @visibleForTesting
  void setTokenForTest(int i, {int? pathIndex, bool? finished}) {
    if (pathIndex != null) _tokens[i].pathIndex = pathIndex;
    if (finished != null) _tokens[i].finished = finished;
  }

  /// Mark every token of [player] finished (at the home end) — for win tests.
  @visibleForTesting
  void finishAllTokensForTest(int player) {
    for (final i in tokenIndicesForPlayerForTest(player)) {
      _tokens[i].finished = true;
      _tokens[i].pathIndex = maxPathIndexForTest;
    }
  }

  @visibleForTesting
  void setCurrentPlayerForTest(int player) => _currentPlayer = player;

  @visibleForTesting
  List<int> movableForTest(int dieValue) => _getMovableTokenIndices(dieValue);
  @visibleForTesting
  Future<void> moveTokenForTest(int i, int value) => _moveToken(i, value);
  @visibleForTesting
  void afterRollForTest(int value) {
    _dieValue = value;
    _dieRolled = true;
    _afterRoll(value);
  }

  @visibleForTesting
  bool checkWinForTest() => _checkWin();
  @visibleForTesting
  void nextTurnForTest() => _nextTurn();
  @visibleForTesting
  int aiBestTokenForTest(List<int> movable, int dieValue) =>
      _aiBestToken(movable, dieValue);
}

class _ScorePill extends StatelessWidget {
  final _Mode mode;
  final _Difficulty difficulty;
  final int wins;
  final int losses;

  const _ScorePill({
    required this.mode,
    required this.difficulty,
    required this.wins,
    required this.losses,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
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
        : _kAccent;
    final diffKind = switch (difficulty) {
      _Difficulty.easy => DifficultyKind.easy,
      _Difficulty.medium => DifficultyKind.medium,
      _Difficulty.hard => DifficultyKind.hard,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: tabColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [BoxShadow(color: tabColor.withValues(alpha: 0.30), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAi) ...[
                AnimatedDifficultyIcon(kind: diffKind, size: 13, prominent: false),
                const SizedBox(width: 5),
              ],
              Text(tabLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ],
          ),
        ),
        if (isAi)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _kAccent.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _scoreCol('YOU', wins, _kRed),
                const SizedBox(width: 12),
                const Text('VS', style: TextStyle(color: Color(0xFF8B7BA7), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                const SizedBox(width: 12),
                _scoreCol('AI', losses, _kYellow),
              ],
            ),
          ),
      ],
    );
  }

  Widget _scoreCol(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        const SizedBox(height: 1),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => ScaleTransition(scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack), child: child),
          child: Text('$value', key: ValueKey(value), style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }
}

class _DieWidget extends StatefulWidget {
  final int value;
  final bool rolling;
  final bool canRoll;
  final VoidCallback onRoll;
  final Color color;

  const _DieWidget({
    required this.value,
    required this.rolling,
    required this.canRoll,
    required this.onRoll,
    required this.color,
  });

  @override
  State<_DieWidget> createState() => _DieWidgetState();
}

class _DieWidgetState extends State<_DieWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.canRoll ? widget.onRoll : null,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, child) {
          final pulse = widget.canRoll ? 0.95 + _pulseCtrl.value * 0.1 : 1.0;
          final glow = widget.canRoll ? 4.0 + _pulseCtrl.value * 10.0 : 0.0;
          return Transform.scale(
            scale: widget.rolling ? 1.05 : pulse,
            child: AnimatedRotation(
              turns: widget.rolling ? 0.05 : 0,
              duration: const Duration(milliseconds: 80),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.canRoll ? widget.color : Colors.grey.shade300,
                    width: widget.canRoll ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    if (widget.canRoll)
                      BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: glow, offset: const Offset(0, 2)),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: widget.value == 0
                    ? Center(child: Icon(Icons.casino_rounded, color: widget.canRoll ? widget.color : Colors.grey.shade400, size: 22))
                    : CustomPaint(painter: _DieFacePainter(value: widget.value, color: widget.color)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DieFacePainter extends CustomPainter {
  final int value;
  final Color color;
  _DieFacePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final sp = size.width * 0.22;
    final dotR = size.width * 0.065;
    final paint = Paint()..color = color;

    final dots = <Offset>[];
    switch (value) {
      case 1:
        dots.add(Offset(cx, cy));
      case 2:
        dots.addAll([Offset(cx - sp, cy - sp), Offset(cx + sp, cy + sp)]);
      case 3:
        dots.addAll([Offset(cx - sp, cy + sp), Offset(cx, cy), Offset(cx + sp, cy - sp)]);
      case 4:
        dots.addAll([Offset(cx - sp, cy - sp), Offset(cx + sp, cy - sp), Offset(cx - sp, cy + sp), Offset(cx + sp, cy + sp)]);
      case 5:
        dots.addAll([Offset(cx - sp, cy - sp), Offset(cx + sp, cy - sp), Offset(cx, cy), Offset(cx - sp, cy + sp), Offset(cx + sp, cy + sp)]);
      case 6:
        dots.addAll([Offset(cx - sp, cy - sp), Offset(cx + sp, cy - sp), Offset(cx - sp, cy), Offset(cx + sp, cy), Offset(cx - sp, cy + sp), Offset(cx + sp, cy + sp)]);
    }
    for (final d in dots) {
      canvas.drawCircle(d, dotR, paint);
    }
  }

  @override
  bool shouldRepaint(_DieFacePainter old) => old.value != value || old.color != color;
}

class _TokenWidget extends StatefulWidget {
  final Color color;
  final bool isHighlighted;

  const _TokenWidget({required this.color, required this.isHighlighted});

  @override
  State<_TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<_TokenWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  }

  @override
  void dispose() { _glowCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.isHighlighted) {
      return CustomPaint(painter: _TokenPainter(color: widget.color, glowAlpha: 0));
    }
    return AnimatedBuilder(
      animation: _glowCtrl,
      builder: (_, _) => CustomPaint(
        painter: _TokenPainter(color: widget.color, glowAlpha: 0.5 + _glowCtrl.value * 0.5),
      ),
    );
  }
}

class _TokenPainter extends CustomPainter {
  final Color color;
  final double glowAlpha;
  _TokenPainter({required this.color, this.glowAlpha = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final headR = w * 0.34;
    final headCy = h * 0.32;
    final tipY = h * 0.88;

    if (glowAlpha > 0) {
      canvas.drawCircle(
        Offset(cx, headCy),
        headR + 4,
        Paint()
          ..color = Colors.white.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    final ringRx = headR * 0.7;
    final ringRy = headR * 0.22;
    final ringCy = tipY + ringRy * 0.3;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, ringCy), width: ringRx * 2, height: ringRy * 2),
      Paint()..color = Color.lerp(color, Colors.black, 0.45)!.withValues(alpha: 0.7),
    );

    final pinPath = Path()
      ..moveTo(cx, tipY)
      ..quadraticBezierTo(cx - headR * 1.35, headCy + headR * 0.3, cx - headR, headCy)
      ..arcToPoint(
        Offset(cx + headR, headCy),
        radius: Radius.circular(headR),
        clockwise: true,
      )
      ..quadraticBezierTo(cx + headR * 1.35, headCy + headR * 0.3, cx, tipY)
      ..close();

    canvas.drawPath(
      pinPath.shift(const Offset(0, 1.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );

    canvas.drawPath(pinPath, Paint()..color = Colors.white);
    canvas.drawPath(
      pinPath,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final dotR = headR * 0.58;
    final gradient = RadialGradient(
      center: const Alignment(-0.25, -0.35),
      colors: [
        Color.lerp(color, Colors.white, 0.30)!,
        color,
        Color.lerp(color, Colors.black, 0.20)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    canvas.drawCircle(
      Offset(cx, headCy),
      dotR,
      Paint()..shader = gradient.createShader(Rect.fromCircle(center: Offset(cx, headCy), radius: dotR)),
    );
    canvas.drawCircle(
      Offset(cx, headCy),
      dotR,
      Paint()
        ..color = Color.lerp(color, Colors.black, 0.3)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawCircle(
      Offset(cx - dotR * 0.25, headCy - dotR * 0.25),
      dotR * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(_TokenPainter old) => old.color != color || old.glowAlpha != glowAlpha;
}

class _LudoBoardPainter extends CustomPainter {
  final List<int> finishOrder;
  _LudoBoardPainter(this.finishOrder);

  static const _kHomePositions = <int, List<double>>{
    1: [0, 0],
    2: [9, 0],
    0: [0, 9],
    3: [9, 9],
  };

  static const _kHomeColors = <int, Color>{
    0: _kRed,
    1: _kGreen,
    2: _kYellow,
    3: _kBlue,
  };

  static Color? _trackColor(int sq) {
    if (sq == 0) return _kRed;
    if (sq == 13) return _kGreen;
    if (sq == 26) return _kYellow;
    if (sq == 39) return _kBlue;
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = _kBoardBg);

    for (final entry in _kHomePositions.entries) {
      final player = entry.key;
      final color = _kHomeColors[player]!;
      _drawHomeArea(canvas, entry.value[0] * cell, entry.value[1] * cell, cell * 6, cell * 6, color, player, cell);
    }

    _drawTrackSquares(canvas, cell);

    _drawHomeLanes(canvas, cell);

    _drawCenter(canvas, cell * 6, cell * 6, cell * 3, cell * 3);

    _drawSafeStars(canvas, cell, size.width);

    _drawEntryArrows(canvas, cell);

    for (int i = 0; i < finishOrder.length; i++) {
      _drawRankBadge(canvas, finishOrder[i], i + 1, cell);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = const Color(0xFF2C3E50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawRankBadge(Canvas canvas, int player, int rank, double cell) {
    final o = _kHomePositions[player]!;
    final hx = o[0] * cell;
    final hy = o[1] * cell;
    final homeSize = cell * 6;
    final cx = hx + homeSize / 2;
    final cy = hy + homeSize / 2;

    final badgeR = cell * 1.1;
    canvas.drawCircle(
      Offset(cx, cy),
      badgeR + 2,
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      badgeR,
      Paint()..color = Colors.white,
    );
    final color = _kHomeColors[player]!;
    canvas.drawCircle(
      Offset(cx, cy),
      badgeR,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final suffix = switch (rank) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$rank',
            style: TextStyle(fontSize: badgeR * 0.8, fontWeight: FontWeight.w800, color: color, height: 1.0),
          ),
          TextSpan(
            text: suffix,
            style: TextStyle(fontSize: badgeR * 0.42, fontWeight: FontWeight.w700, color: color, height: 1.0),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawHomeArea(Canvas canvas, double x, double y, double w, double h, Color color, int player, double cell) {
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), Paint()..color = color);
    final innerPad = w * 0.15;
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + innerPad, y + innerPad, w - innerPad * 2, h - innerPad * 2),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(inner, Paint()..color = Colors.white);
    canvas.drawRRect(
      inner,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final slotR = cell * 0.52;
    final centers = _homeSlotCenters(player, cell);
    for (final c in centers) {
      canvas.drawCircle(c, slotR + 1, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(c, slotR, Paint()..color = color.withValues(alpha: 0.35));
      canvas.drawCircle(
        c, slotR,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawCenter(Canvas canvas, double x, double y, double w, double h) {
    final cx = x + w / 2;
    final cy = y + h / 2;
    final triangles = [
      ([Offset(x, y), Offset(x + w, y), Offset(cx, cy)], _kYellow),
      ([Offset(x + w, y), Offset(x + w, y + h), Offset(cx, cy)], _kBlue),
      ([Offset(x + w, y + h), Offset(x, y + h), Offset(cx, cy)], _kRed),
      ([Offset(x, y + h), Offset(x, y), Offset(cx, cy)], _kGreen),
    ];

    for (final (pts, color) in triangles) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.drawRect(
      Rect.fromLTWH(x, y, w, h),
      Paint()
        ..color = const Color(0xFF2C3E50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawTrackSquares(Canvas canvas, double cell) {
    final strokePaint = Paint()
      ..color = const Color(0xFF90A4AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < 52; i++) {
      final c = _kSquareCoords[i][0];
      final r = _kSquareCoords[i][1];
      final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
      final color = _trackColor(i);
      if (color != null) {
        canvas.drawRect(rect, Paint()..color = color);
      }
      canvas.drawRect(rect, strokePaint);
    }
  }

  void _drawHomeLanes(Canvas canvas, double cell) {
    final lanes = <(List<List<int>>, Color)>[
      ([[7, 13], [7, 12], [7, 11], [7, 10], [7, 9], [7, 8]], _kRed),
      ([[1, 7], [2, 7], [3, 7], [4, 7], [5, 7], [6, 7]], _kGreen),
      ([[7, 1], [7, 2], [7, 3], [7, 4], [7, 5], [7, 6]], _kYellow),
      ([[13, 7], [12, 7], [11, 7], [10, 7], [9, 7], [8, 7]], _kBlue),
    ];

    final strokePaint = Paint()
      ..color = const Color(0xFF90A4AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (final (cells, color) in lanes) {
      for (final coord in cells) {
        final rect = Rect.fromLTWH(coord[0] * cell, coord[1] * cell, cell, cell);
        canvas.drawRect(rect, Paint()..color = color);
        canvas.drawRect(rect, strokePaint);
      }
    }
  }

  static const _kStarSquares = <int>{8, 21, 34, 47};

  void _drawSafeStars(Canvas canvas, double cell, double boardSize) {
    for (final sq in _kStarSquares) {
      final center = _boardSquareCenter(sq, boardSize);
      _drawStar(canvas, center, cell * 0.3, const Color(0xFF2C3E50).withValues(alpha: 0.30));
    }
  }

  void _drawEntryArrows(Canvas canvas, double cell) {
    const arrowData = [
      ([7, 14], 0, _kRed),
      ([0, 7], 1, _kGreen),
      ([7, 0], 2, _kYellow),
      ([14, 7], 3, _kBlue),
    ];
    for (final (coord, dir, color) in arrowData) {
      final cx = coord[0] * cell + cell / 2;
      final cy = coord[1] * cell + cell / 2;
      final s = cell * 0.30;
      final path = Path();
      switch (dir) {
        case 0: // up
          path..moveTo(cx, cy - s)..lineTo(cx - s, cy + s * 0.6)..lineTo(cx + s, cy + s * 0.6)..close();
        case 1: // right
          path..moveTo(cx + s, cy)..lineTo(cx - s * 0.6, cy - s)..lineTo(cx - s * 0.6, cy + s)..close();
        case 2: // down
          path..moveTo(cx, cy + s)..lineTo(cx - s, cy - s * 0.6)..lineTo(cx + s, cy - s * 0.6)..close();
        case 3: // left
          path..moveTo(cx - s, cy)..lineTo(cx + s * 0.6, cy - s)..lineTo(cx + s * 0.6, cy + s)..close();
      }
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -math.pi / 2 + i * 2 * math.pi / 5;
      final innerAngle = outerAngle + math.pi / 5;
      final outerPt = Offset(center.dx + r * math.cos(outerAngle), center.dy + r * math.sin(outerAngle));
      final innerPt = Offset(center.dx + r * 0.4 * math.cos(innerAngle), center.dy + r * 0.4 * math.sin(innerAngle));
      if (i == 0) {
        path.moveTo(outerPt.dx, outerPt.dy);
      } else {
        path.lineTo(outerPt.dx, outerPt.dy);
      }
      path.lineTo(innerPt.dx, innerPt.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LudoBoardPainter old) => old.finishOrder.length != finishOrder.length;
}

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

class _MiniPickerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniPickerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, Color.lerp(color, Colors.white, 0.22)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
