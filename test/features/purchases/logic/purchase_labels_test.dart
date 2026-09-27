import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_labels.dart';

import '../fake_purchase_repository.dart';

void main() {
  test('lineCountLabel counts the lines', () {
    expect(lineCountLabel(0), 'No lines');
    expect(lineCountLabel(1), '1 line');
    expect(lineCountLabel(11), '11 lines');
  });

  test('purchaseDetail names who paid and the lines, with the date when '
      'asked', () {
    final purchase = testPurchase(
      date: DateTime(2026, 9, 24, 18),
      lines: [testLine(), testLine()],
    );

    expect(purchaseDetail(purchase, payerName: 'Giulia'), 'Giulia · 2 lines');
    expect(
      purchaseDetail(purchase, payerName: 'Giulia', withDate: true),
      'Giulia · 24/09/2026 · 2 lines',
    );
  });

  test('purchasesByDay groups by calendar day in the order given', () {
    final late = testPurchase(id: 'late', date: DateTime(2026, 9, 26, 21));
    final early = testPurchase(id: 'early', date: DateTime(2026, 9, 26, 8));
    final before = testPurchase(id: 'before', date: DateTime(2026, 9, 24));

    final groups = purchasesByDay([late, early, before]);

    expect(groups, [
      DayGroup(day: DateTime(2026, 9, 26), purchases: [late, early]),
      DayGroup(day: DateTime(2026, 9, 24), purchases: [before]),
    ]);
  });

  test('dayHeading says today, yesterday, or the weekday', () {
    final now = DateTime(2026, 9, 26, 9);

    expect(dayHeading(DateTime(2026, 9, 26), now: now), 'TODAY · 26/09/2026');
    expect(
      dayHeading(DateTime(2026, 9, 25), now: now),
      'YESTERDAY · 25/09/2026',
    );
    expect(
      dayHeading(DateTime(2026, 9, 24), now: now),
      'THURSDAY · 24/09/2026',
    );
  });

  group('saved lines', () {
    test('a spend-only line keeps its receipt wording', () {
      final line = testLine(
        itemId: null,
        rawText: 'POMODORI PELATI 400G',
        quantity: 2,
        unit: ItemUnit.pcs,
      );

      expect(savedLineTitle(line, itemName: null), 'POMODORI PELATI 400G');
      expect(savedLineDetail(line, itemName: null), 'Spend only · 2 pcs');
    });

    test('a matched line is titled by its item, with the receipt wording', () {
      final line = testLine(rawText: 'RISO ARBORIO 1KG');

      expect(savedLineTitle(line, itemName: 'Rice'), 'Rice');
      expect(
        savedLineDetail(line, itemName: 'Rice'),
        '1 kg · RISO ARBORIO 1KG',
      );
    });

    test('a line typed by hand does not repeat the item name', () {
      final line = testLine(rawText: 'rice');

      expect(savedLineDetail(line, itemName: 'Rice'), '1 kg');
    });

    test('a line whose item is gone says so', () {
      final line = testLine(rawText: 'RISO ARBORIO 1KG');

      expect(savedLineTitle(line, itemName: null), 'RISO ARBORIO 1KG');
      expect(
        savedLineDetail(line, itemName: null),
        '1 kg · no longer in the pantry',
      );
    });

    test('spend-only lines come first, each group in its own order', () {
      final a = testLine(rawText: 'a');
      final b = testLine(itemId: null, rawText: 'b');
      final c = testLine(rawText: 'c');
      final d = testLine(itemId: null, rawText: 'd');

      expect(linesSpendOnlyFirst([a, b, c, d]), [b, d, a, c]);
    });
  });

  test('purchaseDay spells out the weekday', () {
    expect(purchaseDay(DateTime(2026, 9, 26)), 'Saturday 26/09/2026');
  });
}
