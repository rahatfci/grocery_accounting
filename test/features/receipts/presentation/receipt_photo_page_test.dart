import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/receipts/presentation/receipt_photo_page.dart';

import '../fake_receipts.dart';

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onRemove}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReceiptPhotoPage(
                  bytes: testPhoto().bytes,
                  onRemove: onRemove,
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

  testWidgets('shows the photo, zoomable, with a way back', (tester) async {
    await pump(tester);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Remove photo'), findsNothing);
  });

  testWidgets('removing the photo closes the view and removes it', (
    tester,
  ) async {
    var removed = 0;
    await pump(tester, onRemove: () => removed++);

    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pumpAndSettle();

    expect(removed, 1);
    expect(find.byType(ReceiptPhotoPage), findsNothing);
  });
}
