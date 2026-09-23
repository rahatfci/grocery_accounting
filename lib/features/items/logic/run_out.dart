import 'item.dart';

/// Further out than this, a staple has no run-out date. It keeps the
/// `Duration` below overflow, and a reminder a year away is not useful.
const int maxRunOutDays = 366;

/// The instant a staple's derived stock reaches zero, or null when it has no
/// predictable one.
///
/// Solved from the locked formula in stock.dart, so it moves only when the
/// baseline or the usage does, never with the clock. Anything that is not a
/// staple (`dailyUsage <= 0`) never runs out on its own.
DateTime? runOutAt(Item item) {
  final usage = item.dailyUsage;
  final stock = item.stockAtBaseline;
  if (!usage.isFinite || !stock.isFinite || usage <= 0) {
    return null;
  }
  final days = stock / usage;
  if (days > maxRunOutDays) {
    return null;
  }
  final milliseconds = (days * Duration.millisecondsPerDay).round();
  return item.baselineDate.add(Duration(milliseconds: milliseconds));
}
