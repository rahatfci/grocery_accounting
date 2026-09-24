import 'package:equatable/equatable.dart';

import '../../../core/data_failure.dart';
import '../../items/logic/item.dart';
import '../../members/logic/household_member.dart';
import '../logic/purchase_draft.dart';

sealed class RecordPurchaseState extends Equatable {
  const RecordPurchaseState();

  @override
  List<Object?> get props => const [];
}

/// Before both the catalogue and the household have reported, so neither the
/// item picker nor the payer picker can be filled in yet.
final class RecordPurchaseLoading extends RecordPurchaseState {
  const RecordPurchaseLoading();
}

final class RecordPurchaseReady extends RecordPurchaseState {
  const RecordPurchaseReady({
    required this.draft,
    required this.items,
    required this.payers,
    this.reading = false,
  });

  final PurchaseDraft draft;

  /// A receipt photo is being read, and the draft may still change under it.
  final bool reading;

  /// The catalogue, for the item picker. May be empty: an item can be created
  /// on the purchase itself.
  final List<Item> items;

  final List<HouseholdMember> payers;

  @override
  List<Object?> get props => [draft, items, payers, reading];
}

final class RecordPurchaseFailure extends RecordPurchaseState {
  const RecordPurchaseFailure(this.failure);

  final DataFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// What pressing Save did.
///
/// A refusal and an incomplete form both end up in the same message box, but
/// they are not the same thing: one is the member's to fix, the other is
/// Firestore's.
sealed class CommitOutcome extends Equatable {
  const CommitOutcome();

  @override
  List<Object?> get props => const [];
}

final class CommitSucceeded extends CommitOutcome {
  const CommitSucceeded({this.receiptSkipped});

  /// Why the photo was not kept, when the purchase was saved without it.
  final DataFailure? receiptSkipped;

  @override
  List<Object?> get props => [receiptSkipped];
}

/// The draft is not ready to be written. [message] is what to tell the member.
final class CommitInvalid extends CommitOutcome {
  const CommitInvalid(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class CommitFailed extends CommitOutcome {
  const CommitFailed(this.failure);

  final DataFailure failure;

  @override
  List<Object?> get props => [failure];
}

/// What asking for a receipt photo did.
sealed class ReceiptPickOutcome extends Equatable {
  const ReceiptPickOutcome();

  @override
  List<Object?> get props => const [];
}

/// A photo was picked and is now attached to the draft.
final class ReceiptPicked extends ReceiptPickOutcome {
  const ReceiptPicked({this.notice});

  /// Why reading it filled nothing in, when that is worth telling the
  /// member.
  final String? notice;

  @override
  List<Object?> get props => [notice];
}

final class ReceiptPickCancelled extends ReceiptPickOutcome {
  const ReceiptPickCancelled();
}

/// Nothing was picked. [message] is what to tell the member.
final class ReceiptPickRefused extends ReceiptPickOutcome {
  const ReceiptPickRefused(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
