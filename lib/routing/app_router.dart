import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'crash_route_observer.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home/main_shell.dart';
import '../features/search/search_screen.dart';
import '../features/category/category_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../games/game_play_screen.dart';

/// App-wide route observer. Subscribed to by screens that need to refresh
/// when the user pops back to them (e.g. HomeScreen refreshing the
/// favourites rail after toggling a heart on a detail screen).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    observers: [appRouteObserver, CrashRouteObserver()],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/category/:name',
        builder: (context, state) => CategoryScreen(
          categoryName: state.pathParameters['name']!,
        ),
      ),
      // Tapping a game from any list goes straight to its play screen — the
      // picker (or the game itself, for single-mode games) is the detail
      // surface. /game/:id is kept as a redirect alias so deep links and
      // existing callers keep working.
      GoRoute(
        path: '/game/:id',
        redirect: (context, state) => '/play/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/play/:id',
        builder: (context, state) => GamePlayScreen(
          gameId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
    ],
  );
}
