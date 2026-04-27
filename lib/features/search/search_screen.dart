import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/models/game_info.dart';
import '../../core/widgets/game_card.dart';
import '../../games/game_registry.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<GameInfo> _results = [];
  bool _hasSearched = false;

  void _onSearch(String query) {
    setState(() {
      _hasSearched = query.isNotEmpty;
      _results = GameRegistry.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: AppStrings.searchHint,
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textHint,
                        ),
                        suffixIcon: _controller.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  _onSearch('');
                                },
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textHint,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!_hasSearched)
              Expanded(
                child: _buildSuggestions(),
              )
            else if (_results.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.noResults,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final game = _results[index];
                    return GameCardAnimated(
                      game: game,
                      index: index,
                      onTap: () => context.push('/game/${game.id}'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GameRegistry.allGames.take(6).map((game) {
              return GestureDetector(
                onTap: () {
                  _controller.text = game.name;
                  _onSearch(game.name);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    game.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
