import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../auth/logic/app_user.dart';
import '../../items/data/item_repository.dart';
import '../../items/logic/item.dart';
import '../data/shopping_list_repository.dart';
import '../logic/shopping_entry.dart';
import '../logic/shopping_match.dart';
import 'shopping_list_state.dart';

/// The household's shopping list, for Home.
///
/// Also watches the catalogue, but only to link a new entry to the item it
/// names. The list renders without it.
class ShoppingListCubit extends Cubit<ShoppingListState> {
  ShoppingListCubit(
    this._entries,
    this._items, {
    required this._currentUser,
    this._clock = DateTime.now,
  }) : super(const ShoppingListLoading()) {
    _subscribe();
  }

  final ShoppingListRepository _entries;
  final ItemRepository _items;
  final AppUser _currentUser;

  /// Injected so `addedAt` is testable.
  final DateTime Function() _clock;

  StreamSubscription<List<ShoppingEntry>>? _entriesSubscription;
  StreamSubscription<List<Item>>? _itemsSubscription;

  /// The last catalogue reported. Empty until then, or after a failure, which
  /// only means a new entry goes in unlinked.
  List<Item> _catalogue = const [];

  /// Subscribes again after a failure. A snapshot stream is finished once it
  /// has errored, so recovering takes a new subscription.
  void retry() {
    emit(const ShoppingListLoading());
    _subscribe();
  }

  /// Adds [text] to the list, linked to the catalogue item it names.
  ///
  /// Blank text writes nothing: the section refuses it before calling this.
  /// Offline the future stays pending until the server acknowledges the write,
  /// so the caller must not block on it.
  Future<Result<void, DataFailure>> add(String text) {
    final trimmed = text.trim();
    if (validateEntryText(trimmed) != null) {
      return Future.value(const Ok(null));
    }
    return _write(
      () => _entries.add(
        ShoppingEntry(
          id: '',
          text: trimmed,
          itemId: linkedItemId(trimmed, _catalogue),
          addedByUserId: _currentUser.uid,
          addedAt: _clock(),
        ),
      ),
    );
  }

  /// Takes [entry] off the list for everyone.
  Future<Result<void, DataFailure>> remove(ShoppingEntry entry) =>
      _write(() => _entries.remove(entry.id));

  Future<Result<void, DataFailure>> _write(
    Future<Result<void, DataFailure>> Function() write,
  ) async {
    try {
      return await write();
    } catch (error, stackTrace) {
      // The repository maps the Firebase codes it knows. Anything else still
      // has to reach the member as a message rather than an unhandled error.
      addError(error, stackTrace);
      return const Err(UnexpectedDataFailure());
    }
  }

  void _subscribe() {
    _entriesSubscription?.cancel();
    _itemsSubscription?.cancel();

    _entriesSubscription = _entries.watchEntries().listen(
      (entries) => emit(
        entries.isEmpty
            ? const ShoppingListEmpty()
            : ShoppingListLoaded(entries),
      ),
      onError: _onEntriesError,
    );
    _itemsSubscription = _items.watchItems().listen(
      (items) => _catalogue = items,
      onError: _onItemsError,
    );
  }

  /// A stream error must reach Home as a renderable state, never as an
  /// unhandled error that leaves the section stuck on its spinner.
  void _onEntriesError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emit(
      ShoppingListFailure(
        error is DataFailure ? error : const UnexpectedDataFailure(),
      ),
    );
  }

  /// Reported, but not shown: without the catalogue the list still works,
  /// and new entries just go in unlinked.
  void _onItemsError(Object error, StackTrace stackTrace) {
    _catalogue = const [];
    addError(error, stackTrace);
  }

  @override
  Future<void> close() {
    _entriesSubscription?.cancel();
    _itemsSubscription?.cancel();
    return super.close();
  }
}
