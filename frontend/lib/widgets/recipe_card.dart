import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../core/colors.dart';
import '../core/responsive.dart';
import '../models/recipe_model.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.width,
    this.height = 320,
    this.showMatchCircle = false,
    this.onTap,
  });

  final Recipe recipe;
  /// If null, defaults to 260. Use a smaller value on narrow screens for responsiveness.
  final double? width;
  final double height;
  final bool showMatchCircle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final r = Responsive.of(context);
    final radius = r.isNarrow ? 20.0 : 28.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
          child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            width: width ?? 260,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: AppColors.primaryTeal.withOpacity(0.15),
              image: recipe.imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(recipe.imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Stack(
              children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
              ),
              if (showMatchCircle)
                Positioned(
                  top: r.isNarrow ? 12 : 16,
                  right: r.isNarrow ? 12 : 16,
                  child: Container(
                    padding: EdgeInsets.all(r.isNarrow ? 8 : 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(recipe.matchPercentage * 100).round()}%',
                          style: r.titleStyle(context, fontSize: r.isNarrow ? 16 : 18).copyWith(
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Match',
                          style: r.labelStyle(context, fontSize: 9).copyWith(
                            color: AppColors.charcoalText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: r.isNarrow ? 12 : 18,
                right: r.isNarrow ? 12 : 18,
                bottom: r.isNarrow ? 12 : 18,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r.isNarrow ? 16 : 22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: EdgeInsets.all(r.isNarrow ? 10 : 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(r.isNarrow ? 16 : 22),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  recipe.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: r.bodyStyle(context, fontSize: r.isNarrow ? 14 : 16).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: r.isNarrow ? 4 : 6),
                                Container(
                                  constraints: BoxConstraints(maxWidth: r.isNarrow ? 140 : 180),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: r.isNarrow ? 8 : 10,
                                    vertical: r.isNarrow ? 3 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentOrange
                                        .withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${recipe.ownedIngredients}/${recipe.totalIngredients} ingredients',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: r.labelStyle(context, fontSize: 10).copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: r.isNarrow ? 6 : 10),
                          Icon(
                            isIOS
                                ? CupertinoIcons.chevron_right
                                : Icons.chevron_right_rounded,
                            size: r.isNarrow ? 20 : 24,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
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

class RecipeCardShimmer extends StatelessWidget {
  const RecipeCardShimmer({super.key, this.width, this.height = 320});
  final double? width;

  final double height;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.primaryTeal.withOpacity(0.10),
      highlightColor: AppColors.creamBackground.withOpacity(0.9),
      child: Container(
        width: width ?? 260,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.creamBackground,
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }
}

