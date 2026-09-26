import 'dart:typed_data';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../logic/receipt.dart';

/// Where receipt photos go: Supabase Storage, through a queue on the device
/// on phones.
///
/// Implementations own every storage and file system type.
abstract interface class ReceiptStore {
  /// Whether photos wait on the device and upload later. True on phones,
  /// where the purchase can record the photo's path at once. False on web,
  /// where the path is recorded only after [confirm] has uploaded it.
  bool get queuesOffline;

  /// Holds [photo] for `receiptStoragePath(purchaseId)` without uploading
  /// anything yet, so a purchase that is then refused leaves nothing in the
  /// bucket. On a phone it is written to the device, which survives restarts.
  Future<Result<void, DataFailure>> keep(String purchaseId, ReceiptPhoto photo);

  /// The purchase was accepted, so its photo may go. On a phone this hands it
  /// to the upload queue; on web it uploads it, and the result says whether
  /// it is stored.
  Future<Result<void, DataFailure>> confirm(String purchaseId);

  /// Drops a kept photo whose purchase was refused.
  Future<void> discard(String purchaseId);

  /// Uploads every confirmed photo still queued on this device, and returns
  /// how many are left. A photo that fails stays queued for the next flush.
  /// Does nothing on web.
  Future<int> flush();

  /// Whether the photo for [purchaseId] is still waiting on this device to
  /// upload. Always false on web, which never queues.
  Future<bool> isQueued(String purchaseId);

  /// The photo for [purchaseId]: from this device's queue while it waits to
  /// upload, otherwise downloaded from the bucket.
  Future<Result<Uint8List, DataFailure>> read(String purchaseId);
}
