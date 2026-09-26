import 'package:equatable/equatable.dart';

import '../../../core/dates.dart';
import '../../items/logic/stock.dart';
import 'money.dart';
import 'purchase.dart';

String lineCountLabel(int count) => switch (count) {
  0 => 'No lines',
  1 => '1 line',
  _ => '$count lines',
};

/// The line under a purchase's shop: `Giulia · 8 lines`, with the date in
/// front of the line count when the list is not already grouped by day.
String purchaseDetail(
  Purchase purchase, {
  required String payerName,
  bool withDate = false,
}) => [
  payerName,
  if (withDate) formatPurchaseDate(purchase.date),
  lineCountLabel(purchase.lines.length),
].join(' · ');

/// Purchases made on one day.
final class DayGroup extends Equatable {
  const DayGroup({required this.day, required this.purchases});

  /// Midnight of the day.
  final DateTime day;
  final List<Purchase> purchases;

  @override
  List<Object?> get props => [day, purchases];
}

/// [purchases] by day, keeping their order, so a list already newest first
/// gives the latest day first.
List<DayGroup> purchasesByDay(Iterable<Purchase> purchases) {
  final byDay = <DateTime, List<Purchase>>{};
  for (final purchase in purchases) {
    final date = purchase.date;
    byDay
        .putIfAbsent(DateTime(date.year, date.month, date.day), () => [])
        .add(purchase);
  }
  return [
    for (final MapEntry(key: day, value: purchases) in byDay.entries)
      DayGroup(day: day, purchases: purchases),
  ];
}

/// The overline above a day's purchases: `TODAY · 26/09/2026`,
/// `THURSDAY · 24/09/2026`.
String dayHeading(DateTime day, {required DateTime now}) {
  final name = switch (daysBefore(day, now)) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => weekdayName(day),
  };
  return '${name.toUpperCase()} · ${formatPurchaseDate(day)}';
}

/// A saved line's title: the item it restocked while the pantry still has
/// it, otherwise what the receipt or the member called it.
String savedLineTitle(PurchaseLine line, {required String? itemName}) =>
    itemName ?? line.rawText;

/// The line under a saved line's title, as the review screen showed it:
/// `Spend only · 2 pcs`, `1 kg · RISO ARBORIO 1KG`.
String savedLineDetail(PurchaseLine line, {required String? itemName}) {
  final quantity = formatStock(line.quantity, line.unit);
  if (line.itemId == null) {
    return 'Spend only · $quantity';
  }
  if (itemName == null) {
    return '$quantity · no longer in the pantry';
  }
  final raw = line.rawText.trim();
  // A line typed by hand carries the item's own name, which the title
  // already says.
  return raw.isEmpty || raw.toLowerCase() == itemName.trim().toLowerCase()
      ? quantity
      : '$quantity · $raw';
}

/// The lines of a saved purchase with the spend-only ones first, as the
/// review screen put the ones that needed attention on top.
List<PurchaseLine> linesSpendOnlyFirst(List<PurchaseLine> lines) => [
  for (final line in lines)
    if (line.itemId == null) line,
  for (final line in lines)
    if (line.itemId != null) line,
];

/// The day a purchase was made, spelled out: `Saturday 26/09/2026`.
String purchaseDay(DateTime date) =>
    '${weekdayName(date)} ${formatPurchaseDate(date)}';
