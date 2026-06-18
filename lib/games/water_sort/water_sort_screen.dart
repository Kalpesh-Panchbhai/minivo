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
import '../shared/game_control_buttons.dart';
import '../shared/game_difficulty_picker.dart';
import '../shared/game_hud_bar.dart';
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/level_complete_overlay.dart';
import 'water_sort_logo.dart';
import 'water_sort_level_gen.dart' as gen;
import 'water_sort_tutorial.dart';

const kWaterSortGameId = 'water_sort';

const _kAccent = Color(0xFF0EA5E9);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['4–7 colors · 2 free tubes', '8–11 colors · 2 free tubes', '12–14 colors · 2 free tubes'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

class _LevelParams {
  final int numColors;
  final int tubeCapacity;
  final int emptyTubes;
  int get numTubes => numColors + emptyTubes;
  const _LevelParams({required this.numColors, required this.tubeCapacity, required this.emptyTubes});
}

const _waterColors = [
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFF22C55E),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF06B6D4),
  Color(0xFFF97316),
  Color(0xFF14B8A6),
  Color(0xFFE11D48),
  Color(0xFF84CC16), // lime
  Color(0xFF6366F1), // indigo
  Color(0xFFEAB308), // yellow
  Color(0xFFD946EF), // fuchsia
  Color(0xFF047857), // dark emerald
  Color(0xFF92400E), // brown
];

class WaterSortScreen extends StatefulWidget {
  const WaterSortScreen({super.key});

  @override
  State<WaterSortScreen> createState() => _WaterSortScreenState();
}

class _WaterSortScreenState extends State<WaterSortScreen> with TickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _level = 1;
  int _moves = 0;
  bool _gameOver = false;
  bool _won = false;

  List<List<int>> _tubes = [];
  int _selectedTube = -1;
  _LevelParams _params = const _LevelParams(numColors: 4, tubeCapacity: 4, emptyTubes: 2);

  int _extraTubeSlots = 0;

  // Responsive tube sizing — computed each layout to fit the board on any
  // device (down to 320x568) regardless of tube count / capacity.
  double _tubeW = 48.0;
  double _segH = 26.0;

  final Set<int> _completedTubes = {};
  final Set<int> _celebratingTubes = {};
  late final AnimationController _celebrateAnim;

  late final AnimationController _pourAnim;
  int _pourFrom = -1;
  int _pourTo = -1;
  bool _isPouring = false;
  bool _pourDataMoved = false;
  int _pourColor = -1;
  int _pourSrcFill = 0;
  OverlayEntry? _pourOverlay;
  OverlayEntry? _appreciationOverlay;
  final Map<int, GlobalKey> _tubeKeys = {};

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kWaterSortGameId);
    _celebrateAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _celebratingTubes.clear());
        }
      });
    _pourAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(() {
        _pourOverlay?.markNeedsBuild();
        if (_isPouring && !_pourDataMoved && _pourAnim.value >= 0.60) {
          _pourDataMoved = true;
          _pour(_pourFrom, _pourTo);
          setState(() {});
        }
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finishPour();
      });
  }

  @override
  void dispose() {
    _pourOverlay?.remove();
    _pourOverlay = null;
    _appreciationOverlay?.remove();
    _appreciationOverlay = null;
    _pourAnim.dispose();
    _celebrateAnim.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kWaterSortGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kWaterSortGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
      accent: _kAccent, steps: waterSortSteps(), gameId: kWaterSortGameId);
  }

  void _startGame(_Difficulty diff) {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kWaterSortGameId, diff.subKey);
    _gameOver = false;
    _won = false;
    _selectedTube = -1;
    _celebratingTubes.clear();
    _generateLevel(diff);

    final saved = lps.getGameState(kWaterSortGameId, diff.subKey);
    if (saved != null && saved['level'] == _level) {
      _tubes = (saved['tubes'] as List).map((t) => List<int>.from(t as List)).toList();
      _moves = saved['moves'] as int;
      _extraTubeSlots = saved['extraTubeSlots'] as int;
      _completedTubes.clear();
      _completedTubes.addAll((saved['completedTubes'] as List).cast<int>());
    } else {
      _moves = 0;
      _extraTubeSlots = 0;
      _completedTubes.clear();
    }

    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _generateLevel(_Difficulty diff) {
    final result = gen.generateWaterSortLevel(_level, diff.index);
    _params = _LevelParams(
      numColors: result.params.numColors,
      tubeCapacity: result.params.tubeCapacity,
      emptyTubes: result.params.emptyTubes,
    );
    _tubes = result.tubes;
    _extraTubeSlots = 0;
  }

  void _onTubeTap(int idx) {
    if (_gameOver || _isPouring || _appreciationOverlay != null) return;

    if (_selectedTube == -1) {
      if (_tubes[idx].isEmpty) return;
      AudioService().playTap();
      setState(() => _selectedTube = idx);
      return;
    }

    if (_selectedTube == idx) {
      setState(() => _selectedTube = -1);
      return;
    }

    if (_canPour(_selectedTube, idx)) {
      final from = _selectedTube;
      final color = _tubes[from].last;
      int count = 0;
      final maxCap = _effectiveCap(idx);
      for (int i = _tubes[from].length - 1; i >= 0 && _tubes[from][i] == color && _tubes[idx].length + count < maxCap; i--) {
        count++;
      }
      setState(() {
        _pourFrom = from;
        _pourTo = idx;
        _pourColor = color;
        _pourSrcFill = _tubes[from].length;
        _isPouring = true;
        _pourDataMoved = false;
        _selectedTube = -1;
      });
      _showPourOverlay();
      _pourAnim.forward(from: 0);
    } else {
      if (_tubes[idx].isNotEmpty) {
        setState(() => _selectedTube = idx);
      } else {
        setState(() => _selectedTube = -1);
      }
    }
  }

  void _finishPour() {
    if (!mounted) return;
    _pourOverlay?.remove();
    _pourOverlay = null;
    if (!_pourDataMoved) {
      _pourDataMoved = true;
      _pour(_pourFrom, _pourTo);
    }
    AudioService().playTap();
    final cap = _params.tubeCapacity;
    final newlyCompleted = <int>{};
    for (int i = 0; i < _tubes.length; i++) {
      final tube = _tubes[i];
      final isFull = tube.length == cap && tube.toSet().length == 1;
      if (isFull && !_completedTubes.contains(i)) {
        _completedTubes.add(i);
        newlyCompleted.add(i);
      }
    }
    if (newlyCompleted.isNotEmpty) {
      _celebratingTubes.addAll(newlyCompleted);
      _celebrateAnim.forward(from: 0);
      AudioService().playScore();
    }
    setState(() {
      _moves++;
      _isPouring = false;
      _pourFrom = -1;
      _pourTo = -1;
      _pourColor = -1;
      _pourSrcFill = 0;
    });
    _saveState();
    _checkWin();
  }

  int _effectiveCap(int idx) {
    final isExtra = idx == _tubes.length - 1;
    return isExtra ? _extraTubeSlots : _params.tubeCapacity;
  }

  bool _canPour(int from, int to) {
    if (_tubes[from].isEmpty) return false;
    final maxCap = _effectiveCap(to);
    if (maxCap <= 0) return false;
    if (_tubes[to].length >= maxCap) return false;
    if (_tubes[to].isEmpty) return true;
    return _tubes[from].last == _tubes[to].last;
  }

  void _pour(int from, int to) {
    final color = _tubes[from].last;
    final maxCap = _effectiveCap(to);
    while (_tubes[from].isNotEmpty && _tubes[from].last == color && _tubes[to].length < maxCap) {
      _tubes[from].removeLast();
      _tubes[to].add(color);
    }
  }

  void _checkWin() {
    final cap = _params.tubeCapacity;
    for (int i = 0; i < _tubes.length - 1; i++) {
      final tube = _tubes[i];
      if (tube.isEmpty) continue;
      if (tube.length != cap) return;
      if (tube.toSet().length != 1) return;
    }
    _endGame(true);
  }

  void _endGame(bool won) {
    _won = won;
    if (won) {
      final diff = _activeDifficulty!;
      final lps = LevelProgressService();
      lps.advanceLevel(kWaterSortGameId, diff.subKey);
      lps.clearGameState(kWaterSortGameId, diff.subKey);
      GameWrapper.of(context).updateScore(_level);
      AudioService().playScore();
      _showAppreciation();
      return;
    }
    _gameOver = true;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameWrapper.of(context).endGame(result: 'loss');
    });
  }

  void _showAppreciation() {
    _appreciationOverlay?.remove();
    final diff = _activeDifficulty!;
    _appreciationOverlay = OverlayEntry(
      builder: (_) => LevelCompleteOverlay(
        level: _level,
        accentColor: diff.color,
        onComplete: () {
          _appreciationOverlay?.remove();
          _appreciationOverlay = null;
          if (!mounted) return;
          GameWrapper.of(context).completeLevelWithAd(
            onComplete: () {
              if (mounted) _nextLevel();
            },
          );
        },
      ),
    );
    Overlay.of(context).insert(_appreciationOverlay!);
  }

  void _nextLevel() {
    _pourOverlay?.remove();
    _pourOverlay = null;
    _isPouring = false;
    final diff = _activeDifficulty!;
    setState(() {
      _level++;
      _moves = 0;
      _gameOver = false;
      _won = false;
      _selectedTube = -1;
      _extraTubeSlots = 0;
      _completedTubes.clear();
      _celebratingTubes.clear();
    });
    _generateLevel(diff);
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _restartLevel() {
    _pourOverlay?.remove();
    _pourOverlay = null;
    _isPouring = false;
    setState(() {
      _moves = 0;
      _gameOver = false;
      _won = false;
      _selectedTube = -1;
      _extraTubeSlots = 0;
      _completedTubes.clear();
      _celebratingTubes.clear();
    });
    _generateLevel(_activeDifficulty!);
    if (_activeDifficulty != null) {
      LevelProgressService().clearGameState(kWaterSortGameId, _activeDifficulty!.subKey);
    }
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _onUnlockExtraSlot() {
    if (_extraTubeSlots >= _params.tubeCapacity || _gameOver) return;
    if (!AdsService().isRewardedReady) return;
    AudioService().playTap();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kWaterSortGameId,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (!earned || !mounted) return;
        setState(() {
          _extraTubeSlots++;
        });
        _saveState();
      },
    );
  }

  void _saveState() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _won) return;
    LevelProgressService().saveGameState(kWaterSortGameId, diff.subKey, {
      'level': _level,
      'tubes': _tubes,
      'moves': _moves,
      'extraTubeSlots': _extraTubeSlots,
      'completedTubes': _completedTubes.toList(),
    });
  }

  void _backToPicker() {
    _saveState();
    _pourOverlay?.remove();
    _pourOverlay = null;
    _isPouring = false;
    setState(() {
      _activeDifficulty = null;
      _gameOver = false;
    });
    GameWrapper.of(context).restartGame();
  }

  void _backOrHome() {
    _saveState();
    final wrapper = GameWrapper.of(context);
    wrapper.handleExit(() {
      if (context.canPop()) context.pop(); else context.go('/home');
    });
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
      bestScore: LevelProgressService().getHighestLevel(kWaterSortGameId, d.subKey),
      bestLabel: (s) {
        if (s <= 0) return '';
        return 'Completed: Level $s';
      },
    )).toList();

    return GamePickerScaffold(
      bgColorTop: const Color(0xFFE0F2FE),
      bgColorBottom: const Color(0xFFBAE6FD),
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.science_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFF38BDF8), Color(0xFF0284C7)],
      iconChild: buildWaterSortLogo(60),
      title: 'Water Sort',
      subtitle: 'Sort colors into tubes!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kWaterSortGameId,
      body: GameSinglePickerBody(
        difficulties: difficulties,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Water Sort',
        playSubLabel: 'Level ${LevelProgressService().getCurrentLevel(kWaterSortGameId, _pickerDifficulty.subKey)}',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C4A6E), Color(0xFF164E63)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome, bgColor: Colors.white.withValues(alpha: 0.10), iconColor: Colors.white),
              centerContent: _buildHud(diff),
              trailing: GameRestartButton(
                gameName: 'Water Sort',
                accentColor: diff.color,
                onRestart: _restartLevel,
                bgColor: Colors.white.withValues(alpha: 0.10),
                iconColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _buildTubes(constraints.maxWidth, constraints.maxHeight),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Rect? _tubeGlobalRect(int idx) {
    final key = _tubeKeys[idx];
    if (key == null || key.currentContext == null) return null;
    final box = key.currentContext!.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
  }

  Widget _buildTubes(double availW, double availH) {
    final tubeCount = _tubes.length;
    final cap = _params.tubeCapacity;
    const extraBtnW = 46.0;
    const hGap = 6.0; // horizontal padding around each tube
    const rowVPad = 12.0;
    const labelExtra = 34.0;

    // Shrink tubes until the whole board fits the available width AND height —
    // so any tube count / capacity fits even the smallest device (320x568).
    double tw = 18.0;
    for (double w = 48; w >= 18; w -= 1) {
      final seg = w * 0.54;
      final slotW = w + 4 + hGap;
      final usable = availW - (_extraTubeSlots < cap ? extraBtnW : 0);
      final perRow = math.max(1, (usable / slotW).floor());
      final rows = (tubeCount / perRow).ceil();
      final tubeTotalH = cap * seg + 20 + labelExtra;
      if (rows * (tubeTotalH + rowVPad) <= availH) {
        tw = w;
        break;
      }
    }
    _tubeW = tw;
    _segH = tw * 0.54;

    final tubeSlotW = _tubeW + 4 + hGap;
    final hasExtraBtn = _extraTubeSlots < _params.tubeCapacity;
    final effectiveW = hasExtraBtn ? availW - extraBtnW : availW;
    final maxPerRow = (effectiveW / tubeSlotW).floor().clamp(1, tubeCount);

    for (int i = 0; i < tubeCount; i++) {
      _tubeKeys.putIfAbsent(i, () => GlobalKey());
    }

    final rows = <List<int>>[];
    for (int i = 0; i < tubeCount; i += maxPerRow) {
      final end = (i + maxPerRow).clamp(0, tubeCount);
      rows.add(List.generate(end - i, (j) => i + j));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ...row.map((idx) {
                final isExtra = idx == _tubes.length - 1;
                final isPourSrc = _isPouring && _pourFrom == idx;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: KeyedSubtree(
                    key: _tubeKeys[idx]!,
                    child: Opacity(
                      opacity: isPourSrc ? 0.0 : 1.0,
                      child: _buildTube(idx, isExtra),
                    ),
                  ),
                );
              }),
              if (row.contains(_tubes.length - 1) && _extraTubeSlots < _params.tubeCapacity)
                _buildExtraSpaceButton(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExtraSpaceButton() {
    final cap = _params.tubeCapacity;
    final segH = _segH;
    final tubeH = cap * segH + 10;
    final bottomOffset = _extraTubeSlots * segH;
    return GestureDetector(
      onTap: _onUnlockExtraSlot,
      child: SizedBox(
        width: 40,
        height: tubeH + 34,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 4 + bottomOffset),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD43B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE6BE00), width: 1),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFFD43B).withValues(alpha: 0.30), blurRadius: 8),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: Color(0xFF5C4600)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C4600).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 8, color: Color(0xFF5C4600)),
                        Text('AD', style: TextStyle(color: Color(0xFF5C4600), fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5, height: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebration(double w, double h, int colorIdx) {
    final t = _celebrateAnim.value;
    final color = _waterColors[colorIdx];
    final fadeOut = t > 0.7 ? ((1.0 - t) / 0.3).clamp(0.0, 1.0) : 1.0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16), top: Radius.circular(8)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -w + (t * 2.5 * w),
            top: 0, bottom: 0,
            child: Opacity(
              opacity: fadeOut * 0.7,
              child: Container(
                width: w * 0.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          for (int i = 0; i < 6; i++)
            _buildBubble(w, h, i, t, color, fadeOut),
          for (int i = 0; i < 5; i++)
            _buildSparkle(w, i, t, color, fadeOut),
        ],
      ),
    );
  }

  Widget _buildBubble(double w, double h, int i, double t, Color color, double fade) {
    final rng = math.Random(i * 37);
    final startDelay = rng.nextDouble() * 0.3;
    final bt = ((t - startDelay) / 0.7).clamp(0.0, 1.0);
    final x = 4.0 + rng.nextDouble() * (w - 12);
    final size = 4.0 + rng.nextDouble() * 5;
    final rise = bt * (h + 20);
    final opacity = (bt < 0.2 ? bt / 0.2 : (bt > 0.7 ? (1.0 - bt) / 0.3 : 1.0)) * fade;
    return Positioned(
      left: x,
      bottom: -10 + rise,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSparkle(double w, int i, double t, Color color, double fade) {
    final rng = math.Random(i * 53 + 7);
    final startDelay = rng.nextDouble() * 0.2;
    final st = ((t - startDelay) / 0.5).clamp(0.0, 1.0);
    final x = rng.nextDouble() * w;
    final spread = st * (20 + rng.nextDouble() * 15);
    final opacity = (st < 0.3 ? st / 0.3 : (1.0 - st) / 0.7) * fade;
    return Positioned(
      left: x - 4,
      top: -spread,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Icon(
          Icons.auto_awesome,
          size: 8 + rng.nextDouble() * 6,
          color: Color.lerp(color, Colors.white, 0.5),
        ),
      ),
    );
  }

  void _showPourOverlay() {
    _pourOverlay?.remove();
    _pourOverlay = OverlayEntry(builder: (_) => _buildPourOverlayWidget());
    Overlay.of(context).insert(_pourOverlay!);
  }

  Widget _buildPourOverlayWidget() {
    final fromRect = _tubeGlobalRect(_pourFrom);
    final toRect = _tubeGlobalRect(_pourTo);
    if (fromRect == null || toRect == null) return const SizedBox.shrink();

    final t = _pourAnim.value;
    final cap = _params.tubeCapacity;
    final tubeW = _tubeW;
    final segH = _segH;
    final tubeBodyH = cap * segH + 10;
    final widgetW = tubeW + 4;
    final widgetH = tubeBodyH + 34;

    final liftT = Curves.easeOut.transform((t * 3.3).clamp(0.0, 1.0));
    final slideT = Curves.easeInOut.transform(((t - 0.10) * 2.0).clamp(0.0, 1.0));
    final tiltT = Curves.easeInOut.transform(((t - 0.40) * 2.5).clamp(0.0, 1.0));
    final streamT = ((t - 0.50) * 3.5).clamp(0.0, 1.0);

    final mouthLocalY = 24.0;
    final destCenterX = toRect.center.dx;
    final gap = 14.0;

    final tiltDir = (toRect.center.dx >= fromRect.center.dx) ? 1.0 : -1.0;

    final destMouthY = toRect.top + mouthLocalY;
    final destFill = _tubes[_pourTo].length;
    final destFillY = toRect.bottom - 4 - destFill * segH;

    final waterH = _pourSrcFill * segH;
    final tubeInnerH = cap * segH;
    final emptyH = tubeInnerH - waterH;
    final halfW = tubeW / 2;
    final spillAngle = math.atan2(emptyH + segH * 0.3, halfW);
    final maxTilt = spillAngle.clamp(0.35, 1.25);
    final currentTilt = tiltT * tiltDir * maxTilt;

    final edgeDx = tiltDir * (tubeW / 2 - 2);
    final edgeRelX = edgeDx;
    final edgeRelY = mouthLocalY - widgetH;
    final edgeRotX = edgeRelX * math.cos(currentTilt) - edgeRelY * math.sin(currentTilt);
    final edgeRotY = edgeRelX * math.sin(currentTilt) + edgeRelY * math.cos(currentTilt);

    final targetPivotX = destCenterX - edgeRotX;
    final targetPivotY = (destMouthY - gap) - edgeRotY;

    final origPivotX = fromRect.left + widgetW / 2;
    final origPivotY = fromRect.top + widgetH;
    final liftY = liftT * -30.0;
    final liftedPivotY = origPivotY + liftY;

    final pivotX = origPivotX + slideT * (targetPivotX - origPivotX);
    final pivotY = liftedPivotY + slideT * (targetPivotY - liftedPivotY);

    final tubeX = pivotX - widgetW / 2;
    final tubeY = pivotY - widgetH;

    final edgeGlobalX = pivotX + edgeRotX;
    final edgeGlobalY = pivotY + edgeRotY;

    return Stack(
      children: [
        Positioned(
          left: tubeX,
          top: tubeY,
          child: Transform.rotate(
            angle: currentTilt,
            alignment: Alignment.bottomCenter,
            child: _buildTube(_pourFrom, false, animated: false),
          ),
        ),
        if (streamT > 0 && _pourColor >= 0 && destFillY > edgeGlobalY)
          Positioned(
            left: edgeGlobalX - 3,
            top: edgeGlobalY,
            child: Opacity(
              opacity: (streamT * 3).clamp(0.0, 1.0) * (t < 0.88 ? 1.0 : ((1.0 - t) / 0.12).clamp(0.0, 1.0)),
              child: Container(
                width: 6,
                height: (destFillY - edgeGlobalY) * streamT,
                decoration: BoxDecoration(
                  color: _waterColors[_pourColor],
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: _waterColors[_pourColor].withValues(alpha: 0.4), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTube(int idx, bool isExtra, {bool animated = true}) {
    final tube = _tubes[idx];
    final isSelected = animated && _selectedTube == idx;
    final cap = _params.tubeCapacity;
    final tubeW = _tubeW;
    final segH = _segH;
    final tubeH = cap * segH + 10;
    final eCap = _effectiveCap(idx);
    final isLocked = isExtra && eCap <= 0;

    Widget tubeBody = Container(
      width: tubeW + 4,
      height: tubeH + 10,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: isSelected ? 0.22 : 0.12),
            Colors.white.withValues(alpha: isSelected ? 0.06 : 0.03),
            Colors.white.withValues(alpha: isSelected ? 0.22 : 0.12),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16), top: Radius.circular(8)),
        border: Border.all(
          color: isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.20),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(2, 4)),
          if (isSelected) BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 12),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 4, top: 4, bottom: 4,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.25), Colors.white.withValues(alpha: 0.05)],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 3, right: 3, top: 1, bottom: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (int i = cap - 1; i >= 0; i--)
                  _buildWaterSegment(i, tube, eCap, isExtra, tubeW - 6, segH),
              ],
            ),
          ),
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16), top: Radius.circular(8)),
                ),
                child: Center(
                  child: Icon(Icons.lock_rounded, size: 20, color: Colors.white.withValues(alpha: 0.40)),
                ),
              ),
            ),
        ],
      ),
    );

    final isComplete = _completedTubes.contains(idx) && tube.isNotEmpty;
    final isCelebrating = _celebratingTubes.contains(idx);

    if (isComplete && animated) {
      tubeBody = Stack(
        clipBehavior: Clip.none,
        children: [
          tubeBody,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16), top: Radius.circular(8)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                boxShadow: [
                  BoxShadow(color: _waterColors[tube.first].withValues(alpha: 0.30), blurRadius: 14, spreadRadius: 2),
                ],
              ),
            ),
          ),
          if (isCelebrating)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _celebrateAnim,
                builder: (context, _) => _buildCelebration(tubeW + 4, tubeH + 10, tube.first),
              ),
            ),
        ],
      );
    }

    if (animated && isSelected) {
      tubeBody = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, -12, 0),
        child: tubeBody,
      );
    }

    return GestureDetector(
      onTap: animated ? () {
        if (isLocked) {
          _onUnlockExtraSlot();
        } else if (!isComplete) {
          _onTubeTap(idx);
        }
      } : null,
      child: SizedBox(
        width: tubeW + 4,
        height: tubeH + 34,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: tubeBody,
        ),
      ),
    );
  }

  Widget _buildWaterSegment(int slotIdx, List<int> tube, int eCap, bool isExtra, double w, double h) {
    final hasWater = slotIdx < tube.length;
    final isLockedSlot = isExtra && slotIdx >= eCap;
    final isBottom = slotIdx == 0;
    final isTop = slotIdx == tube.length - 1;
    if (isLockedSlot) {
      return Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: isBottom ? const BorderRadius.vertical(bottom: Radius.circular(10)) : BorderRadius.zero,
        ),
        child: Center(child: Icon(Icons.lock_rounded, size: 9, color: Colors.white.withValues(alpha: 0.25))),
      );
    }
    if (!hasWater) {
      return SizedBox(width: w, height: h);
    }
    final baseColor = _waterColors[tube[slotIdx]];
    final botR = isBottom ? const Radius.circular(10) : Radius.zero;
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(baseColor, Colors.black, 0.15)!,
            baseColor,
            Color.lerp(baseColor, Colors.white, 0.25)!,
            baseColor,
            Color.lerp(baseColor, Colors.black, 0.10)!,
          ],
          stops: const [0.0, 0.2, 0.45, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.only(bottomLeft: botR, bottomRight: botR),
      ),
      child: isTop
          ? Align(
              alignment: const Alignment(-0.5, -0.5),
              child: Container(
                width: w * 0.3, height: 2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            )
          : null,
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
              _statCol('LEVEL', '$_level', color),
              _pillDivider(),
              _statCol('MOVES', '$_moves', const Color(0xFF6B7280)),
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
      headline: _won ? 'Level $_level Complete!' : 'Stuck!',
      subtitle: _won ? '$_moves moves' : 'Try again or restart',
      badgeContent: _won ? '💧' : '😔',
      badgeColor: diff.color,
      showNewBestBadge: false,
      gameId: kWaterSortGameId,
      score: _level,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: 'LEVEL', value: _level, color: diff.color),
          game_result.StatItem(label: 'MOVES', value: _moves, color: const Color(0xFF6B7280)),
        ],
      ),
      actions: [
        if (_won)
          game_result.GameResultAction(
            label: 'Next Level',
            icon: Icons.arrow_forward_rounded,
            onTap: _nextLevel,
            filled: true,
            color: diff.color,
            actionId: 'play_again',
          )
        else
          game_result.GameResultAction(
            label: 'Retry Level',
            icon: Icons.refresh_rounded,
            onTap: _restartLevel,
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


