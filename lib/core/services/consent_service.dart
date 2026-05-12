import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'crash_reporter.dart';

/// Manages GDPR/UMP consent for personalized ads.
///
/// Awaits this before loading ads — the UMP SDK decides whether the user
/// is in a consent-required region (EU/EEA/UK/Switzerland) and shows the
/// Google-provided form when needed.
///
/// In debug builds we force EEA geography so the form appears in dev for
/// testing the flow.
class ConsentService {
  ConsentService._();
  static final ConsentService _instance = ConsentService._();
  factory ConsentService() => _instance;

  bool _initialized = false;
  bool _canRequestAds = false;

  bool get isInitialized => _initialized;
  bool get canRequestAds => _canRequestAds;

  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  /// Request consent info update and show form if needed.
  /// Pass [testDeviceHashedIds] from logcat output when testing in EEA mode.
  Future<void> init({List<String> testDeviceHashedIds = const []}) async {
    if (_initialized) return;
    try {
      final params = ConsentRequestParameters(
        consentDebugSettings: kDebugMode
            ? ConsentDebugSettings(
                debugGeography: DebugGeography.debugGeographyEea,
                testIdentifiers: testDeviceHashedIds,
              )
            : null,
      );
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            _showConsentFormIfRequired();
          } else {
            _onConsentComplete();
          }
        },
        (error) {
          CrashReporter().log('consent_info_failed', {'msg': error.message});
          _onConsentComplete();
        },
      );
    } catch (e, st) {
      CrashReporter().recordError(e, st, reason: 'ConsentService.init');
      _onConsentComplete();
    }
  }

  void _showConsentFormIfRequired() {
    ConsentInformation.instance.getConsentStatus().then((status) {
      if (status == ConsentStatus.required) {
        _loadAndShowForm();
      } else {
        _onConsentComplete();
      }
    }).catchError((Object e) {
      CrashReporter().log('consent_status_failed', {'msg': e.toString()});
      _onConsentComplete();
    });
  }

  void _loadAndShowForm() {
    ConsentForm.loadConsentForm(
      (form) {
        form.show((formError) {
          if (formError != null) {
            CrashReporter().log('consent_form_error', {'msg': formError.message});
          }
          _onConsentComplete();
        });
      },
      (formError) {
        CrashReporter().log('consent_form_load_failed', {'msg': formError.message});
        _onConsentComplete();
      },
    );
  }

  Future<void> _onConsentComplete() async {
    _initialized = true;
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      _canRequestAds = false;
    }
    CrashReporter().log('consent_complete', {'can_request_ads': _canRequestAds});
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }

  /// Re-show the consent form so the user can change their choice. Wire
  /// this into a Settings → Privacy → "Ad preferences" tile when you want
  /// to expose it. Returns false if the form isn't available in the user's
  /// region (e.g. non-EEA users have nothing to revoke).
  Future<bool> showPrivacyOptions() async {
    try {
      if (!await ConsentInformation.instance.isConsentFormAvailable()) {
        return false;
      }
      ConsentForm.loadConsentForm(
        (form) => form.show((formError) async {
          try {
            _canRequestAds = await ConsentInformation.instance.canRequestAds();
          } catch (_) {
            // ignored
          }
        }),
        (formError) {
          CrashReporter().log('consent_form_load_failed',
              {'msg': formError.message, 'source': 'privacy_options'});
        },
      );
      return true;
    } catch (e, st) {
      CrashReporter().recordError(e, st, reason: 'showPrivacyOptions');
      return false;
    }
  }

  /// Reset consent state. Testing only.
  void reset() {
    ConsentInformation.instance.reset();
    _initialized = false;
    _canRequestAds = false;
  }
}
