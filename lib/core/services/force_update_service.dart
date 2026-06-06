import 'dart:io' show Platform;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ForceUpdateService {
  ForceUpdateService._();
  static final ForceUpdateService _instance = ForceUpdateService._();
  factory ForceUpdateService() => _instance;

  static const _kMinVersion = 'min_app_version';
  static const _kLatestVersion = 'latest_app_version';
  static const _kUpdateMessage = 'update_message';

  String _currentVersion = '0.0.0';
  String _minVersion = '0.0.0';
  String _latestVersion = '0.0.0';
  String _updateMessage = '';
  bool _initialized = false;

  String get currentVersion => _currentVersion;
  String get minVersion => _minVersion;
  String get latestVersion => _latestVersion;
  String get updateMessage => _updateMessage;

  bool get needsForceUpdate =>
      _initialized && _compareVersions(_currentVersion, _minVersion) < 0;

  bool get hasOptionalUpdate =>
      _initialized &&
      !needsForceUpdate &&
      _compareVersions(_currentVersion, _latestVersion) < 0;

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.puzzloragames.dropzy';
  static const _appStoreUrl =
      'https://apps.apple.com/app/minivo/id0000000000';

  String get storeUrl => Platform.isIOS ? _appStoreUrl : _playStoreUrl;

  Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      await rc.setDefaults({
        _kMinVersion: '0.0.0',
        _kLatestVersion: '0.0.0',
        _kUpdateMessage: '',
      });
      await rc.fetchAndActivate();

      _minVersion = rc.getString(_kMinVersion);
      _latestVersion = rc.getString(_kLatestVersion);
      _updateMessage = rc.getString(_kUpdateMessage);
      _initialized = true;

      if (kDebugMode) {
        debugPrint('[ForceUpdate] current=$_currentVersion '
            'min=$_minVersion latest=$_latestVersion');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ForceUpdate] init failed: $e');
      _initialized = false;
    }
  }

  static int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final bParts = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (int i = 0; i < len; i++) {
      final av = i < aParts.length ? aParts[i] : 0;
      final bv = i < bParts.length ? bParts[i] : 0;
      if (av < bv) return -1;
      if (av > bv) return 1;
    }
    return 0;
  }
}
