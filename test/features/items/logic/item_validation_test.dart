import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_validation.dart';

void main() {
  group('parseDecimal', () {
    test('accepts both separators, because receipts here use a comma', () {
      expect(parseDecimal('1.5'), 1.5);
      expect(parseDecimal('1,5'), 1.5);
      expect(parseDecimal(' 2,25 '), 2.25);
      expect(parseDecimal('3'), 3);
    });

    test('rejects anything that is not a number', () {
      expect(parseDecimal(''), isNull);
      expect(parseDecimal('   '), isNull);
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal('1,2,3'), isNull);
    });
  });

  group('validateName', () {
    test('requires something other than whitespace', () {
      expect(validateName('Milk'), isNull);
      expect(validateName(''), 'Enter a name');
      expect(validateName('   '), 'Enter a name');
      expect(validateName(null), 'Enter a name');
    });
  });

  group('validateCategory', () {
    test('requires a choice', () {
      expect(validateCategory('produce'), isNull);
      expect(validateCategory(null), 'Choose a category');
      expect(validateCategory(''), 'Choose a category');
    });
  });

  group('validateRequiredAmount', () {
    test('accepts zero, because a non-staple has no daily usage', () {
      expect(validateRequiredAmount('0'), isNull);
      expect(validateRequiredAmount('0,5'), isNull);
    });

    test('rejects missing, non-numeric and negative', () {
      expect(validateRequiredAmount(''), 'Enter a number');
      expect(validateRequiredAmount('abc'), 'Enter a valid number');
      expect(validateRequiredAmount('-1'), 'Cannot be negative');
      expect(validateRequiredAmount('-0,5'), 'Cannot be negative');
    });
  });

  group('validateOptionalWeight', () {
    test('absence is allowed, zero and below is not', () {
      expect(validateOptionalWeight(''), isNull);
      expect(validateOptionalWeight(null), isNull);
      expect(validateOptionalWeight('1,2'), isNull);
      expect(validateOptionalWeight('0'), 'Must be greater than zero');
      expect(validateOptionalWeight('-2'), 'Must be greater than zero');
      expect(validateOptionalWeight('abc'), 'Enter a valid number');
    });
  });

  group('formatDecimal', () {
    test('drops the fraction from a whole number', () {
      expect(formatDecimal(2), '2');
      expect(formatDecimal(0), '0');
    });

    test('keeps a real fraction', () {
      expect(formatDecimal(0.25), '0.25');
      expect(formatDecimal(1.5), '1.5');
    });

    test('an absent optional value is an empty field', () {
      expect(formatDecimal(null), '');
    });

    test('round-trips through parseDecimal', () {
      for (final value in [0.0, 2.0, 0.25, 1.5, 12.75]) {
        expect(parseDecimal(formatDecimal(value)), value);
      }
    });
  });
}
