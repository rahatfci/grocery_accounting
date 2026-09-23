import 'package:equatable/equatable.dart';

import '../../../core/data_failure.dart';
import '../logic/spending_report.dart';

/// Every state carries the month and whether the next one can be reached, so
/// the month bar survives a load and a failure. A member who lands on a broken
/// month must still be able to leave it.
sealed class ReportsState extends Equatable {
  const ReportsState({required this.month, required this.canViewNext});

  /// The first instant of the month on screen.
  final DateTime month;

  final bool canViewNext;

  @override
  List<Object?> get props => [month, canViewNext];
}

/// Before all three collections have reported for this month.
final class ReportsLoading extends ReportsState {
  const ReportsLoading({required super.month, required super.canViewNext});
}

/// The month is grouped and ready. A month with nothing in it is still loaded:
/// [SpendingReport.isEmpty] says so, and the frame renders around it.
final class ReportsLoaded extends ReportsState {
  const ReportsLoaded({
    required this.report,
    required super.month,
    required super.canViewNext,
  });

  final SpendingReport report;

  @override
  List<Object?> get props => [report, month, canViewNext];
}

final class ReportsFailure extends ReportsState {
  const ReportsFailure({
    required this.failure,
    required super.month,
    required super.canViewNext,
  });

  final DataFailure failure;

  @override
  List<Object?> get props => [failure, month, canViewNext];
}
