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
import 'nuts_and_bolts_logo.dart';
import 'nuts_and_bolts_tutorial.dart';

const kNutsAndBoltsGameId = 'nuts_and_bolts';

const _kAccent = Color(0xFF78716C);
const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['3–4 colors · varied bolts', '4–6 colors · varied bolts', '6–8 colors · varied bolts'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
}

class _BoltLevelParams {
  final int numColors;
  final int nutsPerBolt;
  final int emptyBolts;
  int get numBolts => numColors + emptyBolts;
  const _BoltLevelParams({required this.numColors, required this.nutsPerBolt, required this.emptyBolts});
}

_BoltLevelParams _rollBoltParams(_Difficulty diff, math.Random rng) {
  switch (diff) {
    case _Difficulty.easy:
      final colors = 3 + rng.nextInt(2);
      final npb = 2 + rng.nextInt(3);
      final empty = 2 + rng.nextInt(2);
      return _BoltLevelParams(numColors: colors, nutsPerBolt: npb, emptyBolts: empty);
    case _Difficulty.medium:
      final colors = 4 + rng.nextInt(3);
      final npb = 3 + rng.nextInt(3);
      final empty = 2;
      return _BoltLevelParams(numColors: colors, nutsPerBolt: npb, emptyBolts: empty);
    case _Difficulty.hard:
      final colors = 6 + rng.nextInt(3);
      final npb = 4 + rng.nextInt(3);
      final empty = 2;
      return _BoltLevelParams(numColors: colors, nutsPerBolt: npb, emptyBolts: empty);
  }
}

const _nutColors = [
  Color(0xFFFF5555),
  Color(0xFF4A9EFF),
  Color(0xFF44DD66),
  Color(0xFFFFCC33),
  Color(0xFFA855F7),
  Color(0xFFFF7EB3),
  Color(0xFF22D3EE),
  Color(0xFFFF8833),
];

class NutsAndBoltsScreen extends StatefulWidget {
  const NutsAndBoltsScreen({super.key});

  @override
  State<NutsAndBoltsScreen> createState() => _NutsAndBoltsScreenState();
}

class _NutsAndBoltsScreenState extends State<NutsAndBoltsScreen> with TickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  int _level = 1;
  int _moves = 0;
  bool _gameOver = false;
  bool _won = false;
  int _bestMoves = 0;

  List<List<int>> _bolts = [];
  int _selectedBolt = -1;
  _BoltLevelParams _params = const _BoltLevelParams(numColors: 3, nutsPerBolt: 3, emptyBolts: 2);

  int _extraBoltSlots = 0;
  OverlayEntry? _appreciationOverlay;

  final Set<int> _completedBolts = {};
  final Map<int, AnimationController> _completionAnims = {};
  final Map<String, AnimationController> _nutPlaceAnims = {};

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kNutsAndBoltsGameId);
  }

  @override
  void dispose() {
    _appreciationOverlay?.remove();
    _appreciationOverlay = null;
    for (final c in _completionAnims.values) c.dispose();
    for (final c in _nutPlaceAnims.values) c.dispose();
    super.dispose();
  }

  void _disposeAnims() {
    for (final c in _completionAnims.values) c.dispose();
    _completionAnims.clear();
    for (final c in _nutPlaceAnims.values) c.dispose();
    _nutPlaceAnims.clear();
    _completedBolts.clear();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kNutsAndBoltsGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kNutsAndBoltsGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
      accent: _kAccent, steps: nutsAndBoltsSteps(), gameId: kNutsAndBoltsGameId);
  }

  void _startGame(_Difficulty diff) {
    final lps = LevelProgressService();
    _level = lps.getCurrentLevel(kNutsAndBoltsGameId, diff.subKey);
    _bestMoves = lps.getLevelBest(kNutsAndBoltsGameId, diff.subKey, _level);

    _gameOver = false;
    _won = false;
    _selectedBolt = -1;
    _generateLevel(diff);

    final saved = lps.getGameState(kNutsAndBoltsGameId, diff.subKey);
    if (saved != null && saved['level'] == _level) {
      _bolts = (saved['bolts'] as List).map((b) => List<int>.from(b as List)).toList();
      _moves = saved['moves'] as int;
      _extraBoltSlots = saved['extraBoltSlots'] as int;
    } else {
      _moves = 0;
      _extraBoltSlots = 0;
    }

    setState(() => _activeDifficulty = diff);
    GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _generateLevel(_Difficulty diff) {
    final rng = math.Random(_level * 1000 + diff.index * 100);
    _params = _rollBoltParams(diff, rng);
    final npb = _params.nutsPerBolt;

    final solved = <List<int>>[];
    for (int c = 0; c < _params.numColors; c++) {
      solved.add(List.filled(npb, c));
    }
    for (int e = 0; e < _params.emptyBolts; e++) {
      solved.add(<int>[]);
    }

    _bolts = solved.map((b) => List<int>.from(b)).toList();

    final shuffleMoves = 60 + _level * 2;
    for (int i = 0; i < shuffleMoves; i++) {
      final validMoves = <List<int>>[];
      for (int from = 0; from < _bolts.length; from++) {
        if (_bolts[from].isEmpty) continue;
        for (int to = 0; to < _bolts.length; to++) {
          if (from == to) continue;
          if (_bolts[to].length >= npb) continue;
          validMoves.add([from, to]);
        }
      }
      if (validMoves.isEmpty) break;
      final move = validMoves[rng.nextInt(validMoves.length)];
      final nut = _bolts[move[0]].removeLast();
      _bolts[move[1]].add(nut);
    }

    _bolts.add(<int>[]);
    _extraBoltSlots = 0;
  }

  void _onBoltTap(int idx) {
    if (_gameOver || _appreciationOverlay != null) return;

    if (_selectedBolt == -1) {
      if (_bolts[idx].isEmpty) return;
      setState(() => _selectedBolt = idx);
      return;
    }

    if (_selectedBolt == idx) {
      setState(() => _selectedBolt = -1);
      return;
    }

    if (_canMove(_selectedBolt, idx)) {
      _moveNut(_selectedBolt, idx);
      AudioService().playTap();
      final nutSlot = _bolts[idx].length - 1;
      final key = '${idx}_$nutSlot';
      _nutPlaceAnims[key]?.dispose();
      final ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
      _nutPlaceAnims[key] = ac;
      ac.forward();
      final npb = _params.nutsPerBolt;
      final bolt = _bolts[idx];
      final isFull = bolt.length == npb && bolt.toSet().length == 1;
      if (isFull && !_completedBolts.contains(idx)) {
        _completedBolts.add(idx);
        _completionAnims[idx]?.dispose();
        final ca = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
        _completionAnims[idx] = ca;
        ca.forward();
        AudioService().playScore();
      }
      setState(() {
        _moves++;
        _selectedBolt = -1;
      });
      _saveState();
      _checkWin();
    } else {
      if (_bolts[idx].isNotEmpty) {
        setState(() => _selectedBolt = idx);
      } else {
        setState(() => _selectedBolt = -1);
      }
    }
  }

  int _effectiveCap(int idx) {
    final isExtra = idx == _bolts.length - 1;
    return isExtra ? _extraBoltSlots : _params.nutsPerBolt;
  }

  bool _canMove(int from, int to) {
    if (_bolts[from].isEmpty) return false;
    final maxCap = _effectiveCap(to);
    if (maxCap <= 0) return false;
    if (_bolts[to].length >= maxCap) return false;
    if (_bolts[to].isEmpty) return true;
    return _bolts[from].last == _bolts[to].last;
  }

  void _moveNut(int from, int to) {
    final color = _bolts[from].last;
    final maxCap = _effectiveCap(to);
    while (_bolts[from].isNotEmpty && _bolts[from].last == color && _bolts[to].length < maxCap) {
      _bolts[from].removeLast();
      _bolts[to].add(color);
    }
  }

  void _checkWin() {
    final npb = _params.nutsPerBolt;
    for (int i = 0; i < _bolts.length - 1; i++) {
      final bolt = _bolts[i];
      if (bolt.isEmpty) continue;
      if (bolt.length != npb) return;
      if (bolt.toSet().length != 1) return;
    }
    _endGame(true);
  }

  void _endGame(bool won) {
    _won = won;
    if (won) {
      final diff = _activeDifficulty!;
      final lps = LevelProgressService();
      final prevBest = lps.getLevelBest(kNutsAndBoltsGameId, diff.subKey, _level);
      if (prevBest == 0 || _moves < prevBest) _bestMoves = _moves;
      lps.saveLevelBest(kNutsAndBoltsGameId, diff.subKey, _level, _moves);
      lps.advanceLevel(kNutsAndBoltsGameId, diff.subKey);
      lps.clearGameState(kNutsAndBoltsGameId, diff.subKey);
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
    _disposeAnims();
    final diff = _activeDifficulty!;
    setState(() {
      _level++;
      _moves = 0;
      _gameOver = false;
      _won = false;
      _selectedBolt = -1;
      _extraBoltSlots = 0;
    });
    _bestMoves = LevelProgressService().getLevelBest(kNutsAndBoltsGameId, diff.subKey, _level);
    _generateLevel(diff);
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _restartLevel() {
    _disposeAnims();
    setState(() {
      _moves = 0;
      _gameOver = false;
      _won = false;
      _selectedBolt = -1;
      _extraBoltSlots = 0;
    });
    _generateLevel(_activeDifficulty!);
    if (_activeDifficulty != null) {
      LevelProgressService().clearGameState(kNutsAndBoltsGameId, _activeDifficulty!.subKey);
    }
    GameWrapper.of(context).restartGame();
    GameWrapper.of(context).startGame();
    GameWrapper.of(context).updateScore(_level);
  }

  void _onUnlockExtraSlot() {
    if (_extraBoltSlots >= _params.nutsPerBolt || _gameOver) return;
    if (!AdsService().isRewardedReady) return;
    AudioService().playTap();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kNutsAndBoltsGameId,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (!earned || !mounted) return;
        setState(() {
          _extraBoltSlots++;
        });
        _saveState();
      },
    );
  }

  void _saveState() {
    final diff = _activeDifficulty;
    if (diff == null || _gameOver || _won) return;
    LevelProgressService().saveGameState(kNutsAndBoltsGameId, diff.subKey, {
      'level': _level,
      'bolts': _bolts,
      'moves': _moves,
      'extraBoltSlots': _extraBoltSlots,
    });
  }

  void _backToPicker() {
    _saveState();
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
      bestScore: LevelProgressService().getHighestLevel(kNutsAndBoltsGameId, d.subKey),
      bestLabel: (s) {
        if (s <= 0) return '';
        final ob = LevelProgressService().getOverallBest(kNutsAndBoltsGameId, d.subKey);
        return ob > 0 ? 'Level $s · Best: $ob moves' : 'Completed: Level $s';
      },
    )).toList();

    return GamePickerScaffold(
      bgColorTop: const Color(0xFFF5F5F4),
      bgColorBottom: const Color(0xFFE7E5E4),
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.hardware_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFFA8A29E), Color(0xFF57534E)],
      iconChild: buildNutsAndBoltsLogo(60),
      title: 'Nuts & Bolts',
      subtitle: 'Sort the nuts onto matching bolts!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kNutsAndBoltsGameId,
      body: GameSinglePickerBody(
        difficulties: difficulties,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Nuts & Bolts',
        playSubLabel: 'Level ${LevelProgressService().getCurrentLevel(kNutsAndBoltsGameId, _pickerDifficulty.subKey)}',
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
          colors: [Color(0xFF1A1040), Color(0xFF2D1B69), Color(0xFF1A1040)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            GameHudBar(
              leading: GameBackButton(onTap: _backOrHome, bgColor: Colors.white.withValues(alpha: 0.10), iconColor: Colors.white),
              centerContent: _buildHud(diff),
              trailing: GameRestartButton(
                gameName: 'Nuts & Bolts',
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
                    builder: (context, constraints) => ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildBolts(diff, constraints.maxWidth),
                      ),
                    ),
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

  Widget _buildBolts(_Difficulty diff, double availW) {
    final boltCount = _bolts.length;
    final hasExtraBtn = _extraBoltSlots < _params.nutsPerBolt;
    const boltSlotW = 82.0;
    const extraBtnW = 44.0;
    final effectiveW = hasExtraBtn ? availW - extraBtnW : availW;
    final maxPerRow = (effectiveW / boltSlotW).floor().clamp(1, boltCount);

    final rows = <List<int>>[];
    for (int i = 0; i < boltCount; i += maxPerRow) {
      final end = (i + maxPerRow).clamp(0, boltCount);
      rows.add(List.generate(end - i, (j) => i + j));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ...row.map((idx) {
                final isExtra = idx == _bolts.length - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildBolt(idx, isExtra),
                );
              }),
              if (row.contains(_bolts.length - 1) && _extraBoltSlots < _params.nutsPerBolt)
                _buildExtraSpaceButton(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExtraSpaceButton() {
    final npb = _params.nutsPerBolt;
    const nutH = 28.0;
    const nutGap = 0.0;
    final shaftH = npb * (nutH + nutGap) + 6;
    final bottomOffset = _extraBoltSlots * (nutH + nutGap);
    return GestureDetector(
      onTap: _onUnlockExtraSlot,
      child: SizedBox(
        width: 40,
        height: shaftH + 24,
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

  Widget _buildBolt(int idx, bool isExtra) {
    final bolt = _bolts[idx];
    final isSelected = _selectedBolt == idx;
    const nutW = 54.0;
    const nutH = 28.0;
    const nutGap = 0.0;
    const shaftW = 14.0;
    const discW = 74.0;
    const discH = 20.0;
    const headR = 11.0;
    final npb = _params.nutsPerBolt;
    final shaftH = npb * (nutH + nutGap) + 6;
    final totalH = discH + shaftH + headR * 2;
    final eCap = _effectiveCap(idx);
    final isLocked = isExtra && eCap <= 0;
    final isComplete = _completedBolts.contains(idx);
    final compAnim = _completionAnims[idx];

    Widget boltWidget = GestureDetector(
      onTap: () {
        if (isLocked) {
          _onUnlockExtraSlot();
        } else {
          _onBoltTap(idx);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, isSelected ? -12 : 0, 0),
        child: SizedBox(
          width: discW + 6,
          height: totalH,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                child: CustomPaint(
                  painter: _DiscBasePainter(isSelected: isSelected),
                  size: const Size(discW, discH),
                ),
              ),
              Positioned(
                bottom: discH - 2,
                child: SizedBox(
                  width: shaftW,
                  height: shaftH,
                  child: CustomPaint(
                    painter: _BoltShaftPainter(isSelected: isSelected),
                    size: Size(shaftW, shaftH),
                  ),
                ),
              ),
              Positioned(
                bottom: discH + shaftH - 2,
                child: CustomPaint(
                  painter: _BoltHeadPainter(),
                  size: const Size(headR * 2, headR * 2),
                ),
              ),
              Positioned(
                bottom: discH - 2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(npb, (i) {
                    final nutIdx = i;
                    final hasNut = nutIdx < bolt.length;
                    final isLockedSlot = isExtra && nutIdx >= eCap;
                    return Padding(
                      padding: const EdgeInsets.only(top: nutGap),
                      child: _buildNut(idx, nutIdx, hasNut ? bolt[nutIdx] : -1, hasNut, isLockedSlot, nutW, nutH),
                    );
                  }).reversed.toList(),
                ),
              ),
              if (isComplete)
                Positioned(
                  bottom: discH + shaftH - 2,
                  child: Container(
                    width: headR * 2 + 6,
                    height: headR * 2 + 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (bolt.isNotEmpty ? _nutColors[bolt.first] : Colors.green).withValues(alpha: 0.6),
                          (bolt.isNotEmpty ? _nutColors[bolt.first] : Colors.green).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bolt.isNotEmpty ? _nutColors[bolt.first] : Colors.green,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: (bolt.isNotEmpty ? _nutColors[bolt.first] : Colors.green).withValues(alpha: 0.7),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(Icons.lock_rounded, size: 22, color: Colors.white.withValues(alpha: 0.40)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (isComplete && compAnim != null) {
      final nutColor = bolt.isNotEmpty ? _nutColors[bolt.first] : Colors.green;
      return AnimatedBuilder(
        animation: compAnim,
        builder: (_, child) {
          final t = compAnim.value;
          final glow = Curves.easeOut.transform(t);
          final scale = 1.0 + 0.04 * Curves.elasticOut.transform(t);
          final fadeOut = 1.0 - 0.12 * Curves.easeIn.transform(t);
          return Opacity(
            opacity: fadeOut,
            child: Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: nutColor.withValues(alpha: 0.5 * glow),
                      blurRadius: 24 * glow,
                      spreadRadius: 6 * glow,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        child: boltWidget,
      );
    }

    if (isComplete) {
      return Opacity(opacity: 0.85, child: boltWidget);
    }

    return boltWidget;
  }

  Widget _buildNut(int boltIdx, int slotIdx, int colorIdx, bool hasNut, bool isLockedSlot, double w, double h) {
    if (isLockedSlot) {
      return Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(child: Icon(Icons.lock_rounded, size: 9, color: Colors.white.withValues(alpha: 0.25))),
      );
    }
    if (!hasNut) {
      return SizedBox(width: w, height: h);
    }
    final baseColor = _nutColors[colorIdx];
    final key = '${boltIdx}_$slotIdx';
    final placeAnim = _nutPlaceAnims[key];

    Widget nut = SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _HexNutPainter(baseColor),
      ),
    );

    if (placeAnim != null) {
      return AnimatedBuilder(
        animation: placeAnim,
        builder: (_, child) {
          final t = Curves.easeOut.transform(placeAnim.value);
          return Transform.rotate(
            angle: t * math.pi * 2,
            child: child,
          );
        },
        child: nut,
      );
    }

    return nut;
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
              _pillDivider(),
              Builder(builder: (_) {
                final ob = LevelProgressService().getOverallBest(kNutsAndBoltsGameId, _activeDifficulty!.subKey);
                return _statCol('BEST', ob > 0 ? '$ob' : '—', const Color(0xFFFEC84B));
              }),
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
    final isNewBest = _won && (_bestMoves == _moves);
    return game_result.GenericGameResultScreen(
      headline: _won ? 'Level $_level Complete!' : 'Stuck!',
      subtitle: _won ? '$_moves moves${isNewBest ? ' — New Best!' : ''}' : 'Try again or restart',
      badgeContent: _won ? '🔩' : '😔',
      badgeColor: diff.color,
      showNewBestBadge: isNewBest,
      gameId: kNutsAndBoltsGameId,
      score: _level,
      statsWidget: Builder(builder: (_) {
        final ob = LevelProgressService().getOverallBest(kNutsAndBoltsGameId, diff.subKey);
        return game_result.GameResultStatsRow(
          stats: [
            game_result.StatItem(label: 'LEVEL', value: _level, color: diff.color),
            game_result.StatItem(label: 'MOVES', value: _moves, color: const Color(0xFF6B7280)),
            game_result.StatItem(label: 'BEST', value: ob, displayValue: ob > 0 ? '$ob' : '—', color: const Color(0xFFFEC84B)),
          ],
        );
      }),
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

class _DiscBasePainter extends CustomPainter {
  final bool isSelected;
  _DiscBasePainter({this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawOval(
      Rect.fromLTWH(6, h * 0.55, w - 12, h * 0.5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final rimRect = Rect.fromLTWH(1, h * 0.18, w - 2, h * 0.85);
    canvas.drawOval(rimRect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFFD8D5D0), Color(0xFFC0BBB3), Color(0xFFA5A09A), Color(0xFF8A857D)],
        stops: const [0.0, 0.3, 0.65, 1.0],
      ).createShader(rimRect));
    canvas.drawOval(rimRect, Paint()
      ..color = const Color(0xFF7A756D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6);

    final topRect = Rect.fromLTWH(1, 0, w - 2, h * 0.52);
    canvas.drawOval(topRect, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.15, -0.2),
        radius: 1.0,
        colors: const [Color(0xFFFFFFFF), Color(0xFFF2F0EC), Color(0xFFE2DFD9)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(topRect));
    canvas.drawOval(topRect, Paint()
      ..color = const Color(0xFFCAC5BD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);

    canvas.drawOval(
      Rect.fromLTWH(w * 0.20, 1, w * 0.30, h * 0.14),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    if (isSelected) {
      canvas.drawOval(topRect.inflate(1), Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0);
    }
  }

  @override
  bool shouldRepaint(_DiscBasePainter old) => old.isSelected != isSelected;
}

class _BoltShaftPainter extends CustomPainter {
  final bool isSelected;
  _BoltShaftPainter({this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;

    canvas.save();
    canvas.clipRRect(RRect.fromLTRBR(0, 0, w, h, Radius.circular(r)));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: const [
          Color(0xFF8E8984), Color(0xFFB8B4AE), Color(0xFFD8D5D0),
          Color(0xFFEAE7E2), Color(0xFFD8D5D0), Color(0xFFB8B4AE), Color(0xFF8E8984),
        ],
        stops: const [0.0, 0.12, 0.30, 0.48, 0.65, 0.82, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h)));

    final tDark = Paint()
      ..color = const Color(0xFF9A9590)
      ..strokeWidth = 1.0;
    final tMid = Paint()
      ..color = const Color(0xFFB5B0AA)
      ..strokeWidth = 1.4;
    final tLight = Paint()
      ..color = Colors.white.withValues(alpha: 0.50)
      ..strokeWidth = 0.7;
    const sp = 4.5;
    for (double y = 2; y < h; y += sp) {
      canvas.drawLine(Offset(0, y), Offset(w, y + 2), tDark);
      canvas.drawLine(Offset(0, y + 1.0), Offset(w, y + 3.0), tMid);
      canvas.drawLine(Offset(0, y + 2.0), Offset(w, y + 4.0), tLight);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w * 0.35, h),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.black.withValues(alpha: 0.08), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, w * 0.35, h)),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.65, 0, w * 0.35, h),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.08)],
        ).createShader(Rect.fromLTWH(w * 0.65, 0, w * 0.35, h)),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.30, 0, w * 0.15, h),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, Colors.white.withValues(alpha: 0.15)],
        ).createShader(Rect.fromLTWH(w * 0.30, 0, w * 0.15, h)),
    );

    canvas.restore();

    if (isSelected) {
      canvas.drawRRect(
        RRect.fromLTRBR(0, 0, w, h, Radius.circular(r)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(_BoltShaftPainter old) => old.isSelected != isSelected;
}

class _BoltHeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + r * 0.15), width: r * 1.8, height: r * 0.5),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.30),
        radius: 0.85,
        colors: const [Color(0xFFF0EDEA), Color(0xFFDAD7D2), Color(0xFFC0BBB5), Color(0xFFA8A39D)],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..color = const Color(0xFF908B85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);

    canvas.drawCircle(Offset(cx, cy), r * 0.65, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.5),
        radius: 0.8,
        colors: [Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.65)));

    canvas.drawCircle(Offset(cx - r * 0.15, cy - r * 0.15), r * 0.15, Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    final ip = Paint()
      ..color = const Color(0xFF908B85).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - r * 0.28, cy), Offset(cx + r * 0.28, cy), ip);
    canvas.drawLine(Offset(cx, cy - r * 0.28), Offset(cx, cy + r * 0.28), ip);
  }

  @override
  bool shouldRepaint(_BoltHeadPainter old) => false;
}

class _HexNutPainter extends CustomPainter {
  final Color color;
  _HexNutPainter(this.color);

  List<Offset> _hexVerts(double cx, double cy, double rx, double ry) {
    return List.generate(6, (i) {
      final a = (math.pi / 3) * i;
      return Offset(cx + rx * math.cos(a), cy + ry * math.sin(a));
    });
  }

  Path _roundedPath(List<Offset> verts, double r) {
    final path = Path();
    final n = verts.length;
    for (int i = 0; i < n; i++) {
      final prev = verts[(i + n - 1) % n];
      final curr = verts[i];
      final next = verts[(i + 1) % n];
      final d1 = (curr - prev).distance;
      final d2 = (next - curr).distance;
      final t1 = (r / d1).clamp(0.0, 0.4);
      final t2 = (r / d2).clamp(0.0, 0.4);
      final p1 = Offset.lerp(curr, prev, t1)!;
      final p2 = Offset.lerp(curr, next, t2)!;
      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final rx = w / 2 - 1.5;
    const topRy = 6.0;
    const R = 6.0;
    final topCy = topRy;
    final depth = h - topRy;

    final tv = _hexVerts(cx, topCy, rx, topRy);
    final bv = tv.map((v) => Offset(v.dx, v.dy + depth)).toList();

    final bodyVerts = [tv[0], tv[1], tv[2], tv[3], bv[3], bv[2], bv[1], bv[0]];
    final bodyPath = _roundedPath(bodyVerts, R);

    canvas.drawPath(bodyPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color.lerp(color, Colors.black, 0.30)!,
          Color.lerp(color, Colors.black, 0.10)!,
          color,
          Color.lerp(color, Colors.white, 0.12)!,
          color,
          Color.lerp(color, Colors.black, 0.12)!,
          Color.lerp(color, Colors.black, 0.30)!,
        ],
        stops: const [0.0, 0.10, 0.28, 0.45, 0.62, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h)));

    canvas.drawPath(bodyPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.08),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, topCy, w, depth)));

    for (int i = 1; i < 3; i++) {
      canvas.drawLine(tv[i], bv[i], Paint()
        ..color = Color.lerp(color, Colors.black, 0.15)!
        ..strokeWidth = 0.8);
      canvas.drawLine(
        Offset(tv[i].dx + 1, tv[i].dy),
        Offset(bv[i].dx + 1, bv[i].dy),
        Paint()
          ..color = Color.lerp(color, Colors.white, 0.08)!
          ..strokeWidth = 0.5,
      );
    }

    final botEdge = Path()..moveTo(bv[0].dx, bv[0].dy);
    for (int i = 1; i <= 3; i++) botEdge.lineTo(bv[i].dx, bv[i].dy);
    canvas.drawPath(botEdge, Paint()
      ..color = Color.lerp(color, Colors.black, 0.28)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round);

    final topPath = _roundedPath(tv, R);

    canvas.drawPath(topPath, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        radius: 1.0,
        colors: [
          Color.lerp(color, Colors.white, 0.55)!,
          Color.lerp(color, Colors.white, 0.40)!,
          Color.lerp(color, Colors.white, 0.22)!,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, topCy - topRy, w, topRy * 2)));

    canvas.drawPath(topPath, Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6);

    final bevelPath = Path()..moveTo(tv[0].dx, tv[0].dy);
    for (int i = 1; i <= 3; i++) bevelPath.lineTo(tv[i].dx, tv[i].dy);
    canvas.drawPath(bevelPath, Paint()
      ..color = Color.lerp(color, Colors.black, 0.10)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, topCy), width: rx * 0.30, height: topRy * 0.50),
      Paint()..color = Color.lerp(color, Colors.black, 0.18)!.withValues(alpha: 0.45),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, topCy), width: rx * 0.30, height: topRy * 0.50),
      Paint()
        ..color = Color.lerp(color, Colors.black, 0.25)!.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    canvas.drawOval(
      Rect.fromLTWH(cx - rx * 0.28, 0.5, rx * 0.30, topRy * 0.45),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  @override
  bool shouldRepaint(_HexNutPainter old) => old.color != color;
}
