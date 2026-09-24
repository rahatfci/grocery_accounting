import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/members/logic/household_member.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_source.dart';
import 'package:grocery_accounting/features/reports/logic/purchases_csv.dart';

import '../../items/fake_item_repository.dart';
import '../../purchases/fake_purchase_repository.dart';

const _header =
    'Date;Shop;Paid by;Purchase total;Receipt text;Item;Category;Quantity;'
    'Unit;Line total;Source';

void main() {
  final september = DateTime(2026, 9);
  final rice = testItem(id: 'rice', name: 'Rice', category: 'pantry');
  const members = [
    HouseholdMember(id: 'u1', displayName: 'Rahat', email: 'r@example.com'),
  ];

  List<String> rowsOf(String csv) => csv.split('\r\n');

  String csvOf(List<dynamic> purchases) => monthCsv(
    month: september,
    purchases: purchases.cast(),
    items: [rice],
    members: members,
  );

  test('names the file after the month', () {
    expect(monthCsvFileName(DateTime(2026, 3)), 'grocery-2026-03.csv');
  });

  test('writes the header, one row per line, CRLF and a final line break', () {
    final csv = csvOf([
      testPurchase(
        date: DateTime(2026, 9, 12),
        shopName: 'Conad',
        total: 43.2,
        paidByUserId: 'u1',
        source: PurchaseSource.scanned,
        lines: [
          testLine(
            itemId: 'rice',
            rawText: 'RISO ARBORIO',
            quantity: 0.45,
            unit: ItemUnit.kg,
            lineTotal: 2.5,
          ),
          testLine(
            itemId: null,
            rawText: 'PANE',
            quantity: 1,
            unit: ItemUnit.pcs,
            lineTotal: 1.2,
          ),
        ],
      ),
    ]);

    expect(rowsOf(csv), [
      _header,
      '12/09/2026;Conad;Rahat;43,20;RISO ARBORIO;Rice;Pantry & Dry Goods;0,45;kg;2,50;scanned',
      '12/09/2026;Conad;Rahat;43,20;PANE;;;1;pcs;1,20;scanned',
      '',
    ]);
  });

  test('keeps a purchase with no lines, in date order', () {
    final csv = csvOf([
      testPurchase(
        id: 'b',
        date: DateTime(2026, 9, 20),
        total: 5,
        lines: const [],
      ),
      testPurchase(
        id: 'a',
        date: DateTime(2026, 9, 2),
        total: 7,
        paidByUserId: 'u1',
        lines: const [],
      ),
    ]);

    final rows = rowsOf(csv);
    expect(rows[1], startsWith('02/09/2026;Conad;Rahat;7,00;;;;;;;manual'));
    expect(rows[2], startsWith('20/09/2026'));
  });

  test('leaves out purchases from other months', () {
    final csv = csvOf([
      testPurchase(date: DateTime(2026, 8, 31, 23, 59)),
      testPurchase(date: DateTime(2026, 10, 1)),
      testPurchase(date: DateTime(2026, 9, 30, 23, 59), lines: const []),
    ]);

    expect(rowsOf(csv), hasLength(3));
  });

  test('a deleted item or a gone member leaves what is known', () {
    final csv = csvOf([
      testPurchase(
        date: DateTime(2026, 9, 5),
        paidByUserId: 'ghost',
        lines: [testLine(itemId: 'deleted', rawText: 'LATTE')],
      ),
    ]);

    expect(
      rowsOf(csv)[1],
      '05/09/2026;Conad;ghost;20,00;LATTE;;;1;kg;5,00;manual',
    );
  });

  test('quotes separators, quotes and line breaks', () {
    final csv = csvOf([
      testPurchase(
        date: DateTime(2026, 9, 5),
        shopName: 'Bar; "Da Mario"',
        lines: [testLine(rawText: 'riga\nspezzata')],
      ),
    ]);

    expect(csv, contains('"Bar; ""Da Mario"""'));
    expect(csv, contains('"riga\nspezzata"'));
  });

  test('guards text that a spreadsheet would run as a formula', () {
    final csv = csvOf([
      testPurchase(
        date: DateTime(2026, 9, 5),
        shopName: '=HYPERLINK("x")',
        lines: [
          testLine(rawText: '+39 LATTE'),
          testLine(rawText: '-SCONTO'),
          testLine(rawText: '@SUM(A1)'),
        ],
      ),
    ]);

    final rows = rowsOf(csv);
    expect(rows[1], contains('"\'=HYPERLINK(""x"")"'));
    expect(rows[1], contains(";'+39 LATTE;"));
    expect(rows[2], contains(";'-SCONTO;"));
    expect(rows[3], contains(";'@SUM(A1);"));
  });

  test('an empty month is only the header', () {
    expect(csvOf(const []), '$_header\r\n');
  });
}
