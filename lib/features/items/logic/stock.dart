import 'item.dart';

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
