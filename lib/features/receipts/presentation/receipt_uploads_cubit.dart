import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/receipt_store.dart';

/// Pushes queued receipt photos up to Storage, for Home.
///
/// State is how many were still queued after the last flush. Nothing shows
/// it yet; it exists so a test can see a flush happened.
class ReceiptUploadsCubit extends Cubit<int> {
  ReceiptUploadsCubit(this._store) : super(0) {
    flush();
  }

  final ReceiptStore _store;

  /// Uploads what is queued. Safe to call often: the store ignores a flush
  /// while one is running, and a failed upload just stays queued.
  Future<void> flush() async {
    try {
      final remaining = await _store.flush();
      if (!isClosed) {
        emit(remaining);
      }
    } catch (error, stackTrace) {
      if (!isClosed) {
        addError(error, stackTrace);
      }
    }
  }
}
