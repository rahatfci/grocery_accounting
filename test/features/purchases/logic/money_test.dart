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
}
