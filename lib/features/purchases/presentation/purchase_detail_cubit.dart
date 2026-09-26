import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../receipts/data/receipt_store.dart';
import '../data/purchase_repository.dart';
import '../logic/purchase.dart';
import 'purchase_detail_state.dart';

/// Follows one saved purchase, and loads its receipt photo once the purchase
/// says it has one.
class PurchaseDetailCubit extends Cubit<PurchaseDetailState> {
  PurchaseDetailCubit({
    required this._purchases,
    required this._receipts,
    required this._purchaseId,
  }) : super(const PurchaseDetailLoading()) {
    _subscribe();
  }

  final PurchaseRepository _purchases;
  final ReceiptStore _receipts;
  final String _purchaseId;

  StreamSubscription<Purchase?>? _subscription;

  Purchase? _purchase;
  PurchasePhoto _photo = const NoPurchasePhoto();

  /// The path the photo was last asked for. On the web a purchase is saved
  /// first and linked to its photo once that has uploaded, so the photo is
  /// read when a path appears rather than only on the first report.
  String? _requestedPath;

  /// Subscribes again after a failure. A snapshot stream is finished once it
  /// has errored, so recovering takes a new subscription.
  void retry() {
    emit(const PurchaseDetailLoading());
    _subscribe();
  }

  /// Asks for the photo again after it failed to load.
  void retryPhoto() {
    final path = _purchase?.receiptImagePath;
    if (path != null) {
      _loadPhoto(path);
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _purchases
        .watchPurchase(_purchaseId)
        .listen(_onPurchase, onError: _onError);
  }

  void _onPurchase(Purchase? purchase) {
    _purchase = purchase;
    if (purchase == null) {
      emit(const PurchaseDetailMissing());
      return;
    }
    final path = purchase.receiptImagePath;
    if (path == null) {
      _requestedPath = null;
      _photo = const NoPurchasePhoto();
    } else if (path != _requestedPath) {
      _loadPhoto(path);
      return;
    }
    _emitLoaded();
  }

  Future<void> _loadPhoto(String path) async {
    _requestedPath = path;
    _photo = const PurchasePhotoLoading();
    _emitLoaded();
    final result = await _receipts.read(_purchaseId);
    // Another path, or no photo at all, may have arrived meanwhile.
    if (isClosed || _requestedPath != path) {
      return;
    }
    _photo = switch (result) {
      Ok(value: final bytes) => PurchasePhotoLoaded(bytes),
      Err(error: final failure) => PurchasePhotoFailed(failure.message),
    };
    _emitLoaded();
  }

  void _emitLoaded() {
    final purchase = _purchase;
    if (purchase != null && !isClosed) {
      emit(PurchaseDetailLoaded(purchase: purchase, photo: _photo));
    }
  }

  /// A stream error must reach the member as a renderable state, never as an
  /// unhandled error that leaves the screen stuck on its spinner.
  void _onError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emit(
      PurchaseDetailFailure(
        error is DataFailure ? error : const UnexpectedDataFailure(),
      ),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
