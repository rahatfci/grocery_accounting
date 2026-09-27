import 'package:equatable/equatable.dart';

import '../../../core/data_failure.dart';
import '../../items/logic/running_low.dart';

sealed class RunningLowState extends Equatable {
  const RunningLowState();

  @override
  List<Object?> get props => const [];
}

/// Before the items stream has reported.
final class RunningLowLoading extends RunningLowState {
  const RunningLowLoading();
}

/// The stream reported, and nothing is under its threshold.
final class RunningLowNone extends RunningLowState {
  const RunningLowNone();
}

final class RunningLowLoaded extends RunningLowState {
  const RunningLowLoaded(this.items, {required this.now});

  /// Never empty; an empty result is [RunningLowNone].
  final List<LowStockItem> items;

  /// The moment the items were judged at, so a date shown beside them, such
  /// as when one ran out, is worked out against the same instant.
  final DateTime now;

  @override
  List<Object?> get props => [items, now];
}

final class RunningLowFailure extends RunningLowState {
  const RunningLowFailure(this.failure);

  final DataFailure failure;

  @override
  List<Object?> get props => [failure];
}
