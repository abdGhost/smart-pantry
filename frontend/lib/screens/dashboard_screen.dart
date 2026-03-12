import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../models/food_item_model.dart';
import '../providers/pantry_provider.dart';
import '../widgets/pantry_item_tile.dart';
import '../widgets/recipe_card.dart';
import '../widgets/scan_action_button.dart';
import 'recipe_results_screen.dart';
import 'recipe_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  static const routeName = '/';

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _loadedUserId;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(userIdProvider);

    // Wait for per-device user ID so each installation has its own data.
    if (userId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.creamBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Load pantry once when this user ID is ready.
    if (_loadedUserId != userId) {
      _loadedUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pantryNotifierProvider(userId).notifier).loadPantry();
      });
    }

    final recipesAsync = ref.watch(dashboardRecipesProvider);
    final pantryState = ref.watch(pantryNotifierProvider(userId));
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isNarrow = screenWidth < 400;
    final horizontalPadding = isNarrow ? 16.0 : 20.0;
    final appBarHeight = isNarrow ? 120.0 : 150.0;
    final recipeCardWidth = screenWidth * (isNarrow ? 0.72 : 0.78).clamp(200.0, 260.0);
    final recipeCardHeight = isNarrow ? 280.0 : 330.0;

    final expiringItems = _computeExpiringSoon(pantryState.items);
    final expiringCount = expiringItems.length;
    final pantryCount = pantryState.items.length;
    final recipesCount = recipesAsync.maybeWhen(
      data: (r) => r.length,
      orElse: () => 0,
    );

    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS;

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, isNarrow ? 8 : 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryTeal.withOpacity(0.12),
                    AppColors.accentOrange.withOpacity(0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isNarrow ? 20 : 28),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 12 : 16,
                vertical: isNarrow ? 10 : 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Good Morning, Chef Alex',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: isNarrow ? 15 : null,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isNarrow ? 2 : 4),
                        Text(
                          'You have $expiringCount items to enjoy soon.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.charcoalText
                                    .withOpacity(0.75),
                                fontSize: isNarrow ? 11 : null,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isNarrow ? 6 : 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _StatChip(
                              icon: isIOS
                                  ? CupertinoIcons.square_stack_3d_down_right
                                  : Icons.kitchen_rounded,
                              label: 'Pantry',
                              value: pantryCount.toString(),
                              compact: isNarrow,
                            ),
                            _StatChip(
                              icon: isIOS
                                  ? CupertinoIcons.flame
                                  : Icons.local_dining_rounded,
                              label: 'Recipes',
                              value: recipesCount.toString(),
                              compact: isNarrow,
                            ),
                            _StatChip(
                              icon: isIOS
                                  ? CupertinoIcons.timer
                                  : Icons.schedule_rounded,
                              label: 'Expiring',
                              value: expiringCount.toString(),
                              compact: isNarrow,
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
      ),
      floatingActionButton: const ScanActionButton(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 96),
          children: [
            SizedBox(height: isNarrow ? 6 : 8),
            _SectionHeader(
              title: 'Tonight\'s inspiration',
              subtitle: 'Recipes you can cook with what you have.',
              horizontalPadding: horizontalPadding,
              onViewAll: () {
                Navigator.of(context).pushNamed(
                  RecipeResultsScreen.routeName,
                );
              },
            ),
            SizedBox(height: isNarrow ? 12 : 16),
            SizedBox(
              height: recipeCardHeight,
              child: recipesAsync.when(
                data: (recipes) {
                  if (recipes.isEmpty) {
                    return Center(
                      child: Text(
                        'No recipes yet. Add pantry items for suggestions.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }
                  return CarouselSlider.builder(
                    itemCount: recipes.length,
                    itemBuilder: (context, index, realIndex) {
                      final recipe = recipes[index];
                      return RecipeCard(
                        recipe: recipe,
                        width: recipeCardWidth,
                        height: recipeCardHeight,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RecipeDetailScreen(recipe: recipe),
                            ),
                          );
                        },
                      );
                    },
                    options: CarouselOptions(
                      height: recipeCardHeight,
                      viewportFraction: isNarrow ? 0.82 : 0.78,
                      enlargeCenterPage: true,
                      enableInfiniteScroll: recipes.length > 1,
                      padEnds: false,
                    ),
                  );
                },
                loading: () => CarouselSlider.builder(
                  itemCount: 3,
                  itemBuilder: (context, index, realIndex) => RecipeCardShimmer(
                    width: recipeCardWidth,
                    height: recipeCardHeight,
                  ),
                  options: CarouselOptions(
                    height: recipeCardHeight,
                    viewportFraction: isNarrow ? 0.82 : 0.78,
                    enlargeCenterPage: true,
                    enableInfiniteScroll: false,
                    padEnds: false,
                  ),
                ),
                error: (_, __) => Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Text(
                      'Couldn\'t load recipes.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: isNarrow ? 20 : 24),
            Padding(
              padding: EdgeInsets.only(right: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expiring soon',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  if (pantryState.isLoading && pantryState.items.isEmpty)
                    Column(
                      children: List.generate(
                        3,
                        (index) => const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: PantryItemTileShimmer(),
                        ),
                      ),
                    )
                  else if (expiringItems.isEmpty)
                    Text(
                      'No pantry items yet. Scan a receipt to get started.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Column(
                      children: expiringItems.take(10).map((FoodItem item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PantryItemTile(
                            item: item,
                            onDelete: () async {
                              final id = int.tryParse(item.id);
                              if (id == null) return;
                              final notifier = ref.read(
                                pantryNotifierProvider(userId).notifier,
                              );
                              final ok = await notifier.deleteItem(id);
                              if (!mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Removed ${item.name} from pantry',
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Could not remove ${item.name}. Check connection and try again.',
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                );
                              }
                            },
                          )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(
                                begin: 0.08,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

List<FoodItem> _computeExpiringSoon(List<PantryItem> items) {
  if (items.isEmpty) return [];

  final now = DateTime.now();

  // Map all pantry items into FoodItem view models, sort by soonest expiry.
  final mapped = items.map((p) {
    final expiry = p.expiryDate ??
        now.add(
          Duration(days: p.estimatedExpiryDays ?? 365),
        );
    final rawDaysLeft = expiry.difference(now).inDays;
    final clampedDaysLeft = rawDaysLeft.clamp(0, 365 * 5);

    return FoodItem(
      id: p.id.toString(),
      name: p.itemName,
      daysLeft: clampedDaysLeft,
      category: p.category ?? 'Pantry',
      expiryDate: expiry,
    );
  }).toList();

  mapped.sort((a, b) {
    final aDate = a.expiryDate ?? now.add(Duration(days: a.daysLeft));
    final bDate = b.expiryDate ?? now.add(Duration(days: b.daysLeft));
    return aDate.compareTo(bDate);
  });

  return mapped;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.horizontalPadding = 20,
    this.onViewAll,
  });

  final String title;
  final String subtitle;
  final double horizontalPadding;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(right: horizontalPadding),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.charcoalText.withOpacity(0.75),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text('View all'),
            ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primaryTeal.withOpacity(0.95),
            AppColors.primaryTeal.withOpacity(0.75),
          ],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 12 : 14,
            color: Colors.white,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            value,
            style: (compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(width: compact ? 1 : 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: compact ? 10 : null,
            ),
          ),
        ],
      ),
    );
  }
}

