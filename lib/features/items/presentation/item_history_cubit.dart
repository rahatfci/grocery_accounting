import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../purchases/logic/purchase.dart';
import '../data/item_repository.dart';
import '../logic/item.dart';
import '../logic/item_history.dart';
import '../logic/stock_event.dart';
import 'item_history_state.dart';

/// One item's history: the stock events recorded against it and the
/// purchases that restocked it. Read from `consumptionEvents`, the audit
/// trail that explains a number the member does not believe.
class ItemHistoryCubit extends Cubit<ItemHistoryState> {
  ItemHistoryCubit(this._items, this._purchases, {required this.itemId})
    : super(const ItemHistoryLoading()) {
    _subscribe();
  }

  final ItemRepository _items;
  final PurchaseRepository _purchases;
  final String itemId;

  List<Item>? _catalogue;
  List<StockEventRecord>? _events;
  List<Purchase>? _bought;

  StreamSubscription<List<Item>>? _itemsSubscription;
  StreamSubscription<List<StockEventRecord>>? _eventsSubscription;
  StreamSubscription<List<Purchase>>? _purchasesSubscription;

  /// Subscribes again after a failure. A snapshot stream is finished once it
  /// has errored, so recovering takes new subscriptions.
  void retry() {
    emit(const ItemHistoryLoading());
    _subscribe();
  }

  void _subscribe() {
    _cancel();
    _catalogue = null;
    _events = null;
    _bought = null;

    _itemsSubscription = _items.watchItems().listen((items) {
      _catalogue = items;
      _emitReady();
    }, onError: _onStreamError);
    _eventsSubscription = _items.watchStockEvents(itemId).listen((events) {
      _events = events;
      _emitReady();
    }, onError: _onStreamError);
    _purchasesSubscription = _purchases.watchPurchasesWithItem(itemId).listen((
      purchases,
    ) {
      _bought = purchases;
      _emitReady();
    }, onError: _onStreamError);
  }

  /// Nothing is shown until all three have reported: a history without the
  /// purchases would read as if the item had only ever been used.
  void _emitReady() {
    final catalogue = _catalogue;
    final events = _events;
    final bought = _bought;
    if (catalogue == null || events == null || bought == null) {
      return;
    }
    final item = catalogue.where((item) => item.id == itemId).firstOrNull;
    emit(
      ItemHistoryLoaded(
        item == null
            ? const []
            : itemHistory(item: item, events: events, purchases: bought),
      ),
    );
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emit(
      ItemHistoryFailure(
        error is DataFailure ? error : const UnexpectedDataFailure(),
      ),
    );
  }

  void _cancel() {
    _itemsSubscription?.cancel();
    _eventsSubscription?.cancel();
    _purchasesSubscription?.cancel();
  }

  @override
  Future<void> close() {
    _cancel();
    return super.close();
  }
}
