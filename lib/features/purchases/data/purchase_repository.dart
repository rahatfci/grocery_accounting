import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../logic/purchase.dart';
import '../logic/purchase_draft.dart';

/// The `purchases` collection: what the household spent, and what it bought.
///
/// Implementations own every Firestore type; none of them cross this boundary.
abstract interface class PurchaseRepository {
  /// Writes the purchase and restocks every item on it in one batch, so the
  /// spend and the restock cannot land apart.
  ///
  /// A batch rather than a transaction: a transaction needs a server round
  /// trip and fails offline, and capturing a shop trip offline is the point.
  /// With persistence on, the returned future completes only once the server
  /// acknowledges the write, so offline it stays pending indefinitely while
  /// the local cache already holds it. Callers must not block navigation on
  /// it.
  ///
  /// [now] stamps the restocked baselines. It is passed in so the stock pair
  /// is internally consistent and testable.
  ///
  /// [clearEntryIds] are the shopping list entries this purchase covers. They
  /// are deleted in the same batch, so the list cannot be cleared by a
  /// purchase that was never written.
  ///
  /// [purchaseId] is the document id to write, from [newPurchaseId], so the
  /// receipt photo can be stored under it before the purchase exists. A new
  /// id is generated when it is null. [receiptImagePath] is written as is.
  Future<Result<void, DataFailure>> commit(
    PurchaseDraft draft, {
    required DateTime now,
    Set<String> clearEntryIds = const {},
    String? purchaseId,
    String? receiptImagePath,
  });

  /// A fresh purchase document id, generated on the device so it works
  /// offline.
  String newPurchaseId();

  /// Every purchase in a half-open window, oldest first, refreshed as the
  /// collection changes.
  ///
  /// [from] is inclusive and [toExclusive] is not, so two consecutive months
  /// cannot both claim a purchase that lands on the boundary.
  ///
  /// The stream fails with a [DataFailure], never with a raw Firebase error,
  /// so presentation can render the message without knowing about Firestore.
  Stream<List<Purchase>> watchPurchasesBetween({
    required DateTime from,
    required DateTime toExclusive,
  });

  /// Whether any purchase still references [itemId].
  ///
  /// Offline this reads the local cache and can miss a purchase this device
  /// has never seen. A failure is returned as a failure, never as a false, so
  /// the caller can refuse a delete it could not verify.
  Future<Result<bool, DataFailure>> isItemReferenced(String itemId);
}
