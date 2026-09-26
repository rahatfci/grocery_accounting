import '../../items/logic/item.dart';
import '../../items/logic/item_unit.dart';
import '../../items/logic/stock.dart';
import 'money.dart';
import 'purchase_draft.dart';

/// Where a line on the review screen stands.
enum LineState {
  /// Read off the receipt, and nobody has said what it is yet.
  unmatched,

  /// Matched by what an earlier purchase taught.
  learned,

  /// Matched to a pantry item by a member.
  matched,

  /// Adds a new item to the pantry when the purchase is saved.
  newItem,
}

LineState lineStateOf(PurchaseDraftLine line) {
  if (!line.isMatched) {
    return LineState.unmatched;
  }
  if (line.createsItem) {
    return LineState.newItem;
  }
  return line.learned ? LineState.learned : LineState.matched;
}

/// The line under a review row's title: the quantity, and where the match
/// came from. `1 kg · learned from RISO ARBORIO 1KG`.
String lineDetail(PurchaseDraftLine line) {
  final quantity = formatStock(line.quantity, line.unit);
  final scanned = line.scannedText?.trim() ?? '';
  final raw = scanned.isEmpty ? null : scanned;
  return switch (lineStateOf(line)) {
    LineState.unmatched => 'Not matched · $quantity',
    LineState.learned when raw != null => '$quantity · learned from $raw',
    LineState.learned || LineState.matched => [quantity, ?raw].join(' · '),
    LineState.newItem => [quantity, 'new pantry item', ?raw].join(' · '),
  };
}

/// The note under the lines and the receipt total. The two may differ, and
/// the note says by how much without treating it as a problem.
String linesGapNote({required double linesTotal, required double total}) {
  final gap = linesTotal - total;
  if (gap.abs() < 0.005) {
    return 'The lines add up to the receipt total.';
  }
  final amount = formatEuro(gap.abs());
  final reason = gap > 0
      ? '$amount more than the receipt, usually a discount'
      : '$amount less than the receipt, usually a line that was not priced';
  return 'The lines come to $reason. Lines never have to match the receipt '
      'total, and reports use the total.';
}

/// What matching a receipt line teaches, as the match sheet says it:
/// `From now on, POMODORI PELATI 400G becomes 2 pcs of Peeled tomatoes by
/// itself.` Without a usable quantity, the quantity is left out.
String learningNote({
  required String rawText,
  required String itemName,
  double? quantity,
  ItemUnit? unit,
}) {
  final amount = quantity != null && unit != null && quantity > 0
      ? '${formatStock(quantity, unit)} of '
      : '';
  return 'From now on, ${rawText.trim()} becomes $amount$itemName by itself.';
}

/// The pantry items the match sheet offers for [query]: those whose name
/// contains it, ignoring case, names that start with it first. [selected]
/// always leads, so the current choice never disappears while searching.
List<Item> matchCandidates(
  Iterable<Item> items,
  String query, {
  Item? selected,
  int limit = 6,
}) {
  final wanted = query.trim().toLowerCase();
  final matches = [
    for (final item in items)
      if (item != selected && item.name.toLowerCase().contains(wanted)) item,
  ];
  int rank(Item item) =>
      wanted.isNotEmpty && item.name.toLowerCase().startsWith(wanted) ? 0 : 1;
  matches.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0
        ? byRank
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return [?selected, ...matches].take(limit).toList();
}
