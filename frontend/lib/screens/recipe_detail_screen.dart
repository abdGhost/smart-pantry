import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/colors.dart';
import '../core/responsive.dart';
import '../models/recipe_model.dart';
import '../models/recipe_details_model.dart';
import '../providers/pantry_provider.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    final detailsAsync = ref.watch(recipeDetailsProvider(recipe));

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.charcoalText,
        leading: IconButton(
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          icon: Icon(isIOS ? CupertinoIcons.back : Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(recipe.title, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroHeader(recipe: recipe),
            SizedBox(height: Responsive.of(context).isNarrow ? 14 : 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.of(context).horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipe.tags.isNotEmpty) _TagsRow(recipe: recipe),
                  SizedBox(height: Responsive.of(context).isNarrow ? 14 : 18),
                  _AiStepsCard(detailsAsync: detailsAsync),
                  SizedBox(height: Responsive.of(context).isNarrow ? 16 : 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final inset = r.isNarrow ? 14.0 : 20.0;
    final circleOuter = r.isNarrow ? 52.0 : 62.0;
    final circleInner = r.isNarrow ? 42.0 : 50.0;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(r.isNarrow ? 24 : 32),
          bottomRight: Radius.circular(r.isNarrow ? 24 : 32),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (recipe.imageUrl.isNotEmpty)
              Image.network(
                recipe.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppColors.primaryTeal.withOpacity(0.12),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryTeal.withOpacity(0.25),
                          AppColors.primaryTeal.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      color: Colors.white.withOpacity(0.85),
                      size: r.isNarrow ? 48 : 56,
                    ),
                  );
                },
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryTeal.withOpacity(0.25),
                      AppColors.primaryTeal.withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: Colors.white.withOpacity(0.85),
                  size: r.isNarrow ? 48 : 56,
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),
            Positioned(
              left: inset,
              right: inset,
              bottom: inset,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: circleOuter,
                    height: circleOuter,
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
                        width: circleInner,
                        height: circleInner,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Center(
                          child: Text(
                            '${(recipe.matchPercentage * 100).round()}%',
                            style: r.titleStyle(context, fontSize: r.isNarrow ? 14 : 16).copyWith(
                              color: AppColors.primaryTeal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: r.isNarrow ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: r.titleStyle(context, fontSize: r.isNarrow ? 14 : 16).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: r.isNarrow ? 2 : 4),
                        Text(
                          '${recipe.ownedIngredients}/${recipe.totalIngredients} ingredients already at home',
                          style: r.bodySmallStyle(context, fontSize: 11).copyWith(
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagsRow extends StatelessWidget {
  const _TagsRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Wrap(
      spacing: r.isNarrow ? 6 : 8,
      runSpacing: 4,
      children: recipe.tags.map((t) {
        final lower = t.toLowerCase();
        final isHighlight =
            lower == 'dinner' || lower == 'chicken' || lower == 'comfort';

        final Color bgColor = isHighlight
            ? AppColors.primaryTeal.withOpacity(0.18)
            : AppColors.creamBackground.withOpacity(0.95);
        final Color textColor = isHighlight
            ? Colors.white
            : AppColors.charcoalText.withOpacity(0.85);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.isNarrow ? 8 : 10,
            vertical: r.isNarrow ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            t,
            style: r.labelStyle(context, fontSize: 11).copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AiStepsCard extends StatelessWidget {
  const _AiStepsCard({required this.detailsAsync});

  final AsyncValue<RecipeDetails> detailsAsync;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final cardPadding = r.isNarrow ? 14.0 : 18.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(cardPadding, cardPadding, cardPadding, r.isNarrow ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r.isNarrow ? 20 : 24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryTeal.withOpacity(0.14),
            AppColors.accentOrange.withOpacity(0.08),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: detailsAsync.when(
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asking AI for cooking steps...',
              style: r.bodySmallStyle(context, color: AppColors.charcoalText.withOpacity(0.9)),
            ),
            SizedBox(height: r.isNarrow ? 6 : 8),
            const LinearProgressIndicator(minHeight: 4),
            SizedBox(height: r.isNarrow ? 18 : 24),
          ],
        ),
        error: (err, stack) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI steps are not available right now.',
              style: r.bodySmallStyle(context, color: Colors.red.shade700),
            ),
            SizedBox(height: r.isNarrow ? 18 : 24),
          ],
        ),
        data: (details) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart cooking guide',
              style: r.titleStyle(context, fontSize: 14),
            ),
            SizedBox(height: r.isNarrow ? 4 : 6),
            Text(
              details.summary,
              style: r.bodySmallStyle(context, color: AppColors.charcoalText.withOpacity(0.9)),
            ),
            SizedBox(height: r.isNarrow ? 10 : 12),
            Row(
              children: [
                _Pill(
                  icon: Icons.schedule_rounded,
                  label: '${details.estimatedTimeMinutes} min',
                ),
                SizedBox(width: r.isNarrow ? 6 : 8),
                _Pill(icon: Icons.whatshot_rounded, label: details.difficulty),
              ],
            ),
            SizedBox(height: r.isNarrow ? 14 : 18),
            Text(
              'Steps',
              style: r.titleStyle(context, fontSize: 14),
            ),
            SizedBox(height: r.isNarrow ? 6 : 8),
            ...details.steps.map(
              (s) => Padding(
                padding: EdgeInsets.symmetric(vertical: r.isNarrow ? 4 : 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: r.isNarrow ? 22 : 26,
                      height: r.isNarrow ? 22 : 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryTeal.withOpacity(0.1),
                      ),
                      child: Center(
                        child: Text(
                          '${s.order}',
                          style: r.labelStyle(context, fontSize: 11).copyWith(
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: r.isNarrow ? 10 : 12),
                    Expanded(
                      child: Text(
                        s.text,
                        style: r.bodyStyle(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (details.tips.isNotEmpty) ...[
              SizedBox(height: r.isNarrow ? 12 : 16),
              Text(
                'Tips from your AI chef',
                style: r.titleStyle(context, fontSize: 14),
              ),
              SizedBox(height: r.isNarrow ? 4 : 6),
              ...details.tips.map(
                (t) => Padding(
                  padding: EdgeInsets.symmetric(vertical: r.isNarrow ? 3 : 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_rounded,
                        size: r.isNarrow ? 16 : 18,
                        color: AppColors.accentOrange,
                      ),
                      SizedBox(width: r.isNarrow ? 6 : 8),
                      Expanded(
                        child: Text(t, style: r.bodySmallStyle(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(height: r.isNarrow ? 18 : 24),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.isNarrow ? 8 : 10,
        vertical: r.isNarrow ? 5 : 6,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.isNarrow ? 14 : 16, color: Colors.white),
          SizedBox(width: r.isNarrow ? 4 : 6),
          Text(
            label,
            style: r.bodySmallStyle(context, fontSize: 11).copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
