import 'package:equatable/equatable.dart';

import '../../items/logic/item.dart';
import '../../items/logic/item_unit.dart';
import '../../items/logic/item_validation.dart';
import '../../receipts/logic/receipt.dart';
import 'purchase.dart';
import 'purchase_source.dart';
import 'quantity_conversion.dart';

/// One line being edited on the review screen.
final class PurchaseDraftLine extends Equatable {
  const PurchaseDraftLine({
    required this.item,
    required this.quantity,
    required this.unit,
    required this.lineTotal,
    this.scannedText,
  });

  /// The catalogue item, or one with an empty id that the commit creates.
  /// Null for a line read off a receipt that nobody has matched yet: it
  /// records spend and restocks nothing.
  final Item? item;

  /// The receipt's own wording, for a line that came from a reading. Kept
  /// after the line is matched, so a mis-mapping stays diagnosable.
  final String? scannedText;

  final double quantity;

  /// As entered. [restockQuantity] converts it into the item's own unit.
  final ItemUnit unit;

  final double lineTotal;

  bool get isMatched => item != null;

  bool get createsItem => item?.id.isEmpty ?? false;

  /// What the screen calls this line: the item once there is one, otherwise
  /// the receipt's wording.
  String get label => item?.name ?? scannedText ?? '';

  /// What the purchase document keeps as `rawText`.
  String get rawText => scannedText ?? item?.name ?? '';

  /// The quantity in the item's own unit, or null when the two cannot be
  /// converted or there is no item. The unit picker only offers convertible
  /// units and `validateDraft` refuses the rest, so a matched line never
  /// reaches a commit with a null here.
  double? get restockQuantity => switch (item) {
    final item? => convertToItemUnit(quantity, unit, item),
    null => null,
  };

  @override
  List<Object?> get props => [item, quantity, unit, lineTotal, scannedText];
}

const Object _unchanged = Object();

/// A purchase being filled in, before anything has been written.
final class PurchaseDraft extends Equatable {
  const PurchaseDraft({
    required this.date,
    required this.shopName,
    required this.totalText,
    required this.paidByUserId,
    required this.lines,
    this.receipt,
    this.scanned = false,
  });

  /// A fresh draft: today's date, the signed-in member as payer, nothing else.
  const PurchaseDraft.blank({
    required DateTime date,
    required String paidByUserId,
  }) : this(
         date: date,
         shopName: '',
         totalText: '',
         paidByUserId: paidByUserId,
         lines: const [],
       );

  final DateTime date;
  final String shopName;

  /// As typed, so both decimal separators survive until validation parses it
  /// and nothing is rounded on the member's behalf.
  final String totalText;

  final String paidByUserId;
  final List<PurchaseDraftLine> lines;

  /// The scontrino photo, or null. Compared by identity: see [ReceiptPhoto].
  final ReceiptPhoto? receipt;

  /// Whether reading the receipt filled anything in, which makes the purchase
  /// `scanned` rather than `manual`.
  final bool scanned;

  /// The sum of the line totals, which the screen shows beside the receipt
  /// total. They are allowed to differ: discounts, deposits and unpriced lines
  /// are all normal, and the receipt total is what reports use.
  double get linesTotal => lines.fold(0, (sum, line) => sum + line.lineTotal);

  /// The purchase document to write.
  ///
  /// [resolveItemId] supplies each line's item id: the existing one, or the id
  /// the commit generated for an item created inline.
  ///
  /// [receiptImagePath] is where the photo will be stored, or null when there
  /// is none or it could not be kept.
  Purchase toPurchase({
    required String? Function(Item item) resolveItemId,
    String id = '',
    String? receiptImagePath,
  }) => Purchase(
    id: id,
    // The day, not the moment. A blank draft starts from the clock, and a
    // purchase is a day on a receipt.
    date: DateTime(date.year, date.month, date.day),
    shopName: shopName.trim(),
    // Validation is what stops an unparseable total ever reaching a document.
    total: parseDecimal(totalText) ?? 0,
    paidByUserId: paidByUserId,
    receiptImagePath: receiptImagePath,
    source: scanned ? PurchaseSource.scanned : PurchaseSource.manual,
    lines: [
      for (final line in lines)
        PurchaseLine(
          itemId: switch (line.item) {
            final item? => resolveItemId(item),
            null => null,
          },
          rawText: line.rawText,
          quantity: line.quantity,
          unit: line.unit,
          lineTotal: line.lineTotal,
        ),
    ],
  );

  PurchaseDraft copyWith({
    DateTime? date,
    String? shopName,
    String? totalText,
    String? paidByUserId,
    List<PurchaseDraftLine>? lines,
    Object? receipt = _unchanged,
    bool? scanned,
  }) => PurchaseDraft(
    date: date ?? this.date,
    shopName: shopName ?? this.shopName,
    totalText: totalText ?? this.totalText,
    paidByUserId: paidByUserId ?? this.paidByUserId,
    lines: lines ?? this.lines,
    // The sentinel keeps "leave it alone" distinct from "remove the photo".
    receipt: identical(receipt, _unchanged)
        ? this.receipt
        : receipt as ReceiptPhoto?,
    scanned: scanned ?? this.scanned,
  );

  @override
  List<Object?> get props => [
    date,
    shopName,
    totalText,
    paidByUserId,
    lines,
    receipt,
    scanned,
  ];
}

/// One item to restock, with everything bought of it on this purchase.
final class RestockTarget extends Equatable {
  const RestockTarget({required this.item, required this.quantity});

  /// An empty [Item.id] means the commit has to create the item first.
  final Item item;

  /// In the item's own unit.
  final double quantity;

  @override
  List<Object?> get props => [item, quantity];
}

/// What identifies an item while a purchase is being committed.
///
/// An existing item is its document id. An item created inline has no id yet,
/// so it is itself: two lines for the same new item merge, two different new
/// items do not.
Object restockKey(Item item) => item.id.isEmpty ? item : item.id;

/// One [RestockTarget] per item, in the order the items first appear.
///
/// Two lines for the same item are summed here, because a Firestore batch must
/// not write the same document twice.
List<RestockTarget> restockTargets(Iterable<PurchaseDraftLine> lines) {
  final indexByKey = <Object, int>{};
  final targets = <RestockTarget>[];

  for (final line in lines) {
    final item = line.item;
    final quantity = line.restockQuantity;
    // An unmatched line restocks nothing, by decision. A matched line with no
    // quantity is unreachable from a valid draft: validation refuses a unit
    // that cannot be converted rather than letting it restock nothing.
    if (item == null || quantity == null) {
      continue;
    }
    final key = restockKey(item);
    final index = indexByKey[key];
    if (index == null) {
      indexByKey[key] = targets.length;
      targets.add(RestockTarget(item: item, quantity: quantity));
    } else {
      final existing = targets[index];
      targets[index] = RestockTarget(
        item: existing.item,
        quantity: existing.quantity + quantity,
      );
    }
  }

  return targets;
}
