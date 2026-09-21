import 'package:equatable/equatable.dart';

import 'item_unit.dart';

const Object _unchanged = Object();

/// One thing the household buys.
///
/// Catalogue and pantry in one document: `stockAtBaseline` and `baselineDate`
/// are the pantry half, owned by the stock features, and are carried here so
/// every document is a valid input to the stock formula.
final class Item extends Equatable {
  const Item({
    required this.id,
    required this.name,
    required this.unit,
    required this.category,
    required this.avgPieceWeight,
    required this.dailyUsage,
    required this.lowThreshold,
    required this.stockAtBaseline,
    required this.baselineDate,
  });

  /// The Firestore document id. Empty for an item that has not been written.
  final String id;

  final String name;
  final ItemUnit unit;

  /// A built-in category key or a member-supplied label. See item_category.dart.
  final String category;

  /// Converts "one chicken" or "2 onions" into [unit]. Null when the item is
  /// not counted in pieces.
  final double? avgPieceWeight;

  /// Per day. Zero for anything that is not a staple.
  final double dailyUsage;

  final double lowThreshold;
  final double stockAtBaseline;
  final DateTime baselineDate;

  Item copyWith({
    String? id,
    String? name,
    ItemUnit? unit,
    String? category,
    Object? avgPieceWeight = _unchanged,
    double? dailyUsage,
    double? lowThreshold,
    double? stockAtBaseline,
    DateTime? baselineDate,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      // The sentinel keeps "leave it alone" distinct from "set it to null".
      avgPieceWeight: identical(avgPieceWeight, _unchanged)
          ? this.avgPieceWeight
          : avgPieceWeight as double?,
      dailyUsage: dailyUsage ?? this.dailyUsage,
      lowThreshold: lowThreshold ?? this.lowThreshold,
      stockAtBaseline: stockAtBaseline ?? this.stockAtBaseline,
      baselineDate: baselineDate ?? this.baselineDate,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    unit,
    category,
    avgPieceWeight,
    dailyUsage,
    lowThreshold,
    stockAtBaseline,
    baselineDate,
  ];
}
