import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Typed wrapper around FirebaseCrashlytics.
///
/// Adds:
///   • Persistent custom keys (flavor, debug, screen, game_id, …) that get
///     attached to every crash report.
///   • Breadcrumb log lines that show up in the "Logs" tab on a crash.
///   • Convenience for non-fatal exception capture.
///
/// All reads go through this so crash context stays consistent.
class CrashReporter {
  CrashReporter._();
  static final CrashReporter _instance = CrashReporter._();
  factory CrashReporter() => _instance;

  bool _enabled = false;
  FirebaseCrashlytics get _cl => FirebaseCrashlytics.instance;

  void setEnabled(bool enabled) => _enabled = enabled;

  // ── Persistent context (attached to every future crash) ────────────────

  Future<void> setUserIdentifier(String id) async {
    if (!_enabled) return;
    await _cl.setUserIdentifier(id);
  }

  Future<void> setKey(String key, Object value) async {
    if (!_enabled) return;
    await _cl.setCustomKey(key, value);
  }

  Future<void> setKeys(Map<String, Object> kv) async {
    if (!_enabled) return;
    for (final e in kv.entries) {
      await _cl.setCustomKey(e.key, e.value);
    }
  }

  Future<void> setCurrentScreen(String screen) =>
      setKey('current_screen', screen);

  Future<void> setCurrentGame(String? gameId) =>
      setKey('current_game', gameId ?? 'none');

  Future<void> clearCurrentGame() => setKey('current_game', 'none');

  // ── Breadcrumbs (last ~64 lines kept by Crashlytics) ───────────────────

  /// Adds a structured breadcrumb. Renders as `tag | k=v k=v` in the Logs
  /// tab on a crash, so future-you can read what the user did.
  Future<void> log(String tag, [Map<String, Object?>? data]) async {
    if (!_enabled) return;
    final buf = StringBuffer(tag);
    if (data != null && data.isNotEmpty) {
      buf.write(' |');
      data.forEach((k, v) {
        if (v != null) buf.write(' $k=$v');
      });
    }
    await _cl.log(buf.toString());
  }

  // ── Recording exceptions ───────────────────────────────────────────────

  /// Caught-but-noteworthy exception. Goes to Crashlytics as non-fatal and
  /// keeps the user in the app.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Map<String, Object?> keys = const {},
  }) async {
    if (!_enabled) {
      if (kDebugMode) debugPrint('[Crash] $reason: $error\n$stack');
      return;
    }
    final infoKeys = <DiagnosticsNode>[];
    keys.forEach((k, v) {
      if (v != null) infoKeys.add(DiagnosticsProperty(k, v));
    });
    await _cl.recordError(
      error,
      stack,
      reason: reason,
      information: infoKeys,
      fatal: false,
    );
  }

}
