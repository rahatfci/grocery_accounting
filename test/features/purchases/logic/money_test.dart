import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/purchases/logic/money.dart';

/// The Italian currency format separates the amount from the symbol with a
/// non-breaking space, which is invisible in an expectation.
String _plain(String formatted) => formatted.replaceAll(' ', ' ');

void main() {
  group('formatEuro', () {
    test('uses a decimal comma and always two decimals', () {
      expect(_plain(formatEuro(12.3)), '12,30 €');
    });

    test('groups thousands with a dot', () {
      expect(_plain(formatEuro(1234.5)), '1.234,50 €');
    });

    test('formats zero', () {
      expect(_plain(formatEuro(0)), '0,00 €');
    });
  });

  group('formatPurchaseDate', () {
    test('is dd/MM/yyyy', () {
      expect(formatPurchaseDate(DateTime(2026, 9, 21)), '21/09/2026');
    });

    test('pads a single digit day and month', () {
      expect(formatPurchaseDate(DateTime(2026, 1, 5)), '05/01/2026');
    });
  });

  group('formatSignedEuro', () {
    test('marks a rise with a plus', () {
      expect(_plain(formatSignedEuro(42.1)), '+42,10 €');
    });

    test('marks a fall with a minus sign', () {
      expect(_plain(formatSignedEuro(-18.3)), '−18,30 €');
    });

    test('leaves nothing unsigned', () {
      expect(_plain(formatSignedEuro(0.001)), '0,00 €');
    });
  });

  group('formatAmountInput', () {
    test('writes two decimals with a comma and no symbol', () {
      expect(formatAmountInput(1.78), '1,78');
      expect(formatAmountInput(40.8), '40,80');
      expect(formatAmountInput(3), '3,00');
    });
  });
}
