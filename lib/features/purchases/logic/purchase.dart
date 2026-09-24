import 'package:equatable/equatable.dart';

import '../../items/logic/item_unit.dart';
import 'purchase_source.dart';

/// One thing on a purchase.
final class PurchaseLine extends Equatable {
  const PurchaseLine({
    required this.itemId,
    required this.rawText,
    required this.quantity,
    required this.unit,
    required this.lineTotal,
  });

  /// The catalogue item this line restocked. Null only for a scanned line that
  /// has not been matched yet, which feature 10 introduces. A line recorded by
  /// hand always has one.
  final String? itemId;

  /// The original wording. A receipt supplies it later; a line entered by hand
  /// carries the item name as it was picked, so the purchase still reads
  /// correctly once the item itself is gone.
  final String rawText;

  final double quantity;

  /// As entered, which is not necessarily the item's own unit.
  final ItemUnit unit;

  final double lineTotal;

  @override
  List<Object?> get props => [itemId, rawText, quantity, unit, lineTotal];
}

/// One shop trip: what it cost, who paid, and what came home.
final class Purchase extends Equatable {
  const Purchase({
    required this.id,
    required this.date,
    required this.shopName,
    required this.total,
    required this.paidByUserId,
    required this.receiptImagePath,
    required this.source,
    required this.lines,
  });

  /// The Firestore document id. Empty for a purchase that has not been
  /// written.
  final String id;

  /// The day of the shop trip, which is not when the restock was baselined.
  final DateTime date;

  final String shopName;

  /// EUR. The receipt total, which reports treat as authoritative rather than
  /// re-deriving it from [lines].
  final double total;

  /// A `users/{userId}` id.
  final String paidByUserId;

  /// Where the receipt photo is stored in Supabase Storage, or null when the
  /// purchase has none. On phones it is recorded with the purchase while the
  /// photo may still be queued on the device; on web only once it has
  /// uploaded.
  final String? receiptImagePath;

  final PurchaseSource source;

  /// May be empty: a purchase that records only the spend is still a purchase.
  final List<PurchaseLine> lines;

  /// The distinct item ids on this purchase, sorted.
  ///
  /// Stored alongside [lines] so the catalogue can ask whether an item is
  /// still referenced. Firestore cannot query a field inside an array of maps,
  /// so the ids have to be denormalized to be queryable at all.
  List<String> get itemIds {
    final ids = <String>{
      for (final line in lines)
        if (line.itemId case final String id) id,
    }.toList();
    return ids..sort();
  }

  @override
  List<Object?> get props => [
    id,
    date,
    shopName,
    total,
    paidByUserId,
    receiptImagePath,
    source,
    lines,
  ];
}
