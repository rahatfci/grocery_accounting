import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/core/widgets/app_button.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('a button runs its action when tapped', (tester) async {
    var taps = 0;
    await _pump(tester, AppButton(label: 'Save', onPressed: () => taps++));

    await tester.tap(find.text('Save'));

    expect(taps, 1);
  });

  testWidgets('a busy button shows progress and ignores taps', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      AppButton(label: 'Save', busy: true, onPressed: () => taps++),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await tester.tap(find.byType(AppButton));

    expect(taps, 0);
    expect(find.bySemanticsLabel('Save'), findsOneWidget);
  });

  testWidgets('each size lays out at the height the design gives it', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final size in AppButtonSize.values)
            AppButton(label: size.name, size: size, onPressed: () {}),
        ],
      ),
    );

    double height(AppButtonSize size) =>
        tester.getSize(find.widgetWithText(AppButton, size.name)).height;

    expect(height(AppButtonSize.large), 52);
    expect(height(AppButtonSize.medium), 44);
    // The 36 px shape sits inside a padded 48 px touch target.
    expect(height(AppButtonSize.small), 48);
  });

  testWidgets('an expanded button fills its width', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 300,
        child: AppButton(label: 'Done', expand: true, onPressed: () {}),
      ),
    );

    expect(tester.getSize(find.byType(AppButton)).width, 300);
  });
}
