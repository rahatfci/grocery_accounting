import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_draft.dart';
import 'package:grocery_accounting/features/purchases/logic/receipt_matching.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_alias.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_reading.dart';

import '../../items/fake_item_repository.dart';

PurchaseDraft _draft(
  List<PurchaseDraftLine> lines, {
  String shop = ' Conad ',
}) => PurchaseDraft(
  date: DateTime(2026, 9, 24),
  shopName: shop,
  totalText: '10',
  paidByUserId: 'u1',
  lines: lines,
  scanned: true,
);

String? _byId(Item item) => item.id.isEmpty ? 'generated' : item.id;

void main() {
  final rice = testItem(id: 'rice', name: 'Rice');
  final eggs = testItem(id: 'eggs', name: 'Eggs', unit: ItemUnit.pcs);

  group('learnedAliases', () {
    test('learns each matched scanned line', () {
      final aliases = learnedAliases(
        _draft([
          PurchaseDraftLine(
            item: rice,
            quantity: 1,
            unit: ItemUnit.kg,
            lineTotal: 1.8,
            scannedText: ' riso  arborio ',
          ),
        ]),
        resolveItemId: _byId,
      );

      expect(aliases, const [
        ReceiptAlias(
          rawTextNormalized: 'RISO ARBORIO',
          itemId: 'rice',
          defaultQuantity: 1,
          defaultUnit: ItemUnit.kg,
          shopName: 'Conad',
        ),
      ]);
    });

    test('learns nothing from unmatched or hand-added lines', () {
      final aliases = learnedAliases(
        _draft([
          const PurchaseDraftLine(
            item: null,
            quantity: 1,
            unit: ItemUnit.pcs,
            lineTotal: 1,
            scannedText: 'PANE',
          ),
          PurchaseDraftLine(
            item: rice,
            quantity: 1,
            unit: ItemUnit.kg,
            lineTotal: 1,
          ),
        ]),
        resolveItemId: _byId,
      );

      expect(aliases, isEmpty);
    });

    test('uses the id generated for an item created on the purchase', () {
      final aliases = learnedAliases(
        _draft([
          PurchaseDraftLine(
            item: newTestItem(name: 'Bread'),
            quantity: 1,
            unit: ItemUnit.kg,
            lineTotal: 2,
            scannedText: 'PANE',
          ),
        ], shop: ''),
        resolveItemId: _byId,
      );

      expect(aliases.single.itemId, 'generated');
      expect(aliases.single.shopName, isNull);
    });

    test('the later of two lines with the same wording wins', () {
      final aliases = learnedAliases(
        _draft([
          PurchaseDraftLine(
            item: rice,
            quantity: 1,
            unit: ItemUnit.kg,
            lineTotal: 1,
            scannedText: 'OFFERTA',
          ),
          PurchaseDraftLine(
            item: eggs,
            quantity: 6,
            unit: ItemUnit.pcs,
            lineTotal: 2,
            scannedText: 'offerta',
          ),
        ]),
        resolveItemId: _byId,
      );

      expect(aliases.single.itemId, 'eggs');
      expect(aliases.single.defaultQuantity, 6);
    });
  });

  group('lineFromReading', () {
    const eggsAlias = ReceiptAlias(
      rawTextNormalized: 'UOVA FRESCHE',
      itemId: 'eggs',
      defaultQuantity: 6,
      defaultUnit: ItemUnit.pcs,
      shopName: 'Conad',
    );
    final aliases = {eggsAlias.rawTextNormalized: eggsAlias};

    const scannedEggs = ScannedLine(
      rawText: 'Uova  Fresche',
      quantity: 1,
      unit: ItemUnit.pcs,
      lineTotal: 2.99,
    );

    test('matches a known wording with the alias quantity', () {
      final line = lineFromReading(
        scannedEggs,
        aliases: aliases,
        catalogue: [rice, eggs],
      );

      expect(line.item, eggs);
      expect(line.quantity, 6);
      expect(line.unit, ItemUnit.pcs);
      expect(line.lineTotal, 2.99);
      expect(line.scannedText, 'Uova  Fresche');
    });

    test('keeps a quantity the receipt printed', () {
      final line = lineFromReading(
        scannedEggs.withQuantity(12, ItemUnit.pcs),
        aliases: aliases,
        catalogue: [eggs],
      );

      expect(line.item, eggs);
      expect(line.quantity, 12);
    });

    test('leaves an unknown wording unmatched', () {
      final line = lineFromReading(
        const ScannedLine(
          rawText: 'LATTE',
          quantity: 1,
          unit: ItemUnit.pcs,
          lineTotal: 1.29,
        ),
        aliases: aliases,
        catalogue: [eggs],
      );

      expect(line.isMatched, isFalse);
      expect(line.scannedText, 'LATTE');
      expect(line.quantity, 1);
    });

    test('ignores an alias whose item was deleted', () {
      final line = lineFromReading(
        scannedEggs,
        aliases: aliases,
        catalogue: [rice],
      );

      expect(line.isMatched, isFalse);
    });

    test('ignores an alias whose unit no longer converts', () {
      // Rice is measured in kg with no piece weight, so 6 pcs means nothing.
      final line = lineFromReading(
        scannedEggs,
        aliases: {
          'UOVA FRESCHE': const ReceiptAlias(
            rawTextNormalized: 'UOVA FRESCHE',
            itemId: 'rice',
            defaultQuantity: 6,
            defaultUnit: ItemUnit.pcs,
            shopName: null,
          ),
        },
        catalogue: [rice],
      );

      expect(line.isMatched, isFalse);
    });
  });

  test('only a quantity row marks a quantity as read', () {
    OcrLine row(String text, int index) => OcrLine(
      text: text,
      left: 0,
      top: index * 20.0,
      right: 300,
      bottom: index * 20.0 + 16,
    );

    final reading = parseReceipt([
      row('PANE 1,20', 0),
      row('2 x 1,29', 1),
      row('YOGURT 2,58', 2),
    ], today: DateTime(2026, 9, 24));

    expect(reading.lines.map((l) => l.quantityRead), [false, true]);
  });
}
