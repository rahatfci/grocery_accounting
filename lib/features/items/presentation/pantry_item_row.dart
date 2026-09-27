import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_tile.dart';
import '../logic/item.dart';
import '../logic/stock.dart';
import '../logic/stock_labels.dart';
import '../logic/stock_status.dart';
import 'category_icons.dart';

/// The Figma Row / Pantry item: the item, how fast it goes, and its derived
/// stock with where that leaves it. Tap opens the item.
class PantryItemRow extends StatelessWidget {
  const PantryItemRow({
    required this.item,
    required this.now,
    required this.onTap,
    super.key,
  });

  final Item item;

  /// The instant every row on screen derives its stock at.
  final DateTime now;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = stockStatusOf(item, now: now);
    final urgent = status == StockStatus.low || status == StockStatus.out;
    final statusColor = switch (status) {
      StockStatus.low || StockStatus.out => AppColors.negative,
      StockStatus.soon => AppColors.warning,
      StockStatus.healthy || StockStatus.untracked => AppColors.textTertiary,
    };

    return AppRow(
      onTap: onTap,
      leading: IconTile(icon: categoryIcon(item.category)),
      body: RowText(
        title: item.name,
        subtitle: usageLabel(item),
        titleStyle: text.bodyLargeStrong,
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatStock(currentStock(item, now: now), item.unit),
            style: text.bodyLargeStrong.copyWith(
              color: urgent ? AppColors.negative : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpace.s2),
          Text(
            statusLabel(item, status, now: now),
            style: (urgent ? text.labelMedium : text.bodySmall)?.copyWith(
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
