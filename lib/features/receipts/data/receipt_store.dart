import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../logic/receipt.dart';

/// Where receipt photos go: Firebase Storage, through a queue on the device
/// on phones.
///
/// Implementations own every Firebase and file system type.
abstract interface class ReceiptStore {
  /// Makes sure [photo] will reach `receiptStoragePath(purchaseId)`.
  ///
  /// On a phone this writes it to the device queue, which survives restarts,
  /// and the upload happens on a later [flush]. On web there is nowhere
  /// durable to keep it, so this uploads it and only succeeds once it is
  /// stored.
  Future<Result<void, DataFailure>> keep(String purchaseId, ReceiptPhoto photo);

  /// Drops a kept photo whose purchase was refused. Does nothing on web.
  Future<void> discard(String purchaseId);

  /// Uploads everything still queued on this device, and returns how many
  /// are left. A photo that fails stays queued for the next flush. Does
  /// nothing on web.
  Future<int> flush();
}
