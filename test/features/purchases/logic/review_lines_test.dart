import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_draft.dart';
import 'package:grocery_accounting/features/purchases/logic/review_lines.dart';

import '../../items/fake_item_repository.dart';

/// The Italian currency format separates the amount from the symbol with a
/// non-breaking space, which is invisible in an expectation.
String _plain(String text) => text.replaceAll('\u00a0', ' ');

PurchaseDraftLine _line({
  bool matched = true,
  bool created = false,
  bool learned = false,
  String? scanned = 'RISO ARBORIO 1KG',
  double quantity = 1,
  ItemUnit unit = ItemUnit.kg,
}) => PurchaseDraftLine(
  item: !matched
      ? null
      : created
      ? newTestItem(name: 'Oat milk')
      : testItem(name: 'Rice'),
  quantity: quantity,
  unit: unit,
  lineTotal: 2.49,
  scannedText: scanned,
  learned: learned,
);

void main() {
  group('lineStateOf', () {
    test('tells the four states apart', () {
      expect(lineStateOf(_line(matched: false)), LineState.unmatched);
      expect(lineStateOf(_line(learned: true)), LineState.learned);
      expect(lineStateOf(_line()), LineState.matched);
      expect(lineStateOf(_line(created: true)), LineState.newItem);
    });

    test('a new item wins over learned', () {
      expect(
        lineStateOf(_line(created: true, learned: true)),
        LineState.newItem,
      );
    });
  });

  group('lineDetail', () {
    test('says an unmatched line is not matched, with its quantity', () {
      expect(
        lineDetail(_line(matched: false, quantity: 2, unit: ItemUnit.pcs)),
        'Not matched · 2 pcs',
      );
    });

    test('names the receipt wording a learned line came from', () {
      expect(
        lineDetail(_line(learned: true)),
        '1 kg · learned from RISO ARBORIO 1KG',
      );
    });

    test('shows the receipt wording beside a matched line', () {
      expect(
        lineDetail(_line(quantity: 1.21, scanned: 'PETTO POLLO 1,210 KG')),
        '1.21 kg · PETTO POLLO 1,210 KG',
      );
    });

    test('marks a line that creates an item', () {
      expect(
        lineDetail(
          _line(created: true, unit: ItemUnit.l, scanned: 'BEV. AVENA 1L'),
        ),
        '1 L · new pantry item · BEV. AVENA 1L',
      );
    });

    test('a line typed by hand has only its quantity', () {
      expect(lineDetail(_line(scanned: null)), '1 kg');
      expect(lineDetail(_line(scanned: '  ', learned: true)), '1 kg');
      expect(
        lineDetail(_line(created: true, scanned: null)),
        '1 kg · new pantry item',
      );
    });
  });

  group('linesGapNote', () {
    test('says when the lines add up exactly', () {
      expect(
        linesGapNote(linesTotal: 40.8, total: 40.8),
        'The lines add up to the receipt total.',
      );
    });

    test('names a gap above the total as a discount', () {
      expect(
        _plain(linesGapNote(linesTotal: 41.4, total: 40.8)),
        'The lines come to 0,60 € more than the receipt, usually a discount. '
        'Lines never have to match the receipt total, and reports use the '
        'total.',
      );
    });

    test('names a gap below the total as an unpriced line', () {
      expect(
        _plain(linesGapNote(linesTotal: 38.8, total: 40.8)),
        startsWith(
          'The lines come to 2,00 € less than the receipt, usually a line '
          'that was not priced.',
        ),
      );
    });

    test('ignores a gap below a cent', () {
      expect(
        linesGapNote(linesTotal: 0.1 + 0.2, total: 0.3),
        'The lines add up to the receipt total.',
      );
    });
  });

  group('learningNote', () {
    test('says what the wording becomes', () {
      expect(
        learningNote(
          rawText: 'POMODORI PELATI 400G',
          itemName: 'Peeled tomatoes',
          quantity: 2,
          unit: ItemUnit.pcs,
        ),
        'From now on, POMODORI PELATI 400G becomes 2 pcs of Peeled tomatoes '
        'by itself.',
      );
    });

    test('leaves out a quantity that is missing or not positive', () {
      expect(
        learningNote(rawText: 'OLIO', itemName: 'Olive oil'),
        'From now on, OLIO becomes Olive oil by itself.',
      );
      expect(
        learningNote(
          rawText: 'OLIO',
          itemName: 'Olive oil',
          quantity: 0,
          unit: ItemUnit.l,
        ),
        'From now on, OLIO becomes Olive oil by itself.',
      );
    });
  });

  group('matchCandidates', () {
    final rice = testItem(id: 'rice', name: 'Rice');
    final brownRice = testItem(id: 'brown', name: 'Brown rice');
    final tomatoes = testItem(id: 'tom', name: 'Tomatoes');
    final peeled = testItem(id: 'peeled', name: 'Peeled tomatoes');
    final all = [tomatoes, rice, peeled, brownRice];

    test('with no query, offers items by name', () {
      expect(matchCandidates(all, ''), [brownRice, peeled, rice, tomatoes]);
    });

    test('finds any part of the name, ignoring case', () {
      expect(matchCandidates(all, 'TOMAT'), [tomatoes, peeled]);
    });

    test('puts names that start with the query first', () {
      expect(matchCandidates(all, 'rice'), [rice, brownRice]);
    });

    test('keeps the chosen item first, even when it does not match', () {
      expect(matchCandidates(all, 'tomat', selected: rice), [
        rice,
        tomatoes,
        peeled,
      ]);
    });

    test('stops at the limit', () {
      expect(matchCandidates(all, '', limit: 2), [brownRice, peeled]);
    });

    test('offers nothing when nothing matches', () {
      expect(matchCandidates(all, 'caviar'), isEmpty);
    });
  });
}
