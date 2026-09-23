import 'package:equatable/equatable.dart';

/// One thing someone in the household wants bought.
final class ShoppingEntry extends Equatable {
  const ShoppingEntry({
    required this.id,
    required this.text,
    required this.itemId,
    required this.addedByUserId,
    required this.addedAt,
  });

  /// The Firestore document id. Empty for an entry that has not been written.
  final String id;

  /// As typed, trimmed.
  final String text;

  /// The catalogue item the text named when it was added, or null when it
  /// named none, or more than one.
  final String? itemId;

  /// A `users/{userId}` id.
  final String addedByUserId;

  final DateTime addedAt;

  @override
  List<Object?> get props => [id, text, itemId, addedByUserId, addedAt];
}
