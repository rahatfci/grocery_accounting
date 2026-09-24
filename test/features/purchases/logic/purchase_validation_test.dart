import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_draft.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_validation.dart';

import '../../items/fake_item_repository.dart';

void main() {
  final today = DateTime(2026, 9, 21, 18, 0);

  group('validateMoney', () {
    test('requires an amount', () {
      expect(validateMoney(null), 'Enter an amount');
      expect(validateMoney('  '), 'Enter an amount');
    });

    test('requires a number', () {
      expect(validateMoney('abc'), 'Enter a valid amount');
    });

    test('refuses a negative amount', () {
      expect(validateMoney('-1'), 'Cannot be negative');
    });

    test('refuses anything finer than a cent', () {
      expect(validateMoney('1.234'), 'Use at most two decimals');
      expect(validateMoney('1,234'), 'Use at most two decimals');
    });

    test('accepts either decimal separator', () {
      expect(validateMoney('12,50'), isNull);
      expect(validateMoney('12.50'), isNull);
      expect(validateMoney('12'), isNull);
      expect(validateMoney('0'), isNull);
    });
  });

  group('validateTotal', () {
    test('refuses a total of zero', () {
      expect(validateTotal('0'), 'Enter an amount greater than zero');
    });

    test('reports the amount problem first', () {
      expect(validateTotal(''), 'Enter an amount');
    });

    test('accepts a real total', () {
      expect(validateTotal('43,20'), isNull);
    });
  });

  test('validateLineTotal allows a line with no price', () {
    expect(validateLineTotal('0'), isNull);
  });

  test('validateShopName requires a shop', () {
    expect(validateShopName('   '), 'Enter a shop');
    expect(validateShopName('Lidl'), isNull);
  });

  group('validateQuantity', () {
    test('requires a quantity above zero', () {
      expect(validateQuantity(''), 'Enter a quantity');
      expect(validateQuantity('nope'), 'Enter a valid number');
      expect(validateQuantity('0'), 'Must be greater than zero');
      expect(validateQuantity('-1'), 'Must be greater than zero');
    });

    test('accepts a decimal quantity with either separator', () {
      expect(validateQuantity('0,125'), isNull);
      expect(validateQuantity('1.5'), isNull);
    });
  });

  group('validateDate', () {
    test('refuses tomorrow', () {
      expect(
        validateDate(DateTime(2026, 9, 22), today: today),
        'A purchase cannot be in the future',
      );
    });

    test('accepts earlier today and the rest of today', () {
      expect(validateDate(DateTime(2026, 9, 21), today: today), isNull);
      expect(validateDate(DateTime(2026, 9, 21, 23, 59), today: today), isNull);
    });

    test('accepts the past', () {
      expect(validateDate(DateTime(2026, 8, 30), today: today), isNull);
    });
  });

  group('validateDraft', () {
    final rice = testItem(id: 'rice', name: 'Rice');

    PurchaseDraft valid() => PurchaseDraft(
      date: DateTime(2026, 9, 21),
      shopName: 'Conad',
      totalText: '12,50',
      paidByUserId: 'u1',
      lines: [
        PurchaseDraftLine(
          item: rice,
          quantity: 1,
          unit: ItemUnit.kg,
          lineTotal: 2,
        ),
      ],
    );

    test('passes a complete draft', () {
      expect(validateDraft(valid(), today: today), isNull);
    });

    test('passes a draft with no lines at all', () {
      expect(
        validateDraft(valid().copyWith(lines: const []), today: today),
        isNull,
      );
    });

    test('reports the date, then the shop, then the total, then the payer', () {
      expect(
        validateDraft(
          valid().copyWith(date: DateTime(2026, 9, 30), shopName: ''),
          today: today,
        ),
        'A purchase cannot be in the future',
      );
      expect(
        validateDraft(
          valid().copyWith(shopName: '', totalText: ''),
          today: today,
        ),
        'Enter a shop',
      );
      expect(
        validateDraft(
          valid().copyWith(totalText: '', paidByUserId: ''),
          today: today,
        ),
        'Enter an amount',
      );
      expect(
        validateDraft(valid().copyWith(paidByUserId: ''), today: today),
        'Choose who paid',
      );
    });

    test('names a line that cannot restock its item', () {
      final draft = valid().copyWith(
        lines: [
          PurchaseDraftLine(
            item: rice,
            quantity: 2,
            unit: ItemUnit.pcs,
            lineTotal: 2,
          ),
        ],
      );

      expect(
        validateDraft(draft, today: today),
        'Rice cannot be measured in pcs',
      );
    });
  });

  test('validateDraft accepts an unmatched line, which is spend only', () {
    final draft = PurchaseDraft(
      date: DateTime(2026, 9, 21),
      shopName: 'Conad',
      totalText: '43,20',
      paidByUserId: 'abc123',
      lines: const [
        PurchaseDraftLine(
          item: null,
          quantity: 1,
          unit: ItemUnit.pcs,
          lineTotal: 2,
          scannedText: 'PANE',
        ),
      ],
    );

    expect(validateDraft(draft, today: DateTime(2026, 9, 21)), isNull);
  });
}
