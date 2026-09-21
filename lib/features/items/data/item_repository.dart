import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../logic/item.dart';

/// The `items` collection: the household's catalogue.
///
/// Implementations own every Firestore type; none of them cross this boundary.
///
/// With offline persistence on, the futures returned by [create] and [update]
/// complete only once the server acknowledges the write, so offline they stay
/// pending indefinitely. The local cache applies the write immediately and
/// [watchItems] emits, so callers must react to the stream and must not block
/// navigation on these futures.
abstract interface class ItemRepository {
  /// Every item, sorted by name, refreshed as the collection changes.
  Stream<List<Item>> watchItems();

  /// Writes a new document, including the baseline pair the stock contract
  /// requires from creation. [Item.id] is ignored: Firestore assigns it.
  Future<Result<void, DataFailure>> create(Item item);

  /// Writes the catalogue half of an existing document, leaving
  /// `stockAtBaseline` and `baselineDate` untouched.
  Future<Result<void, DataFailure>> update(Item item);
}
