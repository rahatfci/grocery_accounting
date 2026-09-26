import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../../core/widgets/level_bar.dart';
import '../../../core/widgets/status_tag.dart';
import '../../items/logic/running_low.dart';
import '../../items/logic/stock.dart';
import '../../items/logic/stock_status.dart';
import '../../items/presentation/category_icons.dart';

/// The Figma Row / Running low: an item under its threshold, how far under,
/// and whether it is on the shopping list yet.
class LowStockRow extends StatelessWidget {
  const LowStockRow({
    required this.low,
    required this.now,
    required this.onList,
    required this.onAddToList,
    this.onTap,
    super.key,
  });

  final LowStockItem low;

  /// The instant [low] was judged at.
  final DateTime now;

  /// Already on the shopping list, so there is nothing to add.
  final bool onList;

  final VoidCallback onAddToList;

  /// Opens the item.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final item = low.item;
    final out = low.stock <= 0;

    return AppRow(
      onTap: onTap,
      leading: IconTile(icon: categoryIcon(item.category)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyLargeStrong,
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            _detail(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpace.s4),
          LevelBar(
            value: stockLevel(low.stock, item.lowThreshold),
            color: AppColors.dataNegative,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusTag(label: out ? 'Out' : 'Low', tone: Tone.negative),
          const SizedBox(width: AppSpace.s8),
          onList
              ? Semantics(
                  label: '${item.name} is on the shopping list',
                  child: const IconTile(
                    icon: Symbols.check_rounded,
                    circle: true,
                    iconSize: 20,
                    background: AppColors.brandSubtle,
                    color: AppColors.brand,
                  ),
                )
              : RoundIconButton(
                  icon: Symbols.add_shopping_cart_rounded,
                  tooltip: 'Add ${item.name} to the list',
                  onPressed: onAddToList,
                ),
        ],
      ),
    );
  }

  String _detail() {
    final item = low.item;
    if (low.stock > 0) {
      return '${formatStock(low.stock, item.unit)} left · low below '
          '${formatStock(item.lowThreshold, item.unit)}';
    }
    final since = outSince(item, now: now);
    return since == null
        ? 'Nothing left'
        : 'Out since ${formatDayMonth(since)}';
  }
}
