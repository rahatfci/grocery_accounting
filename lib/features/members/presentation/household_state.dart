import 'package:equatable/equatable.dart';

import '../../../core/data_failure.dart';
import '../logic/household.dart';

/// Every state carries a [Household], with at least the signed-in member in
/// it, so a name or an avatar can always be drawn while the list loads or
/// after it fails.
sealed class HouseholdState extends Equatable {
  const HouseholdState(this.household);

  final Household household;

  @override
  List<Object?> get props => [household];
}

final class HouseholdLoading extends HouseholdState {
  const HouseholdLoading(super.household);
}

final class HouseholdLoaded extends HouseholdState {
  const HouseholdLoaded(super.household);
}

final class HouseholdFailure extends HouseholdState {
  const HouseholdFailure(super.household, this.failure);

  final DataFailure failure;

  @override
  List<Object?> get props => [household, failure];
}
