import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home/main_shell.dart';
import '../features/search/search_screen.dart';
import '../features/category/category_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../games/game_play_screen.dart';
import '../games/game_registry.dart';
import '../games/shared/single_mode_game_screen.dart';

/// App-wide route observer. Subscribed to by screens that need to refresh
/// when the user pops back to them (e.g. HomeScreen refreshing the
/// favourites rail after toggling a heart on a detail screen).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    observers: [appRouteObserver],
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
      GoRoute(
        path: '/game/:id',
        redirect: (context, state) {
          final id = state.pathParameters['id'];
          // Games with built-in mode pickers handle the detail UX themselves
          // — route straight to the picker/play screen.
          if (id != null && GameRegistry.usesCombinedPickerScreen(id)) {
            return '/play/$id';
          }
          return null;
        },
        builder: (context, state) => SingleModeGameScreen(
          gameId: state.pathParameters['id']!,
        ),
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
