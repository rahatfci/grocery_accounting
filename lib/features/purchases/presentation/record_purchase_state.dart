import 'package:equatable/equatable.dart';

import '../../../core/data_failure.dart';
import '../../items/logic/item.dart';
import '../../members/logic/household.dart';
import '../../receipts/logic/receipt_reading.dart';
import '../logic/purchase_draft.dart';
import '../logic/purchase_summary.dart';

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
    required this.household,
    this.reading = false,
    this.readResult,
    this.readFailed = false,
  });

  final PurchaseDraft draft;

  /// A receipt photo is being read, and the draft may still change under it.
  final bool reading;

  /// What reading the attached photo found, or null when it has not been
  /// read: it was added to a draft that already had something in it.
  final ReceiptReading? readResult;

  /// Reading the attached photo failed, so it is filled in by hand.
  final bool readFailed;

  /// The catalogue, for the item picker. May be empty: an item can be created
  /// on the purchase itself.
  final List<Item> items;

  /// Who can have paid, with the colours the payer chips wear.
  final Household household;

  @override
  List<Object?> get props => [
    draft,
    items,
    household,
    reading,
    readResult,
    readFailed,
  ];
}

/// The purchase is written. What it did stays on screen until the member is
/// done, and the photo's state follows its upload.
final class RecordPurchaseSaved extends RecordPurchaseState {
  const RecordPurchaseSaved(this.summary);

  final PurchaseSummary summary;

  @override
  List<Object?> get props => [summary];
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
