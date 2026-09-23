import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item.dart';
import 'package:grocery_accounting/features/members/logic/household_member.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase.dart';
import 'package:grocery_accounting/features/reports/logic/spending_report.dart';

import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';

/// The month every test selects, and the two around it.
final september = DateTime(2026, 9);
final inSeptember = DateTime(2026, 9, 10, 18, 30);
final inAugust = DateTime(2026, 8, 20, 9);
final inJuly = DateTime(2026, 7, 5, 9);

SpendingReport report({
  List<Purchase> purchases = const [],
  List<Item> items = const [],
  List<HouseholdMember> members = const [],
}) => buildSpendingReport(
  month: september,
  purchases: purchases,
  items: items,
  members: members,
);

/// Label and amount together, so a failure names the row that was wrong.
List<(String, double)> pairs(List<ReportRow> rows) => [
  for (final row in rows) (row.label, row.amount),
];

void main() {
  group('the month window', () {
    test('totals only the selected month', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', date: inSeptember, total: 20),
          testPurchase(id: 'b', date: inSeptember, total: 30),
          testPurchase(id: 'c', date: inAugust, total: 99),
        ],
      );

      expect(result.monthTotal, 50);
      expect(result.purchaseCount, 2);
      expect(result.month, september);
    });

    test('takes the month before it as the comparison', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', date: inSeptember, total: 20),
          testPurchase(id: 'b', date: inAugust, total: 15),
          testPurchase(id: 'c', date: inAugust, total: 25),
        ],
      );

      expect(result.previousMonthTotal, 40);
    });

    test('ignores anything outside both months', () {
      final result = report(purchases: [testPurchase(date: inJuly, total: 99)]);

      expect(result.monthTotal, 0);
      expect(result.previousMonthTotal, 0);
      expect(result.isEmpty, isTrue);
    });

    test('a month with nothing in it reports nothing', () {
      final result = report(members: [testMember()]);

      expect(result.isEmpty, isTrue);
      expect(result.monthTotal, 0);
      expect(result.byCategory, isEmpty);
      expect(result.byShop, isEmpty);
      expect(result.byPerson.single.paid, 0);
    });

    test('a month that only has purchases is not empty', () {
      final result = report(purchases: [testPurchase()]);

      expect(result.isEmpty, isFalse);
    });
  });

  group('by person', () {
    test('splits the month equally across the members', () {
      final result = report(
        purchases: [testPurchase(paidByUserId: 'one', total: 100)],
        members: [
          testMember(id: 'one', displayName: 'rahat'),
          testMember(id: 'two', displayName: 'sara'),
        ],
      );

      expect(result.memberCount, 2);
      expect(result.byPerson.map((row) => row.share), [50, 50]);
    });

    test('a member who paid nothing still appears against their share', () {
      final result = report(
        purchases: [testPurchase(paidByUserId: 'one', total: 100)],
        members: [
          testMember(id: 'one', displayName: 'rahat'),
          testMember(id: 'two', displayName: 'sara'),
        ],
      );

      final sara = result.byPerson.last;
      expect(sara.paid, 0);
      expect(sara.share, 50);
      expect(sara.difference, -50);
      expect(sara.hasShare, isTrue);
    });

    test('a member who paid more than their share is positive', () {
      final result = report(
        purchases: [testPurchase(paidByUserId: 'one', total: 100)],
        members: [
          testMember(id: 'one', displayName: 'rahat'),
          testMember(id: 'two', displayName: 'sara'),
        ],
      );

      expect(result.byPerson.first.difference, 50);
    });

    test(
      'a share that does not divide evenly is still the month over the count',
      () {
        final result = report(
          purchases: [testPurchase(paidByUserId: 'one', total: 100)],
          members: [
            testMember(id: 'one'),
            testMember(id: 'two'),
            testMember(id: 'three'),
          ],
        );

        expect(result.byPerson.first.share, closeTo(33.33, 0.01));
      },
    );

    test('a payer with no member document gets its own row', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', paidByUserId: 'one', total: 60),
          testPurchase(id: 'b', paidByUserId: 'ghost', total: 40),
        ],
        members: [testMember(id: 'one', displayName: 'rahat')],
      );

      final unknown = result.byPerson.last;
      expect(unknown.displayName, unknownMemberLabel);
      expect(unknown.paid, 40);
      expect(unknown.hasShare, isFalse);
      expect(unknown.share, 0);
    });

    test('the unknown payer still counts towards everyone else s share', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', paidByUserId: 'one', total: 60),
          testPurchase(id: 'b', paidByUserId: 'ghost', total: 40),
        ],
        members: [testMember(id: 'one', displayName: 'rahat')],
      );

      expect(result.byPerson.first.share, 100);
      expect(result.memberCount, 1);
    });

    test('an empty household leaves the share at zero rather than a NaN', () {
      final result = report(
        purchases: [testPurchase(paidByUserId: 'ghost', total: 100)],
      );

      expect(result.memberCount, 0);
      final unknown = result.byPerson.single;
      expect(unknown.paid, 100);
      expect(unknown.share, 0);
      expect(unknown.share.isNaN, isFalse);
    });

    test('several purchases by one member add up', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', paidByUserId: 'one', total: 20),
          testPurchase(id: 'b', paidByUserId: 'one', total: 30),
        ],
        members: [testMember(id: 'one')],
      );

      expect(result.byPerson.single.paid, 50);
    });
  });

  group('by category', () {
    test('groups lines by the purchased item category', () {
      final result = report(
        purchases: [
          testPurchase(
            total: 30,
            lines: [
              testLine(itemId: 'i1', lineTotal: 12),
              testLine(itemId: 'i2', lineTotal: 8),
              testLine(itemId: 'i1', lineTotal: 10),
            ],
          ),
        ],
        items: [
          testItem(id: 'i1', category: 'produce'),
          testItem(id: 'i2', category: 'dairy'),
        ],
      );

      expect(pairs(result.byCategory), [
        ('Produce', 22.0),
        ('Dairy & Eggs', 8.0),
      ]);
    });

    test('a member s own category is used as they typed it', () {
      final result = report(
        purchases: [
          testPurchase(total: 5, lines: [testLine(itemId: 'i1', lineTotal: 5)]),
        ],
        items: [testItem(id: 'i1', category: 'Baby food')],
      );

      expect(pairs(result.byCategory), [('Baby food', 5.0)]);
    });

    test('a line with no item is uncategorised', () {
      final result = report(
        purchases: [
          testPurchase(total: 5, lines: [testLine(itemId: null, lineTotal: 5)]),
        ],
      );

      expect(pairs(result.byCategory), [(uncategorisedLabel, 5.0)]);
    });

    test('a line whose item is gone from the catalogue is uncategorised', () {
      final result = report(
        purchases: [
          testPurchase(
            total: 5,
            lines: [testLine(itemId: 'deleted', lineTotal: 5)],
          ),
        ],
        items: [testItem(id: 'i1', category: 'produce')],
      );

      expect(pairs(result.byCategory), [(uncategorisedLabel, 5.0)]);
    });

    test('an item with a blank category is uncategorised', () {
      final result = report(
        purchases: [
          testPurchase(total: 5, lines: [testLine(itemId: 'i1', lineTotal: 5)]),
        ],
        items: [testItem(id: 'i1', category: '  ')],
      );

      expect(pairs(result.byCategory), [(uncategorisedLabel, 5.0)]);
    });

    test('the remainder is whatever the lines do not account for', () {
      final result = report(
        purchases: [
          testPurchase(
            total: 30,
            lines: [testLine(itemId: 'i1', lineTotal: 12)],
          ),
        ],
        items: [testItem(id: 'i1', category: 'produce')],
      );

      expect(pairs(result.byCategory), [
        ('Produce', 12.0),
        (notItemisedLabel, 18.0),
      ]);
    });

    test('a purchase with no lines is entirely not itemised', () {
      final result = report(purchases: [testPurchase(total: 30)]);

      expect(pairs(result.byCategory), [(notItemisedLabel, 30.0)]);
    });

    test('a priced line of zero keeps its category without an amount', () {
      final result = report(
        purchases: [
          testPurchase(
            total: 10,
            lines: [testLine(itemId: 'i1', lineTotal: 0)],
          ),
        ],
        items: [testItem(id: 'i1', category: 'produce')],
      );

      // Zero is a real answer: the line was bought but never priced. The
      // remainder still sorts after it, because it is appended last.
      expect(pairs(result.byCategory), [
        ('Produce', 0.0),
        (notItemisedLabel, 10.0),
      ]);
    });

    test('lines covering the whole total add no remainder', () {
      final result = report(
        purchases: [
          testPurchase(
            total: 20,
            lines: [
              testLine(itemId: 'i1', lineTotal: 12),
              testLine(itemId: 'i1', lineTotal: 8),
            ],
          ),
        ],
        items: [testItem(id: 'i1', category: 'produce')],
      );

      expect(pairs(result.byCategory), [('Produce', 20.0)]);
    });

    test('lines exceeding the total add no negative remainder', () {
      final result = report(
        purchases: [
          testPurchase(
            total: 10,
            lines: [
              testLine(itemId: 'i1', lineTotal: 6),
              testLine(itemId: 'i1', lineTotal: 6),
            ],
          ),
        ],
        items: [testItem(id: 'i1', category: 'produce')],
      );

      expect(pairs(result.byCategory), [('Produce', 12.0)]);
    });

    test('uncategorised and not itemised sort last whatever their size', () {
      final result = report(
        purchases: [
          testPurchase(
            total: 100,
            lines: [
              testLine(itemId: 'i1', lineTotal: 10),
              testLine(itemId: null, lineTotal: 60),
            ],
          ),
        ],
        items: [testItem(id: 'i1', category: 'produce')],
      );

      expect(pairs(result.byCategory), [
        ('Produce', 10.0),
        (uncategorisedLabel, 60.0),
        (notItemisedLabel, 30.0),
      ]);
    });

    test('lines outside the month are not counted', () {
      final result = report(
        purchases: [
          testPurchase(
            id: 'august',
            date: inAugust,
            total: 50,
            lines: [testLine(itemId: 'i1', lineTotal: 50)],
          ),
        ],
        items: [testItem(id: 'i1', category: 'produce')],
      );

      expect(result.byCategory, isEmpty);
    });
  });

  group('by shop', () {
    test('sums the month by shop, biggest first', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', shopName: 'Lidl', total: 20),
          testPurchase(id: 'b', shopName: 'Conad', total: 30),
        ],
      );

      expect(pairs(result.byShop), [('Conad', 30.0), ('Lidl', 20.0)]);
    });

    test('two spellings of one shop are one row', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', shopName: 'Conad', total: 20),
          testPurchase(id: 'b', shopName: 'conad', total: 10),
          testPurchase(id: 'c', shopName: '  CONAD ', total: 5),
        ],
      );

      expect(pairs(result.byShop), [('Conad', 35.0)]);
    });

    test('a blank shop name reads as unknown', () {
      final result = report(
        purchases: [testPurchase(shopName: '   ', total: 20)],
      );

      expect(pairs(result.byShop), [(unknownShopLabel, 20.0)]);
    });

    test('shops on the same amount are ordered by name', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', shopName: 'Lidl', total: 20),
          testPurchase(id: 'b', shopName: 'Conad', total: 20),
        ],
      );

      expect(pairs(result.byShop), [('Conad', 20.0), ('Lidl', 20.0)]);
    });
  });

  group('month over month', () {
    test('reports the change against the previous month', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', date: inSeptember, total: 120),
          testPurchase(id: 'b', date: inAugust, total: 100),
        ],
      );

      expect(result.monthOverMonthChange, 20);
      expect(result.monthOverMonthFraction, closeTo(0.2, 0.0001));
    });

    test('spending less than the previous month is negative', () {
      final result = report(
        purchases: [
          testPurchase(id: 'a', date: inSeptember, total: 80),
          testPurchase(id: 'b', date: inAugust, total: 100),
        ],
      );

      expect(result.monthOverMonthChange, -20);
      expect(result.monthOverMonthFraction, closeTo(-0.2, 0.0001));
    });

    test('a previous month of zero has no fraction to report', () {
      final result = report(
        purchases: [testPurchase(date: inSeptember, total: 80)],
      );

      expect(result.monthOverMonthChange, 80);
      expect(result.monthOverMonthFraction, isNull);
    });
  });
}
