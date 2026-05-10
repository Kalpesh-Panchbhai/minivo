import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight perf logger gated by `--dart-define=PERF=true`.
///
/// Enable via run config #2 ("Dev — Debug + Perf Logs") or #4
/// ("Dev — Profile + Perf Logs"). When disabled, every method is a no-op.
class PerfLogger {
  PerfLogger._();

  static const bool enabled =
      bool.fromEnvironment('PERF', defaultValue: false);

  static final _timers = <String, Stopwatch>{};

  static void startOp(String name) {
    if (!enabled) return;
    _timers[name] = Stopwatch()..start();
  }

  static void endOp(String name) {
    if (!enabled) return;
    final sw = _timers.remove(name);
    if (sw == null) return;
    sw.stop();
    final ms = sw.elapsedMicroseconds / 1000.0;
    final tag = ms > 16.0 ? 'SLOW' : 'OP';
    debugPrint('[PERF][$tag] $name: ${ms.toStringAsFixed(2)}ms');
  }

  static bool _frameCallbackActive = false;
  static int _frameCount = 0;
  static int _jankCount = 0;

  static void startFrameMonitoring() {
    if (!enabled || _frameCallbackActive) return;
    _frameCallbackActive = true;
    _frameCount = 0;
    _jankCount = 0;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    debugPrint('[PERF][FRAMES] Monitoring started');
  }

  static void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameCount++;
      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = buildMs + rasterMs;
      if (totalMs > 16.67) {
        _jankCount++;
        debugPrint('[PERF][JANK] Frame #$_frameCount: '
            'build=${buildMs.toStringAsFixed(1)}ms '
            'raster=${rasterMs.toStringAsFixed(1)}ms '
            'total=${totalMs.toStringAsFixed(1)}ms');
      }
      if (_frameCount % 120 == 0) {
        final pct = (_jankCount * 100.0 / _frameCount).toStringAsFixed(1);
        debugPrint('[PERF][FRAMES] $_frameCount frames | '
            'jank=$_jankCount ($pct%)');
      }
    }
  }
}
