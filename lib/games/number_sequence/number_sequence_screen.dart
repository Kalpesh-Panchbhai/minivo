import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../game_picker_scaffold.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import 'number_sequence_logo.dart';
import 'number_sequence_tutorial.dart';

const kNumberSequenceGameId = 'number_sequence';

const _kAccent = Color(0xFF6366F1);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['25 numbers', '50 numbers', '100 numbers'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
  int get count => [25, 50, 100][index];
}

class NumberSequenceScreen extends StatefulWidget {
  const NumberSequenceScreen({super.key});

  @override
  State<NumberSequenceScreen> createState() => _NumberSequenceScreenState();
}

class _NumberSequenceScreenState extends State<NumberSequenceScreen> with WidgetsBindingObserver {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _nextNumber = 1;
  int _bestTime = 0;
  bool _isNewBest = false;
  bool _gameOver = false;
  int _hintNumber = -1;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kIdleTimeout = Duration(seconds: 15);

  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  int _elapsedSeconds = 0;

  List<_NumberBubble> _bubbles = [];
  final _rng = math.Random();

  static const _circleDesigns = [
    [Color(0xFF6366F1), Color(0xFF818CF8)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    [Color(0xFF06B6D4), Color(0xFF22D3EE)],
    [Color(0xFF10B981), Color(0xFF34D399)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFFEF4444), Color(0xFFF87171)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF14B8A6), Color(0xFF2DD4BF)],
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFavorite = ScoreService().isFavorite(kNumberSequenceGameId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_activeDifficulty == null || _gameOver) return;
    if (state == AppLifecycleState.resumed) {
      _stopwatch.start();
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
      });
    } else {
      _stopwatch.stop();
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kNumberSequenceGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kNumberSequenceGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
      accent: _kAccent, steps: numberSequenceSteps(), gameId: kNumberSequenceGameId);
  }

  void _startGame(_Difficulty diff) {
    final total = diff.count;
    _nextNumber = 1;
    _bestTime = ScoreService().getHighScore(kNumberSequenceGameId, subKey: diff.subKey);
    _isNewBest = false;
    _gameOver = false;
    _hintNumber = -1;
    _idleStuck = false;
    _elapsedSeconds = 0;
    _stopwatch.reset();

    _bubbles = _generateBubbles(total);

    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(0);
    _resetIdleTimer();
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
  }

  List<_NumberBubble> _generateBubbles(int total) {
    final bubbles = <_NumberBubble>[];
    final bubbleRadius = total <= 25 ? 22.0 : total <= 50 ? 18.0 : 14.0;
    final minDist = (bubbleRadius * 2.2) / 340;
    final positions = <Offset>[];

    for (int i = 1; i <= total; i++) {
      Offset? best;
      double bestMinDist = -1;
      for (int a = 0; a < 800; a++) {
        final pos = Offset(
          _rng.nextDouble() * 0.84 + 0.08,
          _rng.nextDouble() * 0.84 + 0.08,
        );
        double nearest = double.infinity;
        for (final p in positions) {
          final d = (p - pos).distance;
          if (d < nearest) nearest = d;
        }
        if (nearest >= minDist) {
          best = pos;
          break;
        }
        if (nearest > bestMinDist) {
          bestMinDist = nearest;
          best = pos;
        }
      }
      positions.add(best!);
      final designIdx = _rng.nextInt(_circleDesigns.length);
      bubbles.add(_NumberBubble(
        number: i,
        x: best.dx,
        y: best.dy,
        designIndex: designIdx,
        found: false,
      ));
    }
    return bubbles;
  }

  void _onBubbleTap(int number) {
    if (_gameOver) return;
    if (number == _nextNumber) {
      AudioService().playTap();
      _idleStuck = false;
      _resetIdleTimer();
      setState(() {
        final idx = _bubbles.indexWhere((b) => b.number == number);
        if (idx != -1) _bubbles[idx] = _bubbles[idx].copyWith(found: true);
        _nextNumber++;
        if (_hintNumber == number) _hintNumber = -1;
      });
      if (_nextNumber > _activeDifficulty!.count) {
        _endGame();
      }
    } else {
      AudioService().playTap();
    }
  }

  void _endGame() {
    _gameOver = true;
    _ticker?.cancel();
    _stopwatch.stop();
    _isNewBest = _bestTime == 0 || _elapsedSeconds < _bestTime;
    if (_isNewBest) {
      _bestTime = _elapsedSeconds;
      ScoreService().saveScore(kNumberSequenceGameId, _elapsedSeconds, subKey: _activeDifficulty!.subKey);
    }
    GameWrapper.of(context).updateScore(_elapsedSeconds);
    AudioService().playScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameWrapper.of(context).endGame(result: 'win');
    });
  }

  bool get _isStuck => _idleStuck;

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleStuck) setState(() => _idleStuck = false);
    _idleTimer = Timer(_kIdleTimeout, () {
      if (mounted && _activeDifficulty != null && !_gameOver) {
        setState(() => _idleStuck = true);
      }
    });
  }

  void _onHint() {
    if (_gameOver || _activeDifficulty == null) return;
    if (!AdsService().isRewardedReady) return;
    AudioService().playTap();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kNumberSequenceGameId,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (!earned || !mounted) return;
        _idleStuck = false;
        _resetIdleTimer();
        setState(() {
          _hintNumber = _nextNumber;
        });
      },
    );
  }

  void _newGame() => _startGame(_activeDifficulty ?? _pickerDifficulty);

  void _backToPicker() {
    _ticker?.cancel();
    _stopwatch.stop();
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
    });
    GameWrapper.of(context).restartGame();
  }

  void _backOrHome() {
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      _ticker?.cancel();
      _stopwatch.stop();
      if (context.canPop()) context.pop(); else context.go('/home');
    });
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_activeDifficulty == null) return _buildPicker();
    if (_gameOver) return _buildResult();
    return _buildGame();
  }

  Widget _buildPicker() {
    final difficulties = _Difficulty.values.map((d) => GameDifficultyData(
      label: d.label,
      color: d.color,
      kind: d.kind,
      hint: d.hint,
      bestScore: ScoreService().getHighScore(kNumberSequenceGameId, subKey: d.subKey),
      bestLabel: (s) => s > 0 ? 'Best: ${_formatTime(s)}' : 'No best yet',
    )).toList();

    return GamePickerScaffold(
      bgColorTop: const Color(0xFFEEF2FF),
      bgColorBottom: const Color(0xFFE0E7FF),
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.tag_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFF818CF8), Color(0xFF4F46E5)],
      iconChild: buildNumberSequenceLogo(60),
      title: 'Number Sequence',
      subtitle: 'Find all numbers in order — fast!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kNumberSequenceGameId,
      body: GameSinglePickerBody(
        difficulties: difficulties,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Number Sequence',
        playSubLabel: '${_pickerDifficulty.count} numbers to find',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    final total = diff.count;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome, bgColor: Colors.white.withValues(alpha: 0.10), iconColor: Colors.white),
              centerContent: _buildHud(diff),
              trailing: GameRestartButton(
                gameName: 'Number Sequence',
                accentColor: diff.color,
                onRestart: _newGame,
                bgColor: Colors.white.withValues(alpha: 0.10),
                iconColor: Colors.white,
                onDialogOpened: () { _ticker?.cancel(); _stopwatch.stop(); },
                onDialogDismissed: () {
                  if (!_gameOver) {
                    _stopwatch.start();
                    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
                      if (mounted) setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Find: $_nextNumber',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final bubbleRadius = total <= 25 ? 22.0 : total <= 50 ? 18.0 : 14.0;
                  return Stack(
                    children: _bubbles.map((b) {
                      final cx = b.x * w;
                      final cy = b.y * h;
                      final isHinted = b.number == _hintNumber;
                      final design = _circleDesigns[b.designIndex];
                      return Positioned(
                        left: cx - bubbleRadius,
                        top: cy - bubbleRadius,
                        child: GestureDetector(
                          onTap: b.found ? null : () => _onBubbleTap(b.number),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: b.found ? 0.0 : 1.0,
                            child: AnimatedScale(
                              scale: b.found ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                width: bubbleRadius * 2,
                                height: bubbleRadius * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: design,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: design[0].withValues(alpha: 0.4),
                                      blurRadius: isHinted ? 16 : 6,
                                      spreadRadius: isHinted ? 4 : 0,
                                    ),
                                  ],
                                  border: isHinted ? Border.all(color: Colors.white, width: 2.5) : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${b.number}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: bubbleRadius * 0.7,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            if (!_gameOver)
              Opacity(
                opacity: AdsService().isRewardedReady ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !AdsService().isRewardedReady,
                  child: _NumberSequenceHintNudge(onTap: _onHint, isStuck: _isStuck),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHud(_Difficulty diff) {
    final color = diff.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDifficultyIcon(kind: diff.kind, size: 14, prominent: false),
              const SizedBox(width: 6),
              Text(diff.label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: _kAccent.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _statCol('FOUND', '${_nextNumber - 1}/${_activeDifficulty!.count}', color),
              _pillDivider(),
              _statCol('TIME', _formatTime(_elapsedSeconds), const Color(0xFF6B7280)),
              _pillDivider(),
              _statCol('BEST', _bestTime > 0 ? _formatTime(_bestTime) : '—', const Color(0xFFFEC84B)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCol(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.70), letterSpacing: 1.0)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, height: 1)),
        ],
      ),
    );
  }

  Widget _pillDivider() {
    return Container(width: 1, height: 22, color: const Color(0xFFE5E7EB));
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: 'Complete!',
      subtitle: 'Found all ${diff.count} numbers in ${_formatTime(_elapsedSeconds)}',
      badgeContent: '🔢',
      badgeColor: diff.color,
      showNewBestBadge: _isNewBest,
      gameId: kNumberSequenceGameId,
      score: _elapsedSeconds,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: 'TIME', value: _elapsedSeconds, displayValue: _formatTime(_elapsedSeconds), color: diff.color),
          game_result.StatItem(label: 'COUNT', value: diff.count, color: const Color(0xFF6B7280)),
          game_result.StatItem(label: 'BEST', value: _bestTime, displayValue: _bestTime > 0 ? _formatTime(_bestTime) : '—', color: const Color(0xFFFEC84B)),
        ],
      ),
      actions: [
        game_result.GameResultAction(
          label: 'Play Again',
          icon: Icons.refresh_rounded,
          onTap: _newGame,
          filled: true,
          color: diff.color,
          actionId: 'play_again',
        ),
        game_result.GameResultAction(
          label: 'Change Difficulty',
          icon: Icons.tune_rounded,
          onTap: _backToPicker,
          filled: false,
          actionId: 'change_mode',
        ),
        game_result.GameResultAction(
          label: 'Home',
          icon: Icons.home_rounded,
          onTap: () => context.go('/home'),
          actionId: 'home',
          filled: false,
        ),
      ],
    );
  }
}

class _NumberBubble {
  final int number;
  final double x;
  final double y;
  final int designIndex;
  final bool found;

  const _NumberBubble({
    required this.number,
    required this.x,
    required this.y,
    required this.designIndex,
    required this.found,
  });

  _NumberBubble copyWith({bool? found}) => _NumberBubble(
    number: number,
    x: x,
    y: y,
    designIndex: designIndex,
    found: found ?? this.found,
  );
}

class _NumberSequenceHintNudge extends StatefulWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _NumberSequenceHintNudge({required this.onTap, required this.isStuck});
  @override
  State<_NumberSequenceHintNudge> createState() => _NumberSequenceHintNudgeState();
}

class _NumberSequenceHintNudgeState extends State<_NumberSequenceHintNudge> with TickerProviderStateMixin {
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
  void didUpdateWidget(_NumberSequenceHintNudge old) {
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
                          painter: _NSeqBubbleTailPainter(),
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

class _NSeqBubbleTailPainter extends CustomPainter {
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
