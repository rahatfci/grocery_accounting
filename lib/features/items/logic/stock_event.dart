import 'package:equatable/equatable.dart';

import '../../purchases/logic/quantity_conversion.dart';
import 'item.dart';
import 'item_unit.dart';
import 'item_validation.dart';
import 'stock.dart';

/// What a stock event does to an item's stock.
enum StockEventType {
  /// Some of the item was used. Subtracts.
  consumed('consumed'),

  /// A correction for an event, in either direction. Adds its signed quantity.
  adjustment('adjustment'),

  /// The item was counted. Replaces the stock outright.
  recount('recount');

  const StockEventType(this.key);

  /// Stored in Firestore. Stable, so the enum can be renamed without a
  /// migration.
  final String key;
}

/// One change to an item's stock, as the member entered it.
final class StockEvent extends Equatable {
  const StockEvent({
    required this.itemId,
    required this.type,
    required this.quantity,
    required this.unit,
    required this.userId,
    this.note,
  });

  final String itemId;
  final StockEventType type;

  /// In [unit], which need not be the item's own. Negative only for an
  /// [StockEventType.adjustment] that removes stock, so the audit trail keeps
  /// the direction without a separate field.
  final double quantity;

  final ItemUnit unit;
  final String userId;

  /// Trimmed, and null rather than empty.
  final String? note;

  @override
  List<Object?> get props => [itemId, type, quantity, unit, userId, note];
}

/// The `stockAtBaseline` to write after [event], or null when [event.unit]
/// cannot be converted into [item]'s unit or the result is not finite.
///
/// A negative derived stock is clamped to zero first, as [restockedBaseline]
/// does, and so is the result: using more than the estimate means the estimate
/// was low, not that the kitchen holds negative rice.
double? baselineAfter(Item item, StockEvent event, {required DateTime now}) {
  final quantity = convertToItemUnit(event.quantity.abs(), event.unit, item);
  if (quantity == null) {
    return null;
  }
  final stock = currentStock(item, now: now);
  // A non-finite stored stock compares false both ways, so it is reset here
  // rather than carried into the new baseline.
  final start = !stock.isFinite || stock < 0 ? 0.0 : stock;

  final after = switch (event.type) {
    StockEventType.consumed => start - quantity,
    StockEventType.adjustment =>
      event.quantity < 0 ? start - quantity : start + quantity,
    StockEventType.recount => quantity,
  };
  // A finite but huge entry, or one multiplied up by a kg to g conversion, can
  // overflow to infinity. That is refused rather than written to the item.
  if (!after.isFinite) {
    return null;
  }
  return after < 0 ? 0 : after;
}

/// The quantity field's error for [type], or null when [raw] is acceptable.
///
/// A recount can be zero, because "we have none" is a real count. The other
/// two must move stock, so zero is refused.
String? stockEventQuantityError(StockEventType type, String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return 'Enter a number';
  }
  final parsed = parseDecimal(text);
  // `double.tryParse` accepts `NaN` and `Infinity`, and either would be
  // written to the shared item as its stock.
  if (parsed == null || !parsed.isFinite) {
    return 'Enter a valid number';
  }
  return switch (type) {
    StockEventType.recount when parsed < 0 => 'Cannot be negative',
    StockEventType.consumed ||
    StockEventType.adjustment when parsed <= 0 => 'Must be greater than zero',
    _ => null,
  };
}
