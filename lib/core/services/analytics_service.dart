import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Phase 1 analytics — typed wrapper around FirebaseAnalytics.
///
/// All gameplay analytics flow through here so naming/params stay consistent.
/// No raw [FirebaseAnalytics.logEvent] calls outside this file.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;

  bool _enabled = false;
  FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  void setEnabled(bool enabled) => _enabled = enabled;

  Future<void> _log(String name, [Map<String, Object?>? params]) async {
    if (!_enabled) return;
    // Firebase Analytics rejects everything except String and num. Coerce
    // bools to int (1/0) and any other type to its `toString()` so callers
    // can pass natural Dart values without hitting an assertion.
    final clean = <String, Object>{};
    params?.forEach((k, v) {
      if (v == null) return;
      if (v is String || v is num) {
        clean[k] = v;
      } else if (v is bool) {
        clean[k] = v ? 1 : 0;
      } else {
        clean[k] = v.toString();
      }
    });
    try {
      await _fa.logEvent(name: name, parameters: clean);
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] $name failed: $e');
    }
  }

  // ── Phase 1 events ──────────────────────────────────────────────────────

  Future<void> gameOpen({required String gameId}) =>
      _log('game_open', {'game_id': gameId});

  Future<void> difficultySelected({
    required String gameId,
    required String difficulty,
  }) =>
      _log('difficulty_selected', {
        'game_id': gameId,
        'difficulty': difficulty,
      });

  Future<void> gameStart({
    required String gameId,
    String? difficulty,
    String? mode,
  }) =>
      _log('game_start', {
        'game_id': gameId,
        'difficulty': difficulty,
        'mode': mode,
      });

  Future<void> gameEnd({
    required String gameId,
    required String result, // win | loss | abandon | draw
    required int score,
    required int durationSec,
    bool isHighScore = false,
    String? difficulty,
    String? mode,
  }) =>
      _log('game_end', {
        'game_id': gameId,
        'result': result,
        'score': score,
        'duration_sec': durationSec,
        'is_high_score': isHighScore,
        'difficulty': difficulty,
        'mode': mode,
      });

  Future<void> gameRestart({
    required String gameId,
    required String from, // result_screen | pause | mode_change
  }) =>
      _log('game_restart', {'game_id': gameId, 'from': from});

  Future<void> resultAction({
    required String gameId,
    required String action, // play_again | change_mode | home | share
  }) =>
      _log('result_action', {'game_id': gameId, 'action': action});

  Future<void> favoriteToggled({
    required String gameId,
    required bool added,
  }) =>
      _log('favorite_toggled', {
        'game_id': gameId,
        'state': added ? 'added' : 'removed',
      });

  Future<void> settingChanged({
    required String key, // sound | vibration | display_name
    required Object value,
  }) =>
      _log('setting_changed', {'key': key, 'value': '$value'});

  Future<void> externalLinkOpened({
    required String link, // privacy_policy | rate_app | share_app | terms
  }) =>
      _log('external_link_opened', {'link': link});

  Future<void> homeSectionTapped({
    required String section, // featured | trending | recent | favorites | search | category
    String? gameId,
  }) =>
      _log('home_section_tapped', {'section': section, 'game_id': gameId});

  Future<void> adShown({
    required String adType, // interstitial | rewarded
    String? gameId,
    String? rewardType,
  }) =>
      _log('ad_shown', {
        'ad_type': adType,
        'game_id': gameId,
        'reward_type': rewardType,
      });

  Future<void> adCompleted({
    String? gameId,
    required String rewardType,
  }) =>
      _log('ad_completed', {
        'game_id': gameId,
        'reward_type': rewardType,
      });

  Future<void> adSkipped({
    String? gameId,
    required String rewardType,
  }) =>
      _log('ad_skipped', {
        'game_id': gameId,
        'reward_type': rewardType,
      });

  Future<void> adFailed({
    required String adType,
    String? gameId,
  }) =>
      _log('ad_failed', {
        'ad_type': adType,
        'game_id': gameId,
      });

  Future<void> tutorialStarted({required String gameId}) =>
      _log('tutorial_started', {'game_id': gameId});

  Future<void> tutorialCompleted({
    required String gameId,
    required bool finished,
  }) =>
      _log('tutorial_completed', {
        'game_id': gameId,
        'finished': finished,
      });
}
