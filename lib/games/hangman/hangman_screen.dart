import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'hangman_stats.dart';
import 'hangman_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;

const Color _kAccent = Color(0xFF6C63FF);
const Color _kBgTop = Color(0xFFF5F3FF);
const Color _kBgBot = Color(0xFFEDE9FE);
const Color _kCorrect = Color(0xFF22C55E);
const Color _kWrong = Color(0xFFEF4444);
const Color _kEasyColor = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor = Color(0xFFEF4444);

enum _Difficulty { easy, medium, hard }

const _kMaxErrors = 6;

const _easyWords = [
  'APPLE', 'HOUSE', 'WATER', 'HAPPY', 'LIGHT', 'MUSIC', 'DANCE', 'SUNNY',
  'BEACH', 'CLOUD', 'PLANT', 'CHAIR', 'TABLE', 'BREAD', 'SMILE', 'DREAM',
  'RIVER', 'OCEAN', 'NORTH', 'SOUTH', 'GREEN', 'BLUE', 'WORLD', 'HEART',
  'SLEEP', 'MOVIE', 'PHONE', 'GAMES', 'JUICE', 'CANDY', 'PARTY', 'GRASS',
  'STONE', 'WATCH', 'NIGHT', 'MONEY', 'QUIET', 'FRESH', 'CLOCK', 'BRAIN',
  'MAGIC', 'PIZZA', 'TIGER', 'PANDA', 'ROBOT', 'SPACE', 'CROWN', 'FLAME',
];

const _mediumWords = [
  'FLUTTER', 'EXPLORE', 'JOURNEY', 'LIBRARY', 'MYSTERY', 'KITCHEN',
  'BALANCE', 'FREEDOM', 'CAPTAIN', 'NETWORK', 'BLANKET', 'DOLPHIN',
  'VOLCANO', 'CRYSTAL', 'HARVEST', 'LANTERN', 'TRUMPET', 'PENGUIN',
  'SAFFRON', 'JIGSAW', 'PUZZLE', 'BASKET', 'GARDEN', 'BRIDGE',
  'PLANET', 'ROCKET', 'TUNNEL', 'BREEZE', 'FOREST', 'DESERT',
  'ISLAND', 'CASTLE', 'SILVER', 'GOLDEN', 'TEMPLE', 'MARKET',
  'PARADE', 'STREAM', 'CANYON', 'MEADOW', 'VALLEY', 'SUMMIT',
];

const _hardWords = [
  'LABYRINTH', 'ALGORITHM', 'XYLOPHONE', 'WHIMSICAL', 'MARVELOUS',
  'TURBULENT', 'BLUEPRINT', 'CHAMPAGNE', 'ALCHEMIST', 'QUICKSAND',
  'MYSTIQUE', 'JUXTAPOSE', 'FIREPLACE', 'ADVENTURE', 'TELESCOPE',
  'INVISIBLE', 'HONEYCOMB', 'JACKFRUIT', 'CROCODILE', 'TRAPEZOID',
  'KNOWLEDGE', 'EPHEMERAL', 'BEAUTIFUL', 'DANGEROUS', 'PINEAPPLE',
  'SAXOPHONE', 'LABYRINTH', 'HURRICANE', 'WOLVERINE', 'DRAGONFLY',
  'NIGHTMARE', 'FRAMEWORK', 'CLOCKWORK', 'SNOWFLAKE', 'WATERFALL',
];

class HangmanScreen extends StatefulWidget {
  const HangmanScreen({super.key});
  @override
  State<HangmanScreen> createState() => _HangmanScreenState();
}

class _HangmanScreenState extends State<HangmanScreen> {
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _started = false;

  String _word = '';
  Set<String> _guessedLetters = {};
  int _errors = 0;
  bool _gameOver = false;
  bool _won = false;
  int _streak = 0;
  int _gamesWon = 0;
  int _gamesLost = 0;
  bool _wasNewBest = false;
  bool _isFavorite = false;
  int _consecutiveWrongs = 0;
  bool _hintUsed = false;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kStuckWrongs = 2;
  static const _kIdleTimeout = Duration(seconds: 30);

  final _rng = math.Random();
  final _audio = AudioService();
  Timer? _endGameTimer;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kHangmanGameId);
  }

  @override
  void dispose() {
    _endGameTimer?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  void _startNewGame() {
    final words = switch (_difficulty) {
      _Difficulty.easy => _easyWords,
      _Difficulty.medium => _mediumWords,
      _Difficulty.hard => _hardWords,
    };
    setState(() {
      _started = true;
      _word = words[_rng.nextInt(words.length)];
      _guessedLetters = {};
      _errors = 0;
      _gameOver = false;
      _won = false;
      _wasNewBest = false;
      _consecutiveWrongs = 0;
      _hintUsed = false;
      _idleStuck = false;
    });
    _resetIdleTimer();
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: 'single',
      subKey: _hangmanSubKey(),
    );
    _wrapper.startGame();
  }

  void _playAgain() {
    _endGameTimer?.cancel();
    final words = switch (_difficulty) {
      _Difficulty.easy => _easyWords,
      _Difficulty.medium => _mediumWords,
      _Difficulty.hard => _hardWords,
    };
    setState(() {
      _word = words[_rng.nextInt(words.length)];
      _guessedLetters = {};
      _errors = 0;
      _gameOver = false;
      _won = false;
      _wasNewBest = false;
      _consecutiveWrongs = 0;
      _hintUsed = false;
      _idleStuck = false;
    });
    _resetIdleTimer();
    _wrapper.setDifficultyAndMode(
      difficulty: _diffLabel(_difficulty),
      mode: 'single',
      subKey: _hangmanSubKey(),
    );
    _wrapper.restartGame();
    _wrapper.startGame();
  }

  void _backToPicker() {
    _wrapper.handleExit(() {
      if (context.canPop()) context.pop(); else context.go('/home');
    });
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      ScoreService().toggleFavorite(kHangmanGameId);
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
    final game = GameRegistry.getById(kHangmanGameId);
    if (game == null) return;
    showHowToPlaySheet(context, title: game.name, howToPlay: game.howToPlay,
      accent: _kAccent, steps: hangmanSteps(), gameId: kHangmanGameId);
  }

  // ── Game Logic ──

  void _guessLetter(String letter) {
    if (_gameOver || _guessedLetters.contains(letter)) return;

    setState(() => _guessedLetters.add(letter));
    _audio.playTap();

    if (_word.contains(letter)) {
      _audio.playScore();
      _consecutiveWrongs = 0;
      _idleStuck = false;
      _resetIdleTimer();
      final allRevealed = _word.split('').every((l) => _guessedLetters.contains(l));
      if (allRevealed) {
        _onWin();
      }
    } else {
      _consecutiveWrongs++;
      _resetIdleTimer();
      setState(() => _errors++);
      if (_errors >= _kMaxErrors) {
        _onLose();
      }
    }
  }

  bool get _isStuck => _consecutiveWrongs >= _kStuckWrongs || _idleStuck;

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleStuck) setState(() => _idleStuck = false);
    _idleTimer = Timer(_kIdleTimeout, () {
      if (mounted && _started && !_gameOver) {
        setState(() => _idleStuck = true);
      }
    });
  }

  void _useHint() {
    if (_gameOver || _hintUsed) return;
    if (!AdsService().isRewardedReady) return;
    _audio.playTap();
    const vowels = {'A', 'E', 'I', 'O', 'U'};
    final allUnrevealed = _word
        .split('')
        .toSet()
        .where((l) => !_guessedLetters.contains(l))
        .toList();
    if (allUnrevealed.isEmpty) return;
    final vowelUnrevealed = allUnrevealed.where((l) => vowels.contains(l)).toList();
    final candidates = vowelUnrevealed.isNotEmpty ? vowelUnrevealed : allUnrevealed;
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kHangmanGameId,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (!earned || !mounted) return;
        _consecutiveWrongs = 0;
        _idleStuck = false;
        _hintUsed = true;
        _resetIdleTimer();
        final pick = candidates[_rng.nextInt(candidates.length)];
        setState(() {
          _guessedLetters.add(pick);
        });
        _audio.playScore();
        final allRevealed =
            _word.split('').every((l) => _guessedLetters.contains(l));
        if (allRevealed) _onWin();
      },
    );
  }

  void _onWin() {
    setState(() {
      _gameOver = true;
      _won = true;
      _gamesWon++;
      _streak++;
    });

    final subKey = switch (_difficulty) {
      _Difficulty.easy => kHangmanSubKeyEasy,
      _Difficulty.medium => kHangmanSubKeyMedium,
      _Difficulty.hard => kHangmanSubKeyHard,
    };
    ScoreService().saveScore(kHangmanGameId, _streak, subKey: subKey).then((isNew) {
      if (mounted && isNew) setState(() => _wasNewBest = true);
    });
    _wrapper.updateScore(_streak);

    _audio.playSuccess();
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _wrapper.endGame(result: 'win');
    });
  }

  void _onLose() {
    setState(() {
      _gameOver = true;
      _won = false;
      _gamesLost++;
      _streak = 0;
      _wasNewBest = false;
    });
    _endGameTimer?.cancel();
    _endGameTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _wrapper.endGame(result: 'loss');
    });
  }

  String? _hangmanSubKey() => switch (_difficulty) {
    _Difficulty.easy => kHangmanSubKeyEasy,
    _Difficulty.medium => kHangmanSubKeyMedium,
    _Difficulty.hard => kHangmanSubKeyHard,
  };

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
    if (state == GameState.ready || !_started) return _buildPicker();
    if (state == GameState.gameOver) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.text_fields_rounded),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [Color(0xFF6C63FF), Color(0xFF9F97FF), Color(0xFF6C63FF)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kHangmanGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) {
          return ClipRRect(borderRadius: BorderRadius.circular(42), child: logo);
        }
        return const Icon(Icons.text_fields_rounded, size: 40, color: _kAccent);
      }),
      title: 'Hangman',
      subtitle: 'Guess the word before time runs out!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kHangmanGameId,
      body: GameSinglePickerBody(
        difficulties: _Difficulty.values.map((d) {
          final subKey = switch (d) {
            _Difficulty.easy => kHangmanSubKeyEasy,
            _Difficulty.medium => kHangmanSubKeyMedium,
            _Difficulty.hard => kHangmanSubKeyHard,
          };
          return GameDifficultyData(
            label: _diffLabel(d),
            color: _diffColor(d),
            kind: _kindFor(d),
            hint: switch (d) {
              _Difficulty.easy => 'Short, common words.',
              _Difficulty.medium => 'Longer words to challenge you.',
              _Difficulty.hard => 'Complex words — true word master!',
            },
            bestScore: bestHangmanScore(subKey),
            bestLabel: (s) => 'Best $s in a row',
          );
        }).toList(),
        activeIndex: _Difficulty.values.indexOf(_difficulty),
        onChanged: (i) => setState(() => _difficulty = _Difficulty.values[i]),
        onPlay: _startNewGame,
        playLabel: 'Play Hangman',
        playSubLabel: 'Guess the hidden word',
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kBgTop, _kBgBot],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome),
              centerContent: _StreakPill(streak: _streak, difficulty: _difficulty),
              trailing: GameRestartButton(
                gameName: 'Hangman',
                accentColor: _kAccent,
                onRestart: _playAgain,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _HangmanFigurePainter(errors: _errors),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _WordDisplay(
              word: _word,
              guessedLetters: _guessedLetters,
              gameOver: _gameOver,
            ),
            const SizedBox(height: 8),
            _ErrorIndicator(errors: _errors, maxErrors: _kMaxErrors),
            const SizedBox(height: 8),
            if (!_gameOver)
              Opacity(
                opacity: AdsService().isRewardedReady && !_hintUsed ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !AdsService().isRewardedReady || _hintUsed,
                  child: _HangmanHintNudge(onTap: _useHint, isStuck: _isStuck),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _Keyboard(
                guessedLetters: _guessedLetters,
                word: _word,
                onTap: _guessLetter,
                enabled: !_gameOver,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    return game_result.GenericGameResultScreen(
      gameId: kHangmanGameId,
      score: _streak,
      headline: _won ? 'You Got It!' : 'Game Over',
      badgeContent: _won ? '🎉' : '💀',
      badgeColor: _won ? _kCorrect : _kWrong,
      showNewBestBadge: _wasNewBest,
      subtitle: 'The word was: $_word',
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: 'WON', value: _gamesWon, color: _kCorrect),
          game_result.StatItem(label: 'STREAK', value: _streak, color: _kAccent),
          game_result.StatItem(label: 'LOST', value: _gamesLost, color: _kWrong),
          game_result.StatItem(
            label: 'BEST',
            value: ScoreService().getHighScore(kHangmanGameId, subKey: _hangmanSubKey()),
            color: const Color(0xFF6C63FF),
          ),
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again', icon: Icons.refresh_rounded, onTap: _playAgain,
          filled: true, color: _kAccent, actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Difficulty', icon: Icons.tune_rounded, onTap: _backToPicker, actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home', icon: Icons.home_rounded, onTap: _backOrHome, actionId: 'home',
        ),
      ],
    );
  }
}

// ── Streak Pill ──

class _StreakPill extends StatelessWidget {
  final int streak;
  final _Difficulty difficulty;
  const _StreakPill({required this.streak, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final tabColor = switch (difficulty) {
      _Difficulty.easy => _kEasyColor,
      _Difficulty.medium => _kMediumColor,
      _Difficulty.hard => _kHardColor,
    };
    final tabLabel = switch (difficulty) {
      _Difficulty.easy => 'EASY',
      _Difficulty.medium => 'MEDIUM',
      _Difficulty.hard => 'HARD',
    };
    final subKey = switch (difficulty) {
      _Difficulty.easy => kHangmanSubKeyEasy,
      _Difficulty.medium => kHangmanSubKeyMedium,
      _Difficulty.hard => kHangmanSubKeyHard,
    };
    final best = ScoreService().getHighScore(kHangmanGameId, subKey: subKey);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: tabColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          boxShadow: [BoxShadow(color: tabColor.withValues(alpha: 0.30),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Text(tabLabel,
            style: const TextStyle(color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 18, color: _kAccent),
              const SizedBox(width: 6),
              Text('$streak', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(width: 4),
              const Text('streak', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E), fontWeight: FontWeight.w500)),
            ],
          ),
          if (best > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('best $best',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    ]);
  }
}

// ── Word Display ──

class _WordDisplay extends StatelessWidget {
  final String word;
  final Set<String> guessedLetters;
  final bool gameOver;

  const _WordDisplay({required this.word, required this.guessedLetters, required this.gameOver});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: word.split('').map((letter) {
        final revealed = guessedLetters.contains(letter) || gameOver;
        final isWrong = gameOver && !guessedLetters.contains(letter);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 44,
          decoration: BoxDecoration(
            color: revealed
                ? (isWrong ? _kWrong.withValues(alpha: 0.15) : _kCorrect.withValues(alpha: 0.1))
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: revealed
                  ? (isWrong ? _kWrong.withValues(alpha: 0.4) : _kCorrect.withValues(alpha: 0.3))
                  : _kAccent.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: revealed
                ? Text(
                    letter,
                    key: ValueKey('$letter-revealed'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isWrong ? _kWrong : const Color(0xFF1E1B4B),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }).toList(),
    );
  }
}

// ── Error Indicator ──

class _ErrorIndicator extends StatelessWidget {
  final int errors;
  final int maxErrors;
  const _ErrorIndicator({required this.errors, required this.maxErrors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxErrors, (i) {
        final isUsed = i < errors;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUsed ? _kWrong : _kAccent.withValues(alpha: 0.15),
            ),
          ),
        );
      }),
    );
  }
}

// ── Keyboard ──

class _Keyboard extends StatelessWidget {
  final Set<String> guessedLetters;
  final String word;
  final ValueChanged<String> onTap;
  final bool enabled;

  const _Keyboard({
    required this.guessedLetters,
    required this.word,
    required this.onTap,
    required this.enabled,
  });

  static const _rows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((letter) {
              final guessed = guessedLetters.contains(letter);
              final isCorrect = guessed && word.contains(letter);
              final isWrong = guessed && !word.contains(letter);

              Color bg;
              Color fg;
              if (isCorrect) {
                bg = _kCorrect;
                fg = Colors.white;
              } else if (isWrong) {
                bg = const Color(0xFFE5E5E5);
                fg = const Color(0xFFBBBBBB);
              } else {
                bg = Colors.white;
                fg = const Color(0xFF1E1B4B);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: GestureDetector(
                  onTap: enabled && !guessed ? () => onTap(letter) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: guessed
                          ? []
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ── Hangman Figure ──

class _HangmanFigurePainter extends CustomPainter {
  final int errors;
  _HangmanFigurePainter({required this.errors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final gallowsPaint = Paint()
      ..color = const Color(0xFF8B6914)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final gallowsFill = Paint()
      ..color = const Color(0xFF8B6914).withValues(alpha: 0.12);

    final baseY = h * 0.94;
    final postX = w * 0.26;
    final topY = h * 0.06;
    final beamEndX = w * 0.60;
    final ropeLen = h * 0.10;

    canvas.drawLine(Offset(w * 0.08, baseY), Offset(w * 0.48, baseY), gallowsPaint);

    final basePath = Path()
      ..moveTo(w * 0.08, baseY)
      ..lineTo(w * 0.48, baseY)
      ..lineTo(w * 0.48, baseY + 3)
      ..lineTo(w * 0.08, baseY + 3)
      ..close();
    canvas.drawPath(basePath, gallowsFill);

    canvas.drawLine(Offset(postX, baseY), Offset(postX, topY), gallowsPaint);

    canvas.drawLine(Offset(postX, topY), Offset(beamEndX, topY), gallowsPaint);

    final bracePath = Path()
      ..moveTo(postX, topY + h * 0.12)
      ..lineTo(postX + w * 0.08, topY);
    canvas.drawPath(bracePath, gallowsPaint..strokeWidth = 2.5);
    gallowsPaint.strokeWidth = 4.5;

    final ropePaint = Paint()
      ..color = const Color(0xFF6B5B3A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(beamEndX, topY), Offset(beamEndX, topY + ropeLen), ropePaint);

    if (errors < 1) return;

    final cx = beamEndX;
    final headR = h * 0.075;
    final headCy = topY + ropeLen + headR;

    final skinColor = const Color(0xFFF5D0A9);
    final skinPaint = Paint()..color = skinColor;
    final outlinePaint = Paint()
      ..color = const Color(0xFFBE8C5E)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final limbPaint = Paint()
      ..color = const Color(0xFF5B4A8A)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final bodyFillPaint = Paint()
      ..color = const Color(0xFF6C5CE7).withValues(alpha: 0.15);

    if (errors >= 1) {
      canvas.drawCircle(Offset(cx, headCy), headR + 1, Paint()..color = Colors.black.withValues(alpha: 0.08));
      canvas.drawCircle(Offset(cx, headCy), headR, skinPaint);
      canvas.drawCircle(Offset(cx, headCy), headR, outlinePaint);

      final eyeY = headCy - headR * 0.15;
      final eyeSpacing = headR * 0.38;
      final eyeR = headR * 0.12;
      final eyePaint = Paint()..color = const Color(0xFF2D2D2D);

      if (errors < 6) {
        canvas.drawCircle(Offset(cx - eyeSpacing, eyeY), eyeR, eyePaint);
        canvas.drawCircle(Offset(cx + eyeSpacing, eyeY), eyeR, eyePaint);

        final pupilR = eyeR * 0.45;
        final pupilPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(cx - eyeSpacing - 0.5, eyeY - 0.5), pupilR, pupilPaint);
        canvas.drawCircle(Offset(cx + eyeSpacing - 0.5, eyeY - 0.5), pupilR, pupilPaint);

        if (errors <= 2) {
          final smilePath = Path()
            ..moveTo(cx - headR * 0.22, headCy + headR * 0.28)
            ..quadraticBezierTo(cx, headCy + headR * 0.48, cx + headR * 0.22, headCy + headR * 0.28);
          canvas.drawPath(smilePath, Paint()
            ..color = const Color(0xFFBE8C5E)
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
        } else {
          final worriedPath = Path()
            ..moveTo(cx - headR * 0.18, headCy + headR * 0.38)
            ..quadraticBezierTo(cx, headCy + headR * 0.22, cx + headR * 0.18, headCy + headR * 0.38);
          canvas.drawPath(worriedPath, Paint()
            ..color = const Color(0xFFBE8C5E)
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
        }
      } else {
        final xPaint = Paint()
          ..color = const Color(0xFFD32F2F)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        final xSize = headR * 0.18;
        canvas.drawLine(Offset(cx - eyeSpacing - xSize, eyeY - xSize), Offset(cx - eyeSpacing + xSize, eyeY + xSize), xPaint);
        canvas.drawLine(Offset(cx - eyeSpacing + xSize, eyeY - xSize), Offset(cx - eyeSpacing - xSize, eyeY + xSize), xPaint);
        canvas.drawLine(Offset(cx + eyeSpacing - xSize, eyeY - xSize), Offset(cx + eyeSpacing + xSize, eyeY + xSize), xPaint);
        canvas.drawLine(Offset(cx + eyeSpacing + xSize, eyeY - xSize), Offset(cx + eyeSpacing - xSize, eyeY + xSize), xPaint);

        final deadPath = Path()
          ..moveTo(cx - headR * 0.22, headCy + headR * 0.42)
          ..quadraticBezierTo(cx, headCy + headR * 0.26, cx + headR * 0.22, headCy + headR * 0.42);
        canvas.drawPath(deadPath, Paint()
          ..color = const Color(0xFFD32F2F)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
      }
    }

    final bodyTop = headCy + headR;
    final bodyBot = bodyTop + h * 0.24;

    if (errors >= 2) {
      final bodyPath = Path()
        ..moveTo(cx - w * 0.04, bodyTop)
        ..quadraticBezierTo(cx - w * 0.05, (bodyTop + bodyBot) / 2, cx - w * 0.02, bodyBot)
        ..lineTo(cx + w * 0.02, bodyBot)
        ..quadraticBezierTo(cx + w * 0.05, (bodyTop + bodyBot) / 2, cx + w * 0.04, bodyTop)
        ..close();
      canvas.drawPath(bodyPath, bodyFillPaint);

      final shirtPaint = Paint()
        ..color = const Color(0xFF6C5CE7)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx, bodyTop), Offset(cx, bodyBot), shirtPaint);

      final neckPaint = Paint()
        ..color = const Color(0xFFBE8C5E)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx, bodyTop - 1), Offset(cx, bodyTop + h * 0.02), neckPaint);
    }

    final shoulderY = bodyTop + h * 0.06;
    final armLen = w * 0.14;
    final armDropY = h * 0.12;

    if (errors >= 3) {
      final leftArm = Path()
        ..moveTo(cx, shoulderY)
        ..quadraticBezierTo(cx - armLen * 0.5, shoulderY + armDropY * 0.3, cx - armLen, shoulderY + armDropY);
      canvas.drawPath(leftArm, limbPaint);
      canvas.drawCircle(Offset(cx - armLen, shoulderY + armDropY), 3.0, Paint()..color = skinColor);
      canvas.drawCircle(Offset(cx - armLen, shoulderY + armDropY), 3.0, Paint()
        ..color = const Color(0xFFBE8C5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
    }

    if (errors >= 4) {
      final rightArm = Path()
        ..moveTo(cx, shoulderY)
        ..quadraticBezierTo(cx + armLen * 0.5, shoulderY + armDropY * 0.3, cx + armLen, shoulderY + armDropY);
      canvas.drawPath(rightArm, limbPaint);
      canvas.drawCircle(Offset(cx + armLen, shoulderY + armDropY), 3.0, Paint()..color = skinColor);
      canvas.drawCircle(Offset(cx + armLen, shoulderY + armDropY), 3.0, Paint()
        ..color = const Color(0xFFBE8C5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
    }

    final legLen = w * 0.10;
    final legDropY = h * 0.18;

    if (errors >= 5) {
      final leftLeg = Path()
        ..moveTo(cx, bodyBot)
        ..quadraticBezierTo(cx - legLen * 0.4, bodyBot + legDropY * 0.6, cx - legLen, bodyBot + legDropY);
      canvas.drawPath(leftLeg, limbPaint);
      final footPaint = Paint()
        ..color = const Color(0xFF3D3268)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx - legLen, bodyBot + legDropY),
        Offset(cx - legLen - w * 0.03, bodyBot + legDropY),
        footPaint,
      );
    }

    if (errors >= 6) {
      final rightLeg = Path()
        ..moveTo(cx, bodyBot)
        ..quadraticBezierTo(cx + legLen * 0.4, bodyBot + legDropY * 0.6, cx + legLen, bodyBot + legDropY);
      canvas.drawPath(rightLeg, limbPaint);
      final footPaint = Paint()
        ..color = const Color(0xFF3D3268)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(cx + legLen, bodyBot + legDropY),
        Offset(cx + legLen + w * 0.03, bodyBot + legDropY),
        footPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_HangmanFigurePainter old) => old.errors != errors;
}

class _HangmanHintNudge extends StatefulWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _HangmanHintNudge({required this.onTap, required this.isStuck});
  @override
  State<_HangmanHintNudge> createState() => _HangmanHintNudgeState();
}

class _HangmanHintNudgeState extends State<_HangmanHintNudge> with TickerProviderStateMixin {
  static const _kBg = Color(0xFFFFD43B);
  static const _kFg = Color(0xFF5C4600);

  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    if (widget.isStuck) {
      _pulseCtrl.repeat(reverse: true);
      _slideCtrl.forward();
    }
  }

  @override
  void didUpdateWidget(_HangmanHintNudge old) {
    super.didUpdateWidget(old);
    if (widget.isStuck && !old.isStuck) {
      _pulseCtrl.repeat(reverse: true);
      _slideCtrl.forward();
    } else if (!widget.isStuck && old.isStuck) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
      _slideCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              final glow = widget.isStuck ? _pulseCtrl.value : 0.0;
              final scale = 1.0 + glow * 0.05;
              return Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE6BE00), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _kBg.withValues(alpha: 0.30 + glow * 0.40),
                          blurRadius: 12 + glow * 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lightbulb_rounded, size: 16, color: _kFg),
                        const SizedBox(width: 6),
                        const Text(
                          'HINT',
                          style: TextStyle(
                            color: _kFg,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kFg.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 12, color: _kFg),
                              SizedBox(width: 2),
                              Text(
                                'AD',
                                style: TextStyle(
                                  color: _kFg,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: 38,
            child: AnimatedBuilder(
              animation: _slideCtrl,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: Transform.translate(
                    offset: Offset(0, (1 - _slideAnim.value.clamp(0.0, 1.0)) * 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kAccent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: _kAccent.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Stuck? Try a hint!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: const Size(14, 7),
                          painter: _HangmanBubbleTailPainter(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HangmanBubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _kAccent;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
