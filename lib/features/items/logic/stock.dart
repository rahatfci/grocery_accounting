import 'item.dart';
import 'item_unit.dart';

/// The locked stock contract, which features 3, 5, 6 and 7 all depend on:
///
/// ```
/// currentStock = stockAtBaseline - dailyUsage * daysSince(baselineDate)
/// ```
///
/// Stock is never stored as a live number. Every purchase, consumption event
/// and recount writes a fresh `stockAtBaseline` and `baselineDate` pair, so the
/// value is correct whether the app was opened or not, and it works offline.
///
/// [now] is passed in rather than read here, so the result is deterministic and
/// testable.
double currentStock(Item item, {required DateTime now}) =>
    item.stockAtBaseline - item.dailyUsage * daysSince(item.baselineDate, now);

/// Fractional days elapsed, floored at zero.
///
/// A baseline in the future consumes nothing rather than crediting stock, which
/// is what a clock skew between two phones would otherwise do.
double daysSince(DateTime baselineDate, DateTime now) {
  final elapsed = now.difference(baselineDate).inMilliseconds;
  return elapsed <= 0 ? 0 : elapsed / Duration.millisecondsPerDay;
}

/// The baseline to write after buying [quantity] of [item], already converted
/// into the item's own unit.
///
/// Current stock is clamped at zero first. A staple that ran out three days ago
/// computes negative, and adding a kilo to a negative would credit less than
/// the kilo that was actually bought.
double restockedBaseline(Item item, double quantity, {required DateTime now}) {
  final stock = currentStock(item, now: now);
  return (stock < 0 ? 0 : stock) + quantity;
}

/// Stock as a member reads it: `3.5 kg`, `0 pcs`.
///
/// A derived stock past empty is shown as zero. The negative value is still
/// what the formula returns, and what later features compare against.
///
/// A non-finite value reads as unknown, and no value is scaled or converted
/// to an int on the way, so no stored number, however large, can throw here
/// and take down the screen that recounts it.
String formatStock(double stock, ItemUnit unit) {
  if (!stock.isFinite) {
    return 'Unknown';
  }
  if (stock <= 0) {
    return '0 ${unit.label}';
  }
  final fixed = stock.toStringAsFixed(2);
  // Values that round to zero print as `0.00`, and values from 1e21 print in
  // exponent form, which has no trailing zeros to trim.
  final trimmed = fixed.contains('e')
      ? fixed
      : fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  return '${trimmed.isEmpty ? '0' : trimmed} ${unit.label}';
}
