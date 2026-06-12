import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LevelProgressService {
  static final LevelProgressService _instance = LevelProgressService._();
  factory LevelProgressService() => _instance;
  LevelProgressService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void setPrefs(SharedPreferences prefs) => _prefs = prefs;

  String _key(String gameId, String difficulty, String field) =>
      'level_${gameId}_${difficulty}_$field';

  int getCurrentLevel(String gameId, String difficulty) {
    return _prefs?.getInt(_key(gameId, difficulty, 'current')) ?? 1;
  }

  Future<void> setCurrentLevel(String gameId, String difficulty, int level) async {
    await _prefs?.setInt(_key(gameId, difficulty, 'current'), level);
  }

  int getHighestLevel(String gameId, String difficulty) {
    return _prefs?.getInt(_key(gameId, difficulty, 'highest')) ?? 0;
  }

  Future<void> updateHighestLevel(String gameId, String difficulty, int level) async {
    final current = getHighestLevel(gameId, difficulty);
    if (level > current) {
      await _prefs?.setInt(_key(gameId, difficulty, 'highest'), level);
    }
  }

  int getLevelBest(String gameId, String difficulty, int level) {
    return _prefs?.getInt(_key(gameId, difficulty, 'best_$level')) ?? 0;
  }

  Future<bool> saveLevelBest(String gameId, String difficulty, int level, int score) async {
    final current = getLevelBest(gameId, difficulty, level);
    if (current == 0 || score < current) {
      await _prefs?.setInt(_key(gameId, difficulty, 'best_$level'), score);
      return true;
    }
    return false;
  }

  int getOverallBest(String gameId, String difficulty) {
    final highest = getHighestLevel(gameId, difficulty);
    if (highest == 0) return 0;
    int best = 0;
    for (int i = 1; i <= highest; i++) {
      final b = getLevelBest(gameId, difficulty, i);
      if (b > 0 && (best == 0 || b < best)) best = b;
    }
    return best;
  }

  Future<void> advanceLevel(String gameId, String difficulty) async {
    final current = getCurrentLevel(gameId, difficulty);
    final next = current + 1;
    await setCurrentLevel(gameId, difficulty, next);
    await updateHighestLevel(gameId, difficulty, current);
  }

  Future<void> clearProgress(String gameId, String difficulty) async {
    final highest = getHighestLevel(gameId, difficulty);
    await _prefs?.remove(_key(gameId, difficulty, 'current'));
    await _prefs?.remove(_key(gameId, difficulty, 'highest'));
    for (int i = 1; i <= highest; i++) {
      await _prefs?.remove(_key(gameId, difficulty, 'best_$i'));
    }
    await clearGameState(gameId, difficulty);
  }

  String _stateKey(String gameId, String difficulty) =>
      'state_${gameId}_$difficulty';

  Future<void> saveGameState(String gameId, String difficulty, Map<String, dynamic> state) async {
    await _prefs?.setString(_stateKey(gameId, difficulty), jsonEncode(state));
  }

  Map<String, dynamic>? getGameState(String gameId, String difficulty) {
    final raw = _prefs?.getString(_stateKey(gameId, difficulty));
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearGameState(String gameId, String difficulty) async {
    await _prefs?.remove(_stateKey(gameId, difficulty));
  }
}
