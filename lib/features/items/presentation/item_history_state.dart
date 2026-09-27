import 'package:equatable/equatable.dart';

import '../../../core/data_failure.dart';
import '../logic/item_history.dart';

sealed class ItemHistoryState extends Equatable {
  const ItemHistoryState();

  @override
  List<Object?> get props => const [];
}

/// Before the item, its events and its purchases have all reported.
final class ItemHistoryLoading extends ItemHistoryState {
  const ItemHistoryLoading();
}

final class ItemHistoryLoaded extends ItemHistoryState {
  const ItemHistoryLoaded(this.entries);

  /// Newest first. May be empty: a new item has no history yet.
  final List<HistoryEntry> entries;

  @override
  List<Object?> get props => [entries];
}

final class ItemHistoryFailure extends ItemHistoryState {
  const ItemHistoryFailure(this.failure);

  final DataFailure failure;

  @override
  List<Object?> get props => [failure];
}
