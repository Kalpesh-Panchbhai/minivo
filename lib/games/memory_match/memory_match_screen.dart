import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import 'memory_match_stats.dart';
import 'memory_match_tutorial.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_undo_button.dart';

// ── Palette ────────────────────────────────────────────────────────────────
const Color _kBgTop    = Color(0xFFD0E8FF);
const Color _kBgBot    = Color(0xFFADD3FF);
const Color _kAccent   = Color(0xFF339AF0);
const Color _kAccentDk = Color(0xFF1971C2);
// Board ambient tints — very subtle warm/cool shift, slow transition avoids flicker
const Color _kTintWarmTop = Color(0xFFFFF5F5);   // P1 coral turn (top)
const Color _kTintWarmBot = Color(0xFFFFF0F0);   // P1 coral turn (bottom)
const Color _kTintCoolTop = Color(0xFFF0F7FF);   // P2/AI cyan turn (top)
const Color _kTintCoolBot = Color(0xFFE8F3FA);   // P2/AI cyan turn (bottom)

// ── Player colors ──────────────────────────────────────────────────────────
const Color _kP1Color  = Color(0xFFE85D75); // coral red  (local / P1)
const Color _kP2Color  = Color(0xFF5BC0DE); // sky cyan   (AI / P2)
// ── Difficulty palette ─────────────────────────────────────────────────────
const Color _kEasyColor   = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor   = Color(0xFFEF4444);

// ── Emoji categories ───────────────────────────────────────────────────────
const _kEmojiCategories = <String, List<String>>{
  'Animals': [
    '🐶','🐱','🦊','🐸','🦁','🐻','🐼','🐧','🐨','🐯',
    '🦄','🐮','🐷','🐙','🦀','🦋','🐝','🦚','🦜','🦩',
  ],
  'Fruits': [
    '🍎','🍊','🍋','🍇','🍓','🍒','🍑','🥭','🍍','🥝',
    '🍌','🍉','🍈','🫐','🍏','🍐','🥥','🍅','🥑','🍆',
  ],
  'Plants & Nature': [
    '🌸','🌺','🌻','🌹','🌷','🌴','🌵','🌿','🍁','🍄',
    '🌾','🎋','🎍','🪷','🌼','🌱','🪴','🍃','🪻','🌲',
  ],
  'Space & Weather': [
    '🌙','⭐','🌟','☀️','🌈','⚡','❄️','🌊','🔥','🌪️',
    '🪐','🌍','🌕','☁️','🌠','🌌','🌀','⛄','🌋','🏔️',
  ],
  'Food & Drinks': [
    '🍕','🍔','🌮','🍣','🍜','🍩','🍦','🧁','🎂','🍫',
    '🍿','🧃','🍵','☕','🧋','🥤','🍺','🧇','🥞','🍟',
  ],
  'Sports & Activities': [
    '⚽','🏀','🎾','🏈','⚾','🎱','🏓','🏊','🚴','🧗',
    '🎯','🏹','🎮','🎲','♟️','🎸','🎺','🎻','🥊','🤿',
  ],
  'Travel & Places': [
    '✈️','🚀','🚂','🚢','🏝️','🏕️','🗼','🗽','🏯','⛩️',
    '🎡','🎢','🎠','🏟️','🌉','🗿','🕌','🛸','🚁','🏖️',
  ],
};

List<String> _pickEmojiPool(math.Random rng) {
  final keys = _kEmojiCategories.keys.toList();
  return List<String>.from(_kEmojiCategories[keys[rng.nextInt(keys.length)]]!);
}

// ── Pair colors ────────────────────────────────────────────────────────────
const _kPairColors = [
  Color(0xFF4DABF7), Color(0xFFFF8787), Color(0xFFFF922B),
  Color(0xFF51CF66), Color(0xFFCC5DE8), Color(0xFFFFD43B),
  Color(0xFF20C997), Color(0xFFF06595), Color(0xFFA9E34B),
  Color(0xFF74C0FC), Color(0xFFFF6B6B), Color(0xFF9775FA),
];

// ── Difficulty ─────────────────────────────────────────────────────────────
enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label      => ['EASY', 'MEDIUM', 'HARD'][index];
  Color  get color      => [_kEasyColor, _kMediumColor, _kHardColor][index];
  String get subKey     => ['easy', 'medium', 'hard'][index];
  int    get cols       => [4, 4, 6][index];
  int    get rows       => [3, 4, 4][index];
  int    get pairCount  => (cols * rows) ~/ 2;
  int    get flipBackMs => [1100, 800, 550][index];
  // How long the AI pauses between flips (ms)
  int    get aiFlipGapMs => [900, 700, 500][index];
  // AI memory retention when watching human mismatches
  double get aiMemoryRate => [0.0, 0.50, 1.0][index];
  String get hint => [
        '4×3 grid • 6 pairs to find.',
        '4×4 grid • 8 pairs, faster flip-back.',
        '6×4 grid • 12 pairs, very fast flip-back.',
      ][index];
  DifficultyKind get kind => [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard,
      ][index];
}

// ── Mode ───────────────────────────────────────────────────────────────────
enum _Mode { ai, twoPlayer }

// ── Card model ─────────────────────────────────────────────────────────────
class _Card {
  final int id;
  final String emoji;
  final int pairColorIdx;
  bool faceUp;
  bool matched;
  bool mismatch;

  _Card({required this.id, required this.emoji, required this.pairColorIdx})
      : faceUp = false,
        matched = false,
        mismatch = false;
}

// ════════════════════════════════════════════════════════════════
// Root screen
// ════════════════════════════════════════════════════════════════

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen>
    with TickerProviderStateMixin {

  // ── Mode / difficulty selection ──────────────────────────────────────────
  _Mode? _mode;
  _Difficulty _pickerDiff = _Difficulty.values[DifficultyKind.defaultIndex];
  _Difficulty? _activeDiff;

  bool _isFavorite = false;

  // ── Per-game state ────────────────────────────────────────────────────────
  List<_Card> _cards = [];
  int _currentTurn = 0;    // 0 = P1 (bottom/local), 1 = P2 (top/AI or friend)
  int _p1Matches = 0;
  int _p2Matches = 0;
  bool _aiThinking = false;
  int? _firstFlipIdx;
  bool _lockInput = false;
  bool _gameOver = false;
  bool _wasNewBest = false;

  // AI memory: cardIndex → emoji the AI has "memorised"
  final Map<int, String> _aiMemory = {};

  // Undo support (AI mode only, 1 per game, on first flip)
  bool _undoUsed = false;
  bool _showUndoButton = false;
  int? _undoFirstIdx;

  // ── Animation controllers ─────────────────────────────────────────────────
  List<AnimationController> _flipCtrl = [];
  List<AnimationController> _bounceCtrl = [];
  List<AnimationController> _matchCtrl = [];
  late AnimationController _celebrationCtrl;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _flipBackTimer;
  Timer? _aiTimer;

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kMemoryMatchGameId);
    _celebrationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void dispose() {
    _cancelAllTimers();
    for (final c in _flipCtrl)   { c.dispose(); }
    for (final c in _bounceCtrl) { c.dispose(); }
    for (final c in _matchCtrl)  { c.dispose(); }
    _celebrationCtrl.dispose();
    super.dispose();
  }

  void _cancelAllTimers() {
    _flipBackTimer?.cancel();
    _aiTimer?.cancel();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kMemoryMatchGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kMemoryMatchGameId);
    if (info == null) return;
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: memoryMatchSteps(),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // GAME SETUP
  // ════════════════════════════════════════════════════════════════

  void _selectMode(_Mode mode) {
    _cancelAllTimers();
    _celebrationCtrl.reset();
    _mode = mode; // set before startGame's setState so build never sees mode≠null + activeDiff==null
    _startGame(_pickerDiff, disposeFirst: false);
    GameWrapper.of(context).startGame();
  }

  void _startGame(_Difficulty diff, {bool disposeFirst = true}) {
    _cancelAllTimers();
    if (disposeFirst) {
      for (final c in _flipCtrl)   { c.dispose(); }
      for (final c in _bounceCtrl) { c.dispose(); }
      for (final c in _matchCtrl)  { c.dispose(); }
    }
    _celebrationCtrl.reset();
    _aiMemory.clear();

    final pool = _pickEmojiPool(_rng)..shuffle(_rng);
    final emojis = pool.take(diff.pairCount).toList();
    final cardEmojis = [...emojis, ...emojis]..shuffle(_rng);

    final cards = List.generate(cardEmojis.length, (i) {
      final emoji = cardEmojis[i];
      final colorIdx = emojis.indexOf(emoji) % _kPairColors.length;
      return _Card(id: i, emoji: emoji, pairColorIdx: colorIdx);
    });

    final flipControllers = List.generate(
      cards.length,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 320)),
    );
    final bounceControllers = List.generate(
      cards.length,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 420)),
    );
    final matchControllers = List.generate(
      cards.length,
      (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 500)),
    );

    // Who goes first? Random.
    final firstTurn = _rng.nextBool() ? 0 : 1;

    setState(() {
      _activeDiff   = diff;
      _pickerDiff   = diff;
      _cards        = cards;
      _flipCtrl     = flipControllers;
      _bounceCtrl   = bounceControllers;
      _matchCtrl    = matchControllers;
      _currentTurn  = firstTurn;
      _p1Matches    = 0;
      _p2Matches    = 0;
      _aiThinking   = false;
      _firstFlipIdx = null;
      _lockInput    = false;
      _gameOver     = false;
      _wasNewBest   = false;
      _undoUsed     = false;
      _showUndoButton = false;
      _undoFirstIdx = null;
    });

    ScoreService().incrementGamePlayCount(kMemoryMatchGameId);

    // Stagger bounce-in
    for (int i = 0; i < bounceControllers.length; i++) {
      final delay = Duration(milliseconds: (i * 40).clamp(0, 600));
      Future.delayed(delay, () {
        if (mounted) bounceControllers[i].forward();
      });
    }

    // If AI goes first
    if (_mode == _Mode.ai && firstTurn == 1) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _scheduleAiTurn();
      });
    }
  }

  // ════════════════════════════════════════════════════════════════
  // HUMAN CARD TAP
  // ════════════════════════════════════════════════════════════════

  void _onCardTap(int index) {
    final diff = _activeDiff;
    if (diff == null || _lockInput || _gameOver || _aiThinking) return;
    if (_mode == _Mode.ai && _currentTurn == 1) return;

    final card = _cards[index];
    if (card.faceUp || card.matched) return;

    AudioService().playTap();

    setState(() {
      card.faceUp = true;
    });
    _flipCtrl[index].forward(from: 0);

    if (_firstFlipIdx == null) {
      setState(() => _firstFlipIdx = index);
      final undoAvailable = _mode == _Mode.ai &&
          _currentTurn == 0 &&
          !_undoUsed &&
          AdsService().isRewardedReady;
      if (undoAvailable) {
        setState(() {
          _showUndoButton = true;
          _undoFirstIdx = index;
        });
      }
    } else {
      if (_showUndoButton) {
        setState(() {
          _showUndoButton = false;
          _undoFirstIdx = null;
        });
      }
      final firstIdx = _firstFlipIdx!;
      setState(() {
        _firstFlipIdx = null;
        _lockInput = true;
      });
      _evaluate(firstIdx, index, fromAi: false);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // MATCH / MISMATCH EVALUATION
  // ════════════════════════════════════════════════════════════════

  void _evaluate(int firstIdx, int secondIdx, {required bool fromAi}) {
    final diff = _activeDiff!;
    final first  = _cards[firstIdx];
    final second = _cards[secondIdx];

    if (first.emoji == second.emoji) {
      // ── MATCH ──────────────────────────────────────────────────
      AudioService().playScore();

      setState(() {
        first.matched  = true;
        second.matched = true;
        if (_currentTurn == 0) {
          _p1Matches++;
        } else {
          _p2Matches++;
        }
        _lockInput = false;
      });

      _matchCtrl[firstIdx].forward(from: 0);
      _matchCtrl[secondIdx].forward(from: 0);

      final totalMatched = _p1Matches + _p2Matches;

      // Update game score for wrapper
      GameWrapper.of(context).updateScore(
        _currentTurn == 0 ? _p1Matches : _p2Matches,
      );

      if (totalMatched == diff.pairCount) {
        // All pairs found — game over
        _finishGame();
      } else {
        // Current player continues their turn
        if (_mode == _Mode.ai && _currentTurn == 1) {
          _aiTimer = Timer(Duration(milliseconds: diff.aiFlipGapMs), () {
            if (mounted) _scheduleAiTurn();
          });
        }
      }
    } else {
      // ── MISMATCH ───────────────────────────────────────────────
      if (_mode == _Mode.ai && !fromAi) {
        _maybeMemoize(firstIdx, diff);
        _maybeMemoize(secondIdx, diff);
      }

      setState(() {
        first.mismatch  = true;
        second.mismatch = true;
      });

      _flipBackTimer?.cancel();
      _flipBackTimer = Timer(Duration(milliseconds: diff.flipBackMs), () {
        if (!mounted) return;
        _flipCtrl[firstIdx].reverse();
        _flipCtrl[secondIdx].reverse();
        setState(() {
          first.faceUp = false;
          first.mismatch = false;
          second.faceUp = false;
          second.mismatch = false;
          _lockInput = false;
        });
        _advanceTurn();
      });
    }
  }

  bool get _canUndo => _showUndoButton && !_undoUsed;

  void _onUndoExpired() {
    if (!mounted || !_showUndoButton) return;
    setState(() {
      _showUndoButton = false;
      _undoFirstIdx = null;
    });
  }

  void _performUndo() {
    final idx = _undoFirstIdx;
    if (idx == null) return;
    _flipCtrl[idx].reverse();
    setState(() {
      _cards[idx].faceUp = false;
      _firstFlipIdx = null;
      _undoUsed = true;
      _showUndoButton = false;
      _undoFirstIdx = null;
    });
  }

  void _advanceTurn() {
    setState(() => _currentTurn = _currentTurn == 0 ? 1 : 0);
    if (_mode == _Mode.ai && _currentTurn == 1) {
      _aiTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) _scheduleAiTurn();
      });
    }
  }

  // ════════════════════════════════════════════════════════════════
  // AI TURN
  // ════════════════════════════════════════════════════════════════

  void _scheduleAiTurn() {
    if (!mounted || _gameOver) return;
    final diff = _activeDiff!;

    setState(() {
      _aiThinking = true;
      _lockInput  = true;
    });

    final (idx1, idx2) = _aiPickCards();

    // Flip first card after thinking delay
    _aiTimer = Timer(Duration(milliseconds: diff.aiFlipGapMs), () {
      if (!mounted || _gameOver) return;

      setState(() {
        _aiThinking = false;
        _cards[idx1].faceUp = true;
      });
      _flipCtrl[idx1].forward(from: 0);
      // AI always memorises cards it flips
      _aiMemory[idx1] = _cards[idx1].emoji;

      // Flip second card after a short pause
      _aiTimer = Timer(Duration(milliseconds: diff.aiFlipGapMs), () {
        if (!mounted || _gameOver) return;

        setState(() => _cards[idx2].faceUp = true);
        _flipCtrl[idx2].forward(from: 0);
        _aiMemory[idx2] = _cards[idx2].emoji;

        // Evaluate
        _aiTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) _evaluate(idx1, idx2, fromAi: true);
        });
      });
    });
  }

  /// Pick two unmatched card indices for the AI.
  (int, int) _aiPickCards() {
    final diff = _activeDiff!;
    final available = _cards.asMap().entries
        .where((e) => !e.value.matched)
        .map((e) => e.key)
        .toList();

    // Look for a known pair in AI memory
    final byEmoji = <String, List<int>>{};
    for (final idx in available) {
      final known = _aiMemory[idx];
      if (known != null) {
        byEmoji.putIfAbsent(known, () => []).add(idx);
      }
    }
    final knownPairs = byEmoji.entries
        .where((e) => e.value.length >= 2)
        .toList();

    if (knownPairs.isNotEmpty) {
      final useMemory = switch (diff) {
        _Difficulty.easy   => _rng.nextDouble() < 0.25,
        _Difficulty.medium => _rng.nextDouble() < 0.65,
        _Difficulty.hard   => true,
      };
      if (useMemory) {
        final pair = knownPairs[_rng.nextInt(knownPairs.length)].value;
        return (pair[0], pair[1]);
      }
    }

    // Random pick
    available.shuffle(_rng);
    return (available[0], available[1]);
  }

  /// Maybe add a card to AI memory based on difficulty retention rate.
  void _maybeMemoize(int idx, _Difficulty diff) {
    if (_rng.nextDouble() < diff.aiMemoryRate) {
      _aiMemory[idx] = _cards[idx].emoji;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // GAME OVER
  // ════════════════════════════════════════════════════════════════

  void _finishGame() {
    _cancelAllTimers();
    final diff = _activeDiff!;

    // Save score in AI mode (player's pair count)
    if (_mode == _Mode.ai) {
      ScoreService().saveScore(
        kMemoryMatchGameId, _p1Matches, subKey: diff.subKey,
      ).then((isNew) {
        if (mounted && isNew) setState(() => _wasNewBest = true);
      });
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _celebrationCtrl.forward();
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() => _gameOver = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) GameWrapper.of(context).endGame();
          });
        }
      });
    });
  }

  void _newGame() {
    final mode = _mode!;
    final diff = _activeDiff!;
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    _startGame(diff);
    // preserve mode
    setState(() => _mode = mode);
  }

  void _backToPicker() {
    _cancelAllTimers();
    GameWrapper.of(context).restartGame();
    setState(() {
      _mode        = null;
      _activeDiff  = null;
      _gameOver    = false;
      _p1Matches   = 0;
      _p2Matches   = 0;
      _currentTurn = 0;
      _aiThinking  = false;
    });
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_mode == null)  return _buildPicker();
    if (_gameOver)      return _buildGameOver();
    return _buildGame();
  }

  // ── Picker ────────────────────────────────────────────────────────────────

  Widget _buildPicker() {
    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBot,
      animatedBg: AnimatedBackground(
        factory: (t) => _MemoryBgPainter(t),
        period: const Duration(seconds: 14),
      ),
      iconRingColors: const [_kAccent, _kAccentDk, _kAccent],
      iconChild: ClipOval(
        child: GameRegistry.getById(kMemoryMatchGameId)
                ?.buildBrandedLogo(size: 84) ??
            const SizedBox.shrink(),
      ),
      title: 'Memory Match',
      subtitle: 'Flip • Match • Remember',
      onBack: () => context.pop(),
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kMemoryMatchGameId,
      tallThreshold: 860,
      body: _ModePickerBody(
        difficulty: _pickerDiff,
        onDifficultyChanged: (d) => setState(() => _pickerDiff = d),
        onPlayAi:     () => _selectMode(_Mode.ai),
        onPlayFriend: () => _selectMode(_Mode.twoPlayer),
      ),
    );
  }

  // ── Game ──────────────────────────────────────────────────────────────────

  Widget _buildGame() {
    final diff = _activeDiff!;
    final isAiMode = _mode == _Mode.ai;
    final p1Active = (_currentTurn == 0 || _showUndoButton) && !_gameOver;
    final p2Active = _currentTurn == 1 && !_showUndoButton && !_gameOver;

    final isP1Turn = _currentTurn == 0 || _showUndoButton;
    final topTint = isP1Turn ? _kTintWarmTop : _kTintCoolTop;
    final botTint = isP1Turn ? _kTintWarmBot : _kTintCoolBot;

    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      tween: ColorTween(end: topTint),
      builder: (context, animTop, _) {
        return TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          tween: ColorTween(end: botTint),
          builder: (context, animBot, _) {
            return Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [animTop ?? topTint, animBot ?? botTint],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 4),
                // HUD
                GameHudBar(
                  leading: GameBackButton(
                    onTap: _backToPicker,
                    iconColor: _kAccentDk,
                  ),
                  centerContent: _MultiScorePill(
                    mode: _mode!,
                    diff: diff,
                    p1Matches: _p1Matches,
                    p2Matches: _p2Matches,
                  ),
                  trailing: GameRestartButton(
                    gameName: 'Memory Match',
                    accentColor: _kAccent,
                    onRestart: _newGame,
                    iconColor: _kAccentDk,
                  ),
                ),
                const SizedBox(height: 6),
                // Progress bar (combined)
                _ProgressBar(
                  matched: _p1Matches + _p2Matches,
                  total: diff.pairCount,
                  color: diff.color,
                ),
                const SizedBox(height: 8),
                // ── Opponent strip (top) ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PlayerStrip(
                    label: isAiMode ? 'AI' : 'P2',
                    mark: 'P2',
                    markIcon: Icons.layers_rounded,
                    color: _kP2Color,
                    isActive: p2Active,
                    isThinking: _aiThinking,
                    avatarIcon: isAiMode ? Icons.smart_toy_rounded : null,
                  ),
                ),
                const SizedBox(height: 6),
                // ── Card grid ───────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _CardGrid(
                      cards: _cards,
                      flipControllers: _flipCtrl,
                      bounceControllers: _bounceCtrl,
                      matchControllers: _matchCtrl,
                      cols: diff.cols,
                      rows: diff.rows,
                      onCardTap: _onCardTap,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // ── Local player strip (bottom) ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PlayerStrip(
                    label: isAiMode ? 'You' : 'P1',
                    mark: 'P1',
                    markIcon: Icons.layers_rounded,
                    color: _kP1Color,
                    isActive: p1Active,
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: _canUndo
                      ? Center(
                          child: RewardedUndoButton(
                            key: ValueKey('undo_$_undoFirstIdx'),
                            onUndo: _performUndo,
                            onExpired: _onUndoExpired,
                            accentColor: _kP1Color,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        // Win celebration
        AnimatedBuilder(
          animation: _celebrationCtrl,
          builder: (_, child) {
            if (_celebrationCtrl.value == 0) return const SizedBox.shrink();
            return Positioned.fill(
              child: IgnorePointer(
                child: _WinCelebrationOverlay(progress: _celebrationCtrl.value),
              ),
            );
          },
        ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Game Over ─────────────────────────────────────────────────────────────

  Widget _buildGameOver() {
    final diff = _activeDiff!;
    final isAiMode = _mode == _Mode.ai;
    final total = diff.pairCount;

    final String headline;
    final String badge;
    final Color badgeColor;

    if (_p1Matches > _p2Matches) {
      headline = isAiMode ? 'You Win! 🎉' : 'P1 Wins! 🎉';
      badge = '🏆';
      badgeColor = _kP1Color;
    } else if (_p2Matches > _p1Matches) {
      headline = isAiMode ? 'AI Wins 🤖' : 'P2 Wins! 🎉';
      badge = isAiMode ? '🤖' : '🏆';
      badgeColor = _kP2Color;
    } else {
      headline = "It's a Tie! 🤝";
      badge = '🤝';
      badgeColor = _kAccent;
    }

    final showNewBest = _wasNewBest && isAiMode && _p1Matches > _p2Matches;

    return game_result.GenericGameResultScreen(
      gameId: kMemoryMatchGameId,
      score: _p1Matches,
      headline: headline,
      subtitle: '${diff.cols}×${diff.rows} grid • $total pairs',
      badgeContent: badge,
      badgeColor: badgeColor,
      showNewBestBadge: showNewBest,
      statsWidget: game_result.GameResultPlayersRow(
        p1Label: isAiMode ? 'YOU' : 'P1',
        p2Label: isAiMode ? 'AI' : 'P2',
        p1Score: _p1Matches,
        p2Score: _p2Matches,
        p1Color: _kP1Color,
        p2Color: _kP2Color,
        p1IsWinner: _p1Matches > _p2Matches,
        p2IsWinner: _p2Matches > _p1Matches,
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
          filled: true,
          color: badgeColor,
        ),
        game_result.GameResultAction(
          label: 'Change Mode',
          icon: Icons.tune_rounded,
          onTap: _backToPicker,
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: () => context.go('/home'),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MODE PICKER BODY
// ════════════════════════════════════════════════════════════════

class _ModePickerBody extends StatelessWidget {
  final _Difficulty difficulty;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final VoidCallback onPlayAi;
  final VoidCallback onPlayFriend;

  const _ModePickerBody({
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.onPlayAi,
    required this.onPlayFriend,
  });

  @override
  Widget build(BuildContext context) {
    return GameAiPickerBody(
      difficulties: _Difficulty.values.map((d) => GameDifficultyData(
        label: d.label,
        color: d.color,
        kind: d.kind,
        hint: d.hint,
        bestScore: ScoreService().getHighScore(kMemoryMatchGameId, subKey: d.subKey),
        bestLabel: (s) => 'Best $s pairs found',
      )).toList(),
      activeIndex: _Difficulty.values.indexOf(difficulty),
      onChanged: (i) => onDifficultyChanged(_Difficulty.values[i]),
      onPlayAi: onPlayAi,
      onPlayFriend: onPlayFriend,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MULTIPLAYER SCORE PILL
// ════════════════════════════════════════════════════════════════

class _MultiScorePill extends StatelessWidget {
  final _Mode mode;
  final _Difficulty diff;
  final int p1Matches;
  final int p2Matches;

  const _MultiScorePill({
    required this.mode,
    required this.diff,
    required this.p1Matches,
    required this.p2Matches,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = mode == _Mode.ai;
    final leftLabel = isAi ? 'YOU' : 'P1';
    final rightLabel = isAi ? 'AI' : 'P2';
    final tabColor = diff.color;

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
              AnimatedDifficultyIcon(kind: diff.kind, size: 14, prominent: false),
              const SizedBox(width: 6),
              Text(
                diff.label,
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8475C2).withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _scoreColumn(leftLabel, p1Matches, _kP1Color),
              const SizedBox(width: 14),
              const Text(
                'VS',
                style: TextStyle(
                  color: Color(0xFF8B7BA7),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 14),
              _scoreColumn(rightLabel, p2Matches, _kP2Color),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreColumn(String label, int value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
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
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PROGRESS BAR
// ════════════════════════════════════════════════════════════════

class _ProgressBar extends StatelessWidget {
  final int matched;
  final int total;
  final Color color;

  const _ProgressBar({
    required this.matched,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : matched / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$matched / $total pairs found',
                style: TextStyle(
                  color: _kAccentDk.withValues(alpha: 0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: _kAccent.withValues(alpha: 0.14),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  widthFactor: progress,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, Color.lerp(color, Colors.white, 0.30)!],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// WIN CELEBRATION OVERLAY
// ════════════════════════════════════════════════════════════════

class _WinCelebrationOverlay extends StatelessWidget {
  final double progress;
  const _WinCelebrationOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ConfettiPainter(progress));
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  static final _rng = math.Random(42);
  static final _particles = List.generate(60, (i) => _ConfettiParticle(
    x: _rng.nextDouble(),
    startY: -0.05 - _rng.nextDouble() * 0.3,
    speedY: 0.35 + _rng.nextDouble() * 0.45,
    speedX: (_rng.nextDouble() - 0.5) * 0.18,
    size: 5 + _rng.nextDouble() * 8,
    color: _randomColor(_rng),
    rotation: _rng.nextDouble() * math.pi * 2,
    rotSpeed: (_rng.nextDouble() - 0.5) * 8,
    delay: _rng.nextDouble() * 0.4,
    shape: _rng.nextInt(3),
  ));

  static Color _randomColor(math.Random rng) {
    const colors = [
      Color(0xFFFFD43B), Color(0xFF74C0FC), Color(0xFF51CF66),
      Color(0xFFFF6B6B), Color(0xFFCC5DE8), Color(0xFFFF922B),
      Color(0xFFA9E34B), Color(0xFFF06595),
    ];
    return colors[rng.nextInt(colors.length)];
  }

  const _ConfettiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final pt = ((t - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (pt <= 0) continue;
      final x = (p.x + p.speedX * pt) * size.width;
      final y = (p.startY + p.speedY * pt) * size.height;
      final alpha = (1.0 - math.max(0.0, pt - 0.7) / 0.3).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: alpha.toDouble());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotSpeed * pt);
      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
        default:
          final path = Path()
            ..moveTo(0, -p.size * 0.5)
            ..lineTo(p.size * 0.5, p.size * 0.5)
            ..lineTo(-p.size * 0.5, p.size * 0.5)
            ..close();
          canvas.drawPath(path, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _ConfettiParticle {
  final double x, startY, speedY, speedX, size, rotation, rotSpeed, delay;
  final Color color;
  final int shape;
  const _ConfettiParticle({
    required this.x, required this.startY, required this.speedY,
    required this.speedX, required this.size, required this.color,
    required this.rotation, required this.rotSpeed, required this.delay,
    required this.shape,
  });
}

// ════════════════════════════════════════════════════════════════
// DIFFICULTY UI WIDGETS
// ════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════
// CARD GRID
// ════════════════════════════════════════════════════════════════

class _CardGrid extends StatelessWidget {
  final List<_Card> cards;
  final List<AnimationController> flipControllers;
  final List<AnimationController> bounceControllers;
  final List<AnimationController> matchControllers;
  final int cols;
  final int rows;
  final ValueChanged<int> onCardTap;

  const _CardGrid({
    required this.cards,
    required this.flipControllers,
    required this.bounceControllers,
    required this.matchControllers,
    required this.cols,
    required this.rows,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final cardW = (c.maxWidth  - gap * (cols - 1)) / cols;
        final cardH = (c.maxHeight - gap * (rows - 1)) / rows;

        return Stack(
          children: List.generate(cards.length, (i) {
            final col = i % cols;
            final row = i ~/ cols;
            return Positioned(
              left: col * (cardW + gap),
              top:  row * (cardH + gap),
              width: cardW,
              height: cardH,
              child: _FlipCard(
                card: cards[i],
                controller: flipControllers[i],
                bounceController: bounceControllers[i],
                matchController: matchControllers[i],
                onTap: () => onCardTap(i),
              ),
            );
          }),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FLIP CARD
// ════════════════════════════════════════════════════════════════

class _FlipCard extends StatelessWidget {
  final _Card card;
  final AnimationController controller;
  final AnimationController bounceController;
  final AnimationController matchController;
  final VoidCallback onTap;

  const _FlipCard({
    required this.card,
    required this.controller,
    required this.bounceController,
    required this.matchController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bounceController, matchController]),
      builder: (_, child) {
        final bounceAnim = CurvedAnimation(
          parent: bounceController, curve: Curves.easeOutBack,
        );
        final bounceScale = bounceController.status == AnimationStatus.completed
            ? 1.0
            : Tween<double>(begin: 0.0, end: 1.0).evaluate(bounceAnim);

        final matchAnim = CurvedAnimation(parent: matchController, curve: Curves.easeOut);
        final matchScale = (matchController.isAnimating || matchController.isCompleted)
            ? TweenSequence<double>([
                TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 40),
                TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 60),
              ]).evaluate(matchAnim)
            : 1.0;

        return Transform.scale(
          scale: bounceScale * matchScale,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              child!,
              if (card.matched && matchController.isAnimating)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: matchController,
                    builder: (context, _) => CustomPaint(
                      painter: _SparkleOverlayPainter(
                        progress: matchController.value,
                        color: _kPairColors[card.pairColorIdx % _kPairColors.length],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final anim = controller.value;
            final scaleX = anim < 0.5 ? 1.0 - anim * 2 : (anim - 0.5) * 2;
            final showFront = anim >= 0.5 || card.faceUp;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, 1.0, 1.0),
              child: _CardFace(card: card, faceUp: showFront),
            );
          },
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final _Card card;
  final bool faceUp;

  const _CardFace({required this.card, required this.faceUp});

  @override
  Widget build(BuildContext context) {
    final pairColor = _kPairColors[card.pairColorIdx % _kPairColors.length];
    final glowColor = card.matched
        ? const Color(0xFF22C55E)
        : card.mismatch
            ? const Color(0xFFEF4444)
            : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: faceUp ? const Color(0xFFFAFDFF) : null,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor.withValues(alpha: card.matched ? 0.55 : 0.45),
              blurRadius: card.matched ? 14 : 10,
              spreadRadius: card.matched ? 2 : 1,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
        border: card.matched
            ? Border.all(color: const Color(0xFF22C55E), width: 2.5)
            : card.mismatch
                ? Border.all(color: const Color(0xFFEF4444), width: 2.0)
                : faceUp
                    ? Border.all(color: pairColor.withValues(alpha: 0.55), width: 2.0)
                    : null,
        gradient: faceUp
            ? null
            : const LinearGradient(
                colors: [Color(0xFF4C3F91), Color(0xFF3949AB), Color(0xFF1A237E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: faceUp ? _FaceSide(card: card) : const _BackSide(),
      ),
    );
  }
}

class _FaceSide extends StatelessWidget {
  final _Card card;
  const _FaceSide({required this.card});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (card.matched)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF22C55E).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: card.matched
                  ? Text(card.emoji, style: const TextStyle(fontSize: 32))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.08, duration: 700.ms, curve: Curves.easeInOut)
                  : Text(card.emoji, style: const TextStyle(fontSize: 32)),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackSide extends StatelessWidget {
  const _BackSide();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CardBackPainter());
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.20);
    const dotCols = 3, dotRows = 4;
    final rr = math.min(size.width, size.height) * 0.06;
    for (int r = 0; r < dotRows; r++) {
      for (int c = 0; c < dotCols; c++) {
        canvas.drawCircle(
          Offset(size.width * (c + 1) / (dotCols + 1), size.height * (r + 1) / (dotRows + 1)),
          rr, dotPaint,
        );
      }
    }
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    var offset = -size.height;
    while (offset < size.width + size.height) {
      canvas.drawLine(Offset(offset, 0), Offset(offset + size.height, size.height), linePaint);
      offset += 12.0;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.width * 0.1),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_CardBackPainter old) => false;
}

class _SparkleOverlayPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _SparkleOverlayPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width * 0.9;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi + progress * 0.5;
      final dist = maxR * progress;
      final radius = ((1.0 - progress) * size.width * 0.09).clamp(0.0, 20.0);
      paint.color = color.withValues(alpha: (1.0 - progress) * 0.85);
      canvas.drawCircle(
        Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist),
        radius, paint,
      );
    }
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4 + 0.125) * 2 * math.pi;
      final dist = maxR * 0.55 * progress;
      final radius = ((1.0 - progress) * size.width * 0.06).clamp(0.0, 12.0);
      paint.color = Colors.white.withValues(alpha: (1.0 - progress) * 0.75);
      canvas.drawCircle(
        Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist),
        radius, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkleOverlayPainter old) => old.progress != progress;
}

// ════════════════════════════════════════════════════════════════
// ANIMATED BACKGROUND
// ════════════════════════════════════════════════════════════════

class _MemoryBgPainter extends AnimatedBgPainter {
  const _MemoryBgPainter(super.t);

  @override
  void paintAt(Canvas canvas, Size size, double t) {
    final phase = t * 2 * math.pi;
    const items = [
      (0.08, 0.10, 56.0, 72.0, 0.0, false),
      (0.87, 0.15, 46.0, 60.0, 1.1, true),
      (0.12, 0.70, 52.0, 68.0, 2.2, false),
      (0.85, 0.72, 42.0, 55.0, 3.3, true),
      (0.50, 0.05, 40.0, 52.0, 4.4, false),
      (0.04, 0.42, 36.0, 47.0, 5.5, true),
      (0.72, 0.42, 44.0, 58.0, 0.7, false),
      (0.30, 0.88, 48.0, 63.0, 2.9, true),
      (0.92, 0.55, 34.0, 44.0, 4.1, false),
      (0.55, 0.60, 38.0, 50.0, 1.6, true),
    ];

    for (final (xRel, yRel, cw, ch, p, faceUp) in items) {
      final yBob = math.sin(phase + p) * 8;
      final rot  = math.sin(phase * 0.6 + p) * 0.10;
      final alpha = 0.14 + (math.sin(phase * 0.8 + p) + 1) / 2 * 0.10;
      final cx = size.width * xRel;
      final cy = size.height * yRel + yBob;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);

      final rect = Rect.fromCenter(center: Offset.zero, width: cw, height: ch);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cw * 0.15));

      if (faceUp) {
        canvas.drawRRect(rr, Paint()..color = Colors.white.withValues(alpha: alpha));
        canvas.drawRRect(rr, Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        canvas.drawRRect(rr, Paint()..color = _kAccentDk.withValues(alpha: alpha));
        canvas.drawRRect(rr, Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      }
      canvas.restore();
    }
  }
}
