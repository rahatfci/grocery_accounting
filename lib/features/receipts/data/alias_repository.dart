import '../logic/receipt_alias.dart';

/// The `aliases` collection: what receipt lines have been taught to mean.
///
/// Read only here. Aliases are written by the purchase commit, in the same
/// batch as the purchase that taught them.
abstract interface class AliasRepository {
  /// Every alias, keyed by `rawTextNormalized`, refreshed as the collection
  /// changes. The household has hundreds at most, so the whole collection is
  /// watched rather than queried per line.
  ///
  /// The stream fails with a `DataFailure`, never with a raw Firebase error.
  Stream<Map<String, ReceiptAlias>> watchAliases();
}
