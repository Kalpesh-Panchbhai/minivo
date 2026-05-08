import 'dart:async';

import 'package:flutter/foundation.dart';

import 'game_definition.dart';

// ── PlayerConfig ────────────────────────────────────────────────────────────

/// Runtime player configuration for an active session. Captures the chosen
/// [PlayerMode] plus per-player metadata (count, names) so games supporting
/// local co-op or vs-AI can render player-specific UI without re-deriving
/// it from the picker.
class PlayerConfig {
  final PlayerMode mode;
  final int playerCount;
  final List<String> playerNames;

  const PlayerConfig({
    required this.mode,
    this.playerCount = 1,
    this.playerNames = const [],
  });

  static const solo = PlayerConfig(mode: PlayerMode.solo, playerCount: 1);
}

// ── GameSession (abstract) ──────────────────────────────────────────────────

/// The contract a running game uses to talk to the framework.
///
/// Games receive a [GameSession] via [GameDefinition.boardBuilder] and call
/// the mutating methods to update score / mistakes / completion state. The
/// framework owns the underlying state and rebuilds the HUD + result screen
/// in response.
abstract class GameSession {
  // ── Read-only state ──────────────────────────────────────────────────────
  DifficultyDef get difficulty;
  PlayerConfig get players;
  int get currentScore;
  int get bestScore;
  bool get isNewBest;
  Duration get elapsedTime;
  int get mistakes;
  Map<String, dynamic> get customData;

  // ── Game-callable mutations ──────────────────────────────────────────────
  void updateScore(int s);
  void incrementScore(int delta);
  void incrementMistakes();
  void completeGame({String? headline, String? subtitle});
  void failGame({String? headline, String? subtitle});
  void setCustomData(String key, dynamic value);
  T? getCustomData<T>(String key);

  // ── Pause / resume (used by restart dialogs) ─────────────────────────────
  void pauseTimer();
  void resumeTimer();

  // ── Streams ──────────────────────────────────────────────────────────────
  /// Emits when the framework wants the game to restart in place. Games can
  /// listen and reset their internal state without rebuilding the widget.
  Stream<void> get restartSignal;

  /// Emits `true` when the framework pauses the session (e.g. restart dialog
  /// opens) and `false` when it resumes. Games can listen to pause their own
  /// timers / animation controllers in sync with the framework's pause state.
  Stream<bool> get pauseStream;

  /// Whether the session is currently paused.
  bool get isPaused;
}

// ── GameSessionImpl (concrete) ──────────────────────────────────────────────

/// Concrete [GameSession] used by the framework's [GameScaffold]. Owns a
/// [Stopwatch]-driven elapsed-time clock plus all per-run mutable state.
class GameSessionImpl implements GameSession {
  final GameDefinition definition;
  @override
  final DifficultyDef difficulty;
  @override
  final PlayerConfig players;

  final VoidCallback onComplete;
  final VoidCallback onFail;

  int _currentScore = 0;
  int _bestScore = 0;
  bool _isNewBest = false;
  int _mistakes = 0;
  final Map<String, dynamic> _customData = {};

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  String? resultHeadline;
  String? resultSubtitle;

  final StreamController<void> _restartCtrl =
      StreamController<void>.broadcast();

  final StreamController<bool> _pauseCtrl =
      StreamController<bool>.broadcast();

  bool _isPaused = false;
  bool _disposed = false;

  GameSessionImpl({
    required this.definition,
    required this.difficulty,
    required this.players,
    required this.onComplete,
    required this.onFail,
    int initialBest = 0,
  }) : _bestScore = initialBest {
    _stopwatch.start();
    // Periodic no-op tick keeps a heartbeat available so HUD widgets that
    // listen via setState in their parents can be wired up later. The
    // stopwatch itself is the source of truth for [elapsedTime].
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {});
  }

  @override
  int get currentScore => _currentScore;

  @override
  int get bestScore => _bestScore;

  @override
  bool get isNewBest => _isNewBest;

  @override
  Duration get elapsedTime => _stopwatch.elapsed;

  @override
  int get mistakes => _mistakes;

  @override
  Map<String, dynamic> get customData => _customData;

  @override
  void updateScore(int s) {
    _currentScore = s;
    if (s > _bestScore) _bestScore = s;
  }

  @override
  void incrementScore(int delta) {
    _currentScore += delta;
    if (_currentScore > _bestScore) _bestScore = _currentScore;
  }

  @override
  void incrementMistakes() {
    _mistakes += 1;
  }

  @override
  void completeGame({String? headline, String? subtitle}) {
    resultHeadline = headline;
    resultSubtitle = subtitle;
    _stopwatch.stop();
    _ticker?.cancel();
    onComplete();
  }

  @override
  void failGame({String? headline, String? subtitle}) {
    resultHeadline = headline;
    resultSubtitle = subtitle;
    _stopwatch.stop();
    _ticker?.cancel();
    onFail();
  }

  @override
  void setCustomData(String key, dynamic value) {
    _customData[key] = value;
  }

  @override
  T? getCustomData<T>(String key) {
    final v = _customData[key];
    if (v is T) return v;
    return null;
  }

  @override
  void pauseTimer() {
    if (_stopwatch.isRunning) _stopwatch.stop();
    if (!_isPaused) {
      _isPaused = true;
      if (!_pauseCtrl.isClosed) _pauseCtrl.add(true);
    }
  }

  @override
  void resumeTimer() {
    if (!_stopwatch.isRunning) _stopwatch.start();
    if (_isPaused) {
      _isPaused = false;
      if (!_pauseCtrl.isClosed) _pauseCtrl.add(false);
    }
  }

  @override
  bool get isPaused => _isPaused;

  @override
  Stream<bool> get pauseStream => _pauseCtrl.stream;

  @override
  Stream<void> get restartSignal => _restartCtrl.stream;

  /// Emit a restart signal — used by the framework when the user opts to
  /// restart in place rather than going back to the picker.
  void signalRestart() {
    if (_restartCtrl.isClosed) return;
    _restartCtrl.add(null);
  }

  /// Mark the session as having achieved a new best — flipped after the
  /// score-service round trip in [GameScaffold].
  void markNewBest(bool value) {
    _isNewBest = value;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    if (!_restartCtrl.isClosed) _restartCtrl.close();
    if (!_pauseCtrl.isClosed) _pauseCtrl.close();
  }
}
