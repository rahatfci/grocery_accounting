import 'package:equatable/equatable.dart';

import '../../purchases/logic/purchase.dart';
import '../../purchases/logic/quantity_conversion.dart';
import 'item.dart';
import 'item_unit.dart';
import 'stock_event.dart';

enum HistoryKind { purchase, use, adjustment, recount }

/// One thing that moved an item's stock, as its history lists it.
final class HistoryEntry extends Equatable {
  const HistoryEntry({
    required this.kind,
    required this.date,
    required this.userId,
    required this.quantity,
    required this.unit,
    this.note,
    this.shopName,
  });

  final HistoryKind kind;
  final DateTime date;

  /// Who recorded it, or who paid for a purchase.
  final String userId;

  /// Signed: what a purchase or an adding adjustment put in is positive,
  /// what a use or a removing adjustment took out is negative. A recount is
  /// the amount counted.
  final double quantity;

  final ItemUnit unit;
  final String? note;

  /// Where a purchase was made.
  final String? shopName;

  @override
  List<Object?> get props => [
    kind,
    date,
    userId,
    quantity,
    unit,
    note,
    shopName,
  ];
}

/// Everything that moved [item]'s stock, newest first: its recorded stock
/// events, and the purchases that restocked it.
///
/// Quantities are shown in the item's own unit when they convert, so the
/// history reads in the same unit as the stock above it.
List<HistoryEntry> itemHistory({
  required Item item,
  required Iterable<StockEventRecord> events,
  required Iterable<Purchase> purchases,
}) {
  final entries = [
    for (final record in events)
      if (record.event.itemId == item.id) _fromEvent(item, record),
    for (final purchase in purchases) ?_fromPurchase(item, purchase),
  ]..sort((a, b) => b.date.compareTo(a.date));
  return entries;
}

HistoryEntry _fromEvent(Item item, StockEventRecord record) {
  final event = record.event;
  final (quantity, unit) = _inItemUnit(item, event.quantity.abs(), event.unit);
  final (kind, signed) = switch (event.type) {
    StockEventType.consumed => (HistoryKind.use, -quantity),
    StockEventType.adjustment => (
      HistoryKind.adjustment,
      event.quantity < 0 ? -quantity : quantity,
    ),
    StockEventType.recount => (HistoryKind.recount, quantity),
  };
  return HistoryEntry(
    kind: kind,
    date: record.date,
    userId: event.userId,
    quantity: signed,
    unit: unit,
    note: event.note,
  );
}

/// A purchase's lines for [item], summed. Null when it has none, which the
/// query should never return but a stale local cache can.
HistoryEntry? _fromPurchase(Item item, Purchase purchase) {
  final lines = purchase.lines.where((line) => line.itemId == item.id);
  if (lines.isEmpty) {
    return null;
  }
  final converted = [
    for (final line in lines) convertToItemUnit(line.quantity, line.unit, item),
  ];
  // Lines recorded before the item's unit changed cannot be added up in the
  // new one, so the first is shown as it was entered instead.
  final (quantity, unit) = converted.every((quantity) => quantity != null)
      ? (converted.fold<double>(0, (sum, q) => sum + (q ?? 0)), item.unit)
      : (lines.first.quantity, lines.first.unit);
  final shop = purchase.shopName.trim();
  return HistoryEntry(
    kind: HistoryKind.purchase,
    date: purchase.date,
    userId: purchase.paidByUserId,
    quantity: quantity,
    unit: unit,
    shopName: shop.isEmpty ? null : shop,
  );
}

/// [quantity] in [item]'s unit when it converts, otherwise as it was entered,
/// for a line recorded before the item's unit was changed.
(double, ItemUnit) _inItemUnit(Item item, double quantity, ItemUnit from) {
  final converted = convertToItemUnit(quantity, from, item);
  return converted == null ? (quantity, from) : (converted, item.unit);
}
