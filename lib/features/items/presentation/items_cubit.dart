import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../purchases/data/purchase_repository.dart';
import '../data/item_repository.dart';
import '../logic/item.dart';
import '../logic/stock_event.dart';
import 'items_state.dart';

/// What the catalogue says when a purchase still points at the item.
const _itemInUseMessage = 'This item is on a purchase and cannot be deleted';

class ItemsCubit extends Cubit<ItemsState> {
  ItemsCubit(this._repository, this._purchases, {this._clock = DateTime.now})
    : super(const ItemsLoading()) {
    _subscribe();
  }

  final ItemRepository _repository;

  /// Injected so derived stock and event timestamps are testable.
  final DateTime Function() _clock;

  /// Only ever asked whether an item is still referenced. The catalogue does
  /// not read purchases for anything else.
  final PurchaseRepository _purchases;
  StreamSubscription<List<Item>>? _subscription;

  /// Subscribes again after a failure.
  ///
  /// A snapshot stream is finished once it has errored, so recovering takes a
  /// new subscription rather than waiting for the old one to right itself.
  void retry() {
    emit(const ItemsLoading());
    _subscribe();
  }

  /// Re-derives the loaded catalogue at the current time.
  ///
  /// The stream only reports when an item changes, so without this a screen
  /// left open, for example across a night in the background, keeps showing
  /// stock for the moment it last reported.
  void refresh() {
    if (state case ItemsLoaded(:final items)) {
      emit(ItemsLoaded(items, now: _clock()));
    }
  }

  /// Writes an item: a create when it has no document id yet, an update
  /// otherwise.
  ///
  /// The list is refreshed by the stream rather than by this call. With
  /// persistence on, the write completes only once the server acknowledges it,
  /// so a caller must not block navigation on the returned future.
  Future<Result<void, DataFailure>> save(Item item) async {
    try {
      return item.id.isEmpty
          ? await _repository.create(item)
          : await _repository.update(item);
    } catch (error, stackTrace) {
      // The repository maps the Firebase codes it knows. Anything else still
      // has to reach the caller as a failure rather than an unhandled error.
      addError(error, stackTrace);
      return const Err(UnexpectedDataFailure());
    }
  }

  /// Why [item] cannot be deleted, or null when it can be.
  ///
  /// A purchase that references the item would be left pointing at nothing, so
  /// the delete is refused. A check that could not be completed refuses it as
  /// well: an unverified delete is exactly what this guard exists to prevent,
  /// and the mapped failure already says why. Offline the check reads the
  /// local cache, so it can miss a purchase this device has never seen.
  Future<DataFailure?> deleteBlocker(Item item) async {
    try {
      final referenced = await _purchases.isItemReferenced(item.id);
      return switch (referenced) {
        Err(:final error) => error,
        Ok(:final value) =>
          value ? const ReferenceInUse(_itemInUseMessage) : null,
      };
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return const UnexpectedDataFailure();
    }
  }

  /// Removes an item. Like [save], the catalogue is refreshed by the stream
  /// rather than by this call, and the returned future must not block
  /// navigation.
  Future<Result<void, DataFailure>> delete(Item item) async {
    // Checked here and not only before the confirmation: the guard belongs to
    // the write, and a purchase can land while the dialog is open.
    final blocker = await deleteBlocker(item);
    if (blocker != null) {
      return Err(blocker);
    }

    try {
      return await _repository.delete(item);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return const Err(UnexpectedDataFailure());
    }
  }

  /// Records a use, adjustment or recount of [item], as the member saw it.
  ///
  /// Like [save], the stream refreshes the stock, and the returned future must
  /// not block navigation.
  Future<Result<void, DataFailure>> recordStockEvent(
    Item item,
    StockEvent event,
  ) async {
    try {
      return await _repository.recordStockEvent(item, event, now: _clock());
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return const Err(UnexpectedDataFailure());
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchItems().listen(
      _onItemsChanged,
      onError: _onStreamError,
    );
  }

  void _onItemsChanged(List<Item> items) => emit(
    items.isEmpty ? const ItemsEmpty() : ItemsLoaded(items, now: _clock()),
  );

  /// A stream error must reach the user as a renderable state, never as an
  /// unhandled error that leaves the screen stuck on its spinner.
  void _onStreamError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emit(
      ItemsFailure(
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
