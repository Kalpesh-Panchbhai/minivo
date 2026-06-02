import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/ad_config.dart';
import 'core/constants/app_theme.dart';
import 'core/services/ads_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/consent_service.dart';
import 'core/services/crash_reporter.dart';
import 'core/services/score_service.dart';
import 'games/game_stats_bootstrap.dart';
import 'routing/app_router.dart';
import 'utils/perf_logger.dart';

Future<void> bootstrap({
  required FirebaseOptions firebaseOptions,
  required AdConfig adConfig,
  required bool isDev,
}) async {
  // runZonedGuarded catches anything that escapes Flutter's own error path —
  // async errors raised outside a Flutter callback land here.
  await runZonedGuarded<Future<void>>(() async {
    PerfLogger.startOp('app-startup');
    WidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    PerfLogger.startOp('score-service-init');
    await ScoreService().init();
    PerfLogger.endOp('score-service-init');

    registerAllGameStats();

    PerfLogger.endOp('app-startup');
    runApp(const MinivoApp());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      PerfLogger.startFrameMonitoring();

      PerfLogger.startOp('firebase-init');
      await Firebase.initializeApp(options: firebaseOptions);
      PerfLogger.endOp('firebase-init');

      // Dev → always enabled (real-time Crashlytics + Analytics, even in debug).
      // Prod → enabled only for release builds.
      final shouldCollect = isDev || !kDebugMode;
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(shouldCollect);
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(shouldCollect);

      AnalyticsService().setEnabled(shouldCollect);
      CrashReporter().setEnabled(shouldCollect);

      // ── Error pipelines → Crashlytics ────────────────────────────────
      FlutterError.onError = (FlutterErrorDetails details) {
        // Keep the default red-screen / console print in debug.
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      // Uncaught isolate errors (background isolates, compute(), etc.).
      Isolate.current.addErrorListener(RawReceivePort((pair) async {
        final List<dynamic> errorAndStacktrace = pair as List<dynamic>;
        await FirebaseCrashlytics.instance.recordError(
          errorAndStacktrace.first,
          errorAndStacktrace.last is StackTrace
              ? errorAndStacktrace.last as StackTrace
              : StackTrace.fromString('${errorAndStacktrace.last}'),
          reason: 'Uncaught isolate error',
          fatal: true,
        );
      }).sendPort);

      // ── Persistent custom keys (attached to every report) ────────────
      await CrashReporter().setKeys({
        'flavor': isDev ? 'dev' : 'prod',
        'debug_build': kDebugMode,
        'profile_build': kProfileMode,
        'release_build': kReleaseMode,
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
      });
      await CrashReporter()
          .setUserIdentifier(ScoreService().getDisplayName());

      if (shouldCollect) {
        await FirebaseAnalytics.instance.logAppOpen();
        await CrashReporter().log('app_open');
      }

      // Consent must complete before any ad request.
      // Order: UMP info update → form (if EEA) → AdsService.init.
      unawaited(() async {
        await ConsentService().init();
        await ConsentService().ready;
        await AdsService().init(config: adConfig);
      }());
    });
  }, (error, stack) {
    // Anything that escaped runZonedGuarded — report fatal.
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: 'Uncaught zone error',
      fatal: true,
    );
  });
}

class MinivoApp extends StatelessWidget {
  const MinivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Minivo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}
