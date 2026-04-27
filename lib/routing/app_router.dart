import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home/main_shell.dart';
import '../features/search/search_screen.dart';
import '../features/category/category_screen.dart';
import '../features/game_detail/game_detail_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/achievements/achievements_screen.dart';
import '../games/game_play_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
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
        builder: (context, state) => GameDetailScreen(
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
