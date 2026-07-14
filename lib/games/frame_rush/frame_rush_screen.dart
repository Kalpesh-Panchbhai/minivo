import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/ads_service.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/level_progress_service.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../game_registry.dart';
import '../game_wrapper.dart';
import '../game_picker_scaffold.dart';
import '../shared/animated_background.dart';
import '../shared/animated_difficulty_icon.dart';
import '../shared/continue_dialog.dart';
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/level_complete_overlay.dart';
import 'frame_rush_level_gen.dart';
import 'frame_rush_logo.dart';
import 'frame_rush_objects.dart';
import 'frame_rush_scenes.dart';
import 'frame_rush_tutorial.dart';

const kFrameRushGameId = 'frame_rush';

const _kAccent = Color(0xFF10B981);
const _kNeon = Color(0xFF39FF6A);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => const ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => const [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => const [
        DifficultyKind.easy,
        DifficultyKind.medium,
        DifficultyKind.hard
      ][index];
  String get hint => const [
        'Slow · roomy frame',
        'Quicker · tighter frame',
        'Fast · pinpoint frame',
      ][index];
  String get subKey => const ['easy', 'medium', 'hard'][index];
}

enum _Fx { none, win, miss }

class FrameRushScreen extends StatefulWidget {
  const FrameRushScreen({super.key});

  @override
  State<FrameRushScreen> createState() => _FrameRushScreenState();
}

class _FrameRushScreenState extends State<FrameRushScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty =
      _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _level = 1;
  int _attempts = 0;
  bool _won = false;
  double _capturedS = 0;

  /// Rewarded "Slow-Mo" active for the current level — slows the loop so the
  /// timing window is easier to hit. Resets each level.
  bool _slowMo = false;
  static const _kSlowMoFactor = 1.8;

  /// Shows the "Too fast? Slow it down!" nudge on the button once the player is
  /// clearly struggling — after [_kStuckAfterMisses] missed taps OR
  /// [_kStuckAfterSeconds] on the level, whichever comes first.
  bool _stuck = false;
  Timer? _stuckTimer;
  static const _kStuckAfterMisses = 6;
  static const _kStuckAfterSeconds = 15;

  FrameRushLevelResult? _lvl;

  // Feedback overlay state.
  _Fx _fxType = _Fx.none;
  double _missS = 0;
  String? _feedback;
  Color _feedbackColor = _kNeon;

  late final AnimationController _loop; // object motion (repeats)
  late final AnimationController _fx; // one-shot capture/miss burst
  OverlayEntry? _overlay;
  Timer? _pendingComplete;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFavorite = ScoreService().isFavorite(kFrameRushGameId);
    _loop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000));
    _fx = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingComplete?.cancel();
    _stuckTimer?.cancel();
    _overlay?.remove();
    _overlay = null;
    _loop.dispose();
    _fx.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_activeDifficulty == null) return;
    if (state != AppLifecycleState.resumed) {
      if (_loop.isAnimating) _loop.stop();
    } else if (!_won && _lvl != null && !_loop.isAnimating) {
      _loop.repeat();
    }
  }

  // ── actions ───────────────────────────────────────────────────────────────

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kFrameRushGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kFrameRushGameId);
    if (info == null) return;
    _loop.stop();
    showHowToPlaySheet(
      context,
      title: info.name,
      howToPlay: info.howToPlay,
      accent: _kAccent,
      steps: frameRushSteps(),
      gameId: kFrameRushGameId,
    ).then((_) {
      if (mounted && _activeDifficulty != null && !_won) _loop.repeat();
    });
  }

  void _applyLevel(_Difficulty diff) {
    final lvl = generateFrameRushLevel(_level, diff.index);
    _lvl = lvl;
    _slowMo = false; // fresh level runs at full speed
    _stuck = false;
    _loop.stop();
    _loop.duration = _loopDuration();
    _loop.repeat();
    _stuckTimer?.cancel();
    _stuckTimer = Timer(const Duration(seconds: _kStuckAfterSeconds), () {
      if (mounted && !_won && !_slowMo) setState(() => _stuck = true);
    });
  }

  Duration _loopDuration() {
    final base = (_lvl?.loopSeconds ?? 3.0) * 1000;
    return Duration(
        milliseconds: (base * (_slowMo ? _kSlowMoFactor : 1.0)).round());
  }

  /// Rewarded "Slow-Mo": watch an ad to slow the loop for this level (one per
  /// level). Falls back to granting it free when no ad is loaded — same as the
  /// hint buttons in the other level games. The loop is paused behind the ad.
  void _onSlowMo() {
    if (_won || _slowMo || _lvl == null || _activeDifficulty == null) return;
    if (!AdsService().isRewardedReady) {
      _activateSlowMo();
      return;
    }
    _loop.stop();
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kFrameRushGameId,
      onRewarded: (_) {},
      onComplete: () {
        if (mounted) _activateSlowMo();
      },
    );
  }

  void _activateSlowMo() {
    if (_slowMo) return;
    _stuckTimer?.cancel();
    setState(() {
      _slowMo = true;
      _stuck = false;
    });
    _loop.stop();
    _loop.duration = _loopDuration();
    if (!_won) _loop.repeat();
    AudioService().playTap();
  }

  Future<void> _startGame(_Difficulty diff) async {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kFrameRushGameId, diff.subKey);

    final saved = lps.getGameState(kFrameRushGameId, diff.subKey);
    final savedAttempts = (saved?['attempts'] as int?) ?? 0;
    final hasSave =
        saved != null && saved['level'] == _level && savedAttempts > 0;

    bool cont = false;
    if (hasSave) {
      cont = await showContinueDialog(
        context,
        gameName: 'Frame Rush',
        accentColor: diff.color,
        level: _level,
      );
      if (!mounted) return;
    }

    _won = false;
    _missS = 0;
    _feedback = null;
    _fxType = _Fx.none;
    _attempts = (hasSave && cont) ? savedAttempts : 0;
    if (hasSave && !cont) lps.clearGameState(kFrameRushGameId, diff.subKey);

    setState(() => _activeDifficulty = diff);
    _applyLevel(diff);
    GameWrapper.of(context)
        .setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _saveState() {
    final diff = _activeDifficulty;
    if (diff == null || _won || _attempts == 0) return;
    LevelProgressService().saveGameState(kFrameRushGameId, diff.subKey, {
      'level': _level,
      'attempts': _attempts,
    });
  }

  void _onFreeze() {
    final lvl = _lvl;
    if (lvl == null || _won || _activeDifficulty == null) return;
    final s = _loop.value;
    _attempts++;
    final err = frameRushError(lvl, s);
    if (err <= 1.0) {
      _onCapture(s);
      return;
    }
    // Miss.
    AudioService().playTap();
    setState(() {
      _missS = s;
      _fxType = _Fx.miss;
      _feedback = err < 1.5 ? 'SO CLOSE!' : 'MISS';
      _feedbackColor =
          err < 1.5 ? const Color(0xFFFFC53D) : const Color(0xFFFF6B6B);
      if (_attempts >= _kStuckAfterMisses) _stuck = true;
    });
    _fx.forward(from: 0);
    _saveState();
  }

  void _onCapture(double s) {
    final lvl = _lvl!;
    final diff = _activeDifficulty!;
    _loop.stop();
    _stuckTimer?.cancel();
    final acc = frameRushAccuracy(lvl, s);
    setState(() {
      _won = true;
      _capturedS = s;
      _fxType = _Fx.win;
      _feedback = acc >= 0.72 ? 'PERFECT!' : (acc >= 0.42 ? 'GREAT!' : 'NICE!');
      _feedbackColor = _kNeon;
    });
    _fx.forward(from: 0);
    AudioService().playSuccess();

    final lps = LevelProgressService();
    lps.advanceLevel(kFrameRushGameId, diff.subKey);
    lps.saveLevelBest(kFrameRushGameId, diff.subKey, _level, _attempts);
    lps.clearGameState(kFrameRushGameId, diff.subKey);
    GameWrapper.of(context).updateScore(_level);

    _pendingComplete?.cancel();
    _pendingComplete = Timer(const Duration(milliseconds: 640), () {
      if (mounted && _won) _showLevelComplete();
    });
  }

  void _showLevelComplete() {
    final diff = _activeDifficulty!;
    _overlay?.remove();
    _overlay = OverlayEntry(
      builder: (_) => LevelCompleteOverlay(
        level: _level,
        accentColor: diff.color,
        onComplete: () {
          _overlay?.remove();
          _overlay = null;
          if (!mounted) return;
          GameWrapper.of(context).completeLevelWithAd(onComplete: () {
            if (mounted) _nextLevel();
          });
        },
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _nextLevel() {
    final diff = _activeDifficulty!;
    setState(() {
      _level++;
      _attempts = 0;
      _won = false;
      _missS = 0;
      _feedback = null;
      _fxType = _Fx.none;
    });
    _applyLevel(diff);
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _restartLevel() {
    final diff = _activeDifficulty;
    if (diff == null) return;
    _pendingComplete?.cancel();
    _overlay?.remove();
    _overlay = null;
    setState(() {
      _attempts = 0;
      _won = false;
      _missS = 0;
      _feedback = null;
      _fxType = _Fx.none;
    });
    LevelProgressService().clearGameState(kFrameRushGameId, diff.subKey);
    _applyLevel(diff);
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _backOrHome() {
    _saveState();
    _loop.stop();
    _stuckTimer?.cancel();
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) =>
      _activeDifficulty == null ? _buildPicker() : _buildGame();

  Widget _buildPicker() {
    final lps = LevelProgressService();
    final diffs = _Difficulty.values
        .map((d) => GameDifficultyData(
              label: d.label,
              color: d.color,
              kind: d.kind,
              hint: d.hint,
              bestScore: lps.getHighestLevel(kFrameRushGameId, d.subKey),
              bestLabel: (s) => s <= 0 ? '' : 'Reached: Level $s',
            ))
        .toList();

    return GamePickerScaffold(
      bgColorTop: const Color(0xFFDCFCE9),
      bgColorBottom: const Color(0xFFB8F1D6),
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(
          t,
          accent: _kAccent,
          icon: Icons.center_focus_strong_rounded,
        ),
      ),
      iconRingColors: const [_kAccent, Color(0xFF22C55E), Color(0xFF047857)],
      iconChild: buildFrameRushLogo(60),
      title: 'Frame Rush',
      subtitle: 'Freeze the object inside the frame!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kFrameRushGameId,
      body: GameSinglePickerBody(
        difficulties: diffs,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) =>
            setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Frame Rush',
        playSubLabel:
            'Level ${lps.getCurrentLevel(kFrameRushGameId, _pickerDifficulty.subKey)}',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    final lvl = _lvl!;
    final theme = frameRushTheme(lvl.objectType);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: frameRushSceneBg(lvl.objectType),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(
                onTap: _backOrHome,
                bgColor: Colors.white.withValues(alpha: 0.16),
                iconColor: Colors.white,
              ),
              centerContent: _buildHud(diff),
              trailing: GameRestartButton(
                gameName: 'Frame Rush',
                accentColor: diff.color,
                onRestart: _restartLevel,
                bgColor: Colors.white.withValues(alpha: 0.16),
                iconColor: Colors.white,
                onDialogOpened: () => _loop.stop(),
                onDialogDismissed: () {
                  if (!_won && _lvl != null) _loop.repeat();
                },
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _onFreeze(),
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_loop, _fx]),
                    builder: (_, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _BoardPainter(
                        lvl: lvl,
                        progress: _loop.value,
                        won: _won,
                        capturedS: _capturedS,
                        fx: _fx.value,
                        fxType: _fxType,
                        missS: _missS,
                        feedback: _feedback,
                        feedbackColor: _feedbackColor,
                        showTapHint: _attempts == 0 && !_won,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildSlowMoButton(),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSlowMoButton() {
    final show = !_won && !_slowMo;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: show ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !show,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Center(child: _SlowMoButton(onTap: _onSlowMo, isStuck: _stuck)),
        ),
      ),
    );
  }

  Widget _buildHud(_Difficulty diff) {
    final best =
        LevelProgressService().getOverallBest(kFrameRushGameId, diff.subKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LEVEL $_level',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            best > 0 ? '$_attempts taps · best $best' : '$_attempts taps',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(FrTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Text(
        'Tap anywhere to freeze the ${theme.name.toLowerCase()} in the green frame',
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
          height: 1.2,
        ),
      ),
    );
  }
}

// ── rewarded Slow-Mo button (matches the in-game hint buttons) ──────────────

class _SlowMoButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _SlowMoButton({required this.onTap, required this.isStuck});

  static const _kBg = Color(0xFFFFD43B);
  static const _kFg = Color(0xFF5C4600);
  static const _kBubble = Color(0xFF7C3AED);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE6BE00), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _kBg.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.slow_motion_video_rounded,
                    size: 16, color: _kFg),
                const SizedBox(width: 6),
                const Text('SLOW-MO',
                    style: TextStyle(
                        color: _kFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        height: 1)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: _kFg.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow_rounded, size: 12, color: _kFg),
                    SizedBox(width: 2),
                    Text('AD',
                        style: TextStyle(
                            color: _kFg,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            height: 1)),
                  ]),
                ),
              ],
            ),
          ),
        ),
        if (isStuck)
          Positioned(
            bottom: 44,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kBubble,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: _kBubble.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Text('Too fast? Slow it down!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3)),
                ),
                CustomPaint(
                    size: const Size(14, 7), painter: _BubbleTailPainter()),
              ],
            ),
          ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF7C3AED));
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) => false;
}

// ── board painter ─────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  final FrameRushLevelResult lvl;
  final double progress;
  final bool won;
  final double capturedS;
  final double fx;
  final _Fx fxType;
  final double missS;
  final String? feedback;
  final Color feedbackColor;
  final bool showTapHint;

  _BoardPainter({
    required this.lvl,
    required this.progress,
    required this.won,
    required this.capturedS,
    required this.fx,
    required this.fxType,
    required this.missS,
    required this.feedback,
    required this.feedbackColor,
    required this.showTapHint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    final half = math.min(size.width, size.height * 0.92) / 2;
    final posScale = half * 0.56;
    final objR = half * 0.30 * frameRushObjectScale(lvl.objectType);

    Offset map(double x, double y) =>
        Offset(center.dx + x * posScale, center.dy + y * posScale);

    // Themed environment (concrete spillway, sky, space, underwater).
    paintFrameRushScene(canvas, size, lvl.objectType, progress);

    // Screen shake on miss.
    canvas.save();
    if (fxType == _Fx.miss && fx < 1) {
      final k = (1 - fx);
      canvas.translate(math.sin(fx * math.pi * 9) * 7 * k, 0);
    }

    final fp = frameRushFramePose(lvl);
    final framePx = map(fp.$1, fp.$2);

    _drawTrack(canvas, map);

    // Target frame — the hand-drawn green marker outline (no ring; the sketch
    // itself is the cue, like the reference).
    _drawObject(canvas, framePx, fp.$3, objR, outlineOnly: true);

    // Object. A win triggers only when the outline is already tightly aligned
    // (see the capture budget), then the object SNAPS-AND-LOCKS precisely into
    // the frame with a quick click — so every capture reads as a perfect 100%
    // fit. The lock-in is small (the tap was already close), never a teleport.
    final ground = frameRushIsGroundVehicle(lvl.objectType);
    if (won) {
      final e = Curves.easeOutCubic.transform((fx / 0.35).clamp(0.0, 1.0));
      final cp = frameRushPose(lvl, capturedS);
      final px = Offset.lerp(map(cp.$1, cp.$2), framePx, e)!;
      final ang = _lerpAngle(cp.$3, fp.$3, e);
      if (fxType == _Fx.win) _drawBurst(canvas, framePx, objR);
      if (ground) {
        paintFrameRushGroundShadow(canvas, px.translate(0, objR * 0.52), objR * 0.9);
      }
      _drawObject(canvas, px, ang, objR,
          outlineOnly: false, captured: true, flash: (1 - fx) * 0.5);
    } else {
      _drawTrail(canvas, map, objR);
      final p = frameRushPose(lvl, progress);
      final px = map(p.$1, p.$2);
      if (ground) {
        paintFrameRushGroundShadow(canvas, px.translate(0, objR * 0.52), objR * 0.9);
      }
      _drawObject(canvas, px, p.$3, objR, outlineOnly: false);
    }

    // Miss ghost.
    if (fxType == _Fx.miss && fx < 1) {
      final mp = frameRushPose(lvl, missS);
      canvas.save();
      canvas.translate(map(mp.$1, mp.$2).dx, map(mp.$1, mp.$2).dy);
      frameRushApplyOrientation(canvas, lvl.objectType, mp.$3);
      paintFrameRushObject(canvas, lvl.objectType, objR,
          outlineOnly: true, outlineColor: const Color(0xFFFF6B6B));
      canvas.restore();
    }

    _drawFeedback(canvas, size, center, objR);

    canvas.restore();
  }

  void _drawTrack(Canvas canvas, Offset Function(double, double) map) {
    final path = Path();
    for (int i = 0; i <= 96; i++) {
      final p = frameRushPoint(lvl, i / 96);
      final o = map(p.$1, p.$2);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.13),
    );
  }

  void _drawTrail(Canvas canvas, Offset Function(double, double) map, double objR) {
    for (int i = 1; i <= 3; i++) {
      final s = (progress - i * 0.028) % 1.0;
      final p = frameRushPose(lvl, s);
      canvas.save();
      canvas.translate(map(p.$1, p.$2).dx, map(p.$1, p.$2).dy);
      frameRushApplyOrientation(canvas, lvl.objectType, p.$3);
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: 0.10 * (4 - i) / 4),
      );
      paintFrameRushObject(canvas, lvl.objectType, objR, outlineOnly: false);
      canvas.restore();
      canvas.restore();
    }
  }

  void _drawObject(Canvas canvas, Offset px, double angle, double objR,
      {required bool outlineOnly, bool captured = false, double flash = 0}) {
    canvas.save();
    canvas.translate(px.dx, px.dy);
    frameRushApplyOrientation(canvas, lvl.objectType, angle);
    paintFrameRushObject(canvas, lvl.objectType, objR,
        outlineOnly: outlineOnly,
        outlineColor: _kNeon,
        captured: captured,
        captureFlash: flash);
    canvas.restore();
  }

  void _drawBurst(Canvas canvas, Offset c, double objR) {
    final e = fx.clamp(0.0, 1.0);
    // Expanding ring.
    canvas.drawCircle(
      c,
      objR * (0.9 + e * 1.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = objR * 0.16 * (1 - e)
        ..color = _kNeon.withValues(alpha: 0.8 * (1 - e)),
    );
    // Particles.
    const n = 14;
    for (int i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi + (i * 1.7);
      final d = objR * (0.5 + 2.2 * Curves.easeOut.transform(e));
      final pos = c + Offset(math.cos(a), math.sin(a)) * d;
      canvas.drawCircle(
        pos,
        objR * 0.12 * (1 - e),
        Paint()..color = _kNeon.withValues(alpha: 1 - e),
      );
    }
  }

  void _drawFeedback(Canvas canvas, Size size, Offset center, double objR) {
    if (feedback == null || fxType == _Fx.none) return;
    final e = fx.clamp(0.0, 1.0);
    final alpha = fxType == _Fx.win
        ? (1 - (e - 0.6).clamp(0.0, 0.4) / 0.4)
        : (1 - e);
    if (alpha <= 0) return;
    final scale = fxType == _Fx.win
        ? (0.6 + Curves.elasticOut.transform(e.clamp(0.0, 1.0)) * 0.4)
        : 1.0;
    final rise = fxType == _Fx.win ? 0.0 : -e * 22;
    final fs = (fxType == _Fx.win ? 30.0 : 20.0) * scale;
    final tp = TextPainter(
      text: TextSpan(
        text: feedback,
        style: TextStyle(
          color: feedbackColor.withValues(alpha: alpha.clamp(0.0, 1.0)),
          fontSize: fs,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.4 * alpha),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final y = center.dy - objR * 1.7 + rise;
    tp.paint(canvas, Offset(center.dx - tp.width / 2, y - tp.height / 2));
  }

  double _lerpAngle(double a, double b, double t) {
    var d = (b - a) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return a + d * t;
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.progress != progress ||
      old.fx != fx ||
      old.won != won ||
      old.fxType != fxType ||
      old.feedback != feedback ||
      old.showTapHint != showTapHint ||
      old.lvl != lvl;
}
