import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_tile.dart';
import '../logic/money.dart';
import '../logic/purchase.dart';
import '../logic/purchase_labels.dart';
import '../logic/purchase_source.dart';
import 'purchase_detail_page.dart';

/// One saved purchase in a list: the shop, who paid, the total and whether
/// it came from a receipt. Opens the purchase.
class PurchaseRow extends StatelessWidget {
  const PurchaseRow({
    required this.purchase,
    required this.payerName,
    this.withDate = false,
    super.key,
  });

  final Purchase purchase;
  final String payerName;

  /// Shows the date too, where the list is not grouped by day.
  final bool withDate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scanned = purchase.source == PurchaseSource.scanned;
    final caption = text.bodySmall?.copyWith(color: AppColors.textTertiary);
    final shop = purchase.shopName.trim();

    return AppRow(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PurchaseDetailPage(purchaseId: purchase.id),
        ),
      ),
      leading: const IconTile(
        icon: Symbols.storefront_rounded,
        color: AppColors.iconSecondary,
      ),
      body: RowText(
        title: shop.isEmpty ? 'Unknown shop' : shop,
        subtitle: purchaseDetail(
          purchase,
          payerName: payerName,
          withDate: withDate,
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatEuro(purchase.total), style: text.bodyLargeStrong),
          const SizedBox(height: AppSpace.s2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (scanned) ...[
                const Icon(
                  Symbols.receipt_long_rounded,
                  size: 14,
                  color: AppColors.iconSecondary,
                ),
                const SizedBox(width: AppSpace.s4),
              ],
              Text(scanned ? 'Receipt' : 'Manual', style: caption),
            ],
          ),
        ],
      ),
    );
  }
}
