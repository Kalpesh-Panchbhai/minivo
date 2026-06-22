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
import '../shared/generic_game_result_screen.dart' as game_result;
import '../shared/rewarded_undo_button.dart';
import 'chess_stats.dart';
import 'chess_tutorial.dart';

const Color _kBlackPiece = Color(0xFF2D3436);
const Color _kDrawColor = Color(0xFFB6A5DD);
const Color _kAccent = Color(0xFFD4AF37);
const Color _kBgTop = Color(0xFFFAF8F5);
const Color _kBgBot = Color(0xFFF0EDE8);
const Color _kBoardLight = Color(0xFFF0D9B5);
const Color _kBoardDark = Color(0xFFB58863);
const Color _kEasyColor = Color(0xFF22C55E);
const Color _kMediumColor = Color(0xFFF59E0B);
const Color _kHardColor = Color(0xFFEF4444);

const Color _kTintWhiteTop = Color(0xFFFFFAF0);
const Color _kTintWhiteBot = Color(0xFFF5EDE0);
const Color _kTintBlackTop = Color(0xFFF0EDED);
const Color _kTintBlackBot = Color(0xFFE8E4E4);

enum _Mode { ai, twoPlayer }
enum _Difficulty { easy, medium, hard }

const _kPieceChars = <int, String>{
  1: '♔', 2: '♕', 3: '♖', 4: '♗', 5: '♘', 6: '♙',
  -1: '♚', -2: '♛', -3: '♜', -4: '♝', -5: '♞', -6: '♟',
};

const _kPieceValues = <int, int>{
  1: 20000, 2: 900, 3: 500, 4: 330, 5: 320, 6: 100,
};

const _kPST = <int, List<int>>{
  6: [
     0,  0,  0,  0,  0,  0,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
     5,  5, 10, 25, 25, 10,  5,  5,
     0,  0,  0, 20, 20,  0,  0,  0,
     5, -5,-10,  0,  0,-10, -5,  5,
     5, 10, 10,-20,-20, 10, 10,  5,
     0,  0,  0,  0,  0,  0,  0,  0,
  ],
  5: [
   -50,-40,-30,-30,-30,-30,-40,-50,
   -40,-20,  0,  0,  0,  0,-20,-40,
   -30,  0, 10, 15, 15, 10,  0,-30,
   -30,  5, 15, 20, 20, 15,  5,-30,
   -30,  0, 15, 20, 20, 15,  0,-30,
   -30,  5, 10, 15, 15, 10,  5,-30,
   -40,-20,  0,  5,  5,  0,-20,-40,
   -50,-40,-30,-30,-30,-30,-40,-50,
  ],
  4: [
   -20,-10,-10,-10,-10,-10,-10,-20,
   -10,  0,  0,  0,  0,  0,  0,-10,
   -10,  0,  5, 10, 10,  5,  0,-10,
   -10,  5,  5, 10, 10,  5,  5,-10,
   -10,  0, 10, 10, 10, 10,  0,-10,
   -10, 10, 10, 10, 10, 10, 10,-10,
   -10,  5,  0,  0,  0,  0,  5,-10,
   -20,-10,-10,-10,-10,-10,-10,-20,
  ],
  3: [
     0,  0,  0,  0,  0,  0,  0,  0,
     5, 10, 10, 10, 10, 10, 10,  5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
     0,  0,  0,  5,  5,  0,  0,  0,
  ],
  2: [
   -20,-10,-10, -5, -5,-10,-10,-20,
   -10,  0,  0,  0,  0,  0,  0,-10,
   -10,  0,  5,  5,  5,  5,  0,-10,
    -5,  0,  5,  5,  5,  5,  0, -5,
     0,  0,  5,  5,  5,  5,  0, -5,
   -10,  5,  5,  5,  5,  5,  0,-10,
   -10,  0,  5,  0,  0,  0,  0,-10,
   -20,-10,-10, -5, -5,-10,-10,-20,
  ],
  1: [
   -30,-40,-40,-50,-50,-40,-40,-30,
   -30,-40,-40,-50,-50,-40,-40,-30,
   -30,-40,-40,-50,-50,-40,-40,-30,
   -30,-40,-40,-50,-50,-40,-40,-30,
   -20,-30,-30,-40,-40,-30,-30,-20,
   -10,-20,-20,-20,-20,-20,-20,-10,
    20, 20,  0,  0,  0,  0, 20, 20,
    20, 30, 10,  0,  0, 10, 30, 20,
  ],
};

const _kOpeningBook = <String, List<List<int>>>{
  'initial': [[52, 36], [52, 44], [50, 34], [62, 45]],
};

class _PieceId {
  final int uid;
  final int type;
  int sq;
  _PieceId(this.uid, this.type, this.sq);
}

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});
  @override
  State<ChessScreen> createState() => ChessScreenState();
}

class ChessScreenState extends State<ChessScreen>
    with TickerProviderStateMixin {
  _Mode? _mode;
  _Difficulty _difficulty = _Difficulty.values[DifficultyKind.defaultIndex];

  List<int> _board = List.filled(64, 0);
  int _turn = 1;
  bool _gameOver = false;
  int? _winner;
  bool _aiThinking = false;
  int? _selectedCell;
  List<int> _validMoves = [];
  bool _inCheck = false;
  int _streak = 0;
  String? _streakOwner;
  bool _showStreakBadge = false;
  int _whiteWins = 0;
  int _blackWins = 0;
  int _draws = 0;
  bool _wasNewBest = false;
  bool _isFavorite = false;
  bool _firstRoundOfSession = true;
  String _starter = 'white';
  bool _celebrating = false;
  String? _bannerLabel;
  Color _bannerColor = _kDrawColor;
  bool _showWinBanner = false;
  int? _lastMoveFrom;
  int? _lastMoveTo;
  List<int> _whiteCaptured = [];
  List<int> _blackCaptured = [];
  List<_PieceId> _pieceIds = [];
  int _nextUid = 0;
  int _moveCount = 0;

  int _undosUsed = 0;
  static const _kMaxUndos = 2;
  bool _inUndoWindow = false;
  List<int>? _boardBeforeHumanMove;
  List<int>? _stateBeforeHumanMove;

  bool _whiteKingMoved = false;
  bool _blackKingMoved = false;
  bool _whiteRookAMoved = false;
  bool _whiteRookHMoved = false;
  bool _blackRookAMoved = false;
  bool _blackRookHMoved = false;
  int? _enPassantTarget;
  int _halfMoveClock = 0;
  List<String> _positionHistory = [];

  final _rng = math.Random();
  final _audio = AudioService();
  Timer? _aiMoveTimer;
  Timer? _endGameTimer;
  AnimationController? _checkPulseCtrl;

  @override
  void initState() {
    super.initState();
    _isFavorite = ScoreService().isFavorite(kChessGameId);
    _checkPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _aiMoveTimer?.cancel();
    _endGameTimer?.cancel();
    _checkPulseCtrl?.stop();
    _checkPulseCtrl?.dispose();
    super.dispose();
  }

  GameWrapperState get _wrapper => GameWrapper.of(context);

  void _initBoard() {
    _board = List.filled(64, 0);
    const backRank = [3, 5, 4, 2, 1, 4, 5, 3];
    for (int c = 0; c < 8; c++) {
      _board[c] = -backRank[c];
      _board[8 + c] = -6;
      _board[48 + c] = 6;
      _board[56 + c] = backRank[c];
    }
    _whiteKingMoved = false;
    _blackKingMoved = false;
    _whiteRookAMoved = false;
    _whiteRookHMoved = false;
    _blackRookAMoved = false;
    _blackRookHMoved = false;
    _enPassantTarget = null;
    _halfMoveClock = 0;
    _positionHistory = [_boardKey()];
    _whiteCaptured = [];
    _blackCaptured = [];
    _lastMoveFrom = null;
    _lastMoveTo = null;
    _inCheck = false;
    _nextUid = 0;
    _pieceIds = [];
    _moveCount = 0;
    for (int i = 0; i < 64; i++) {
      if (_board[i] != 0) {
        _pieceIds.add(_PieceId(_nextUid++, _board[i], i));
      }
    }
  }

  String _boardKey() {
    final sb = StringBuffer();
    for (int i = 0; i < 64; i++) {
      sb.write('${_board[i]},');
    }
    sb.write('$_turn,$_whiteKingMoved,$_blackKingMoved,$_whiteRookAMoved,$_whiteRookHMoved,$_blackRookAMoved,$_blackRookHMoved,$_enPassantTarget');
    return sb.toString();
  }

  void _selectMode(_Mode mode) {
    setState(() {
      _mode = mode;
      _whiteWins = 0;
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
      _whiteWins = 0;
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
        _starter = 'white';
        _firstRoundOfSession = false;
      } else {
        _starter = _starter == 'white' ? 'black' : 'white';
      }
      _turn = _starter == 'white' ? 1 : -1;
      _gameOver = false;
      _winner = null;
      _aiThinking = false;
      _selectedCell = null;
      _validMoves = [];
      _wasNewBest = false;
      _showStreakBadge = false;
      _celebrating = false;
      _showWinBanner = false;
      _bannerLabel = null;
      _undosUsed = 0;
      _inUndoWindow = false;
      _boardBeforeHumanMove = null;
      _stateBeforeHumanMove = null;
    });
    _checkPulseCtrl?.stop();
    _checkPulseCtrl?.reset();
    if (_mode == _Mode.ai && _turn == -1) {
      _scheduleAiMove();
    }
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
      ScoreService().toggleFavorite(kChessGameId);
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
    final game = GameRegistry.getById(kChessGameId);
    if (game == null) return;
    showHowToPlaySheet(
      context,
      title: game.name,
      howToPlay: game.howToPlay,
      accent: _kAccent,
      steps: chessSteps(),
      gameId: kChessGameId,
    );
  }

  bool get _canUndo => _inUndoWindow && !_gameOver;

  void _onUndoExpired() {
    if (!mounted || _gameOver || !_inUndoWindow) return;
    setState(() => _inUndoWindow = false);
    _scheduleAiMove();
  }

  void _performUndo() {
    final saved = _boardBeforeHumanMove;
    final state = _stateBeforeHumanMove;
    if (saved == null || state == null) return;
    setState(() {
      _board = List.from(saved);
      _whiteKingMoved = state[0] == 1;
      _blackKingMoved = state[1] == 1;
      _whiteRookAMoved = state[2] == 1;
      _whiteRookHMoved = state[3] == 1;
      _blackRookAMoved = state[4] == 1;
      _blackRookHMoved = state[5] == 1;
      _enPassantTarget = state[6] == -1 ? null : state[6];
      _halfMoveClock = state[7];
      _turn = 1;
      _inUndoWindow = false;
      _undosUsed++;
      _boardBeforeHumanMove = null;
      _stateBeforeHumanMove = null;
      _selectedCell = null;
      _validMoves = [];
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _inCheck = _isInCheck(1);
      _whiteCaptured = List.from(state.sublist(8, 8 + state[8 + state.length - 9]));
      _blackCaptured = [];
    });
  }

  void _saveStateForUndo() {
    if (_mode != _Mode.ai || _undosUsed >= _kMaxUndos || _turn != 1) return;
    _boardBeforeHumanMove = List.from(_board);
    _stateBeforeHumanMove = [
      _whiteKingMoved ? 1 : 0,
      _blackKingMoved ? 1 : 0,
      _whiteRookAMoved ? 1 : 0,
      _whiteRookHMoved ? 1 : 0,
      _blackRookAMoved ? 1 : 0,
      _blackRookHMoved ? 1 : 0,
      _enPassantTarget ?? -1,
      _halfMoveClock,
      ..._whiteCaptured,
      _whiteCaptured.length,
    ];
  }

  bool _isOwnPiece(int sq, int side) {
    if (side == 1) return _board[sq] > 0;
    return _board[sq] < 0;
  }

  int _findKing(int side) {
    final k = side == 1 ? 1 : -1;
    for (int i = 0; i < 64; i++) {
      if (_board[i] == k) return i;
    }
    return -1;
  }

  bool _isInCheck(int side) {
    final kingSq = _findKing(side);
    if (kingSq < 0) return true;
    return _isAttackedBy(-side, kingSq);
  }

  bool _isAttackedBy(int attacker, int sq) {
    for (int i = 0; i < 64; i++) {
      if (!_isOwnPiece(i, attacker)) continue;
      final piece = _board[i].abs();
      if (_canPieceAttack(i, sq, piece, attacker)) return true;
    }
    return false;
  }

  bool _canPieceAttack(int from, int to, int pieceType, int side) {
    final fr = from ~/ 8, fc = from % 8;
    final tr = to ~/ 8, tc = to % 8;
    final dr = tr - fr, dc = tc - fc;

    switch (pieceType) {
      case 6:
        final dir = side == 1 ? -1 : 1;
        return dr == dir && dc.abs() == 1;
      case 5:
        return (dr.abs() == 2 && dc.abs() == 1) || (dr.abs() == 1 && dc.abs() == 2);
      case 4:
        if (dr.abs() != dc.abs() || dr == 0) return false;
        return _pathClear(from, to);
      case 3:
        if (dr != 0 && dc != 0) return false;
        return _pathClear(from, to);
      case 2:
        if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return false;
        return _pathClear(from, to);
      case 1:
        return dr.abs() <= 1 && dc.abs() <= 1;
    }
    return false;
  }

  bool _pathClear(int from, int to) {
    final fr = from ~/ 8, fc = from % 8;
    final tr = to ~/ 8, tc = to % 8;
    final dr = (tr - fr).sign, dc = (tc - fc).sign;
    int r = fr + dr, c = fc + dc;
    while (r != tr || c != tc) {
      if (_board[r * 8 + c] != 0) return false;
      r += dr;
      c += dc;
    }
    return true;
  }

  List<int> _legalMoves(int sq) {
    if (_board[sq] == 0) return [];
    final side = _board[sq] > 0 ? 1 : -1;
    final piece = _board[sq].abs();
    final moves = <int>[];
    final pseudo = _pseudoMoves(sq, piece, side);
    for (final to in pseudo) {
      if (_tryMove(sq, to, side)) moves.add(to);
    }
    if (piece == 1) {
      for (final castle in _castleMoves(side)) {
        if (_tryMove(sq, castle, side)) moves.add(castle);
      }
    }
    return moves;
  }

  List<int> _pseudoMoves(int sq, int piece, int side) {
    final r = sq ~/ 8, c = sq % 8;
    final moves = <int>[];

    switch (piece) {
      case 6:
        final dir = side == 1 ? -1 : 1;
        final fwd = r + dir;
        if (fwd >= 0 && fwd < 8 && _board[fwd * 8 + c] == 0) {
          moves.add(fwd * 8 + c);
          final startRow = side == 1 ? 6 : 1;
          if (r == startRow) {
            final fwd2 = r + dir * 2;
            if (_board[fwd2 * 8 + c] == 0) moves.add(fwd2 * 8 + c);
          }
        }
        for (final dc in [-1, 1]) {
          final nc = c + dc;
          if (nc < 0 || nc > 7) continue;
          final target = fwd * 8 + nc;
          if (fwd >= 0 && fwd < 8) {
            if (_board[target] != 0 && !_isOwnPiece(target, side)) {
              moves.add(target);
            }
            if (target == _enPassantTarget) {
              moves.add(target);
            }
          }
        }
      case 5:
        for (final d in [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]]) {
          final nr = r + d[0], nc = c + d[1];
          if (nr < 0 || nr > 7 || nc < 0 || nc > 7) continue;
          final to = nr * 8 + nc;
          if (!_isOwnPiece(to, side)) moves.add(to);
        }
      case 4:
        for (final d in [[-1, -1], [-1, 1], [1, -1], [1, 1]]) {
          _addSlidingMoves(r, c, d[0], d[1], side, moves);
        }
      case 3:
        for (final d in [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          _addSlidingMoves(r, c, d[0], d[1], side, moves);
        }
      case 2:
        for (final d in [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]) {
          _addSlidingMoves(r, c, d[0], d[1], side, moves);
        }
      case 1:
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr, nc = c + dc;
            if (nr < 0 || nr > 7 || nc < 0 || nc > 7) continue;
            final to = nr * 8 + nc;
            if (!_isOwnPiece(to, side)) moves.add(to);
          }
        }
    }
    return moves;
  }

  void _addSlidingMoves(int r, int c, int dr, int dc, int side, List<int> moves) {
    int nr = r + dr, nc = c + dc;
    while (nr >= 0 && nr < 8 && nc >= 0 && nc < 8) {
      final to = nr * 8 + nc;
      if (_isOwnPiece(to, side)) break;
      moves.add(to);
      if (_board[to] != 0) break;
      nr += dr;
      nc += dc;
    }
  }

  List<int> _castleMoves(int side) {
    final moves = <int>[];
    if (side == 1) {
      if (!_whiteKingMoved && !_whiteRookHMoved && _board[61] == 0 && _board[62] == 0 && _board[63] == 3) {
        if (!_isAttackedBy(-1, 60) && !_isAttackedBy(-1, 61) && !_isAttackedBy(-1, 62)) {
          moves.add(62);
        }
      }
      if (!_whiteKingMoved && !_whiteRookAMoved && _board[59] == 0 && _board[58] == 0 && _board[57] == 0 && _board[56] == 3) {
        if (!_isAttackedBy(-1, 60) && !_isAttackedBy(-1, 59) && !_isAttackedBy(-1, 58)) {
          moves.add(58);
        }
      }
    } else {
      if (!_blackKingMoved && !_blackRookHMoved && _board[5] == 0 && _board[6] == 0 && _board[7] == -3) {
        if (!_isAttackedBy(1, 4) && !_isAttackedBy(1, 5) && !_isAttackedBy(1, 6)) {
          moves.add(6);
        }
      }
      if (!_blackKingMoved && !_blackRookAMoved && _board[3] == 0 && _board[2] == 0 && _board[1] == 0 && _board[0] == -3) {
        if (!_isAttackedBy(1, 4) && !_isAttackedBy(1, 3) && !_isAttackedBy(1, 2)) {
          moves.add(2);
        }
      }
    }
    return moves;
  }

  bool _tryMove(int from, int to, int side) {
    final saved = List<int>.from(_board);
    final savedEP = _enPassantTarget;
    _applyMoveRaw(from, to);
    final legal = !_isInCheck(side);
    _board = saved;
    _enPassantTarget = savedEP;
    return legal;
  }

  void _applyMoveRaw(int from, int to) {
    final piece = _board[from];
    final pieceType = piece.abs();
    final side = piece > 0 ? 1 : -1;

    if (pieceType == 6 && to == _enPassantTarget) {
      final capturedPawnSq = to + (side == 1 ? 8 : -8);
      _board[capturedPawnSq] = 0;
    }

    _board[to] = piece;
    _board[from] = 0;

    if (pieceType == 1) {
      final kingSq = side == 1 ? 60 : 4;
      if (from == kingSq && (to - from).abs() == 2) {
        if (to > from) {
          _board[to - 1] = _board[to + 1];
          _board[to + 1] = 0;
        } else {
          _board[to + 1] = _board[to - 2];
          _board[to - 2] = 0;
        }
      }
    }

    if (pieceType == 6) {
      final promoRow = side == 1 ? 0 : 7;
      if (to ~/ 8 == promoRow) {
        _board[to] = side * 2;
      }
    }

    _enPassantTarget = null;
    if (pieceType == 6 && (from - to).abs() == 16) {
      _enPassantTarget = (from + to) ~/ 2;
    }
  }

  void _onCellTap(int pos) {
    if (_gameOver || _aiThinking || _inUndoWindow) return;
    if (_mode == _Mode.ai && _turn == -1) return;

    if (_selectedCell != null && _validMoves.contains(pos)) {
      _saveStateForUndo();
      _executeMove(_selectedCell!, pos, isHumanInitiated: _turn == 1);
      return;
    }

    if (_isOwnPiece(pos, _turn)) {
      final moves = _legalMoves(pos);
      setState(() {
        _selectedCell = pos;
        _validMoves = moves;
      });
      _audio.playTap();
      return;
    }

    setState(() {
      _selectedCell = null;
      _validMoves = [];
    });
  }

  void _executeMove(int from, int to, {bool isHumanInitiated = false}) {
    final captured = _board[to];
    final piece = _board[from];
    final pieceType = piece.abs();
    final side = piece > 0 ? 1 : -1;

    final isPawnMove = pieceType == 6;
    final isCapture = captured != 0 || (pieceType == 6 && to == _enPassantTarget);

    if (isCapture) {
      int actualCaptured = captured;
      int captureSq = to;
      if (captured == 0 && pieceType == 6 && to == _enPassantTarget) {
        captureSq = to + (side == 1 ? 8 : -8);
        actualCaptured = _board[captureSq];
      }
      if (actualCaptured > 0) {
        _blackCaptured.add(actualCaptured);
      } else if (actualCaptured < 0) {
        _whiteCaptured.add(actualCaptured.abs());
      }
      _pieceIds.removeWhere((p) => p.sq == captureSq);
    }

    final movingPiece = _pieceIds.firstWhere((p) => p.sq == from, orElse: () => _PieceId(-1, 0, -1));

    _applyMoveRaw(from, to);

    if (movingPiece.uid >= 0) {
      movingPiece.sq = to;
      final newType = _board[to];
      if (newType != movingPiece.type) {
        _pieceIds.remove(movingPiece);
        _pieceIds.add(_PieceId(movingPiece.uid, newType, to));
      }
    }

    if (pieceType == 1 && (to - from).abs() == 2) {
      if (to > from) {
        final rookPiece = _pieceIds.where((p) => p.sq == to + 1).toList();
        if (rookPiece.isEmpty) {
          final old = _pieceIds.where((p) => p.sq == from + 3).toList();
          for (final r in old) {
            r.sq = to - 1;
          }
        } else {
          for (final r in rookPiece) {
            r.sq = to - 1;
          }
        }
      } else {
        final rookPiece = _pieceIds.where((p) => p.sq == to - 2).toList();
        if (rookPiece.isEmpty) {
          final old = _pieceIds.where((p) => p.sq == from - 4).toList();
          for (final r in old) {
            r.sq = to + 1;
          }
        } else {
          for (final r in rookPiece) {
            r.sq = to + 1;
          }
        }
      }
    }

    if (from == 60 || to == 60) _whiteKingMoved = true;
    if (from == 4 || to == 4) _blackKingMoved = true;
    if (from == 56 || to == 56) _whiteRookAMoved = true;
    if (from == 63 || to == 63) _whiteRookHMoved = true;
    if (from == 0 || to == 0) _blackRookAMoved = true;
    if (from == 7 || to == 7) _blackRookHMoved = true;

    if (isPawnMove || isCapture) {
      _halfMoveClock = 0;
    } else {
      _halfMoveClock++;
    }

    _moveCount++;

    setState(() {
      _selectedCell = null;
      _validMoves = [];
      _lastMoveFrom = from;
      _lastMoveTo = to;
    });

    if (isCapture) {
      _audio.playScore();
    } else {
      _audio.playTap();
    }

    _turn = -_turn;
    _positionHistory.add(_boardKey());
    _inCheck = _isInCheck(_turn);

    if (_inCheck) {
      _checkPulseCtrl?.repeat(reverse: true);
    } else {
      _checkPulseCtrl?.stop();
      _checkPulseCtrl?.reset();
    }

    if (_checkGameEnd()) return;
    if (isHumanInitiated && _mode == _Mode.ai) {
      final undoAvail = _undosUsed < _kMaxUndos && AdsService().isRewardedReady;
      if (undoAvail) {
        setState(() => _inUndoWindow = true);
        return;
      }
    }
    if (_mode == _Mode.ai && _turn == -1 && !_gameOver) {
      _scheduleAiMove();
    } else {
      setState(() {});
    }
  }

  bool _checkGameEnd() {
    bool hasLegal = false;
    for (int i = 0; i < 64; i++) {
      if (_isOwnPiece(i, _turn) && _legalMoves(i).isNotEmpty) {
        hasLegal = true;
        break;
      }
    }

    if (!hasLegal) {
      if (_inCheck) {
        _onWin(-_turn);
      } else {
        _onDraw('Stalemate');
      }
      return true;
    }

    if (_halfMoveClock >= 100) {
      _onDraw('50-move rule');
      return true;
    }

    final key = _boardKey();
    int reps = 0;
    for (final k in _positionHistory) {
      if (k == key) reps++;
    }
    if (reps >= 3) {
      _onDraw('Threefold repetition');
      return true;
    }

    if (_isInsufficientMaterial()) {
      _onDraw('Insufficient material');
      return true;
    }

    return false;
  }

  bool _isInsufficientMaterial() {
    final pieces = <int>[];
    for (int i = 0; i < 64; i++) {
      if (_board[i] != 0) pieces.add(_board[i]);
    }
    if (pieces.length == 2) return true;
    if (pieces.length == 3) {
      for (final p in pieces) {
        if (p.abs() == 4 || p.abs() == 5) return true;
      }
    }
    if (pieces.length == 4) {
      final bishops = pieces.where((p) => p.abs() == 4).toList();
      if (bishops.length == 2 && bishops[0] > 0 != bishops[1] > 0) {
        int sq0 = -1, sq1 = -1;
        for (int i = 0; i < 64; i++) {
          if (_board[i].abs() == 4) {
            if (sq0 < 0) {
              sq0 = i;
            } else {
              sq1 = i;
            }
          }
        }
        if (sq0 >= 0 && sq1 >= 0) {
          final color0 = (sq0 ~/ 8 + sq0 % 8) % 2;
          final color1 = (sq1 ~/ 8 + sq1 % 8) % 2;
          if (color0 == color1) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _onWin(int winner) {
    final isAi = _mode == _Mode.ai;
    final winnerLabel = winner == 1 ? 'white' : 'black';
    setState(() {
      _gameOver = true;
      _winner = winner;
      _showWinBanner = true;
      _celebrating = true;
      if (winner == 1) {
        _whiteWins++;
        _bannerLabel = isAi ? 'You Win!' : 'Player 1 Wins!';
        _bannerColor = const Color(0xFFD4AF37);
      } else {
        _blackWins++;
        _bannerLabel = isAi ? 'AI Wins!' : 'Player 2 Wins!';
        _bannerColor = _kBlackPiece;
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
            .saveScore(kChessGameId, _streak, subKey: subKey)
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

  void _onDraw(String reason) {
    setState(() {
      _gameOver = true;
      _winner = null;
      _wasNewBest = false;
      _draws++;
      _streak = 0;
      _streakOwner = null;
      _showStreakBadge = false;
      _showWinBanner = true;
      _bannerLabel = 'Draw — $reason';
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
      _Difficulty.easy => kChessSubKeyEasy,
      _Difficulty.medium => kChessSubKeyMedium,
      _Difficulty.hard => kChessSubKeyHard,
    };
  }

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
    final depth = switch (_difficulty) {
      _Difficulty.easy => 1,
      _Difficulty.medium => 3,
      _Difficulty.hard => 4,
    };

    final allMoves = _generateOrderedMoves(-1);

    if (allMoves.isEmpty) {
      setState(() => _aiThinking = false);
      return;
    }

    if (_difficulty == _Difficulty.easy && _rng.nextDouble() < 0.35) {
      final pick = allMoves[_rng.nextInt(allMoves.length)];
      setState(() => _aiThinking = false);
      _executeMove(pick.$1, pick.$2);
      return;
    }

    if (_moveCount < 6 && _kOpeningBook.containsKey('initial')) {
      final bookMoves = _kOpeningBook['initial']!;
      for (final bm in bookMoves) {
        final from = bm[0], to = bm[1];
        if (_board[from] != 0 && _board[from] < 0 == false) continue;
        if (_board[from] < 0 && allMoves.any((m) => m.$1 == from && m.$2 == to)) {
          setState(() => _aiThinking = false);
          _executeMove(from, to);
          return;
        }
      }
    }

    var bestScore = -999999;
    var bestMove = allMoves.first;

    for (final move in allMoves) {
      final savedBoard = List<int>.from(_board);
      final savedEP = _enPassantTarget;
      final savedFlags = [_whiteKingMoved, _blackKingMoved, _whiteRookAMoved, _whiteRookHMoved, _blackRookAMoved, _blackRookHMoved];
      final savedHMC = _halfMoveClock;

      _applyMoveRaw(move.$1, move.$2);
      _turn = 1;
      final score = -_alphaBeta(depth - 1, -999999, 999999, 1);
      _board = savedBoard;
      _enPassantTarget = savedEP;
      _turn = -1;
      _whiteKingMoved = savedFlags[0];
      _blackKingMoved = savedFlags[1];
      _whiteRookAMoved = savedFlags[2];
      _whiteRookHMoved = savedFlags[3];
      _blackRookAMoved = savedFlags[4];
      _blackRookHMoved = savedFlags[5];
      _halfMoveClock = savedHMC;

      final jitter = _rng.nextInt(3);
      if (score + jitter > bestScore) {
        bestScore = score + jitter;
        bestMove = move;
      }
    }

    setState(() => _aiThinking = false);
    _executeMove(bestMove.$1, bestMove.$2);
  }

  List<(int, int)> _generateOrderedMoves(int side) {
    final captures = <(int, int, int)>[];
    final nonCaptures = <(int, int, int)>[];
    for (int i = 0; i < 64; i++) {
      if (!_isOwnPiece(i, side)) continue;
      for (final to in _legalMoves(i)) {
        if (_board[to] != 0) {
          final mvvLva = (_kPieceValues[_board[to].abs()] ?? 0) * 10 -
              (_kPieceValues[_board[i].abs()] ?? 0);
          captures.add((i, to, mvvLva));
        } else {
          final pst = _kPST[_board[i].abs()];
          final bonus = pst != null
              ? (side > 0 ? pst[to] : pst[63 - to]) -
                (side > 0 ? pst[i] : pst[63 - i])
              : 0;
          nonCaptures.add((i, to, bonus));
        }
      }
    }
    captures.sort((a, b) => b.$3.compareTo(a.$3));
    nonCaptures.sort((a, b) => b.$3.compareTo(a.$3));
    return [
      ...captures.map((m) => (m.$1, m.$2)),
      ...nonCaptures.map((m) => (m.$1, m.$2)),
    ];
  }

  int _alphaBeta(int depth, int alpha, int beta, int side) {
    if (depth <= 0) return _evaluate(side);

    final moves = _generateOrderedMoves(side);

    if (moves.isEmpty) {
      if (_isInCheck(side)) return -99999 - depth;
      return 0;
    }

    for (final move in moves) {
      final savedBoard = List<int>.from(_board);
      final savedEP = _enPassantTarget;
      final savedFlags = [_whiteKingMoved, _blackKingMoved, _whiteRookAMoved, _whiteRookHMoved, _blackRookAMoved, _blackRookHMoved];
      final savedHMC = _halfMoveClock;
      final savedTurn = _turn;

      _applyMoveRaw(move.$1, move.$2);
      _turn = -side;
      final score = -_alphaBeta(depth - 1, -beta, -alpha, -side);
      _board = savedBoard;
      _enPassantTarget = savedEP;
      _turn = savedTurn;
      _whiteKingMoved = savedFlags[0];
      _blackKingMoved = savedFlags[1];
      _whiteRookAMoved = savedFlags[2];
      _whiteRookHMoved = savedFlags[3];
      _blackRookAMoved = savedFlags[4];
      _blackRookHMoved = savedFlags[5];
      _halfMoveClock = savedHMC;

      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  int _evaluate(int side) {
    int score = 0;
    for (int i = 0; i < 64; i++) {
      final p = _board[i];
      if (p == 0) continue;
      final val = _kPieceValues[p.abs()] ?? 0;
      final pst = _kPST[p.abs()];
      final posBonus = pst != null ? (p > 0 ? pst[i] : pst[63 - i]) : 0;
      if (p > 0) {
        score += val + posBonus;
      } else {
        score -= val + posBonus;
      }
    }
    return score * side;
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
        factory: (t) => GenericAnimatedBgPainter(t, accent: _kAccent, icon: Icons.castle_rounded),
        period: const Duration(seconds: 9),
      ),
      iconRingColors: const [Color(0xFFD4AF37), Color(0xFF2D3436), Color(0xFFD4AF37)],
      iconChild: Builder(builder: (ctx) {
        final info = GameRegistry.getById(kChessGameId);
        final logo = info?.buildBrandedLogo(size: 84);
        if (logo != null) return logo;
        return const Icon(Icons.castle_rounded, size: 40, color: _kAccent);
      }),
      title: 'Chess',
      subtitle: 'The ultimate strategy game!',
      onBack: _backOrHome,
      isFavorite: _isFavorite,
      onFavoriteToggle: _toggleFavorite,
      onHowToPlay: _showHelp,
      gameId: kChessGameId,
      body: GameAiPickerBody(
        difficulties: _Difficulty.values.map((d) {
          final subKey = switch (d) {
            _Difficulty.easy => kChessSubKeyEasy,
            _Difficulty.medium => kChessSubKeyMedium,
            _Difficulty.hard => kChessSubKeyHard,
          };
          return GameDifficultyData(
            label: _diffLabel(d),
            color: _diffColor(d),
            kind: _kindFor(d),
            hint: switch (d) {
              _Difficulty.easy => 'Often random — easy to beat.',
              _Difficulty.medium => 'Thinks 2 moves ahead.',
              _Difficulty.hard => 'Thinks 3 moves ahead — good luck!',
            },
            bestScore: bestChessStreak(subKey),
            bestLabel: (s) => 'Best $s in a row',
          );
        }).toList(),
        activeIndex: _Difficulty.values.indexOf(_difficulty),
        onChanged: (i) => setState(() => _difficulty = _Difficulty.values[i]),
        onPlayAi: () => _selectMode(_Mode.ai),
        onPlayFriend: () => _selectMode(_Mode.twoPlayer),
        aiGradient: const [Color(0xFF2D3436), Color(0xFF636E72)],
        friendGradient: const [Color(0xFFD4AF37), Color(0xFFE8D48B)],
      ),
    );
  }

  Widget _buildGame() {
    final isAi = _mode == _Mode.ai;
    final isWhiteTurn = _turn == 1 || _inUndoWindow;
    final topColor = _showWinBanner ? _kBgTop : (isWhiteTurn ? _kTintWhiteTop : _kTintBlackTop);
    final botColor = _showWinBanner ? _kBgBot : (isWhiteTurn ? _kTintWhiteBot : _kTintBlackBot);

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
                        whiteWins: _whiteWins,
                        blackWins: _blackWins,
                      ),
                      trailing: GameRestartButton(
                        gameName: 'Chess',
                        accentColor: _kAccent,
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
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PlayerStrip(
                        label: isAi ? 'AI' : 'Player 2',
                        mark: '♚',
                        color: _kBlackPiece,
                        isActive: _turn == -1 && !_inUndoWindow && !_showWinBanner,
                        isThinking: _aiThinking,
                        avatarIcon: isAi ? Icons.smart_toy_rounded : null,
                      ),
                    ),
                    _buildCapturedRow(_whiteCaptured, true),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
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
                                        lastMoveFrom: _lastMoveFrom,
                                        lastMoveTo: _lastMoveTo,
                                        inCheck: _inCheck,
                                        checkKingSq: _inCheck ? _findKing(_turn) : null,
                                        onCellTap: _onCellTap,
                                        pieceIds: _pieceIds,
                                        flipped: false,
                                        checkPulse: _checkPulseCtrl,
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
                    _buildCapturedRow(_blackCaptured, false),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: PlayerStrip(
                        label: isAi ? 'You' : 'Player 1',
                        mark: '♔',
                        color: const Color(0xFFD4AF37),
                        isActive: (_turn == 1 || _inUndoWindow) && !_showWinBanner,
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
                                accentColor: const Color(0xFFD4AF37),
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

  Widget _buildCapturedRow(List<int> captured, bool isWhiteCaptured) {
    if (captured.isEmpty) return const SizedBox(height: 20);
    final sorted = List<int>.from(captured)..sort((a, b) => (_kPieceValues[b] ?? 0).compareTo(_kPieceValues[a] ?? 0));
    return SizedBox(
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: sorted.map((p) {
            final ch = isWhiteCaptured ? (_kPieceChars[-p] ?? '?') : (_kPieceChars[p] ?? '?');
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(ch, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final isAi = _mode == _Mode.ai;
    String headline;
    String big;
    Color bigColor;
    if (_winner == 1) {
      headline = isAi ? 'You Win!' : 'Player 1 Wins!';
      big = '♔';
      bigColor = const Color(0xFFD4AF37);
    } else if (_winner == -1) {
      headline = isAi ? 'AI Wins!' : 'Player 2 Wins!';
      big = '♚';
      bigColor = _kBlackPiece;
    } else {
      headline = "It's a Draw!";
      big = '=';
      bigColor = _kDrawColor;
    }

    final showStreak = _streak >= 2 && ((_winner == 1 && _streakOwner == 'white') || (_winner == -1 && _streakOwner == 'black'));
    final extraBadges = <Widget>[
      if (showStreak) _StreakBadge(streak: _streak),
      if (_wasNewBest) const _NewBestBadge(),
    ];

    return game_result.GenericGameResultScreen(
      gameId: kChessGameId,
      score: _streak,
      headline: headline,
      badgeContent: big,
      badgeColor: bigColor,
      showNewBestBadge: false,
      extraBadges: extraBadges,
      statsWidget: game_result.GameResultStatsRow(
        stats: [
          game_result.StatItem(label: isAi ? 'YOU' : 'P1', value: _whiteWins, color: const Color(0xFFD4AF37)),
          game_result.StatItem(label: 'DRAWS', value: _draws, color: const Color(0xFF8B7BA7)),
          game_result.StatItem(label: isAi ? 'AI' : 'P2', value: _blackWins, color: _kBlackPiece),
          if (isAi)
            game_result.StatItem(
              label: 'BEST',
              value: ScoreService().getHighScore(kChessGameId, subKey: _aiSubKey()),
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
  // Test hooks (@visibleForTesting — never called by the running app). They
  // expose live engine state and let tests drive the REAL rule code on any
  // position — mates, stalemate, castling, en passant, promotion, draws — and
  // assert exact board contents. This is what makes the shipped engine, not a
  // copy, the thing under test.
  // ---------------------------------------------------------------------------
  @visibleForTesting
  List<int> get board => List.unmodifiable(_board);
  @visibleForTesting
  int get turnToMove => _turn;
  @visibleForTesting
  bool get isGameOver => _gameOver;
  @visibleForTesting
  int? get winner => _winner;
  @visibleForTesting
  bool get inCheck => _inCheck;
  @visibleForTesting
  int? get enPassantTargetSq => _enPassantTarget;
  @visibleForTesting
  List<int> legalMovesForTest(int sq) => _legalMoves(sq);
  @visibleForTesting
  bool isInCheckForTest(int side) => _isInCheck(side);
  @visibleForTesting
  bool isInsufficientMaterialForTest() => _isInsufficientMaterial();
  @visibleForTesting
  int findKingForTest(int side) => _findKing(side);

  /// All legal moves for [side] as (from, to) pairs — for checkmate/stalemate
  /// cross-checks in tests.
  @visibleForTesting
  List<(int, int)> allLegalMovesForTest(int side) {
    final out = <(int, int)>[];
    for (int i = 0; i < 64; i++) {
      if (!_isOwnPiece(i, side)) continue;
      for (final to in _legalMoves(i)) {
        out.add((i, to));
      }
    }
    return out;
  }

  /// Load an arbitrary position so a single rule can be exercised in isolation.
  /// Rebuilds piece-ids + history so the normal move path ([doMoveForTest])
  /// behaves exactly as in play. Castling rights default to "already moved";
  /// pass them explicitly to test castling.
  @visibleForTesting
  void loadPosition(
    List<int> position, {
    int turn = 1,
    bool whiteKingMoved = true,
    bool blackKingMoved = true,
    bool whiteRookAMoved = true,
    bool whiteRookHMoved = true,
    bool blackRookAMoved = true,
    bool blackRookHMoved = true,
    int? enPassantTarget,
    int halfMoveClock = 0,
  }) {
    setState(() {
      _board = List<int>.from(position);
      _turn = turn;
      _whiteKingMoved = whiteKingMoved;
      _blackKingMoved = blackKingMoved;
      _whiteRookAMoved = whiteRookAMoved;
      _whiteRookHMoved = whiteRookHMoved;
      _blackRookAMoved = blackRookAMoved;
      _blackRookHMoved = blackRookHMoved;
      _enPassantTarget = enPassantTarget;
      _halfMoveClock = halfMoveClock;
      _gameOver = false;
      _winner = null;
      _selectedCell = null;
      _validMoves = [];
      _whiteCaptured = [];
      _blackCaptured = [];
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _nextUid = 0;
      _pieceIds = [];
      _moveCount = 0;
      for (int i = 0; i < 64; i++) {
        if (_board[i] != 0) _pieceIds.add(_PieceId(_nextUid++, _board[i], i));
      }
      _positionHistory = [_boardKey()];
      _inCheck = _isInCheck(_turn);
    });
  }

  /// Apply a move through the real pipeline (run game-end detection, switch
  /// turn). Pass a move taken from [legalMovesForTest]. In two-player mode this
  /// never schedules an AI reply, so tests stay deterministic.
  @visibleForTesting
  void doMoveForTest(int from, int to) => _executeMove(from, to);
}

class _ScoreBoardPill extends StatelessWidget {
  final _Mode mode;
  final _Difficulty difficulty;
  final int whiteWins;
  final int blackWins;

  const _ScoreBoardPill({
    required this.mode,
    required this.difficulty,
    required this.whiteWins,
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
                color: _kAccent.withValues(alpha: 0.14),
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
                  _scoreColumn(leftLabel, whiteWins, const Color(0xFFD4AF37)),
                  const SizedBox(width: 14),
                  const Text('VS', style: TextStyle(color: Color(0xFF8B7BA7), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(width: 14),
                  _scoreColumn(rightLabel, blackWins, _kBlackPiece),
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
      _Difficulty.easy => kChessSubKeyEasy,
      _Difficulty.medium => kChessSubKeyMedium,
      _Difficulty.hard => kChessSubKeyHard,
    };
    final best = ScoreService().getHighScore(kChessGameId, subKey: subKey);
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

class _BoardWidget extends StatelessWidget {
  final List<int> board;
  final double boardSize;
  final int? selectedCell;
  final List<int> validMoves;
  final int? lastMoveFrom;
  final int? lastMoveTo;
  final bool inCheck;
  final int? checkKingSq;
  final ValueChanged<int> onCellTap;
  final List<_PieceId> pieceIds;
  final bool flipped;
  final AnimationController? checkPulse;

  const _BoardWidget({
    required this.board,
    required this.boardSize,
    required this.selectedCell,
    required this.validMoves,
    required this.lastMoveFrom,
    required this.lastMoveTo,
    required this.inCheck,
    required this.checkKingSq,
    required this.onCellTap,
    required this.pieceIds,
    required this.flipped,
    required this.checkPulse,
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
              checkPulse != null
                  ? AnimatedBuilder(
                      animation: checkPulse!,
                      builder: (_, _) => CustomPaint(
                        size: Size(boardSize, boardSize),
                        painter: _BoardBgPainter(
                          board: board,
                          selectedCell: selectedCell,
                          validMoves: validMoves,
                          lastMoveFrom: lastMoveFrom,
                          lastMoveTo: lastMoveTo,
                          inCheck: inCheck,
                          checkKingSq: checkKingSq,
                          checkPulse: inCheck ? checkPulse!.value : 0.0,
                        ),
                      ),
                    )
                  : CustomPaint(
                      size: Size(boardSize, boardSize),
                      painter: _BoardBgPainter(
                        board: board,
                        selectedCell: selectedCell,
                        validMoves: validMoves,
                        lastMoveFrom: lastMoveFrom,
                        lastMoveTo: lastMoveTo,
                        inCheck: inCheck,
                        checkKingSq: checkKingSq,
                        checkPulse: 0.0,
                      ),
                    ),
              for (final pid in pieceIds)
                _AnimatedPiece(
                  key: ValueKey('pid_${pid.uid}'),
                  cellSize: cellSize,
                  pos: pid.sq,
                  piece: pid.type,
                  isSelected: selectedCell == pid.sq,
                  flipped: flipped,
                ),
              for (int i = 0; i < 64; i++)
                Positioned(
                  left: (i % 8) * cellSize,
                  top: (i ~/ 8) * cellSize,
                  width: cellSize,
                  height: cellSize,
                  child: GestureDetector(
                    key: ValueKey('sq_$i'),
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

class _AnimatedPiece extends StatelessWidget {
  final double cellSize;
  final int pos;
  final int piece;
  final bool isSelected;
  final bool flipped;

  const _AnimatedPiece({
    super.key,
    required this.cellSize,
    required this.pos,
    required this.piece,
    required this.isSelected,
    required this.flipped,
  });

  @override
  Widget build(BuildContext context) {
    final r = pos ~/ 8;
    final c = pos % 8;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
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
            width: cellSize * 0.85,
            height: cellSize * 0.85,
            child: CustomPaint(
              painter: _PiecePainter(
                piece: piece,
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
  final int piece;
  final bool isSelected;
  _PiecePainter({required this.piece, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.42;
    final isWhite = piece > 0;

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

    final color = isWhite ? const Color(0xFFF5F0E1) : const Color(0xFF2D3436);
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
        ..color = (isWhite ? const Color(0xFFD4AF37) : const Color(0xFF636E72)).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawCircle(
      Offset(cx - radius * 0.25, cy - radius * 0.3),
      radius * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    final ch = _kPieceChars[piece] ?? '?';
    final tp = TextPainter(
      text: TextSpan(
        text: ch,
        style: TextStyle(
          fontSize: radius * 1.1,
          color: isWhite ? const Color(0xFF3E2723) : const Color(0xFFF0D9B5),
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.piece != piece || old.isSelected != isSelected;
}

class _BoardBgPainter extends CustomPainter {
  final List<int> board;
  final int? selectedCell;
  final List<int> validMoves;
  final int? lastMoveFrom;
  final int? lastMoveTo;
  final bool inCheck;
  final int? checkKingSq;
  final double checkPulse;

  _BoardBgPainter({
    required this.board,
    required this.selectedCell,
    required this.validMoves,
    required this.lastMoveFrom,
    required this.lastMoveTo,
    required this.inCheck,
    required this.checkKingSq,
    required this.checkPulse,
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

    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    for (int c = 0; c < 8; c++) {
      final isDark = (7 + c) % 2 == 1;
      final color = isDark ? _kBoardLight : _kBoardDark;
      final tp = TextPainter(
        text: TextSpan(
          text: files[c],
          style: TextStyle(color: color, fontSize: cellSize * 0.22, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c * cellSize + cellSize - tp.width - cellSize * 0.06, 7 * cellSize + cellSize - tp.height - cellSize * 0.02));
    }
    for (int r = 0; r < 8; r++) {
      final isDark = (r) % 2 == 1;
      final color = isDark ? _kBoardLight : _kBoardDark;
      final tp = TextPainter(
        text: TextSpan(
          text: '${8 - r}',
          style: TextStyle(color: color, fontSize: cellSize * 0.22, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cellSize * 0.06, r * cellSize + cellSize * 0.02));
    }

    if (lastMoveFrom != null) {
      final r = lastMoveFrom! ~/ 8;
      final c = lastMoveFrom! % 8;
      final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, Paint()..color = const Color(0x40CDD26A));
    }
    if (lastMoveTo != null) {
      final r = lastMoveTo! ~/ 8;
      final c = lastMoveTo! % 8;
      final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, Paint()..color = const Color(0x60CDD26A));
    }

    if (selectedCell != null) {
      final r = selectedCell! ~/ 8;
      final c = selectedCell! % 8;
      final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, Paint()..color = Colors.amber.withValues(alpha: 0.35));
    }

    if (inCheck && checkKingSq != null) {
      final r = checkKingSq! ~/ 8;
      final c = checkKingSq! % 8;
      final cx = (c + 0.5) * cellSize;
      final cy = (r + 0.5) * cellSize;
      final pulseRadius = cellSize * (0.6 + checkPulse * 0.3);
      final baseAlpha = 0.25 + checkPulse * 0.25;
      canvas.drawCircle(
        Offset(cx, cy),
        pulseRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.red.withValues(alpha: baseAlpha),
              Colors.red.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: pulseRadius)),
      );
      final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
      canvas.drawRect(rect, Paint()..color = Colors.red.withValues(alpha: 0.35));
    }

    for (final m in validMoves) {
      final r = m ~/ 8;
      final c = m % 8;
      if (board[m] != 0) {
        final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
        canvas.drawRect(rect, Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.38));
      } else {
        final cx = (c + 0.5) * cellSize;
        final cy = (r + 0.5) * cellSize;
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.16, Paint()..color = Colors.green.withValues(alpha: 0.5));
      }
    }
  }

  @override
  bool shouldRepaint(_BoardBgPainter old) => true;
}
