import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/features/purchases/logic/purchase_summary.dart';
import 'package:grocery_accounting/features/purchases/presentation/purchase_saved_view.dart';

const _summary = PurchaseSummary(
  purchaseId: 'p1',
  total: 40.8,
  shopName: 'Conad City',
  payerName: 'Rahat',
  restocked: 9,
  created: ['Oat milk'],
  cleared: 3,
  learned: 5,
  spendOnly: 2,
  photo: SavedPhoto.waiting,
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    PurchaseSummary summary = _summary,
    VoidCallback? onViewPurchase,
  }) async {
    // Phone width, where a long value is most likely to crowd its label.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PurchaseSavedView(
                  summary: summary,
                  onViewPurchase: onViewPurchase,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('says what the save did', (tester) async {
    await pump(tester);

    expect(find.text('Purchase saved'), findsOneWidget);
    expect(find.text('40,80 € at Conad City, paid by Rahat'), findsOneWidget);
    for (final label in [
      'Spend recorded',
      'Pantry restocked',
      'New pantry item',
      'Ticked off the list',
      'Learned for next time',
      'Saved as spend only',
      'Receipt photo',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Oat milk'), findsOneWidget);
    expect(find.text('Uploads when online'), findsOneWidget);
  });

  testWidgets('explains a photo that was not kept', (tester) async {
    await pump(
      tester,
      summary: _summary.withPhoto(
        SavedPhoto.notSaved,
        problem: 'No connection. Check your network and try again',
      ),
    );

    expect(find.text('Not saved'), findsOneWidget);
    expect(
      find.text('No connection. Check your network and try again'),
      findsOneWidget,
    );
  });

  testWidgets('Done goes back', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(PurchaseSavedView), findsNothing);
  });

  testWidgets('offers the purchase only when there is a way to it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('View purchase'), findsNothing);

    var opened = 0;
    await tester.pumpWidget(const SizedBox());
    await pump(tester, onViewPurchase: () => opened++);
    await tester.tap(find.text('View purchase'));

    expect(opened, 1);
  });
}
