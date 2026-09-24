import '../../items/logic/item.dart';
import '../../receipts/logic/receipt_alias.dart';
import '../../receipts/logic/receipt_reading.dart';
import 'purchase_draft.dart';
import 'quantity_conversion.dart';

/// The aliases saving [draft] teaches: one per scanned line that was matched.
///
/// [resolveItemId] supplies the item's id, which for an item created on this
/// purchase is only known once the commit has generated it. When two lines
/// share a wording, the later one wins, as it would on the next save anyway.
List<ReceiptAlias> learnedAliases(
  PurchaseDraft draft, {
  required String? Function(Item item) resolveItemId,
}) {
  final shop = draft.shopName.trim();
  final byText = <String, ReceiptAlias>{};
  for (final line in draft.lines) {
    final item = line.item;
    final scanned = line.scannedText;
    if (item == null || scanned == null) {
      continue;
    }
    final text = normalizeReceiptText(scanned);
    final itemId = resolveItemId(item);
    if (text.isEmpty || itemId == null || itemId.isEmpty) {
      continue;
    }
    byText[text] = ReceiptAlias(
      rawTextNormalized: text,
      itemId: itemId,
      defaultQuantity: line.quantity,
      defaultUnit: line.unit,
      shopName: shop.isEmpty ? null : shop,
    );
  }
  return byText.values.toList();
}

/// The draft line a reading produces for [scanned]: matched through its alias
/// when there is a usable one, otherwise unmatched.
///
/// An alias is usable only while its item is still in [catalogue] and its
/// unit converts into the item's, so a stale alias degrades to an unmatched
/// line rather than a wrong restock.
PurchaseDraftLine lineFromReading(
  ScannedLine scanned, {
  required Map<String, ReceiptAlias> aliases,
  required Iterable<Item> catalogue,
}) {
  final unmatched = PurchaseDraftLine(
    item: null,
    quantity: scanned.quantity,
    unit: scanned.unit,
    lineTotal: scanned.lineTotal,
    scannedText: scanned.rawText,
  );

  final alias = aliases[normalizeReceiptText(scanned.rawText)];
  if (alias == null) {
    return unmatched;
  }
  final item = catalogue.where((item) => item.id == alias.itemId).firstOrNull;
  if (item == null) {
    return unmatched;
  }

  // A quantity the receipt printed is a fact about this purchase; the alias
  // only fills in what the receipt left out.
  final quantity = scanned.quantityRead
      ? scanned.quantity
      : alias.defaultQuantity;
  final unit = scanned.quantityRead ? scanned.unit : alias.defaultUnit;
  if (convertToItemUnit(quantity, unit, item) == null) {
    return unmatched;
  }

  return PurchaseDraftLine(
    item: item,
    quantity: quantity,
    unit: unit,
    lineTotal: scanned.lineTotal,
    scannedText: scanned.rawText,
  );
}
