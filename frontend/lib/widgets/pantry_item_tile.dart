import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../core/colors.dart';
import '../core/responsive.dart';
import '../models/food_item_model.dart';

class PantryItemTile extends StatelessWidget {
  const PantryItemTile({
    super.key,
    required this.item,
    this.onDelete,
  });

  final FoodItem item;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final r = Responsive.of(context);

    IconData icon;
    switch (item.category.toLowerCase()) {
      case 'fruit':
        icon = isIOS
            ? CupertinoIcons.leaf_arrow_circlepath
            : Icons.local_florist_rounded;
        break;
      case 'dairy':
        icon = isIOS ? CupertinoIcons.cube_box : Icons.icecream_outlined;
        break;
      default:
        icon = isIOS ? CupertinoIcons.cart : Icons.local_grocery_store_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(r.isNarrow ? 16 : 20),
        onTap: () {},
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.isNarrow ? 10 : 12,
            vertical: r.isNarrow ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.isNarrow ? 16 : 20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.primaryTeal.withOpacity(0.12),
                AppColors.primaryTeal.withOpacity(0.04),
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showBadge = constraints.maxWidth > 140;
              final showDelete = onDelete != null;

              return Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(r.isNarrow ? 6 : 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(r.isNarrow ? 12 : 16),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.primaryTeal,
                      size: r.isNarrow ? 18 : 20,
                    ),
                  ),
                  SizedBox(width: r.isNarrow ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: r.bodyStyle(context, fontSize: 15).copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.charcoalText,
                          ),
                        ),
                        SizedBox(height: r.isNarrow ? 1 : 2),
                        Builder(
                          builder: (context) {
                            final now = DateTime.now();
                            final hasExpiry = item.expiryDate != null;
                            final isExpired = hasExpiry &&
                                item.expiryDate!
                                    .isBefore(now);

                            String label;
                            Color color;

                            if (isExpired) {
                              label = 'Expired';
                              color = Colors.redAccent;
                            } else {
                              final days = item.daysLeft;
                              if (days <= 0) {
                                label = 'Today';
                              } else if (days == 1) {
                                label = '1 day left';
                              } else {
                                label = '$days days left';
                              }
                              color = AppColors.charcoalText.withOpacity(0.7);
                            }

                            final datePart = hasExpiry
                                ? '${DateFormat.yMMMd().format(item.expiryDate!)}, ${DateFormat.jm().format(item.expiryDate!)}'
                                : null;

                            final text = datePart != null
                                ? '$label · $datePart'
                                : label;

                            return Text(
                              text,
                              style: r.bodySmallStyle(context, fontSize: 11).copyWith(
                                color: color,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (showBadge) ...[
                    SizedBox(width: r.isNarrow ? 6 : 8),
                    FittedBox(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.isNarrow ? 8 : 10,
                          vertical: r.isNarrow ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppColors.accentOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Expiring',
                          style: r.labelStyle(context, fontSize: 10).copyWith(
                            color: AppColors.accentOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (showDelete) ...[
                    if (showBadge) SizedBox(width: r.isNarrow ? 2 : 4),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: r.isNarrow ? 16 : 18,
                        color: Colors.redAccent,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class PantryItemTileShimmer extends StatelessWidget {
  const PantryItemTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Shimmer.fromColors(
      baseColor: AppColors.primaryTeal.withOpacity(0.08),
      highlightColor: AppColors.creamBackground.withOpacity(0.95),
      child: Container(
        height: r.isNarrow ? 56 : 62,
        decoration: BoxDecoration(
          color: AppColors.creamBackground,
          borderRadius: BorderRadius.circular(r.isNarrow ? 16 : 20),
        ),
      ),
    );
  }
}

