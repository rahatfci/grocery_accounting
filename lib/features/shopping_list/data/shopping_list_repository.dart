import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../logic/shopping_entry.dart';

/// The `shoppingList` collection: what the household still has to buy.
///
/// Implementations own every Firestore type; none of them cross this boundary.
///
/// With offline persistence on, the futures returned by [add] and [remove]
/// complete only once the server acknowledges the write, so offline they stay
/// pending indefinitely while [watchEntries] already reflects them. Callers
/// must not block on these futures.
abstract interface class ShoppingListRepository {
  /// Every entry, oldest first, refreshed as the collection changes.
  ///
  /// The stream fails with a [DataFailure], never with a raw Firebase error.
  Stream<List<ShoppingEntry>> watchEntries();

  /// Writes a new document. [ShoppingEntry.id] is ignored: Firestore assigns
  /// it.
  Future<Result<void, DataFailure>> add(ShoppingEntry entry);

  /// Deletes the entry. Deleting one that is already gone succeeds, so two
  /// devices ticking the same entry both do.
  Future<Result<void, DataFailure>> remove(String entryId);
}
