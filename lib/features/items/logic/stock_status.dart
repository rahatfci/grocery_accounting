import 'item.dart';
import 'run_out.dart';
import 'running_low.dart';
import 'stock.dart';

/// Where an item stands, as the pantry colours it.
enum StockStatus {
  /// A staple with more than [soonWindow] left.
  healthy,

  /// A staple that runs out within [soonWindow], though it is not low yet.
  soon,

  /// Under its low threshold.
  low,

  /// Nothing left.
  out,

  /// Not a staple, so there is no run-out date to judge, or the stock is not
  /// a number.
  untracked,
}

/// How far ahead a staple's run-out date counts as soon.
const Duration soonWindow = Duration(days: 7);

/// Where [item] stands at [now]. Out and low come before the run-out date: an
/// item under its threshold is low however long it would still last.
StockStatus stockStatusOf(Item item, {required DateTime now}) {
  final stock = currentStock(item, now: now);
  if (!stock.isFinite) {
    return StockStatus.untracked;
  }
  if (stock <= 0) {
    return StockStatus.out;
  }
  if (isBelowThreshold(stock, item.lowThreshold)) {
    return StockStatus.low;
  }
  final runsOut = runOutAt(item);
  if (runsOut == null) {
    return item.dailyUsage > 0 ? StockStatus.healthy : StockStatus.untracked;
  }
  return runsOut.difference(now) <= soonWindow
      ? StockStatus.soon
      : StockStatus.healthy;
}

/// Whole days until [item] runs out, or null when it has no run-out date.
int? daysLeft(Item item, {required DateTime now}) {
  final runsOut = runOutAt(item);
  if (runsOut == null) {
    return null;
  }
  final days = runsOut.difference(now).inHours ~/ Duration.hoursPerDay;
  return days < 0 ? 0 : days;
}

/// When [item] ran out, or null when it has not, or it is not known.
///
/// A staple ran out at its predicted run-out instant. Anything else ran out at
/// its last stock event, which is what set it to nothing.
DateTime? outSince(Item item, {required DateTime now}) {
  if (currentStock(item, now: now) > 0) {
    return null;
  }
  final runsOut = runOutAt(item);
  if (runsOut != null && !runsOut.isAfter(now)) {
    return runsOut;
  }
  return item.stockAtBaseline <= 0 ? item.baselineDate : null;
}

/// How full the gauge for [stock] against [threshold] is, from 0 to 1. At or
/// over the threshold the gauge is full: above it the item is not a concern.
double stockLevel(double stock, double threshold) {
  if (!stock.isFinite || stock <= 0) {
    return 0;
  }
  if (!threshold.isFinite || threshold <= 0) {
    return 1;
  }
  final level = stock / threshold;
  return level > 1 ? 1 : level;
}
