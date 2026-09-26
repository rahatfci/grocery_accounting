import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/receipt_found.dart';
import 'package:grocery_accounting/features/receipts/logic/receipt_reading.dart';

ScannedLine _line(String text) =>
    ScannedLine(rawText: text, quantity: 1, unit: ItemUnit.pcs, lineTotal: 1);

void main() {
  test('lists everything that was found', () {
    expect(
      receiptFoundLabel(
        ReceiptReading(
          total: 40.8,
          date: DateTime(2026, 9, 26),
          lines: [for (var i = 0; i < 11; i++) _line('LINE $i')],
        ),
      ),
      'Total, date and 11 lines found',
    );
  });

  test('names a single part on its own', () {
    expect(receiptFoundLabel(const ReceiptReading(total: 3)), 'Total found');
    expect(
      receiptFoundLabel(ReceiptReading(lines: [_line('PANE')])),
      '1 line found',
    );
  });

  test('says when nothing was found', () {
    expect(
      receiptFoundLabel(ReceiptReading.empty),
      'Nothing could be read. Fill it in by hand',
    );
  });
}
