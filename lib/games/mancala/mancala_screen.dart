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
import 'mancala_stats.dart';
import 'mancala_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_undo_button.dart';

const Color _kP1Color = Color(0xFF2196F3);
const Color _kP2Color = Color(0xFFFF7043);
const Color _kDrawColor = Color(0xFFB6A5DD);
const Color _kAiColor = Color(0xFF7B5B3A);
const Color _kBgTop = Color(0xFFFFF5E6);
const Color _kBgBot = Color(0xFFF5EADB);
const Color _kBoardColor = Color(0xFF7B5B3A);
const Color _kPitColor = Color(0xFF5C3D24);
const Color _kSeedColor = Color(0xFFD4A76A);
const Color _kEasyColor = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor = Color(0xFFEF4444);

const Color _kTintP1Top = Color(0xFFE8F0FE);
const Color _kTintP1Bot = Color(0xFFDAE6F8);
const Color _kTintP2Top = Color(0xFFFFF0EB);
const Color _kTintP2Bot = Color(0xFFF5E2DA);
const Color _kTintNeutralTop = Color(0xFFFFF5E6);
const Color _kTintNeutralBot = Color(0xFFF5EADB);

enum _Mode { ai, twoPlayer }
enum _Difficulty { easy, medium, hard }

// Board layout: indices 0-5 = P1 pits, 6 = P1 store, 7-12 = P2 pits, 13 = P2 store
class MancalaScreen extends StatefulWidget {
  const MancalaScreen({super.key});
  @override
  State<MancalaScreen> createState() => _MancalaScreenState();
}

class _MancalaScreenState extends State<MancalaScreen> {
  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  List<int> _pits = List.filled(14, 0);
  int _currentPlayer = 1; // 1 or 2
  bool _gameOver = false;
  int? _winner;
  bool _aiThinking = false;
  int _p1Wins = 0;
  int _p2Wins = 0;
  int _draws = 0;
  int _streak = 0;
  String? _streakOwner;
  bool _wasNewBest = false;
  bool _isFavorite = false;
  bool _firstRoundOfSession = true;
  bool _showStreakBadge = false;
  bool _celebrating = false;
  String? _bannerLabel;
  Color _bannerColor = _kDrawColor;
  bool _showWinBanner = false;

  List<int>? _undoPitsSnapshot;
  bool _undoUsedThisRound = false;
  bool _inUndoWindow = false;

  final _rng = math.Random();
  final _audio = AudioService();
  Timer? _aiMoveTimer;
  Timer? _endGameTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kMancalaGameId);
  }

  @override
  void dispose() {
    _aiMoveTimer?.cancel();
    _endGameTimer?.cancel();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  void _initBoard() {
    _pits = List.filled(14, 4);
    _pits[6] = 0;  // P1 store
    _pits[13] = 0; // P2 store
  }

  void _selectMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _p1Wins = 0;
      _p2Wins = 0;
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
      _p1Wins = 0;
      _p2Wins = 0;
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
        _currentPlayer = _rng.nextBool() ? 1 : 2;
        _firstRoundOfSession = false;
      } else {
        _currentPlayer = _currentPlayer == 1 ? 2 : 1;
      }
      _gameOver = false;
      _winner = null;
      _aiThinking = false;
      _wasNewBest = false;
      _showStreakBadge = false;
      _celebrating = false;
      _showWinBanner = false;
      _bannerLabel = null;
      _undoPitsSnapshot = null;
      _undoUsedThisRound = false;
      _inUndoWindow = false;
    });
    if (_mode == _Mode.ai && _currentPlayer == 2) _scheduleAiMove();
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      ScoreService().toggleFavorite(kMancalaGameId);
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
    final game = GameRegistry.getById(kMancalaGameId);
    if (game == null) return;
    showHowToPlaySheet(context, title: game.name, howToPlay: game.howToPlay,
      accent: _kAiColor, steps: mancalaSteps(), gameId: kMancalaGameId);
  }

  // ── Undo ──

  bool get _canUndo => _inUndoWindow && !_gameOver;

  void _onUndoExpired() {
    if (!mounted || _gameOver || !_inUndoWindow) return;
    setState(() => _inUndoWindow = false);
    _scheduleAiMove();
  }

  void _performUndo() {
    final snap = _undoPitsSnapshot;
    if (snap == null) return;
    setState(() {
      _pits = List<int>.from(snap);
      _currentPlayer = 1;
      _inUndoWindow = false;
      _undoPitsSnapshot = null;
      _undoUsedThisRound = true;
    });
  }

  // ── Game Logic ──

  bool _isPlayerPit(int index, int player) {
    if (player == 1) return index >= 0 && index <= 5;
    return index >= 7 && index <= 12;
  }

  int _storeIndex(int player) => player == 1 ? 6 : 13;

  void _onPitTap(int index) {
    if (_gameOver || _aiThinking) return;
    if (_mode == _Mode.ai && (_inUndoWindow || _currentPlayer == 2)) return;
    if (!_isPlayerPit(index, _currentPlayer)) return;
    if (_pits[index] == 0) return;

    if (_mode == _Mode.ai && _currentPlayer == 1) {
      _undoPitsSnapshot = List<int>.from(_pits);
    }
    _sow(index);
  }

  void _sow(int pitIndex) {
    int seeds = _pits[pitIndex];
    _pits[pitIndex] = 0;
    int current = pitIndex;
    final opponentStore = _storeIndex(_currentPlayer == 1 ? 2 : 1);

    while (seeds > 0) {
      current = (current + 1) % 14;
      if (current == opponentStore) continue;
      _pits[current]++;
      seeds--;
    }

    _audio.playTap();

    // Capture rule: last seed in empty pit on own side
    if (_isPlayerPit(current, _currentPlayer) && _pits[current] == 1) {
      final opposite = 12 - current;
      if (_pits[opposite] > 0) {
        final store = _storeIndex(_currentPlayer);
        _pits[store] += _pits[opposite] + 1;
        _pits[opposite] = 0;
        _pits[current] = 0;
        _audio.playScore();
      }
    }

    setState(() {});
    _checkGameEnd();

    if (!_gameOver) {
      if (current == _storeIndex(_currentPlayer)) {
        // Extra turn — no undo for extra turns
        if (_mode == _Mode.ai && _currentPlayer == 2) {
          _scheduleAiMove();
        }
      } else {
        final wasHuman = _mode == _Mode.ai && _currentPlayer == 1;
        final undoAvailable = wasHuman && !_undoUsedThisRound && AdsService().isRewardedReady;
        setState(() => _currentPlayer = _currentPlayer == 1 ? 2 : 1);
        if (_mode == _Mode.ai && _currentPlayer == 2) {
          if (undoAvailable) {
            setState(() => _inUndoWindow = true);
          } else {
            _scheduleAiMove();
          }
        }
      }
    }
  }

  void _checkGameEnd() {
    bool p1Empty = true;
    bool p2Empty = true;
    for (int i = 0; i <= 5; i++) {
      if (_pits[i] > 0) p1Empty = false;
    }
    for (int i = 7; i <= 12; i++) {
      if (_pits[i] > 0) p2Empty = false;
    }

    if (!p1Empty && !p2Empty) return;

    // Sweep remaining seeds
    for (int i = 0; i <= 5; i++) {
      _pits[6] += _pits[i];
      _pits[i] = 0;
    }
    for (int i = 7; i <= 12; i++) {
      _pits[13] += _pits[i];
      _pits[i] = 0;
    }

    if (_pits[6] > _pits[13]) {
      _onWin(1);
    } else if (_pits[13] > _pits[6]) {
      _onWin(2);
    } else {
      _onDraw();
    }
  }

  void _onWin(int winner) {
    final isAi = _mode == _Mode.ai;
    final label = winner == 1 ? 'p1' : 'p2';
    setState(() {
      _gameOver = true;
      _winner = winner;
      _showWinBanner = true;
      _celebrating = true;
      if (winner == 1) {
        _p1Wins++;
        _bannerLabel = isAi ? 'You Win!' : 'Player 1 Wins!';
        _bannerColor = _kP1Color;
      } else {
        _p2Wins++;
        _bannerLabel = isAi ? 'AI Wins!' : 'Player 2 Wins!';
        _bannerColor = _kP2Color;
      }
      if (_streakOwner == label) {
        _streak++;
      } else {
        _streakOwner = label;
        _streak = 1;
      }
      _showStreakBadge = _streak >= 2;
    });

    if (isAi && winner == 1) {
      final subKey = switch (_difficulty) {
        _Difficulty.easy => kMancalaSubKeyEasy,
        _Difficulty.medium => kMancalaSubKeyMedium,
        _Difficulty.hard => kMancalaSubKeyHard,
      };
      ScoreService().saveScore(kMancalaGameId, _streak, subKey: subKey).then((isNew) {
        if (mounted && isNew) setState(() => _wasNewBest = true);
      });
      _wrapper.updateScore(_streak);
    } else {
      _wasNewBest = false;
    }

    final gameResult = isAi ? (winner == 1 ? 'win' : 'loss') : 'win';
    _audio.playSuccess();
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _wrapper.endGame(result: gameResult);
    });
  }

  void _onDraw() {
    setState(() {
      _gameOver = true;
      _winner = null;
      _draws++;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _showWinBanner = true;
      _bannerLabel = "It's a Draw!";
      _bannerColor = _kDrawColor;
      _wasNewBest = false;
    });
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _wrapper.endGame(result: 'draw');
    });
  }

  // ── AI ──

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    final ms = switch (_difficulty) {
      _Difficulty.easy => 600,
      _Difficulty.medium => 900,
      _Difficulty.hard => 1200,
    };
    _aiMoveTimer?.cancel();
    _aiMoveTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted || _gameOver) return;
      _performAiMove();
    });
  }

  void _performAiMove() {
    final validPits = <int>[];
    for (int i = 7; i <= 12; i++) {
      if (_pits[i] > 0) validPits.add(i);
    }

    if (validPits.isEmpty) {
      setState(() => _aiThinking = false);
      _checkGameEnd();
      return;
    }

    int chosen;
    switch (_difficulty) {
      case _Difficulty.easy:
        chosen = validPits[_rng.nextInt(validPits.length)];
      case _Difficulty.medium:
        chosen = _pickSmartPit(validPits, 0.35);
      case _Difficulty.hard:
        chosen = _pickSmartPit(validPits, 0.1);
    }

    setState(() {
      _aiThinking = false;
      _undoPitsSnapshot = null;
    });
    _sow(chosen);
  }

  int _pickSmartPit(List<int> pits, double randomFactor) {
    if (_rng.nextDouble() < randomFactor) return pits[_rng.nextInt(pits.length)];

    int bestScore = -9999;
    int bestPit = pits.first;

    for (final pit in pits) {
      int score = 0;
      final seeds = _pits[pit];
      final landing = (pit + seeds) % 14;
      // Skip opponent store logic counted implicitly

      if (landing == 13) score += 10; // Extra turn
      if (_isPlayerPit(landing, 2) && _pits[landing] == 0) {
        final opp = 12 - landing;
        if (opp >= 0 && opp <= 5) score += _pits[opp];
      }
      score += seeds;
      score += _rng.nextInt(3);

      if (score > bestScore) {
        bestScore = score;
        bestPit = pit;
      }
    }
    return bestPit;
  }

  // ── Helpers ──

  String? _aiSubKey() {
    if (_mode != _Mode.ai) return null;
    return switch (_difficulty) {
      _Difficulty.easy => kMancalaSubKeyEasy,
      _Difficulty.medium => kMancalaSubKeyMedium,
      _Difficulty.hard => kMancalaSubKeyHard,
    };
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
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAiColor, icon: Icons.circle_rounded),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [Color(0xFF7B5B3A), Color(0xFFD4A76A), Color(0xFF7B5B3A)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kMancalaGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) return logo;
        return const Icon(Icons.circle_rounded, size: 40, color: _kAiColor);
      }),
      title: 'Mancala',
      subtitle: 'Sow seeds, capture stones, outplay!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kMancalaGameId,
      body: GameAiPickerBody(
        difficulties: _Difficulty.values.map((d) {
          final subKey = switch (d) {
            _Difficulty.easy => kMancalaSubKeyEasy,
            _Difficulty.medium => kMancalaSubKeyMedium,
            _Difficulty.hard => kMancalaSubKeyHard,
          };
          return GameDifficultyData(
            label: _diffLabel(d),
            color: _diffColor(d),
            kind: _kindFor(d),
            hint: switch (d) {
              _Difficulty.easy => 'Random sowing — learn the basics.',
              _Difficulty.medium => 'Plans captures and free turns.',
              _Difficulty.hard => 'Calculates best moves ahead.',
            },
            bestScore: bestMancalaStreak(subKey),
            bestLabel: (s) => 'Best $s in a row',
          );
        }).toList(),
        activeIndex: _Difficulty.values.indexOf(_difficulty),
        onChanged: (i) => setState(() => _difficulty = _Difficulty.values[i]),
        onPlayAi: () => _selectMode(_Mode.ai),
        onPlayFriend: () => _selectMode(_Mode.twoPlayer),
        aiGradient: const [Color(0xFF7B5B3A), Color(0xFFA07548)],
        friendGradient: const [Color(0xFFFF7043), Color(0xFFFF9A76)],
      ),
    );
  }

  Widget _buildGame() {
    final isAi = _mode == _Mode.ai;
    final isP1Turn = _currentPlayer == 1 || _inUndoWindow;
    final topColor = _showWinBanner ? _kTintNeutralTop : (isP1Turn ? _kTintP1Top : _kTintP2Top);
    final botColor = _showWinBanner ? _kTintNeutralBot : (isP1Turn ? _kTintP1Bot : _kTintP2Bot);

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
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome),
              centerContent: _ScoreBoardPill(
                mode: _mode!,
                difficulty: _difficulty,
                p1Score: _pits[6],
                p2Score: _pits[13],
              ),
              trailing: GameRestartButton(
                gameName: 'Mancala',
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PlayerStrip(
                label: isAi ? 'AI' : 'Player 2',
                mark: '2',
                color: _kP2Color,
                isActive: _currentPlayer == 2 && !_inUndoWindow && !_gameOver,
                isThinking: _aiThinking,
                avatarIcon: isAi ? Icons.smart_toy_rounded : null,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Center(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final maxH = constraints.maxHeight;
                    final boardW = maxW;
                    final boardH = math.min(maxH, boardW * 0.55);
                    return Stack(
                      children: [
                        _MancalaBoardWidget(
                          pits: _pits,
                          boardW: boardW,
                          boardH: boardH,
                          currentPlayer: _currentPlayer,
                          onPitTap: _onPitTap,
                          gameOver: _gameOver,
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
                  }),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PlayerStrip(
                label: isAi ? 'You' : 'Player 1',
                mark: '1',
                color: _kP1Color,
                isActive: (_currentPlayer == 1 || _inUndoWindow) && !_gameOver,
              ),
            ),
            SizedBox(
              height: 44,
              child: _canUndo
                  ? Center(
                      child: RewardedUndoButton(
                        key: ValueKey('undo_${_pits.join()}'),
                        onUndo: _performUndo,
                        onExpired: _onUndoExpired,
                        accentColor: _kP1Color,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
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
      big = '${_pits[6]}';
      bigColor = _kP1Color;
    } else if (_winner == 2) {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = '${_pits[13]}';
      bigColor = _kP2Color;
    } else {
      headline = "It's a Draw!";
      big = '=';
      bigColor = _kDrawColor;
    }

    final showStreak = _streak >= 2 && ((_winner == 1 && _streakOwner == 'p1') || (_winner == 2 && _streakOwner == 'p2'));
    final extraBadges = <Widget>[
      if (showStreak) _StreakBadge(streak: _streak),
      if (_wasNewBest) const _NewBestBadge(),
    ];

    return game_result.GenericGameResultScreen(
      gameId: kMancalaGameId,
      score: _streak,
      headline: headline,
      badgeContent: big,
      badgeColor: bigColor,
      showNewBestBadge: false,
      extraBadges: extraBadges,
      statsWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          game_result.GameResultPlayersRow(
            p1Label: isAi ? 'YOU' : 'P1',
            p2Label: isAi ? 'AI' : 'P2',
            p1Score: _pits[6],
            p2Score: _pits[13],
            p1Color: _kP1Color,
            p2Color: _kP2Color,
            p1IsWinner: _winner == 1,
            p2IsWinner: _winner == 2,
            scoreUnit: 'seeds',
          ),
          if (isAi) ...[
            const SizedBox(height: 12),
            game_result.GameResultStatsRow(
              stats: [
                game_result.StatItem(
                  label: 'BEST',
                  value: ScoreService().getHighScore(kMancalaGameId, subKey: _aiSubKey()),
                  color: const Color(0xFF6C63FF),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again', icon: Icons.refresh_rounded, onTap: _playAgain,
          filled: true, color: _kAiColor, actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Mode', icon: Icons.swap_horiz_rounded, onTap: _changeMode, actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home', icon: Icons.home_rounded, onTap: _backOrHome, actionId: 'home',
        ),
      ],
    );
  }
}

// ── Score Board Pill (with difficulty tab) ──

class _ScoreBoardPill extends StatelessWidget {
  final _Mode mode;
  final _Difficulty difficulty;
  final int p1Score;
  final int p2Score;

  const _ScoreBoardPill({
    required this.mode,
    required this.difficulty,
    required this.p1Score,
    required this.p2Score,
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
            boxShadow: [BoxShadow(color: tabColor.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAi) ...[AnimatedDifficultyIcon(kind: diffKind, size: 14, prominent: false), const SizedBox(width: 6)],
              Text(tabLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _kAiColor.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _scoreColumn(leftLabel, p1Score, _kP1Color),
                  const SizedBox(width: 14),
                  const Text('VS', style: TextStyle(color: Color(0xFF8B7BA7), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(width: 14),
                  _scoreColumn(rightLabel, p2Score, _kP2Color),
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
      _Difficulty.easy => kMancalaSubKeyEasy,
      _Difficulty.medium => kMancalaSubKeyMedium,
      _Difficulty.hard => kMancalaSubKeyHard,
    };
    final best = ScoreService().getHighScore(kMancalaGameId, subKey: subKey);
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

// ── Mancala Board Widget ──

class _MancalaBoardWidget extends StatelessWidget {
  final List<int> pits;
  final double boardW;
  final double boardH;
  final int currentPlayer;
  final ValueChanged<int> onPitTap;
  final bool gameOver;

  const _MancalaBoardWidget({
    required this.pits,
    required this.boardW,
    required this.boardH,
    required this.currentPlayer,
    required this.onPitTap,
    required this.gameOver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boardW,
      height: boardH,
      decoration: BoxDecoration(
        color: _kBoardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final storeW = w * 0.10;
        final pitAreaW = w - storeW * 2 - w * 0.08;
        final pitSpacing = pitAreaW / 6;
        final pitAreaLeft = storeW + w * 0.04;
        final pitR = math.min(pitSpacing * 0.38, h * 0.2);
        final rowY1 = h * 0.30;
        final rowY2 = h * 0.70;

        return Stack(
          children: [
            // P2 store (left)
            Positioned(
              left: w * 0.02,
              top: h * 0.1,
              child: _Store(width: storeW, height: h * 0.8, seeds: pits[13], color: _kP2Color),
            ),
            // P1 store (right)
            Positioned(
              right: w * 0.02,
              top: h * 0.1,
              child: _Store(width: storeW, height: h * 0.8, seeds: pits[6], color: _kP1Color),
            ),
            // P2 pits (top row, reversed: 12..7)
            for (int i = 0; i < 6; i++)
              Positioned(
                left: pitAreaLeft + i * pitSpacing + pitSpacing / 2 - pitR,
                top: rowY1 - pitR,
                child: _Pit(
                  radius: pitR,
                  seeds: pits[12 - i],
                  isActive: currentPlayer == 2 && !gameOver,
                  color: _kP2Color,
                  onTap: () => onPitTap(12 - i),
                ),
              ),
            // P1 pits (bottom row: 0..5)
            for (int i = 0; i < 6; i++)
              Positioned(
                left: pitAreaLeft + i * pitSpacing + pitSpacing / 2 - pitR,
                top: rowY2 - pitR,
                child: _Pit(
                  radius: pitR,
                  seeds: pits[i],
                  isActive: currentPlayer == 1 && !gameOver,
                  color: _kP1Color,
                  onTap: () => onPitTap(i),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _Store extends StatelessWidget {
  final double width;
  final double height;
  final int seeds;
  final Color color;

  const _Store({required this.width, required this.height, required this.seeds, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kPitColor,
        borderRadius: BorderRadius.circular(width / 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$seeds',
        style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
      ),
    );
  }
}

class _Pit extends StatelessWidget {
  final double radius;
  final int seeds;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _Pit({
    required this.radius,
    required this.seeds,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: seeds > 0 && isActive ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isActive ? 1.0 : 0.6,
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            color: _kPitColor,
            shape: BoxShape.circle,
            border: isActive && seeds > 0
                ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$seeds',
            style: TextStyle(
              color: seeds > 0 ? _kSeedColor : _kSeedColor.withValues(alpha: 0.3),
              fontWeight: FontWeight.w800,
              fontSize: radius * 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 4),
          Text('$streak streak!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.orange.shade800)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, size: 14, color: Color(0xFF7C3AED)),
          SizedBox(width: 4),
          Text('New Best!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF7C3AED))),
        ],
      ),
    );
  }
}

class _WinBanner extends StatelessWidget {
  final String label;
  final Color color;
  const _WinBanner({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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
        hueShift: _rng.nextDouble() * 60 - 30,
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
    final maxR = size.shortestSide * 0.6;
    for (final p in particles) {
      final r = maxR * progress * p.speed;
      final dx = center.dx + math.cos(p.angle) * r;
      final dy = center.dy + math.sin(p.angle) * r - 30 * progress;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final hsl = HSLColor.fromColor(baseColor);
      final color = hsl.withHue((hsl.hue + p.hueShift) % 360).toColor().withValues(alpha: opacity);
      canvas.drawCircle(Offset(dx, dy), p.size * (1 - progress * 0.3), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
