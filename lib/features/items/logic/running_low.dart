import 'package:equatable/equatable.dart';

import 'item.dart';
import 'stock.dart';

/// An item under its low threshold, with the stock it was judged on.
final class LowStockItem extends Equatable {
  const LowStockItem({required this.item, required this.stock});

  final Item item;
  final double stock;

  @override
  List<Object?> get props => [item, stock];
}

/// The running low rule for one stock level: strictly below the threshold,
/// and never for a stock or threshold that is not a number.
bool isBelowThreshold(double stock, double threshold) =>
    stock.isFinite && threshold.isFinite && stock < threshold;

/// Every item whose derived stock is strictly below its low threshold.
///
/// Calculated, never stored: a restock lifts the stock and the item drops out
/// on its own. A non-finite stock or threshold is left out: the catalogue shows
/// such a stock as unknown, and an unknown is not a shortage.
///
/// Anything already out comes first, then the rest by name.
List<LowStockItem> runningLow(List<Item> items, {required DateTime now}) {
  final low = [
    for (final (index, item) in items.indexed)
      if (currentStock(item, now: now) case final stock
          when isBelowThreshold(stock, item.lowThreshold))
        (index: index, entry: LowStockItem(item: item, stock: stock)),
  ];

  // `List.sort` is not stable, so the input position breaks the last tie.
  low.sort((a, b) {
    final out = _outRank(a.entry) - _outRank(b.entry);
    if (out != 0) {
      return out;
    }
    final byName = a.entry.item.name.toLowerCase().compareTo(
      b.entry.item.name.toLowerCase(),
    );
    return byName != 0 ? byName : a.index - b.index;
  });
  return [for (final ranked in low) ranked.entry];
}

int _outRank(LowStockItem low) => low.stock <= 0 ? 0 : 1;
