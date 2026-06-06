import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../config/ad_config.dart';
import 'analytics_service.dart';
import 'crash_reporter.dart';

/// Reward types — drive the per-game logic that runs after a watch.
enum RewardType { coins, continueGame, hint, undo, clearRow }

/// Manages interstitial and rewarded ads via Google AdMob.
///
/// Ad unit IDs come from [AdConfig], injected per flavor:
///   - `main_dev.dart` → [AdConfig.test] (Google test ad units)
///   - `main_prod.dart` → [AdConfig.prod] (real ad units)
///
/// Rule: never call this without [init] succeeding first. UI code that
/// calls [showInterstitial] or [showRewarded] before init will be a no-op
/// (returns immediately, fires `onComplete`).
class AdsService {
  AdsService._();
  static final AdsService _instance = AdsService._();
  factory AdsService() => _instance;

  AdConfig? _config;
  bool _initialized = false;

  // ─── Interstitial ───────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _interstitialRetries = 0;
  DateTime? _lastInterstitialShown;
  int _gameOversThisSession = 0;

  // Frequency caps. Tunable in one place.
  static const _interstitialCooldown = Duration(seconds: 90);
  static const _interstitialSkipFirstNGameOvers = 2;

  // ─── Rewarded ───────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;
  int _rewardedRetries = 0;
  DateTime? _lastRewardedShown;
  static const _rewardedGlobalCooldown = Duration(seconds: 5);

  // ─── Retry policy ───────────────────────────────────────────────────
  static const _maxRetries = 5;

  Timer? _initTimer;
  Timer? _interstitialRetryTimer;
  Timer? _rewardedRetryTimer;

  /// Initialize the SDK and preload one of each format.
  /// Safe to call multiple times — second call is a no-op.
  Future<void> init({required AdConfig config}) async {
    if (_initialized) return;
    _config = config;

    if (kDebugMode) {
      debugPrint('[Ads] init — interstitial: ${config.interstitialId}');
      debugPrint('[Ads] init — rewarded:     ${config.rewardedId}');
    }

    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: const []),
      );
      _initialized = true;
      // Small grace period before first request — lets UI stabilize.
      _initTimer = Timer(const Duration(seconds: 2), () {
        _loadInterstitial();
        _loadRewarded();
      });
    } catch (e, st) {
      CrashReporter().recordError(e, st, reason: 'AdsService.init');
    }
  }

  /// Increment the per-session game-over counter. Drives the
  /// "skip first N game-overs before showing interstitial" rule.
  /// Call from `GameWrapper.endGame`.
  void notifyGameOver() => _gameOversThisSession++;

  // ─── INTERSTITIAL ───────────────────────────────────────────────────

  void _loadInterstitial() {
    final cfg = _config;
    if (cfg == null || _isInterstitialLoading || _interstitialAd != null) {
      return;
    }
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: cfg.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialRetries = 0;
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          CrashReporter().log('ad_load_failed', {
            'type': 'interstitial',
            'msg': error.message,
            'attempt': _interstitialRetries + 1,
          });
          if (_interstitialRetries < _maxRetries) {
            _interstitialRetries++;
            final delay =
                Duration(seconds: 5 * (1 << (_interstitialRetries - 1)));
            _interstitialRetryTimer?.cancel();
            _interstitialRetryTimer = Timer(delay, _loadInterstitial);
          }
        },
      ),
    );
  }

  /// Whether an interstitial may be shown right now (loaded + caps OK).
  bool get _canShowInterstitial {
    if (!_initialized) return false;
    if (_interstitialAd == null) return false;
    if (_gameOversThisSession <= _interstitialSkipFirstNGameOvers) return false;
    if (_lastInterstitialShown != null &&
        DateTime.now().difference(_lastInterstitialShown!) <
            _interstitialCooldown) {
      return false;
    }
    return true;
  }

  /// Tries to show an interstitial. Always calls [onComplete] when control
  /// returns to your UI — whether the ad showed, was capped, or failed.
  void showInterstitial({required void Function() onComplete, String? gameId}) {
    if (!_canShowInterstitial) {
      onComplete();
      return;
    }

    final ad = _interstitialAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastInterstitialShown = DateTime.now();
        CrashReporter().log('ad_shown', {'type': 'interstitial'});
        AnalyticsService().adShown(adType: 'interstitial', gameId: gameId);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialRetries = 0;
        _loadInterstitial();
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialRetries = 0;
        _loadInterstitial();
        CrashReporter().log('ad_show_failed', {
          'type': 'interstitial',
          'msg': error.message,
        });
        AnalyticsService().adFailed(adType: 'interstitial', gameId: gameId);
        onComplete();
      },
    );
    _interstitialAd = null;
    ad.show();
  }

  // ─── REWARDED ───────────────────────────────────────────────────────

  void _loadRewarded() {
    final cfg = _config;
    if (cfg == null || _isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: cfg.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _rewardedRetries = 0;
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
          CrashReporter().log('ad_load_failed', {
            'type': 'rewarded',
            'msg': error.message,
            'attempt': _rewardedRetries + 1,
          });
          if (_rewardedRetries < _maxRetries) {
            _rewardedRetries++;
            final delay =
                Duration(seconds: 5 * (1 << (_rewardedRetries - 1)));
            _rewardedRetryTimer?.cancel();
            _rewardedRetryTimer = Timer(delay, _loadRewarded);
          }
        },
      ),
    );
  }

  /// Whether a rewarded ad is loaded and the global cooldown is past.
  bool get isRewardedReady {
    if (!_initialized || _rewardedAd == null) return false;
    if (_lastRewardedShown != null &&
        DateTime.now().difference(_lastRewardedShown!) <
            _rewardedGlobalCooldown) {
      return false;
    }
    return true;
  }

  /// Show a rewarded ad. [onRewarded] only fires if the user finishes the
  /// ad — partial views do **not** trigger it. [onComplete] always fires
  /// when the ad surface goes away (even on failure).
  void showRewarded({
    required RewardType rewardType,
    required void Function(RewardType type) onRewarded,
    void Function()? onComplete,
    String? gameId,
  }) {
    final ad = _rewardedAd;
    if (ad == null || !isRewardedReady) {
      if (kDebugMode) debugPrint('[Ads] rewarded not ready');
      _loadRewarded();
      onComplete?.call();
      return;
    }

    bool rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastRewardedShown = DateTime.now();
        if (kDebugMode) debugPrint('[Ads] rewarded shown (${rewardType.name})');
        CrashReporter().log('ad_shown', {
          'type': 'rewarded',
          'reward': rewardType.name,
        });
        AnalyticsService().adShown(
          adType: 'rewarded',
          gameId: gameId,
          rewardType: rewardType.name,
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) {
          debugPrint('[Ads] rewarded dismissed — '
              'rewardEarned=$rewardEarned (${rewardType.name})');
        }
        CrashReporter().log('ad_dismissed', {
          'type': 'rewarded',
          'reward_earned': rewardEarned,
        });
        if (rewardEarned) {
          AnalyticsService().adCompleted(
            gameId: gameId,
            rewardType: rewardType.name,
          );
        } else {
          AnalyticsService().adSkipped(
            gameId: gameId,
            rewardType: rewardType.name,
          );
        }
        ad.dispose();
        _rewardedAd = null;
        _rewardedRetries = 0;
        _loadRewarded();
        onComplete?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          debugPrint('[Ads] rewarded show failed: ${error.message}');
        }
        ad.dispose();
        _rewardedAd = null;
        _rewardedRetries = 0;
        _loadRewarded();
        CrashReporter().log('ad_show_failed', {
          'type': 'rewarded',
          'msg': error.message,
        });
        AnalyticsService().adFailed(adType: 'rewarded', gameId: gameId);
        onComplete?.call();
      },
    );
    _rewardedAd = null;
    ad.show(onUserEarnedReward: (ad, reward) {
      rewardEarned = true;
      if (kDebugMode) {
        debugPrint('[Ads] user earned reward (${rewardType.name})');
      }
      onRewarded(rewardType);
    });
  }

  void dispose() {
    _initTimer?.cancel();
    _interstitialRetryTimer?.cancel();
    _rewardedRetryTimer?.cancel();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
