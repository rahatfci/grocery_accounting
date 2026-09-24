import 'package:equatable/equatable.dart';

import '../../../core/data_failure.dart';
import '../logic/item.dart';

sealed class ItemsState extends Equatable {
  const ItemsState();

  @override
  List<Object?> get props => const [];
}

/// Before the items stream has reported anything, so it is not yet known
/// whether the catalogue has anything in it.
final class ItemsLoading extends ItemsState {
  const ItemsLoading();
}

/// The stream reported, and the catalogue is empty.
final class ItemsEmpty extends ItemsState {
  const ItemsEmpty();
}

final class ItemsLoaded extends ItemsState {
  const ItemsLoaded(this.items, {required this.now});

  final List<Item> items;

  /// The moment current stock is shown for. Taken when the stream reports or
  /// the catalogue is refreshed, so every row on screen is derived against the
  /// same instant.
  final DateTime now;

  @override
  List<Object?> get props => [items, now];
}

final class ItemsFailure extends ItemsState {
  const ItemsFailure(this.failure);

  final DataFailure failure;

  @override
  List<Object?> get props => [failure];
}
