import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../../core/result.dart';
import '../../auth/logic/app_user.dart';
import '../../items/data/item_repository.dart';
import '../../items/logic/item.dart';
import '../../members/data/member_repository.dart';
import '../../members/logic/household_member.dart';
import '../data/purchase_repository.dart';
import '../logic/purchase_draft.dart';
import '../logic/purchase_validation.dart';
import 'record_purchase_state.dart';

/// Owns the purchase being filled in, and the two collections the pickers need.
class RecordPurchaseCubit extends Cubit<RecordPurchaseState> {
  RecordPurchaseCubit({
    required this._purchases,
    required this._items,
    required this._members,
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
  final AppUser _currentUser;

  /// Injected so the date the draft starts on, the future check and the
  /// restock baseline are all the same clock, and all testable.
  final DateTime Function() _now;

  PurchaseDraft _draft;
  List<Item>? _catalogue;
  List<HouseholdMember>? _household;

  StreamSubscription<List<Item>>? _itemsSubscription;
  StreamSubscription<List<HouseholdMember>>? _membersSubscription;

  void setDate(DateTime date) => _update(_draft.copyWith(date: date));

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

  /// Subscribes again after a failure, keeping what has been typed so far.
  ///
  /// A snapshot stream is finished once it has errored, so recovering takes a
  /// new subscription rather than waiting for the old one to right itself.
  void retry() {
    emit(const RecordPurchaseLoading());
    _subscribe();
  }

  /// Writes the purchase and restocks everything on it.
  ///
  /// The write completes only once the server acknowledges it, so the caller
  /// must not block navigation on this future.
  Future<CommitOutcome> commit() async {
    final invalid = validateDraft(_draft, today: _now());
    if (invalid != null) {
      return CommitInvalid(invalid);
    }

    try {
      final result = await _purchases.commit(_draft, now: _now());
      return switch (result) {
        Ok() => const CommitSucceeded(),
        Err(:final error) => CommitFailed(error),
      };
    } catch (error, stackTrace) {
      // The repository maps the Firebase codes it knows. Anything else still
      // has to reach the member as a message rather than an unhandled error.
      addError(error, stackTrace);
      return const CommitFailed(UnexpectedDataFailure());
    }
  }

  void _subscribe() {
    _itemsSubscription?.cancel();
    _membersSubscription?.cancel();
    _catalogue = null;
    _household = null;

    _itemsSubscription = _items.watchItems().listen((items) {
      _catalogue = items;
      _emitReady();
    }, onError: _onStreamError);
    _membersSubscription = _members.watchMembers().listen((members) {
      _household = members;
      _emitReady();
    }, onError: _onStreamError);
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
    return super.close();
  }
}
