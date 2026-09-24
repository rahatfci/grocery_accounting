import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_alias.dart';

void main() {
  test('normalises case and spacing only', () {
    expect(
      normalizeReceiptText('  Pomodori   pelati\t400G '),
      'POMODORI PELATI 400G',
    );
    expect(
      normalizeReceiptText('RISO 1KG'),
      isNot(normalizeReceiptText('RISO 1 KG')),
    );
  });

  test('document ids are stable, distinct and safe', () {
    final id = aliasDocumentId('POMODORI PELATI 400G');

    expect(aliasDocumentId('POMODORI PELATI 400G'), id);
    expect(aliasDocumentId('POMODORI PELATI 800G'), isNot(id));
    expect(id, isNot(contains('/')));
    expect(id, isNot(contains('=')));
    // Characters base64 would render as `/` or `+` still come out safe.
    expect(aliasDocumentId('???>>>'), isNot(contains('/')));
  });
}
