import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/responsive.dart';
import '../models/recipe_model.dart';
import '../providers/pantry_provider.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

/// Local search query for the recipe results screen.
final recipeSearchQueryProvider = StateProvider<String>((ref) => '');

/// Simple filters for the recipe results screen.
final recipeFiltersProvider = StateProvider<_RecipeFilters>((ref) {
  return const _RecipeFilters();
});

class _RecipeFilters {
  final bool fast;
  final bool vegetarian;
  final bool mostIngredients;

  const _RecipeFilters({
    this.fast = false,
    this.vegetarian = false,
    this.mostIngredients = false,
  });

  _RecipeFilters copyWith({
    bool? fast,
    bool? vegetarian,
    bool? mostIngredients,
  }) {
    return _RecipeFilters(
      fast: fast ?? this.fast,
      vegetarian: vegetarian ?? this.vegetarian,
      mostIngredients: mostIngredients ?? this.mostIngredients,
    );
  }

  bool get hasAny => fast || vegetarian || mostIngredients;
}

class RecipeResultsScreen extends ConsumerWidget {
  const RecipeResultsScreen({super.key});

  static const routeName = '/recipes';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(dashboardRecipesProvider);
    final searchQuery = ref.watch(recipeSearchQueryProvider);
    final filters = ref.watch(recipeFiltersProvider);
    final userId = ref.watch(userIdProvider);
    final pantryState = ref.watch(pantryNotifierProvider(userId));
    final pantryNames = pantryState.items.map((i) => i.itemName).toList();
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final r = Responsive.of(context);

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            isIOS ? CupertinoIcons.back : Icons.arrow_back_rounded,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ready-to-Cook Recipes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: r.scaleFont(18),
            fontWeight: FontWeight.w600,
            color: AppColors.charcoalText,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: r.isNarrow ? 10 : 12,
                      vertical: r.isNarrow ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.creamBackground.withOpacity(0.98),
                      borderRadius: BorderRadius.circular(r.isNarrow ? 16 : 20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pantryNames.isEmpty
                              ? 'Add pantry items to see matched recipes.'
                              : 'Recipes matched to your pantry:',
                          style: r.bodySmallStyle(context, color: AppColors.charcoalText.withOpacity(0.75)),
                        ),
                        if (pantryNames.isNotEmpty) ...[
                          SizedBox(height: r.isNarrow ? 6 : 8),
                          Wrap(
                            spacing: r.isNarrow ? 6 : 8,
                            runSpacing: 4,
                            children: pantryNames
                                .take(12)
                                .map((name) => _IngredientChip(label: name))
                                .toList(),
                          ),
                          SizedBox(height: r.isNarrow ? 8 : 10),
                          Text(
                            'Filter by:',
                            style: r.labelStyle(context, fontSize: 11).copyWith(
                              color: AppColors.charcoalText.withOpacity(0.6),
                            ),
                          ),
                          SizedBox(height: 4),
                          Wrap(
                            spacing: r.isNarrow ? 6 : 8,
                            runSpacing: 4,
                            children: const [
                              _FilterChipLabel(label: 'Fast'),
                              _FilterChipLabel(label: 'Vegetarian'),
                              _FilterChipLabel(label: 'High match'),
                            ],
                          ),
                        ] else
                          SizedBox(height: r.isNarrow ? 6 : 8),
                      ],
                    ),
                  ),
                  SizedBox(height: r.isNarrow ? 8 : 10),
                  _SearchBar(),
                ],
              ),
            ),
            SizedBox(height: r.isNarrow ? 4 : 6),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: r.horizontalPadding),
                child: recipesAsync.when(
                  data: (recipes) {
                    final q = searchQuery.trim().toLowerCase();
                    var filtered = recipes;

                    // Text search
                    if (q.isNotEmpty) {
                      filtered = filtered.where((r) {
                        final inTitle =
                            r.title.toLowerCase().contains(q);
                        final inTags = r.tags
                            .any((t) => t.toLowerCase().contains(q));
                        return inTitle || inTags;
                      }).toList();
                    }

                    // Fast filter (rough heuristic based on tags)
                    if (filters.fast) {
                      filtered = filtered
                          .where((r) => r.tags.any((t) {
                                final lt = t.toLowerCase();
                                return lt.contains('fast') ||
                                    lt.contains('quick') ||
                                    lt.contains('easy');
                              }))
                          .toList();
                    }

                    // Vegetarian filter
                    if (filters.vegetarian) {
                      filtered = filtered
                          .where((r) => r.tags.any(
                                (t) => t.toLowerCase().contains('vegetarian'),
                              ))
                          .toList();
                    }

                    // Most ingredients filter (high match percentage)
                    if (filters.mostIngredients) {
                      filtered = filtered
                          .where((r) => r.matchPercentage >= 0.7)
                          .toList();
                    }

                    if (filtered.isEmpty) {
                      final hasAnyFilter = filters.hasAny || q.isNotEmpty;
                      final resp = Responsive.of(context);
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: resp.horizontalPadding),
                          child: Text(
                            hasAnyFilter
                                ? 'No recipes match your current search or filters.'
                                : 'No recipes yet. Add a few pantry items to get suggestions.',
                            style: resp.bodySmallStyle(context),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: Responsive.of(context).isNarrow ? 12 : 16),
                      itemBuilder: (context, index) {
                        final recipe = filtered[index];
                        return _ResultCard(recipe: recipe);
                      },
                    );
                  },
                  loading: () {
                    final resp = Responsive.of(context);
                    return ListView.separated(
                      itemCount: 3,
                      separatorBuilder: (_, __) => SizedBox(height: resp.isNarrow ? 12 : 16),
                      itemBuilder: (_, __) =>
                          RecipeCardShimmer(height: resp.isNarrow ? 180 : 220),
                    );
                  },
                  error: (_, __) => Center(
                    child: Text(
                      'Couldn\'t load recipes.',
                      style: Responsive.of(context).bodySmallStyle(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final r = Responsive.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamBackground.withOpacity(0.98),
        borderRadius: BorderRadius.circular(r.isNarrow ? 20 : 24),
        border: Border.all(
          color: AppColors.primaryTeal.withOpacity(0.25),
          width: 1,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: r.isNarrow ? 10 : 12),
      child: Row(
        children: [
          Icon(
            isIOS ? CupertinoIcons.search : Icons.search_rounded,
            color: AppColors.charcoalText.withOpacity(0.7),
            size: r.isNarrow ? 20 : 24,
          ),
          SizedBox(width: r.isNarrow ? 6 : 8),
          Expanded(
            child: TextField(
              style: r.bodyStyle(context),
              decoration: InputDecoration(
                hintText: 'Search recipes...',
                border: InputBorder.none,
                hintStyle: r.bodySmallStyle(context),
              ),
              onChanged: (value) {
                ref.read(recipeSearchQueryProvider.notifier).state = value;
              },
            ),
          ),
          SizedBox(width: r.isNarrow ? 6 : 8),
          GestureDetector(
            onTap: () => _showFiltersSheet(context, ref),
            child: Container(
              padding: EdgeInsets.all(r.isNarrow ? 6 : 8),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(r.isNarrow ? 12 : 16),
              ),
              child: Icon(
                isIOS
                    ? CupertinoIcons.slider_horizontal_3
                    : Icons.tune_rounded,
                color: AppColors.primaryTeal,
                size: r.isNarrow ? 16 : 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showFiltersSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.creamBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, refWatch, _) {
          final filters = refWatch.watch(recipeFiltersProvider);
          final theme = Theme.of(context);

          final r = Responsive.of(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(r.horizontalPadding, 16, r.horizontalPadding, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filters',
                  style: r.titleStyle(context, fontSize: 16),
                ),
                SizedBox(height: r.isNarrow ? 10 : 12),
                _FilterPill(
                  label: 'Fast',
                  active: filters.fast,
                  onTap: () {
                    refWatch
                        .read(recipeFiltersProvider.notifier)
                        .state = filters.copyWith(fast: !filters.fast);
                  },
                ),
                _FilterPill(
                  label: 'Vegetarian',
                  active: filters.vegetarian,
                  onTap: () {
                    refWatch
                        .read(recipeFiltersProvider.notifier)
                        .state =
                            filters.copyWith(vegetarian: !filters.vegetarian);
                  },
                ),
                _FilterPill(
                  label: 'Most ingredients',
                  active: filters.mostIngredients,
                  onTap: () {
                    refWatch
                        .read(recipeFiltersProvider.notifier)
                        .state = filters.copyWith(
                      mostIngredients: !filters.mostIngredients,
                    );
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: r.isNarrow ? 4 : 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.isNarrow ? 8 : 10,
            vertical: r.isNarrow ? 5 : 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: active
                ? AppColors.primaryTeal.withOpacity(0.10)
                : AppColors.creamBackground.withOpacity(0.9),
            border: Border.all(
              color: active
                  ? AppColors.primaryTeal
                  : AppColors.creamBackground.withOpacity(0.8),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: r.isNarrow ? 14 : 16,
                color: active
                    ? AppColors.primaryTeal
                    : AppColors.charcoalText.withOpacity(0.6),
              ),
              SizedBox(width: r.isNarrow ? 6 : 8),
              Text(
                label,
                style: r.bodyStyle(context, fontSize: 14).copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.charcoalText.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.isNarrow ? 8 : 10,
        vertical: r.isNarrow ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.accentOrange.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: r.labelStyle(context, fontSize: 11).copyWith(
          color: AppColors.charcoalText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterChipLabel extends StatelessWidget {
  const _FilterChipLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Chip(
      label: Text(
        label,
        style: r.labelStyle(context, fontSize: 11).copyWith(
          color: Colors.white,
        ),
      ),
      backgroundColor: AppColors.primaryTeal.withOpacity(0.85),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: const StadiumBorder(
        side: BorderSide(style: BorderStyle.none),
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: r.isNarrow ? 8 : 10),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final cardHeight = r.isNarrow ? 180.0 : 220.0;
    final circleSize = r.isNarrow ? 44.0 : 54.0;
    final innerCircle = r.isNarrow ? 36.0 : 44.0;
    final contentPadding = r.isNarrow ? 10.0 : 14.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(r.isNarrow ? 22 : 28),
      child: InkWell(
        borderRadius: BorderRadius.circular(r.isNarrow ? 22 : 28),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        },
        child: Container(
          height: cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.isNarrow ? 22 : 28),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r.isNarrow ? 22 : 28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  recipe.imageUrl,
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.65),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: r.isNarrow ? 10 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: r.titleStyle(context, fontSize: 15).copyWith(
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: r.isNarrow ? 4 : 6),
                          Wrap(
                            spacing: r.isNarrow ? 4 : 6,
                            runSpacing: 2,
                            children: recipe.tags
                                .map(
                                  (t) => Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: r.isNarrow ? 6 : 8,
                                      vertical: r.isNarrow ? 3 : 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      t,
                                      style: r.labelStyle(context, fontSize: 10).copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: circleSize,
                            height: circleSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  AppColors.primaryTeal.withOpacity(0.35),
                                  AppColors.primaryTeal.withOpacity(0.95),
                                  AppColors.primaryTeal.withOpacity(0.35),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: innerCircle,
                                height: innerCircle,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: Center(
                                  child: Text(
                                    '${(recipe.matchPercentage * 100).round()}%',
                                    style: r.labelStyle(context, fontSize: 12).copyWith(
                                      color: AppColors.primaryTeal,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: r.isNarrow ? 8 : 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Pantry match',
                                  style: r.bodySmallStyle(context, fontSize: 11).copyWith(
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${recipe.ownedIngredients}/${recipe.totalIngredients} ingredients already at home.',
                                  style: r.bodySmallStyle(context, fontSize: 11).copyWith(
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(
          begin: 0.08,
          end: 0,
          curve: Curves.easeOutCubic,
        );
  }
}

