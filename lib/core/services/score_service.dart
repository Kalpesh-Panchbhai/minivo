import 'package:shared_preferences/shared_preferences.dart';

class ScoreService {
  static final ScoreService _instance = ScoreService._();
  factory ScoreService() => _instance;
  ScoreService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int getHighScore(String gameId) {
    return _prefs?.getInt('highscore_$gameId') ?? 0;
  }

  Future<bool> saveScore(String gameId, int score) async {
    final current = getHighScore(gameId);
    if (score > current) {
      await _prefs?.setInt('highscore_$gameId', score);
      return true;
    }
    return false;
  }

  int getTotalGamesPlayed() {
    return _prefs?.getInt('total_games_played') ?? 0;
  }

  Future<void> incrementGamesPlayed() async {
    final current = getTotalGamesPlayed();
    await _prefs?.setInt('total_games_played', current + 1);
  }

  int getTotalCoins() {
    return _prefs?.getInt('total_coins') ?? 0;
  }

  Future<void> addCoins(int amount) async {
    final current = getTotalCoins();
    await _prefs?.setInt('total_coins', current + amount);
  }

  List<String> getRecentlyPlayed() {
    return _prefs?.getStringList('recently_played') ?? [];
  }

  Future<void> addRecentlyPlayed(String gameId) async {
    final list = getRecentlyPlayed();
    list.remove(gameId);
    list.insert(0, gameId);
    if (list.length > 10) list.removeLast();
    await _prefs?.setStringList('recently_played', list);
  }

  List<String> getFavorites() {
    return _prefs?.getStringList('favorites') ?? [];
  }

  Future<void> toggleFavorite(String gameId) async {
    final list = getFavorites();
    if (list.contains(gameId)) {
      list.remove(gameId);
    } else {
      list.add(gameId);
    }
    await _prefs?.setStringList('favorites', list);
  }

  bool isFavorite(String gameId) {
    return getFavorites().contains(gameId);
  }

  bool hasSeenOnboarding() {
    return _prefs?.getBool('seen_onboarding') ?? false;
  }

  Future<void> setOnboardingSeen() async {
    await _prefs?.setBool('seen_onboarding', true);
  }

  bool isSoundEnabled() {
    return _prefs?.getBool('sound_enabled') ?? true;
  }

  Future<void> setSoundEnabled(bool enabled) async {
    await _prefs?.setBool('sound_enabled', enabled);
  }

  bool isVibrationEnabled() {
    return _prefs?.getBool('vibration_enabled') ?? true;
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await _prefs?.setBool('vibration_enabled', enabled);
  }

  String getDisplayName() {
    return _prefs?.getString('display_name') ?? 'Player';
  }

  Future<void> setDisplayName(String name) async {
    await _prefs?.setString('display_name', name);
  }

  int getGamePlayCount(String gameId) {
    return _prefs?.getInt('play_count_$gameId') ?? 0;
  }

  Future<void> incrementGamePlayCount(String gameId) async {
    final current = getGamePlayCount(gameId);
    await _prefs?.setInt('play_count_$gameId', current + 1);
  }
}
