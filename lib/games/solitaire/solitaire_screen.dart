import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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
import 'solitaire_logo.dart';
import 'solitaire_tutorial.dart';

const kSolitaireGameId = 'solitaire';

const _kBgTop = Color(0xFFE8F5E9);
const _kBgBottom = Color(0xFFC8E6C9);
const _kAccent = Color(0xFF22C55E);
const _kFelt = Color(0xFF1B5E20);

const _kEasyColor = Color(0xFF22C55E);
const _kMediumColor = Color(0xFFF59E0B);
const _kHardColor = Color(0xFFEF4444);

enum _Difficulty { easy, medium, hard }

extension _DifficultyX on _Difficulty {
  String get label => ['EASY', 'MEDIUM', 'HARD'][index];
  Color get color => [_kEasyColor, _kMediumColor, _kHardColor][index];
  DifficultyKind get kind => [DifficultyKind.easy, DifficultyKind.medium, DifficultyKind.hard][index];
  String get hint => ['Draw 1 card at a time', 'Draw 3 cards at a time', 'Draw 3, limited passes'][index];
  String get subKey => ['easy', 'medium', 'hard'][index];
  int get drawCount => [1, 3, 3][index];
}

enum _Suit { spades, hearts, diamonds, clubs }

extension _SuitX on _Suit {
  String get symbol => ['♠', '♥', '♦', '♣'][index];
  Color get color => (this == _Suit.hearts || this == _Suit.diamonds) ? const Color(0xFFE53E3E) : const Color(0xFF1A1A2E);
  bool get isRed => this == _Suit.hearts || this == _Suit.diamonds;
}

class _Card {
  final int rank;
  final _Suit suit;
  bool faceUp;

  _Card(this.rank, this.suit, {this.faceUp = false});

  String get rankLabel {
    if (rank == 1) return 'A';
    if (rank == 11) return 'J';
    if (rank == 12) return 'Q';
    if (rank == 13) return 'K';
    return '$rank';
  }

  String get display => '$rankLabel${suit.symbol}';
  Color get displayColor => suit.color;
  bool get isRed => suit.isRed;

  bool canStackOnTableau(_Card other) {
    return other.rank == rank + 1 && other.isRed != isRed;
  }

  bool canStackOnFoundation(_Card? top) {
    if (top == null) return rank == 1;
    return suit == top.suit && rank == top.rank + 1;
  }
}

int _findSolvableSeed(List<int> args) {
  final baseSeed = args[0];
  final drawCount = args[1];

  for (int attempt = 0; attempt < 500; attempt++) {
    final seed = baseSeed + attempt;
    if (_trySolve(seed, drawCount)) return seed;
  }
  return baseSeed;
}

bool _trySolve(int seed, int drawCount) {
  final deck = List.generate(52, (i) => i);
  final rng = math.Random(seed);
  for (int i = 51; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = deck[i]; deck[i] = deck[j]; deck[j] = t;
  }

  final tabR = List.generate(7, (_) => <int>[]);
  final tabF = List.generate(7, (_) => <bool>[]);
  int di = 51;
  for (int i = 0; i < 7; i++) {
    for (int j = 0; j <= i; j++) {
      tabR[i].add(deck[di]);
      tabF[i].add(j == i);
      di--;
    }
  }

  final stock = <int>[];
  for (int i = di; i >= 0; i--) stock.add(deck[i]);
  final waste = <int>[];
  final fnd = List.filled(4, 0);

  int rankOf(int c) => (c % 13) + 1;
  int suitOf(int c) => c ~/ 13;
  bool isRed(int c) { final s = suitOf(c); return s == 1 || s == 2; }

  void flipTops() {
    for (int i = 0; i < 7; i++) {
      if (tabR[i].isNotEmpty && !tabF[i].last) tabF[i][tabF[i].length - 1] = true;
    }
  }

  bool moveToFnd() {
    var moved = false;
    bool pass;
    do {
      pass = false;
      for (int c = 0; c < 7; c++) {
        if (tabR[c].isEmpty) continue;
        if (!tabF[c].last) continue;
        final card = tabR[c].last;
        if (rankOf(card) == fnd[suitOf(card)] + 1) {
          fnd[suitOf(card)] = rankOf(card);
          tabR[c].removeLast(); tabF[c].removeLast();
          flipTops();
          pass = true; moved = true;
        }
      }
      if (waste.isNotEmpty) {
        final card = waste.last;
        if (rankOf(card) == fnd[suitOf(card)] + 1) {
          fnd[suitOf(card)] = rankOf(card);
          waste.removeLast();
          pass = true; moved = true;
        }
      }
    } while (pass);
    return moved;
  }

  bool tabToTab() {
    for (int src = 0; src < 7; src++) {
      if (tabR[src].isEmpty) continue;
      int first = 0;
      for (int k = 0; k < tabR[src].length; k++) {
        if (tabF[src][k]) { first = k; break; }
      }
      if (first == 0 && rankOf(tabR[src][first]) == 13) continue;
      final card = tabR[src][first];
      for (int dst = 0; dst < 7; dst++) {
        if (dst == src) continue;
        if (tabR[dst].isEmpty) {
          if (rankOf(card) == 13 && first > 0) {
            tabR[dst].addAll(tabR[src].sublist(first));
            tabF[dst].addAll(tabF[src].sublist(first));
            tabR[src].removeRange(first, tabR[src].length);
            tabF[src].removeRange(first, tabF[src].length);
            flipTops();
            return true;
          }
        } else {
          final top = tabR[dst].last;
          if (tabF[dst].last && rankOf(card) + 1 == rankOf(top) && isRed(card) != isRed(top)) {
            tabR[dst].addAll(tabR[src].sublist(first));
            tabF[dst].addAll(tabF[src].sublist(first));
            tabR[src].removeRange(first, tabR[src].length);
            tabF[src].removeRange(first, tabF[src].length);
            flipTops();
            return true;
          }
        }
      }
    }
    return false;
  }

  bool wasteToTab() {
    if (waste.isEmpty) return false;
    final card = waste.last;
    for (int dst = 0; dst < 7; dst++) {
      if (tabR[dst].isEmpty) {
        if (rankOf(card) == 13) { waste.removeLast(); tabR[dst].add(card); tabF[dst].add(true); return true; }
      } else {
        final top = tabR[dst].last;
        if (tabF[dst].last && rankOf(card) + 1 == rankOf(top) && isRed(card) != isRed(top)) {
          waste.removeLast(); tabR[dst].add(card); tabF[dst].add(true); return true;
        }
      }
    }
    return false;
  }

  int draws = 0;
  int moves = 0;
  while (fnd[0] + fnd[1] + fnd[2] + fnd[3] < 52 && moves < 800) {
    if (moveToFnd()) { draws = 0; moves++; continue; }
    if (tabToTab()) { draws = 0; moves++; continue; }
    if (wasteToTab()) { draws = 0; moves++; continue; }
    if (stock.isNotEmpty) {
      final n = math.min(drawCount, stock.length);
      for (int i = 0; i < n; i++) waste.add(stock.removeLast());
      draws++; moves++;
      if (draws > 52) break;
    } else if (waste.isNotEmpty) {
      stock.addAll(waste.reversed); waste.clear();
      draws++; moves++;
      if (draws > 52) break;
    } else {
      break;
    }
  }
  return fnd[0] + fnd[1] + fnd[2] + fnd[3] == 52;
}

class SolitaireScreen extends StatefulWidget {
  const SolitaireScreen({super.key});

  @override
  State<SolitaireScreen> createState() => _SolitaireScreenState();
}

class _SolitaireScreenState extends State<SolitaireScreen> with TickerProviderStateMixin {
  _Difficulty? _activeDifficulty;
  _Difficulty _pickerDifficulty = _Difficulty.values[DifficultyKind.defaultIndex];
  bool _isFavorite = false;

  List<_Card> _stock = [];
  List<_Card> _waste = [];
  List<List<_Card>> _foundations = [];
  List<List<_Card>> _tableau = [];

  bool _gameOver = false;
  bool _won = false;
  int _moves = 0;
  int _bestTime = 0;
  bool _isNewBest = false;
  int _consecutiveShakes = 0;
  Timer? _idleTimer;
  bool _idleStuck = false;
  static const _kStuckShakes = 3;
  static const _kIdleTimeout = Duration(seconds: 45);

  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  int _elapsedSeconds = 0;

  final _gameStackKey = GlobalKey();
  final _wasteKey = GlobalKey();
  final _foundationKeys = List.generate(4, (_) => GlobalKey());
  final _tableauColKeys = List.generate(7, (_) => GlobalKey());
  final _cardKeys = <String, GlobalKey>{};

  AnimationController? _flyCtrl;
  List<_Card>? _flyingCards;
  Offset _flyFrom = Offset.zero;
  Offset _flyTo = Offset.zero;

  AnimationController? _shakeCtrl;
  int _shakeCol = -1;
  int _shakeIdx = -1;
  bool _shakeWaste = false;

  AnimationController? _drawSlideCtrl;

  int? _selCol;
  int _selIdx = -1;
  Set<int> _validTabDests = {};
  Set<int> _validFndDests = {};
  bool _selHasMoves = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kSolitaireGameId);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    _idleTimer?.cancel();
    _flyCtrl?.dispose();
    _shakeCtrl?.dispose();
    _drawSlideCtrl?.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    ScoreService().toggleFavorite(kSolitaireGameId);
    setState(() => _isFavorite = !_isFavorite);
  }

  void _showHelp() {
    final info = GameRegistry.getById(kSolitaireGameId);
    if (info == null) return;
    showHowToPlaySheet(context, title: info.name, howToPlay: info.howToPlay,
      accent: _kAccent, steps: solitaireSteps(), gameId: kSolitaireGameId);
  }

  Future<void> _startGame(_Difficulty diff) async {
    final baseSeed = DateTime.now().microsecondsSinceEpoch;
    final seed = await compute(_findSolvableSeed, [baseSeed, diff.drawCount]);
    if (!mounted) return;

    final deck = <_Card>[];
    for (final suit in _Suit.values) {
      for (int r = 1; r <= 13; r++) {
        deck.add(_Card(r, suit));
      }
    }
    deck.shuffle(math.Random(seed));

    _tableau = List.generate(7, (_) => <_Card>[]);
    for (int i = 0; i < 7; i++) {
      for (int j = 0; j <= i; j++) {
        final card = deck.removeLast();
        card.faceUp = j == i;
        _tableau[i].add(card);
      }
    }

    _stock = deck.reversed.toList();
    _waste = [];
    _foundations = List.generate(4, (_) => <_Card>[]);
    _gameOver = false;
    _won = false;
    _moves = 0;
    _isNewBest = false;
    _consecutiveShakes = 0;
    _idleStuck = false;
    _elapsedSeconds = 0;
    _flyingCards = null;
    _flyCtrl?.dispose();
    _flyCtrl = null;
    _shakeCtrl?.dispose();
    _shakeCtrl = null;
    _drawSlideCtrl?.dispose();
    _drawSlideCtrl = null;
    _shakeCol = -1;
    _shakeIdx = -1;
    _shakeWaste = false;
    _selCol = null;
    _selIdx = -1;
    _validTabDests = {};
    _validFndDests = {};
    _selHasMoves = false;
    _bestTime = ScoreService().getHighScore(kSolitaireGameId, subKey: diff.subKey);
    _stopwatch.reset();

    setState(() => _activeDifficulty = diff);

    if (mounted) {
      GameWrapper.of(context).setDifficultyAndMode(difficulty: diff.label, subKey: diff.subKey);
      GameWrapper.of(context).startGame();
      GameWrapper.of(context).updateScore(0);
    }

    _resetIdleTimer();
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
      GameWrapper.of(context).updateScore(_elapsedSeconds);
    });
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

  void _countMove() {
    _moves++;
    _consecutiveShakes = 0;
    _idleStuck = false;
    _resetIdleTimer();
  }

  bool get _isStuck => _consecutiveShakes >= _kStuckShakes || _idleStuck;

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_idleStuck) setState(() => _idleStuck = false);
    _idleTimer = Timer(_kIdleTimeout, () {
      if (mounted && _activeDifficulty != null && !_gameOver && !_won) {
        setState(() => _idleStuck = true);
      }
    });
  }

  void _drawFromStock() {
    if (_gameOver || _flyingCards != null) return;
    _selCol = null;
    _selIdx = -1;
    final diff = _activeDifficulty!;
    if (_stock.isEmpty) {
      if (_waste.isEmpty) return;
      _stock = _waste.reversed.toList();
      for (final c in _stock) c.faceUp = false;
      _waste = [];
      _countMove();
    } else {
      final count = math.min(diff.drawCount, _stock.length);
      for (int i = 0; i < count; i++) {
        final card = _stock.removeLast();
        card.faceUp = true;
        _waste.add(card);
      }
      _drawSlideCtrl?.dispose();
      _drawSlideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
        ..forward();
    }
    AudioService().playTap();
    setState(() {});
  }

  void _clearSel() {
    _selCol = null;
    _selIdx = -1;
    _validTabDests = {};
    _validFndDests = {};
    _selHasMoves = false;
    setState(() {});
  }

  bool get _hasSel => _selCol != null;

  void _computeValidDests() {
    _validTabDests = {};
    _validFndDests = {};
    final cards = _getSelCards();
    if (cards.isEmpty) { _selHasMoves = false; return; }
    final first = cards.first;

    if (cards.length == 1) {
      for (int i = 0; i < 4; i++) {
        final top = _foundations[i].isEmpty ? null : _foundations[i].last;
        if (first.canStackOnFoundation(top)) _validFndDests.add(i);
      }
    }

    for (int i = 0; i < 7; i++) {
      if (_selCol == i) continue;
      final pile = _tableau[i];
      if (pile.isEmpty) {
        if (first.rank == 13) {
          if (_selCol != null && _selCol! >= 0 && _selIdx == 0) continue;
          _validTabDests.add(i);
        }
      } else if (pile.last.faceUp && first.canStackOnTableau(pile.last)) {
        _validTabDests.add(i);
      }
    }

    _selHasMoves = _validTabDests.isNotEmpty || _validFndDests.isNotEmpty;
  }

  List<_Card> _getSelCards() {
    if (_selCol == -1) return _waste.isEmpty ? [] : [_waste.last];
    if (_selCol != null && _selCol! <= -2) {
      final fIdx = -2 - _selCol!;
      if (fIdx >= 0 && fIdx < 4 && _foundations[fIdx].isNotEmpty) return [_foundations[fIdx].last];
    }
    if (_selCol != null && _selCol! >= 0 && _selCol! < 7) {
      final col = _tableau[_selCol!];
      if (_selIdx >= 0 && _selIdx < col.length) return col.sublist(_selIdx);
    }
    return [];
  }

  void _moveSelTo({required int destCol}) {
    if (!_hasSel) return;
    final cards = _getSelCards();
    if (cards.isEmpty) { _clearSel(); return; }
    final first = cards.first;

    final destPile = _tableau[destCol];
    final canPlace = destPile.isEmpty
        ? first.rank == 13
        : destPile.last.faceUp && first.canStackOnTableau(destPile.last);
    if (!canPlace) {
      _triggerShake(col: _selCol == -1 ? destCol : _selCol!, idx: _selCol == -1 ? 0 : _selIdx);
      _clearSel();
      return;
    }

    Offset from;
    if (_selCol == -1) {
      from = _posOfKey(_wasteKey);
      _waste.removeLast();
    } else if (_selCol! <= -2) {
      final fIdx = -2 - _selCol!;
      from = _posOfKey(_foundationKeys[fIdx]);
      _foundations[fIdx].removeLast();
    } else {
      from = _posOfKey(_keyFor(first));
      _tableau[_selCol!].removeRange(_selIdx, _tableau[_selCol!].length);
    }
    final srcCol = _selCol;
    _selCol = null;
    _selIdx = -1;
    _validTabDests = {};
    _validFndDests = {};
    _selHasMoves = false;

    final to = destPile.isEmpty
        ? _posOfKey(_tableauColKeys[destCol])
        : _posOfKey(_keyFor(destPile.last));

    setState(() {});
    _flyCards(cards, from, to, () {
      _tableau[destCol].addAll(cards);
      if (srcCol != null && srcCol >= 0) _flipTopCard(srcCol);
      _countMove();
      AudioService().playTap();
      setState(() {});
    });
  }

  void _moveSelToFoundation(int fIdx) {
    if (!_hasSel) return;
    final cards = _getSelCards();
    if (cards.length != 1) { _clearSel(); return; }
    final card = cards.first;
    final top = _foundations[fIdx].isEmpty ? null : _foundations[fIdx].last;
    if (!card.canStackOnFoundation(top)) {
      _triggerShake(col: _selCol == -1 ? -1 : _selCol!, idx: _selIdx, waste: _selCol == -1);
      _clearSel();
      return;
    }

    Offset from;
    if (_selCol == -1) {
      from = _posOfKey(_wasteKey);
      _waste.removeLast();
    } else if (_selCol! <= -2) {
      _clearSel();
      return;
    } else {
      from = _posOfKey(_keyFor(card));
      _tableau[_selCol!].removeRange(_selIdx, _tableau[_selCol!].length);
    }
    final srcCol = _selCol;
    _selCol = null;
    _selIdx = -1;
    _validTabDests = {};
    _validFndDests = {};
    _selHasMoves = false;

    final to = _posOfKey(_foundationKeys[fIdx]);
    setState(() {});
    _flyCards([card], from, to, () {
      _foundations[fIdx].add(card);
      if (srcCol != null && srcCol >= 0) _flipTopCard(srcCol);
      _countMove();
      AudioService().playScore();
      _checkWin();
      setState(() {});
    });
  }

  void _autoMoveSelected() {
    final cards = _getSelCards();
    if (cards.isEmpty) { _clearSel(); return; }
    final first = cards.first;

    if (cards.length == 1) {
      for (int i = 0; i < 4; i++) {
        final top = _foundations[i].isEmpty ? null : _foundations[i].last;
        if (first.canStackOnFoundation(top)) {
          _moveSelToFoundation(i);
          return;
        }
      }
    }

    for (int i = 0; i < 7; i++) {
      if (_selCol == i) continue;
      final pile = _tableau[i];
      if (pile.isEmpty) {
        if (first.rank == 13) {
          if (_selCol != null && _selCol! >= 0 && _selIdx == 0) continue;
          _moveSelTo(destCol: i);
          return;
        }
      } else if (pile.last.faceUp && first.canStackOnTableau(pile.last)) {
        _moveSelTo(destCol: i);
        return;
      }
    }

    _triggerShake(col: _selCol == -1 ? -1 : _selCol!, idx: _selIdx, waste: _selCol == -1);
    _clearSel();
  }

  void _onWasteTap() {
    if (_gameOver || _flyingCards != null) return;
    if (_waste.isEmpty) { _clearSel(); return; }

    if (_selCol == -1) {
      _autoMoveSelected();
      return;
    }
    if (_hasSel) { _clearSel(); }

    _selCol = -1;
    _selIdx = 0;
    _computeValidDests();
    if (!_selHasMoves) {
      _triggerShake(waste: true);
      _selCol = null;
      _selIdx = -1;
      _validTabDests = {};
      _validFndDests = {};
      _selHasMoves = false;
      return;
    }
    if (_validTabDests.length + _validFndDests.length == 1) {
      _autoMoveSelected();
      return;
    }
    AudioService().playTap();
    setState(() {});
  }

  void _onTableauTap(int colIdx, int cardIdx) {
    if (_gameOver || _flyingCards != null) return;
    final col = _tableau[colIdx];
    if (cardIdx < 0 || cardIdx >= col.length) return;
    final card = col[cardIdx];
    if (!card.faceUp) return;

    if (_selCol == colIdx && _selIdx == cardIdx) {
      _autoMoveSelected();
      return;
    }

    if (_hasSel) {
      final selCards = _getSelCards();
      if (selCards.isNotEmpty) {
        final first = selCards.first;
        if (card.faceUp && first.canStackOnTableau(card) && cardIdx == col.length - 1) {
          _moveSelTo(destCol: colIdx);
          return;
        }
      }
      _clearSel();
    }

    _selCol = colIdx;
    _selIdx = cardIdx;
    _computeValidDests();
    if (!_selHasMoves) {
      _triggerShake(col: colIdx, idx: cardIdx);
      _selCol = null;
      _selIdx = -1;
      _validTabDests = {};
      _validFndDests = {};
      _selHasMoves = false;
      return;
    }
    if (_validTabDests.length + _validFndDests.length == 1) {
      _autoMoveSelected();
      return;
    }
    AudioService().playTap();
    setState(() {});
  }

  void _onEmptyTableauTap(int colIdx) {
    if (_gameOver || _flyingCards != null) return;
    if (_hasSel) {
      _moveSelTo(destCol: colIdx);
    }
  }

  void _onFoundationTap(int idx) {
    if (_gameOver || _flyingCards != null) return;
    if (_hasSel) {
      _moveSelToFoundation(idx);
      return;
    }
    if (_foundations[idx].isEmpty) return;
    _selCol = -2 - idx;
    _selIdx = 0;
    _computeValidDests();
    if (!_selHasMoves) {
      _triggerShake(col: -1, idx: 0);
      _selCol = null;
      _selIdx = -1;
      _validTabDests = {};
      _validFndDests = {};
      _selHasMoves = false;
      return;
    }
    if (_validTabDests.length + _validFndDests.length == 1) {
      _autoMoveSelected();
      return;
    }
    AudioService().playTap();
    setState(() {});
  }

  void _flipTopCard(int colIdx) {
    if (_tableau[colIdx].isNotEmpty && !_tableau[colIdx].last.faceUp) {
      _tableau[colIdx].last.faceUp = true;
    }
  }

  void _checkWin() {
    for (final f in _foundations) {
      if (f.length < 13) return;
    }
    _endGame(true);
  }

  void _onHint() {
    if (_gameOver) return;
    if (!AdsService().isRewardedReady) return;
    AudioService().playTap();
    bool earned = false;
    AdsService().showRewarded(
      rewardType: RewardType.hint,
      gameId: kSolitaireGameId,
      onRewarded: (_) => earned = true,
      onComplete: () {
        if (!earned || !mounted) return;
        _consecutiveShakes = 0;
        _idleStuck = false;
        _resetIdleTimer();
        _clearSel();
        for (int c = 0; c < 7; c++) {
          if (_tableau[c].isEmpty) continue;
          final card = _tableau[c].last;
          if (!card.faceUp) continue;
          for (int f = 0; f < 4; f++) {
            final top = _foundations[f].isEmpty ? null : _foundations[f].last;
            if (card.canStackOnFoundation(top)) {
              setState(() { _selCol = c; _selIdx = _tableau[c].length - 1; });
              _computeValidDests();
              setState(() {});
              return;
            }
          }
        }
        if (_waste.isNotEmpty) {
          final card = _waste.last;
          for (int f = 0; f < 4; f++) {
            final top = _foundations[f].isEmpty ? null : _foundations[f].last;
            if (card.canStackOnFoundation(top)) {
              setState(() { _selCol = -1; _selIdx = _waste.length - 1; });
              _computeValidDests();
              setState(() {});
              return;
            }
          }
          for (int d = 0; d < 7; d++) {
            if (_tableau[d].isEmpty) {
              if (card.rank == 13) {
                setState(() { _selCol = -1; _selIdx = _waste.length - 1; });
                _computeValidDests();
                setState(() {});
                return;
              }
            } else if (_tableau[d].last.faceUp && card.canStackOnTableau(_tableau[d].last)) {
              setState(() { _selCol = -1; _selIdx = _waste.length - 1; });
              _computeValidDests();
              setState(() {});
              return;
            }
          }
        }
        for (int s = 0; s < 7; s++) {
          if (_tableau[s].isEmpty) continue;
          int first = 0;
          for (int k = 0; k < _tableau[s].length; k++) {
            if (_tableau[s][k].faceUp) { first = k; break; }
          }
          final card = _tableau[s][first];
          for (int d = 0; d < 7; d++) {
            if (d == s) continue;
            if (_tableau[d].isEmpty) {
              if (card.rank == 13 && first > 0) {
                setState(() { _selCol = s; _selIdx = first; });
                _computeValidDests();
                setState(() {});
                return;
              }
            } else if (_tableau[d].last.faceUp && card.canStackOnTableau(_tableau[d].last)) {
              setState(() { _selCol = s; _selIdx = first; });
              _computeValidDests();
              setState(() {});
              return;
            }
          }
        }
        setState(() {});
      },
    );
  }

  void _endGame(bool won) {
    _gameOver = true;
    _won = won;
    _ticker?.cancel();
    _stopwatch.stop();
    _isNewBest = won && (_bestTime == 0 || _elapsedSeconds < _bestTime);
    if (_isNewBest) {
      _bestTime = _elapsedSeconds;
      ScoreService().saveScore(kSolitaireGameId, _elapsedSeconds, subKey: _activeDifficulty!.subKey);
    }
    GameWrapper.of(context).updateScore(_elapsedSeconds);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GameWrapper.of(context).endGame(result: won ? 'win' : 'loss');
    });
  }

  GlobalKey _keyFor(_Card c) => _cardKeys.putIfAbsent('${c.rank}_${c.suit.index}', () => GlobalKey());

  Offset _posOfKey(GlobalKey k) {
    final rb = k.currentContext?.findRenderObject() as RenderBox?;
    return rb?.localToGlobal(Offset.zero) ?? Offset.zero;
  }

  Offset _toLocal(Offset global) {
    final rb = _gameStackKey.currentContext?.findRenderObject() as RenderBox?;
    return rb?.globalToLocal(global) ?? global;
  }

  void _flyCards(List<_Card> cards, Offset from, Offset to, VoidCallback onDone) {
    _flyingCards = cards;
    _flyFrom = _toLocal(from);
    _flyTo = _toLocal(to);
    _flyCtrl?.dispose();
    _flyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _flyingCards = null;
          _flyCtrl?.dispose();
          _flyCtrl = null;
          onDone();
        }
      });
    setState(() {});
    _flyCtrl!.forward();
  }

  void _triggerShake({int col = -1, int idx = -1, bool waste = false}) {
    _consecutiveShakes++;
    _resetIdleTimer();
    _shakeCol = col;
    _shakeIdx = idx;
    _shakeWaste = waste;
    _shakeCtrl?.dispose();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _shakeCol = -1;
          _shakeIdx = -1;
          _shakeWaste = false;
          if (mounted) setState(() {});
        }
      })
      ..forward();
    setState(() {});
  }

  Widget _wrapShake(Widget child, bool shaking) {
    if (!shaking || _shakeCtrl == null) return child;
    return AnimatedBuilder(
      animation: _shakeCtrl!,
      builder: (_, ch) {
        final t = _shakeCtrl!.value;
        final dx = math.sin(t * math.pi * 4) * 6 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: ch);
      },
      child: child,
    );
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
      bestScore: ScoreService().getHighScore(kSolitaireGameId, subKey: d.subKey),
      bestLabel: (s) => s > 0 ? 'Best: ${_formatTime(s)}' : '',
    )).toList();

    return GamePickerScaffold(
      bgColorTop: _kBgTop,
      bgColorBottom: _kBgBottom,
      animatedBg: AnimatedBackground(
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.style_rounded),
      ),
      iconRingColors: const [_kAccent, Color(0xFF81C784), Color(0xFF2E7D32)],
      iconChild: buildSolitaireLogo(60),
      title: 'Solitaire',
      subtitle: 'Classic Klondike — stack aces to kings!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kSolitaireGameId,
      body: GameSinglePickerBody(
        difficulties: difficulties,
        activeIndex: _pickerDifficulty.index,
        onChanged: (i) => setState(() => _pickerDifficulty = _Difficulty.values[i]),
        playLabel: 'Play Solitaire',
        playSubLabel: 'Deal the cards!',
        onPlay: () => _startGame(_pickerDifficulty),
        accentColor: _kAccent,
      ),
    );
  }

  Widget _buildGame() {
    final diff = _activeDifficulty!;
    return Stack(
      key: _gameStackKey,
      children: [
        Container(
          color: _kFelt,
          child: SafeArea(
            child: Column(
              children: [
                GameHudBar(
                  leading: GameBackButton(
                    onTap: _backOrHome,
                    bgColor: Colors.white.withValues(alpha: 0.15),
                    iconColor: Colors.white,
                  ),
                  centerContent: _buildScorePill(diff),
                  trailing: GameRestartButton(
                    gameName: 'Solitaire',
                    accentColor: diff.color,
                    onRestart: _newGame,
                    bgColor: Colors.white.withValues(alpha: 0.15),
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
                _buildTopRow(),
                const SizedBox(height: 6),
                Expanded(child: _buildTableau()),
                Opacity(
                  opacity: AdsService().isRewardedReady ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !AdsService().isRewardedReady,
                    child: _SolitaireHintNudge(onTap: _onHint, isStuck: _isStuck),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_flyingCards != null && _flyCtrl != null)
          AnimatedBuilder(
            animation: _flyCtrl!,
            builder: (_, __) {
              final t = Curves.easeOutCubic.transform(_flyCtrl!.value);
              final pos = Offset.lerp(_flyFrom, _flyTo, t)!;
              final cw = _cardWidth;
              final ch = _cardHeight;
              final cards = _flyingCards!;
              final overlap = ch * 0.28;
              return Positioned(
                left: pos.dx,
                top: pos.dy,
                child: IgnorePointer(
                  child: SizedBox(
                    width: cw,
                    height: ch + (cards.length - 1) * overlap,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(cards.length, (i) => Positioned(
                        top: i * overlap,
                        child: _buildCardWidget(cards[i], cw, ch),
                      )),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildScorePill(_Difficulty diff) {
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
              _statCol('TIME', _formatTime(_elapsedSeconds), color),
              _pillDivider(),
              _statCol('MOVES', '$_moves', const Color(0xFF6B7280)),
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
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900, height: 1)),
        ],
      ),
    );
  }

  Widget _pillDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
    );
  }

  Widget _buildTopRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _buildStockPile(),
          const SizedBox(width: 4),
          _buildWastePile(),
          const Spacer(),
          ..._buildFoundations(),
        ],
      ),
    );
  }

  double get _cardWidth {
    final w = MediaQuery.sizeOf(context).width;
    return ((w - 24) / 7).clamp(36.0, 56.0);
  }

  double get _cardHeight => _cardWidth * 1.45;

  Widget _buildStockPile() {
    final cw = _cardWidth;
    final ch = _cardHeight;
    return GestureDetector(
      onTap: _drawFromStock,
      child: Container(
        width: cw,
        height: ch,
        decoration: BoxDecoration(
          color: _stock.isEmpty
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(cw * 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: _stock.isEmpty
            ? Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.4), size: cw * 0.4)
            : Center(
                child: Text(
                  '${_stock.length}',
                  style: TextStyle(color: Colors.white, fontSize: cw * 0.35, fontWeight: FontWeight.w800),
                ),
              ),
      ),
    );
  }

  Widget _buildWastePile() {
    final cw = _cardWidth;
    final ch = _cardHeight;
    if (_waste.isEmpty) {
      return Container(
        key: _wasteKey,
        width: cw,
        height: ch,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(cw * 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      );
    }
    final card = _waste.last;
    final wasteSelected = _selCol == -1;
    Widget child = _buildCardWidget(card, cw, ch, selected: wasteSelected);

    if (_drawSlideCtrl != null && _drawSlideCtrl!.isAnimating) {
      child = SlideTransition(
        position: Tween<Offset>(begin: const Offset(-1.5, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: _drawSlideCtrl!, curve: Curves.easeOutCubic)),
        child: child,
      );
    }

    child = _wrapShake(child, _shakeWaste);

    return GestureDetector(
      key: _wasteKey,
      onTap: _onWasteTap,
      child: child,
    );
  }

  List<Widget> _buildFoundations() {
    final cw = _cardWidth;
    final ch = _cardHeight;
    return List.generate(4, (i) {
      final pile = _foundations[i];
      const suits = ['♠', '♥', '♦', '♣'];
      final isValidDest = _validFndDests.contains(i);
      return Padding(
        padding: const EdgeInsets.only(left: 3),
        child: GestureDetector(
          key: _foundationKeys[i],
          onTap: () => _onFoundationTap(i),
          child: pile.isEmpty
              ? Container(
                  width: cw,
                  height: ch,
                  decoration: BoxDecoration(
                    color: isValidDest ? _kAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(cw * 0.12),
                    border: Border.all(
                      color: isValidDest ? _kAccent : Colors.white.withValues(alpha: 0.15),
                      width: isValidDest ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      suits[i],
                      style: TextStyle(color: isValidDest ? _kAccent : Colors.white.withValues(alpha: 0.2), fontSize: cw * 0.4),
                    ),
                  ),
                )
              : _buildCardWidget(pile.last, cw, ch, validDest: isValidDest),
        ),
      );
    });
  }

  Widget _buildTableau() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = _cardWidth;
        final ch = _cardHeight;
        final availH = constraints.maxHeight;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(7, (colIdx) {
              final col = _tableau[colIdx];
              final overlap = col.length > 1
                  ? math.min(ch * 0.28, (availH - ch) / math.max(1, col.length - 1))
                  : ch * 0.28;

              final isValidDest = _validTabDests.contains(colIdx);
              return Expanded(
                child: Padding(
                  key: _tableauColKeys[colIdx],
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: col.isEmpty
                      ? GestureDetector(
                          onTap: () => _onEmptyTableauTap(colIdx),
                          child: Container(
                            height: ch,
                            decoration: BoxDecoration(
                              color: isValidDest ? _kAccent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(cw * 0.12),
                              border: Border.all(
                                color: isValidDest ? _kAccent : Colors.white.withValues(alpha: 0.08),
                                width: isValidDest ? 2 : 1,
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: ch + overlap * (col.length - 1),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: List.generate(col.length, (cardIdx) {
                              final card = col[cardIdx];
                              final isShaking = _shakeCol == colIdx && _shakeIdx == cardIdx;
                              final isSelected = _selCol == colIdx && _selIdx <= cardIdx && card.faceUp;
                              final isLastCard = cardIdx == col.length - 1;
                              Widget cardW = card.faceUp
                                  ? _buildCardWidget(card, cw, ch, selected: isSelected, validDest: isLastCard && isValidDest && !isSelected)
                                  : _buildCardBack(cw, ch);
                              cardW = _wrapShake(cardW, isShaking);
                              return Positioned(
                                top: cardIdx * overlap + (isSelected ? -4 : 0),
                                left: 0,
                                right: 0,
                                child: GestureDetector(
                                  key: card.faceUp ? _keyFor(card) : null,
                                  onTap: () => _onTableauTap(colIdx, cardIdx),
                                  child: cardW,
                                ),
                              );
                            }),
                          ),
                        ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildCardWidget(_Card card, double w, double h, {bool selected = false, bool validDest = false}) {
    final highlight = selected || validDest;
    final hColor = selected ? _kAccent : const Color(0xFF22C55E);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(w * 0.12),
        border: highlight ? Border.all(color: hColor, width: 2.5) : null,
        boxShadow: [
          BoxShadow(
            color: highlight ? hColor.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.18),
            blurRadius: highlight ? 10 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 3,
            left: 4,
            child: Text(
              card.rankLabel,
              style: TextStyle(
                color: card.displayColor,
                fontSize: w * 0.28,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          Positioned(
            top: w * 0.28 + 1,
            left: 4,
            child: Text(
              card.suit.symbol,
              style: TextStyle(color: card.displayColor, fontSize: w * 0.22, height: 1),
            ),
          ),
          Center(
            child: Text(
              card.suit.symbol,
              style: TextStyle(color: card.displayColor.withValues(alpha: 0.25), fontSize: w * 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(w * 0.12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: w * 0.6,
          height: h * 0.7,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
            borderRadius: BorderRadius.circular(w * 0.08),
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildResult() {
    final diff = _activeDifficulty!;
    return game_result.GenericGameResultScreen(
      headline: _won ? 'You Won!' : 'Game Over',
      subtitle: _won ? 'Completed in ${_formatTime(_elapsedSeconds)}' : '$_moves moves · ${_formatTime(_elapsedSeconds)}',
      badgeContent: _won ? '🃏' : '😔',
      badgeColor: diff.color,
      showNewBestBadge: _isNewBest,
      gameId: kSolitaireGameId,
      score: _elapsedSeconds,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: 'TIME', value: _elapsedSeconds, displayValue: _formatTime(_elapsedSeconds), color: diff.color),
          game_result.StatItem(label: 'MOVES', value: _moves, color: const Color(0xFF6B7280)),
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

class _SolitaireHintNudge extends StatefulWidget {
  final VoidCallback onTap;
  final bool isStuck;
  const _SolitaireHintNudge({required this.onTap, required this.isStuck});
  @override
  State<_SolitaireHintNudge> createState() => _SolitaireHintNudgeState();
}

class _SolitaireHintNudgeState extends State<_SolitaireHintNudge> with TickerProviderStateMixin {
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
  void didUpdateWidget(_SolitaireHintNudge old) {
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
                          painter: _SolitaireBubbleTailPainter(),
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

class _SolitaireBubbleTailPainter extends CustomPainter {
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
