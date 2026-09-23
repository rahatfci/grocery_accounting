import '../../items/logic/item.dart';
import '../../items/logic/item_unit.dart';

/// Converts [quantity], measured in [from], into [item]'s own unit.
///
/// Null means the pair cannot be converted: pieces without an average piece
/// weight, or anything involving litres. Restocking an item in a unit it cannot
/// be measured in would write a wrong number into the stock contract, so it is
/// refused rather than approximated.
double? convertToItemUnit(double quantity, ItemUnit from, Item item) {
  if (from == item.unit) {
    return quantity;
  }
  return switch ((from, item.unit)) {
    (ItemUnit.kg, ItemUnit.g) => quantity * 1000,
    (ItemUnit.g, ItemUnit.kg) => quantity / 1000,
    // avgPieceWeight is expressed in the item's own unit, so one piece is one
    // of those units.
    (ItemUnit.pcs, ItemUnit.kg || ItemUnit.g) => _byPiece(quantity, item),
    _ => null,
  };
}

double? _byPiece(double quantity, Item item) {
  final weight = item.avgPieceWeight;
  return weight == null ? null : quantity * weight;
}

/// The units a line for [item] may be entered in, its own unit first.
///
/// Derived from [convertToItemUnit] rather than listed separately, so the
/// picker and the conversion cannot disagree.
List<ItemUnit> unitsFor(Item item) => [
  item.unit,
  for (final unit in ItemUnit.values)
    if (unit != item.unit && convertToItemUnit(1, unit, item) != null) unit,
];
