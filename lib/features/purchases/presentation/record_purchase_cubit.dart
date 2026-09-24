import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/refusal_window.dart';
import '../../../core/result.dart';
import '../../auth/logic/app_user.dart';
import '../../items/data/item_repository.dart';
import '../../items/logic/item.dart';
import '../../members/data/member_repository.dart';
import '../../members/logic/household_member.dart';
import '../../receipts/data/alias_repository.dart';
import '../../receipts/data/receipt_picker.dart';
import '../../receipts/data/receipt_reader.dart';
import '../../receipts/data/receipt_store.dart';
import '../../receipts/logic/receipt.dart';
import '../../receipts/logic/receipt_alias.dart';
import '../../receipts/logic/receipt_reading.dart';
import '../../shopping_list/data/shopping_list_repository.dart';
import '../../shopping_list/logic/shopping_entry.dart';
import '../../shopping_list/logic/shopping_match.dart';
import '../data/purchase_repository.dart';
import '../logic/purchase_draft.dart';
import '../logic/receipt_matching.dart';
import '../logic/purchase_validation.dart';
import 'record_purchase_state.dart';

/// Owns the purchase being filled in, the two collections the pickers need,
/// the shopping list a saved purchase clears, and the receipt photo.
class RecordPurchaseCubit extends Cubit<RecordPurchaseState> {
  RecordPurchaseCubit({
    required this._purchases,
    required this._items,
    required this._members,
    required this._shoppingList,
    required this._receiptPicker,
    required this._receipts,
    required this._receiptReader,
    required this._aliases,
    required AppUser currentUser,
    DateTime Function() now = DateTime.now,
  }) : _currentUser = currentUser,
       _now = now,
       _draft = PurchaseDraft.blank(date: now(), paidByUserId: currentUser.uid),
       super(const RecordPurchaseLoading()) {
    _subscribe();
  }

  final PurchaseRepository _purchases;
  final ItemRepository _items;
  final MemberRepository _members;
  final ShoppingListRepository _shoppingList;
  final ReceiptPicker _receiptPicker;
  final ReceiptStore _receipts;
  final ReceiptReader _receiptReader;
  final AliasRepository _aliases;

  /// What receipt lines have been taught to mean. Empty until the watch
  /// reports, or after it fails: a reading then just arrives unmatched.
  Map<String, ReceiptAlias> _learned = const {};

  /// True while a photo is being read, so the screen can say so.
  bool _reading = false;

  /// Set once the member picks a date, so a reading never overrides it.
  bool _dateChosen = false;
  final AppUser _currentUser;

  /// Injected so the date the draft starts on, the future check and the
  /// restock baseline are all the same clock, and all testable.
  final DateTime Function() _now;

  PurchaseDraft _draft;
  List<Item>? _catalogue;
  List<HouseholdMember>? _household;

  /// The list as this device last saw it. Empty until it reports, or after a
  /// failure: the purchase never waits on it, it just clears nothing.
  List<ShoppingEntry> _entries = const [];

  StreamSubscription<List<Item>>? _itemsSubscription;
  StreamSubscription<List<HouseholdMember>>? _membersSubscription;
  StreamSubscription<List<ShoppingEntry>>? _shoppingListSubscription;
  StreamSubscription<Map<String, ReceiptAlias>>? _aliasesSubscription;

  void setDate(DateTime date) {
    _dateChosen = true;
    _update(_draft.copyWith(date: date));
  }

  void setShopName(String shopName) =>
      _update(_draft.copyWith(shopName: shopName));

  void setTotalText(String totalText) =>
      _update(_draft.copyWith(totalText: totalText));

  void setPaidByUserId(String paidByUserId) =>
      _update(_draft.copyWith(paidByUserId: paidByUserId));

  void addLine(PurchaseDraftLine line) =>
      _update(_draft.copyWith(lines: [..._draft.lines, line]));

  void updateLine(int index, PurchaseDraftLine line) {
    if (index < 0 || index >= _draft.lines.length) {
      return;
    }
    final lines = [..._draft.lines]..[index] = line;
    _update(_draft.copyWith(lines: lines));
  }

  void removeLine(int index) {
    if (index < 0 || index >= _draft.lines.length) {
      return;
    }
    final lines = [..._draft.lines]..removeAt(index);
    _update(_draft.copyWith(lines: lines));
  }

  void attachReceipt(ReceiptPhoto photo) =>
      _update(_draft.copyWith(receipt: photo));

  void removeReceipt() => _update(_draft.copyWith(receipt: null));

  /// Asks the camera or gallery for a photo and attaches it, replacing any
  /// photo already attached. On a draft nothing has been entered into yet,
  /// the photo is then read to prefill it.
  Future<ReceiptPickOutcome> pickReceipt(ReceiptSource source) async {
    final result = await _receiptPicker.pick(source);
    switch (result) {
      case Ok(value: final photo?):
        final fresh = _draft.lines.isEmpty && _draft.totalText.trim().isEmpty;
        attachReceipt(photo);
        return ReceiptPicked(notice: fresh ? await _read(photo) : null);
      case Ok():
        return const ReceiptPickCancelled();
      case Err(:final error):
        if (error case ReceiptPickerUnavailable(
          :final cause,
          :final stackTrace,
        )) {
          addError(cause, stackTrace);
        }
        return ReceiptPickRefused(error.message);
    }
  }

  /// Reads [photo] into the draft, and returns what to tell the member when
  /// nothing came of it.
  ///
  /// Only fills what is still empty: a total or date the member entered while
  /// the reading ran is kept, and lines are only added to a draft with none.
  Future<String?> _read(ReceiptPhoto photo) async {
    _reading = true;
    _emitReady();
    final result = await _receiptReader.read(photo, today: _now());
    _reading = false;
    if (isClosed) {
      return null;
    }

    switch (result) {
      case Err(:final error):
        addError(error.cause, error.stackTrace);
        _emitReady();
        return error.message;
      case Ok(value: final reading):
        // The photo was removed or replaced while it was being read.
        if (!identical(_draft.receipt, photo)) {
          _emitReady();
          return null;
        }
        final applied = _apply(reading);
        _update(applied ?? _draft);
        return applied == null
            ? 'Nothing could be read from the receipt. Fill it in by hand'
            : null;
    }
  }

  /// The draft with [reading] filled in, or null when it added nothing.
  PurchaseDraft? _apply(ReceiptReading reading) {
    var draft = _draft;
    var changed = false;

    final total = reading.total;
    if (total != null && draft.totalText.trim().isEmpty) {
      draft = draft.copyWith(totalText: formatReadAmount(total));
      changed = true;
    }
    final date = reading.date;
    if (date != null && !_dateChosen) {
      draft = draft.copyWith(date: date);
      changed = true;
    }
    if (reading.lines.isNotEmpty && draft.lines.isEmpty) {
      draft = draft.copyWith(
        lines: [
          for (final line in reading.lines)
            lineFromReading(
              line,
              aliases: _learned,
              catalogue: _catalogue ?? const [],
            ),
        ],
      );
      changed = true;
    }
    return changed ? draft.copyWith(scanned: true) : null;
  }

  /// Subscribes again after a failure, keeping what has been typed so far.
  ///
  /// A snapshot stream is finished once it has errored, so recovering takes a
  /// new subscription rather than waiting for the old one to right itself.
  void retry() {
    emit(const RecordPurchaseLoading());
    _subscribe();
  }

  /// Writes the purchase and restocks everything on it, keeping the receipt
  /// photo first so the purchase can point at it.
  ///
  /// Offline the Firestore write only completes once the server acknowledges
  /// it, so a commit still pending after [refusalWindow] counts as done: it is
  /// already queued, and a refusal would have arrived by then. The window
  /// covers the Firestore write only, not keeping the photo, which on web is
  /// an upload.
  Future<CommitOutcome> commit() async {
    final invalid = validateDraft(_draft, today: _now());
    if (invalid != null) {
      return CommitInvalid(invalid);
    }

    final draft = _draft;
    final purchaseId = _purchases.newPurchaseId();
    String? receiptPath;
    DataFailure? receiptSkipped;

    try {
      if (draft.receipt case final photo?) {
        switch (await _receipts.keep(purchaseId, photo)) {
          case Ok():
            receiptPath = receiptStoragePath(purchaseId);
          case Err(:final error):
            // The spend matters more than the photo, so the purchase is
            // saved without it and the member is told.
            receiptSkipped = error;
        }
      }

      final result = await _purchases
          .commit(
            draft,
            now: _now(),
            clearEntryIds: entriesClearedBy(_entries, [
              for (final line in draft.lines) ?line.item,
            ]),
            purchaseId: purchaseId,
            receiptImagePath: receiptPath,
          )
          .timeout(refusalWindow, onTimeout: () => const Ok(null));

      switch (result) {
        case Ok():
          if (receiptPath != null) {
            unawaited(_flushReceipts());
          }
          return CommitSucceeded(receiptSkipped: receiptSkipped);
        case Err(:final error):
          if (receiptPath != null) {
            await _receipts.discard(purchaseId);
          }
          return CommitFailed(error);
      }
    } catch (error, stackTrace) {
      // The repository and store map the Firebase codes they know. Anything
      // else still has to reach the member as a message rather than an
      // unhandled error.
      addError(error, stackTrace);
      if (receiptPath != null) {
        await _receipts.discard(purchaseId);
      }
      return const CommitFailed(UnexpectedDataFailure());
    }
  }

  /// Starts the upload the purchase screen does not wait for. A failure
  /// leaves the photo queued, and Home flushes again later.
  Future<void> _flushReceipts() async {
    try {
      await _receipts.flush();
    } catch (error, stackTrace) {
      if (!isClosed) {
        addError(error, stackTrace);
      }
    }
  }

  void _subscribe() {
    _itemsSubscription?.cancel();
    _membersSubscription?.cancel();
    _shoppingListSubscription?.cancel();
    _aliasesSubscription?.cancel();
    _catalogue = null;
    _household = null;
    _entries = const [];
    _learned = const {};

    _itemsSubscription = _items.watchItems().listen((items) {
      _catalogue = items;
      _emitReady();
    }, onError: _onStreamError);
    _membersSubscription = _members.watchMembers().listen((members) {
      _household = members;
      _emitReady();
    }, onError: _onStreamError);
    _shoppingListSubscription = _shoppingList.watchEntries().listen(
      (entries) => _entries = entries,
      onError: _onShoppingListError,
    );
    _aliasesSubscription = _aliases.watchAliases().listen(
      (aliases) => _learned = aliases,
      onError: _onAliasesError,
    );
  }

  /// Reported, but not shown: without aliases a reading only arrives
  /// unmatched, and saving still teaches new ones.
  void _onAliasesError(Object error, StackTrace stackTrace) {
    _learned = const {};
    addError(error, stackTrace);
  }

  /// Reported, but not shown: recording a spend must not depend on the list.
  void _onShoppingListError(Object error, StackTrace stackTrace) {
    _entries = const [];
    addError(error, stackTrace);
  }

  void _update(PurchaseDraft draft) {
    _draft = draft;
    _emitReady();
  }

  /// Nothing is shown until both collections have reported, because a payer
  /// picker with no members in it looks like a broken screen rather than a
  /// loading one.
  void _emitReady() {
    final items = _catalogue;
    final members = _household;
    if (items == null || members == null) {
      return;
    }
    emit(
      RecordPurchaseReady(
        draft: _draft,
        items: items,
        payers: payerOptions(members, _currentUser),
        reading: _reading,
      ),
    );
  }

  /// A stream error must reach the member as a renderable state, never as an
  /// unhandled error that leaves the screen stuck on its spinner.
  void _onStreamError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emit(
      RecordPurchaseFailure(
        error is DataFailure ? error : const UnexpectedDataFailure(),
      ),
    );
  }

  @override
  Future<void> close() {
    _itemsSubscription?.cancel();
    _membersSubscription?.cancel();
    _shoppingListSubscription?.cancel();
    _aliasesSubscription?.cancel();
    return super.close();
  }
}

/// A read amount as the total field shows it: two decimals and a decimal
/// comma, the way the receipt printed it.
String formatReadAmount(double amount) =>
    amount.toStringAsFixed(2).replaceAll('.', ',');
