import '../../../core/dates.dart';
import 'item.dart';
import 'item_unit.dart';
import 'run_out.dart';
import 'stock.dart';
import 'stock_status.dart';

/// How fast [item] goes: `0.1 kg a day`, or that it is only ever logged.
String usageLabel(Item item) => item.dailyUsage > 0
    ? '${formatStock(item.dailyUsage, item.unit)} a day'
    : 'Logged by hand';

/// Whether [item] is a staple, and what it is measured in: `Staple · kg`.
String kindLabel(Item item) =>
    '${item.dailyUsage > 0 ? 'Staple' : 'Not a staple'} · ${item.unit.label}';

/// The pantry row's word under the stock.
String statusLabel(Item item, StockStatus status, {required DateTime now}) =>
    switch (status) {
      StockStatus.out => 'Out',
      StockStatus.low => 'Low',
      StockStatus.soon => switch (runOutAt(item)) {
        final date? => 'Runs out ${formatDayMonth(date)}',
        null => 'Runs out soon',
      },
      StockStatus.healthy => switch (daysLeft(item, now: now)) {
        null => 'Lasts over a year',
        1 => '~1 day left',
        final days => '~$days days left',
      },
      StockStatus.untracked => 'Not a staple',
    };

/// Item detail's line under the gauge, on the right: when it ran out or when
/// it will.
String runOutCaption(Item item, StockStatus status, {required DateTime now}) {
  if (status == StockStatus.out) {
    final since = outSince(item, now: now);
    return since == null
        ? 'Nothing left'
        : 'Out since ${formatDayMonth(since)}';
  }
  if (item.dailyUsage <= 0) {
    return 'Not a staple';
  }
  final date = runOutAt(item);
  return date == null
      ? 'Lasts over a year'
      : 'Runs out around ${formatDayMonth(date)}';
}

/// A change to stock with its sign: `+1 kg`, `−0.2 kg`.
String formatStockChange(double quantity, ItemUnit unit) {
  final magnitude = formatStock(quantity.abs(), unit);
  if (quantity > 0) {
    return '+$magnitude';
  }
  return quantity < 0 ? '−$magnitude' : magnitude;
}
