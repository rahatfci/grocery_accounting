import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/data_failure.dart';
import '../../items/data/item_repository.dart';
import '../../items/logic/item.dart';
import '../../members/data/member_repository.dart';
import '../../members/logic/household_member.dart';
import '../../purchases/data/purchase_repository.dart';
import '../../purchases/logic/purchase.dart';
import '../logic/report_month.dart';
import '../logic/spending_report.dart';
import 'reports_state.dart';

/// Owns the month on screen and the three collections a report is built from.
class ReportsCubit extends Cubit<ReportsState> {
  /// [now] is injected so the month the screen opens on and the guard that
  /// refuses a future month share one clock, and both are testable.
  ReportsCubit({
    required this._purchases,
    required this._items,
    required this._members,
    DateTime Function() now = DateTime.now,
  }) : _now = now,
       super(
         // The current month, which is also the last one worth offering.
         ReportsLoading(month: monthStart(now()), canViewNext: false),
       ) {
    _subscribeCollections();
    _subscribeWindow();
  }

  final PurchaseRepository _purchases;
  final ItemRepository _items;
  final MemberRepository _members;
  final DateTime Function() _now;

  /// Read back off the state rather than duplicated in a field, so the month
  /// on screen and the month being queried cannot drift apart.
  DateTime get _month => state.month;

  bool get _canViewNext => canViewNextMonth(_month, now: _now());

  List<Purchase>? _window;
  List<Item>? _catalogue;
  List<HouseholdMember>? _household;

  StreamSubscription<List<Purchase>>? _windowSubscription;
  StreamSubscription<List<Item>>? _itemsSubscription;
  StreamSubscription<List<HouseholdMember>>? _membersSubscription;

  void showPreviousMonth() => _showMonth(previousMonth(_month));

  /// Refuses to leave the current month. A purchase cannot be recorded in the
  /// future, so a later month can only ever be empty.
  void showNextMonth() {
    if (!_canViewNext) {
      return;
    }
    _showMonth(nextMonth(_month));
  }

  /// Subscribes again after a failure, on the month that failed.
  ///
  /// A snapshot stream is finished once it has errored, so recovering takes a
  /// new subscription rather than waiting for the old one to right itself.
  void retry() {
    emit(ReportsLoading(month: _month, canViewNext: _canViewNext));
    _subscribeCollections();
    _subscribeWindow();
  }

  /// The catalogue and the household are the same whatever month is shown, so
  /// only the window is re-subscribed.
  void _showMonth(DateTime month) {
    emit(
      ReportsLoading(
        month: month,
        canViewNext: canViewNextMonth(month, now: _now()),
      ),
    );
    _subscribeWindow();
  }

  /// One window covering the previous month as well as the selected one, so
  /// the comparison costs no second subscription and no composite index.
  void _subscribeWindow() {
    _windowSubscription?.cancel();
    _window = null;

    _windowSubscription = _purchases
        .watchPurchasesBetween(
          from: previousMonth(_month),
          toExclusive: nextMonth(_month),
        )
        .listen((purchases) {
          _window = purchases;
          _emitReady();
        }, onError: _onStreamError);
  }

  void _subscribeCollections() {
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

  /// Nothing is shown until all three have reported. A report built without
  /// the catalogue would file every line under `Uncategorised`, and one built
  /// without the household would show an equal share of nothing.
  void _emitReady() {
    final window = _window;
    final items = _catalogue;
    final members = _household;
    if (window == null || items == null || members == null) {
      return;
    }

    emit(
      ReportsLoaded(
        report: buildSpendingReport(
          month: _month,
          purchases: window,
          items: items,
          members: members,
        ),
        month: _month,
        canViewNext: _canViewNext,
      ),
    );
  }

  /// A stream error must reach the member as a renderable state, never as an
  /// unhandled error that leaves the screen stuck on its spinner.
  void _onStreamError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emit(
      ReportsFailure(
        failure: error is DataFailure ? error : const UnexpectedDataFailure(),
        month: _month,
        canViewNext: _canViewNext,
      ),
    );
  }

  @override
  Future<void> close() {
    _windowSubscription?.cancel();
    _itemsSubscription?.cancel();
    _membersSubscription?.cancel();
    return super.close();
  }
}
