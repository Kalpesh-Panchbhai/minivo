import 'package:flutter/widgets.dart';
import '../core/services/crash_reporter.dart';

/// Logs every route change as a Crashlytics breadcrumb and updates the
/// `current_screen` custom key. When a crash happens, the Logs tab will show
/// the user's recent screen path, and the report headline will carry the
/// last screen they were on.
class CrashRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  void _track(String action, Route<dynamic>? route) {
    final name = route?.settings.name ?? route?.settings.toString() ?? 'unknown';
    CrashReporter().setCurrentScreen(name);
    CrashReporter().log('nav_$action', {'route': name});
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) _track('push', route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) _track('pop', previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) _track('replace', newRoute);
  }
}
