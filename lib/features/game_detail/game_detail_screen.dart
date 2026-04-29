import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/best_stat.dart';
import '../../core/services/best_stats_registry.dart';
import '../../core/services/score_service.dart';
import '../../core/widgets/how_to_play_sheet.dart';
import '../../games/game_registry.dart';

class GameDetailScreen extends StatefulWidget {
  final String gameId;

  const GameDetailScreen({super.key, required this.gameId});

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = ScoreService().isFavorite(widget.gameId);
  }

  void _toggleFav() {
    ScoreService().toggleFavorite(widget.gameId);
    setState(() => _isFav = !_isFav);
  }

  void _play(String gameId) {
    if (GameRegistry.hasGame(gameId)) {
      context.push('/play/$gameId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Coming soon!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showHowToPlay(BuildContext context, String title, String howToPlay,
      Color accent) {
    showHowToPlaySheet(
      context,
      title: title,
      howToPlay: howToPlay,
      accent: accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = GameRegistry.getById(widget.gameId);
    if (game == null) {
      return const Scaffold(body: Center(child: Text('Game not found')));
    }
    // Drive the "Your best" panel via the registry — games can opt in to a
    // richer breakdown (per difficulty / per mode) by registering a custom
    // builder. Falls back to a single high-score row.
    final bestStats = BestStatsRegistry.statsFor(widget.gameId);
    final similar = GameRegistry.getByCategory(game.category)
        .where((g) => g.id != game.id)
        .toList();

    // Premium body palette — cream paper with a faint warm peach tint at the
    // top that fades into off-white. Same on every game so the detail screen
    // feels editorial and consistent; the game's own accent shows up in the
    // hero gradient and in card highlights below.
    const softBg = Color(0xFFFAF6F1);     // warm cream
    const warmTint = Color(0xFFFFF1E6);   // gentle peach overlay near hero

    // Hero gradient — three tonal stops of the game accent for a richer,
    // more premium feel than a single colour wash.
    final heroTop = game.color;
    final heroMid = Color.lerp(game.color, Colors.white, 0.28)!;
    final heroEnd = Color.lerp(game.color, warmTint, 0.85)!;

    return Scaffold(
      backgroundColor: softBg,
      body: Stack(
        children: [
          // Soft warm-tint that fades into the cream body so the hero's
          // bottom edge doesn't slam into a flat background.
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [warmTint, softBg],
                  stops: [0.0, 0.35],
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  height: 320,
                  // Three-stop hero gradient: deeper accent at the top, soft
                  // mid-tone, then a kiss of warm peach where it meets the
                  // cream body.
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [heroTop, heroMid, heroEnd],
                      stops: const [0.0, 0.55, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative "ghost" icons add depth without competing
                      // with the foreground content.
                      Positioned(
                        right: -30,
                        bottom: -30,
                        child: Icon(
                          game.icon,
                          size: 200,
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        top: 60,
                        child: Icon(
                          game.icon,
                          size: 100,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              _circleButton(
                                Icons.arrow_back_rounded,
                                () => context.pop(),
                              ),
                              const Spacer(),
                              _circleButton(
                                Icons.help_outline_rounded,
                                () => _showHowToPlay(
                                  context,
                                  game.name,
                                  game.howToPlay,
                                  game.color,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _circleButton(
                                _isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                _toggleFav,
                                tint: _isFav
                                    ? const Color(0xFFE85D75)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        game.color.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: game.iconAsset != null
                                  ? Image.asset(
                                      game.iconAsset!,
                                      fit: BoxFit.cover,
                                      width: 96,
                                      height: 96,
                                    )
                                  : game.buildIcon(size: 48),
                            )
                                .animate()
                                .scale(
                                  begin: const Offset(0.5, 0.5),
                                  end: const Offset(1, 1),
                                  duration: 500.ms,
                                  curve: Curves.easeOutBack,
                                )
                                .fadeIn(duration: 300.ms),
                            const SizedBox(height: 16),
                            if (game.iconAsset == null)
                              Text(
                                game.name,
                                style: TextStyle(
                                  // White over the vibrant hero gradient with
                                  // a subtle drop shadow for readability.
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.20),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
                            const SizedBox(height: 8),
                            // Soft white meta-chip (category + play count).
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: game.color.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    game.category.icon,
                                    size: 14,
                                    color: game.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    game.category.label,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    game.playCountFormatted,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bestStats.isNotEmpty) ...[
                        _BestStatsCard(
                          stats: bestStats,
                          accent: game.color,
                        ),
                        const SizedBox(height: 16),
                      ],

                      _sectionCard(
                        icon: Icons.info_outline_rounded,
                        title: 'About',
                        color: game.color,
                        child: Text(
                          game.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(height: 1.5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Compact CTA strip that opens the detailed how-to
                      // bottom sheet — replaces the verbose inline section.
                      _HowToPlayTile(
                        accent: game.color,
                        onTap: () => _showHowToPlay(
                          context,
                          game.name,
                          game.howToPlay,
                          game.color,
                        ),
                      ),

                      if (similar.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          AppStrings.similarGames,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: similar.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final g = similar[index];
                              return GestureDetector(
                                onTap: () => context.push('/game/${g.id}'),
                                child: SizedBox(
                                  width: 90,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              g.bgColor,
                                              g.color
                                                  .withValues(alpha: 0.2),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        child: Icon(
                                          g.icon,
                                          size: 32,
                                          color: g.color,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        g.name,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: SizedBox(
              height: 58,
              child: ElevatedButton(
                onPressed: () => _play(game.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: game.color,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: game.color.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      AppStrings.playNow,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 400.ms)
                .slideY(begin: 0.3, delay: 300.ms, duration: 400.ms),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {Color? tint}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: tint ?? AppColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Tinted icon disc.
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Compact "How to Play" tile (CTA on the detail screen) ─────────────────
class _HowToPlayTile extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _HowToPlayTile({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to Play',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to view step-by-step instructions',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// "Your best" panel — driven by BestStatsRegistry. Renders one row
// per BestStat returned by the registered builder. Single-row variant
// uses the trophy hero card; multi-row uses a compact list.
// ════════════════════════════════════════════════════════════════
class _BestStatsCard extends StatelessWidget {
  final List<BestStat> stats;
  final Color accent;

  const _BestStatsCard({required this.stats, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFC233), Color(0xFFFF8A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.40),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Your best',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(stats.length, (i) {
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: _BestStatRow(stat: stats[i], fallback: accent),
            );
          }),
        ],
      ),
    );
  }
}

class _BestStatRow extends StatelessWidget {
  final BestStat stat;
  final Color fallback;
  const _BestStatRow({required this.stat, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final color = stat.color ?? fallback;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              stat.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Text(
            stat.value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          if (stat.sublabel != null) ...[
            const SizedBox(width: 8),
            Text(
              stat.sublabel!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

