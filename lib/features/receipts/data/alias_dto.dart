import '../../items/logic/item_unit.dart';
import '../logic/receipt_alias.dart';

/// The full body of an `aliases` document.
Map<String, Object?> aliasToFirestore(ReceiptAlias alias) => {
  'rawTextNormalized': alias.rawTextNormalized,
  'itemId': alias.itemId,
  'defaultQuantity': alias.defaultQuantity,
  'defaultUnit': alias.defaultUnit.key,
  'shopName': alias.shopName,
};

/// Reads a document body into a [ReceiptAlias], or null when it cannot map
/// anything: an alias with no wording or no item would only mislead.
ReceiptAlias? aliasFromFirestore(Map<String, Object?> data) {
  final text = data['rawTextNormalized'];
  final itemId = data['itemId'];
  if (text is! String || text.isEmpty || itemId is! String || itemId.isEmpty) {
    return null;
  }
  final quantity = data['defaultQuantity'];
  final shop = data['shopName'];
  return ReceiptAlias(
    rawTextNormalized: text,
    itemId: itemId,
    defaultQuantity: quantity is num && quantity > 0 ? quantity.toDouble() : 1,
    defaultUnit: ItemUnit.fromKey(
      data['defaultUnit'] is String ? data['defaultUnit'] as String : '',
    ),
    shopName: shop is String && shop.isNotEmpty ? shop : null,
  );
}
