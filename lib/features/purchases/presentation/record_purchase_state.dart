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
  });

  final PurchaseDraft draft;

  /// The catalogue, for the item picker. May be empty: an item can be created
  /// on the purchase itself.
  final List<Item> items;

  final List<HouseholdMember> payers;

  @override
  List<Object?> get props => [draft, items, payers];
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
  const CommitSucceeded();
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
