import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_tile.dart';
import '../../members/logic/household.dart';
import '../../purchases/logic/money.dart';
import '../logic/item_history.dart';
import '../logic/stock.dart';
import '../logic/stock_labels.dart';

/// The Figma Row / Activity: one thing that moved an item's stock, who did
/// it and when.
class HistoryRow extends StatelessWidget {
  const HistoryRow({required this.entry, required this.household, super.key});

  final HistoryEntry entry;
  final Household household;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (icon, tile, iconColor) = switch (entry.kind) {
      HistoryKind.purchase => (
        Symbols.shopping_basket_rounded,
        AppColors.positiveSubtle,
        AppColors.positive,
      ),
      HistoryKind.use => (
        Symbols.restaurant_rounded,
        AppColors.negativeSubtle,
        AppColors.negative,
      ),
      HistoryKind.adjustment => (
        Symbols.tune_rounded,
        AppColors.subtle,
        AppColors.iconPrimary,
      ),
      HistoryKind.recount => (
        Symbols.checklist_rounded,
        AppColors.brandSubtle,
        AppColors.brand,
      ),
    };
    final (amount, amountColor) = entry.kind == HistoryKind.recount
        ? (
            '= ${formatStock(entry.quantity, entry.unit)}',
            AppColors.textPrimary,
          )
        : (
            formatStockChange(entry.quantity, entry.unit),
            entry.quantity < 0 ? AppColors.negative : AppColors.positive,
          );

    return AppRow(
      leading: IconTile(
        icon: icon,
        size: 36,
        iconSize: 20,
        circle: true,
        background: tile,
        color: iconColor,
      ),
      body: RowText(
        title: _title(),
        subtitle:
            '${household.nameOf(entry.userId)} · '
            '${formatPurchaseDate(entry.date)}',
        titleStyle: text.bodyMediumStrong,
      ),
      trailing: Text(
        amount,
        style: text.bodyMediumStrong.copyWith(color: amountColor),
      ),
    );
  }

  String _title() {
    final note = entry.note;
    final base = switch (entry.kind) {
      HistoryKind.purchase => switch (entry.shopName) {
        final shop? => 'Bought at $shop',
        null => 'Bought',
      },
      HistoryKind.use => 'Logged use',
      HistoryKind.adjustment => 'Adjusted',
      HistoryKind.recount => 'Recounted',
    };
    return note == null ? base : '$base: $note';
  }
}
