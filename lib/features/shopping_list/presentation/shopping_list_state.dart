import 'package:equatable/equatable.dart';

import '../../../core/data_failure.dart';
import '../logic/shopping_entry.dart';

sealed class ShoppingListState extends Equatable {
  const ShoppingListState();

  @override
  List<Object?> get props => const [];
}

/// Before the list has reported.
final class ShoppingListLoading extends ShoppingListState {
  const ShoppingListLoading();
}

/// The list reported, and nothing is on it.
final class ShoppingListEmpty extends ShoppingListState {
  const ShoppingListEmpty();
}

final class ShoppingListLoaded extends ShoppingListState {
  const ShoppingListLoaded(this.entries);

  /// Oldest first. Never empty; an empty list is [ShoppingListEmpty].
  final List<ShoppingEntry> entries;

  @override
  List<Object?> get props => [entries];
}

final class ShoppingListFailure extends ShoppingListState {
  const ShoppingListFailure(this.failure);

  final DataFailure failure;

  @override
  List<Object?> get props => [failure];
}
