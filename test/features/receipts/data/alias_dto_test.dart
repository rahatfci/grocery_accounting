import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/receipts/data/alias_dto.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_alias.dart';

void main() {
  const alias = ReceiptAlias(
    rawTextNormalized: 'POMODORI PELATI 400G',
    itemId: 'tomatoes',
    defaultQuantity: 0.4,
    defaultUnit: ItemUnit.kg,
    shopName: 'Conad',
  );

  test('writes the planned fields', () {
    expect(aliasToFirestore(alias), {
      'rawTextNormalized': 'POMODORI PELATI 400G',
      'itemId': 'tomatoes',
      'defaultQuantity': 0.4,
      'defaultUnit': 'kg',
      'shopName': 'Conad',
    });
  });

  test('reads back what it wrote', () {
    expect(aliasFromFirestore(aliasToFirestore(alias)), alias);
  });

  test('an alias with no wording or no item is ignored', () {
    expect(aliasFromFirestore(const {'itemId': 'x'}), isNull);
    expect(aliasFromFirestore(const {'rawTextNormalized': 'PANE'}), isNull);
    expect(
      aliasFromFirestore(const {'rawTextNormalized': '', 'itemId': 'x'}),
      isNull,
    );
    expect(
      aliasFromFirestore(const {'rawTextNormalized': 'PANE', 'itemId': 7}),
      isNull,
    );
  });

  test('reads a malformed quantity, unit or shop defensively', () {
    final read = aliasFromFirestore(const {
      'rawTextNormalized': 'PANE',
      'itemId': 'bread',
      'defaultQuantity': -3,
      'defaultUnit': 42,
      'shopName': '',
    });

    expect(read?.defaultQuantity, 1);
    expect(read?.defaultUnit, ItemUnit.fallback);
    expect(read?.shopName, isNull);
  });
}
