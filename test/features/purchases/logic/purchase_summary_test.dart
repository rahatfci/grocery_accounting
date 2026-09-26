import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/items/logic/item_unit.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_draft.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_summary.dart';

import '../../items/fake_item_repository.dart';

/// The Italian currency format separates the amount from the symbol with a
/// non-breaking space, which is invisible in an expectation.
String _plain(String text) => text.replaceAll('\u00a0', ' ');

PurchaseDraftLine _line({
  String? itemId = 'rice',
  String name = 'Rice',
  String? scanned,
  bool learned = false,
}) => PurchaseDraftLine(
  item: itemId == null ? null : testItem(id: itemId, name: name),
  quantity: 1,
  unit: ItemUnit.kg,
  lineTotal: 2,
  scannedText: scanned,
  learned: learned,
);

void main() {
  PurchaseDraft draft(List<PurchaseDraftLine> lines) => PurchaseDraft(
    date: DateTime(2026, 9, 26),
    shopName: '  Conad City ',
    totalText: '40,80',
    paidByUserId: 'u1',
    lines: lines,
  );

  PurchaseSummary summarize(List<PurchaseDraftLine> lines) => summarizePurchase(
    draft(lines),
    purchaseId: 'p1',
    payerName: 'Rahat',
    cleared: 3,
    photo: SavedPhoto.waiting,
  );

  test('carries the spend, the shop and who paid', () {
    final summary = summarize(const []);

    expect(summary.total, 40.8);
    expect(summary.shopName, 'Conad City');
    expect(summary.payerName, 'Rahat');
    expect(summary.cleared, 3);
    expect(summary.photo, SavedPhoto.waiting);
  });

  test('counts each restocked item once, however many lines it had', () {
    final summary = summarize([
      _line(),
      _line(),
      _line(itemId: 'milk', name: 'Milk'),
    ]);

    expect(summary.restocked, 2);
  });

  test('names the items the purchase created', () {
    final summary = summarize([_line(itemId: '', name: 'Oat milk'), _line()]);

    expect(summary.created, ['Oat milk']);
    expect(summary.restocked, 1);
  });

  test('counts only the lines a member taught on this purchase', () {
    final summary = summarize([
      _line(scanned: 'RISO ARBORIO 1KG'),
      _line(scanned: 'riso  arborio 1kg'),
      _line(scanned: 'LATTE 1L', itemId: 'milk', learned: true),
      _line(),
    ]);

    expect(summary.learned, 1);
  });

  test('counts the lines saved as spend only', () {
    final summary = summarize([
      _line(itemId: null, scanned: 'POMODORI PELATI'),
      _line(itemId: null, scanned: 'DETERSIVO'),
      _line(),
    ]);

    expect(summary.spendOnly, 2);
  });

  test('the photo state can be updated after the save', () {
    final summary = summarize(
      const [],
    ).withPhoto(SavedPhoto.notSaved, problem: 'No connection');

    expect(summary.photo, SavedPhoto.notSaved);
    expect(summary.photoProblem, 'No connection');
    expect(summary.total, 40.8);
  });

  group('savedHeadline', () {
    test('says how much, where and who paid', () {
      expect(
        _plain(savedHeadline(summarize(const []))),
        '40,80 € at Conad City, paid by Rahat',
      );
    });
  });

  group('outcomesOf', () {
    PurchaseSummary summary({
      int restocked = 0,
      List<String> created = const [],
      int cleared = 0,
      int learned = 0,
      int spendOnly = 0,
      SavedPhoto photo = SavedPhoto.none,
      String? problem,
    }) => PurchaseSummary(
      purchaseId: 'p1',
      total: 40.8,
      shopName: 'Conad City',
      payerName: 'Rahat',
      restocked: restocked,
      created: created,
      cleared: cleared,
      learned: learned,
      spendOnly: spendOnly,
      photo: photo,
      photoProblem: problem,
    );

    List<(String, String)> rows(PurchaseSummary summary) => [
      for (final outcome in outcomesOf(summary))
        (outcome.label, _plain(outcome.value)),
    ];

    test('always records the spend, and nothing that did not happen', () {
      expect(rows(summary()), [('Spend recorded', '40,80 €')]);
    });

    test('counts everything the save did, in the design order', () {
      expect(
        rows(
          summary(
            restocked: 9,
            created: ['Oat milk'],
            cleared: 3,
            learned: 5,
            spendOnly: 2,
            photo: SavedPhoto.waiting,
          ),
        ),
        [
          ('Spend recorded', '40,80 €'),
          ('Pantry restocked', '9 items'),
          ('New pantry item', 'Oat milk'),
          ('Ticked off the list', '3 entries'),
          ('Learned for next time', '5 receipt lines'),
          ('Saved as spend only', '2 lines'),
          ('Receipt photo', 'Uploads when online'),
        ],
      );
    });

    test('speaks of one in the singular', () {
      expect(
        rows(
          summary(
            restocked: 1,
            created: ['Oat milk', 'Tofu'],
            cleared: 1,
            learned: 1,
            spendOnly: 1,
          ),
        ).skip(1),
        [
          ('Pantry restocked', '1 item'),
          ('New pantry items', '2 items'),
          ('Ticked off the list', '1 entry'),
          ('Learned for next time', '1 receipt line'),
          ('Saved as spend only', '1 line'),
        ],
      );
    });

    test('colours a line saved as spend only as a loss', () {
      final spendOnly = outcomesOf(
        summary(spendOnly: 2),
      ).singleWhere((outcome) => outcome.kind == OutcomeKind.spendOnly);

      expect(spendOnly.tone, OutcomeTone.negative);
    });

    test('follows the photo through its states', () {
      Outcome photoOf(SavedPhoto photo, {String? problem}) =>
          outcomesOf(summary(photo: photo, problem: problem)).last;

      expect(photoOf(SavedPhoto.uploading).value, 'Uploading');
      expect(photoOf(SavedPhoto.uploading).tone, OutcomeTone.neutral);
      expect(photoOf(SavedPhoto.uploaded).value, 'Uploaded');
      expect(photoOf(SavedPhoto.uploaded).tone, OutcomeTone.positive);
      expect(photoOf(SavedPhoto.waiting).tone, OutcomeTone.warning);
      expect(
        photoOf(SavedPhoto.notSaved, problem: 'No connection'),
        const Outcome(
          kind: OutcomeKind.photo,
          label: 'Receipt photo',
          value: 'Not saved',
          tone: OutcomeTone.negative,
          detail: 'No connection',
        ),
      );
      expect(
        outcomesOf(summary()).map((outcome) => outcome.kind),
        isNot(contains(OutcomeKind.photo)),
      );
    });
  });
}
