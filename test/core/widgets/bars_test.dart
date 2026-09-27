import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/core/widgets/bars.dart';
import 'package:grocery_accounting/core/widgets/level_bar.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('the month switcher disables next when there is no next', (
    tester,
  ) async {
    var previous = 0;
    await _pump(
      tester,
      MonthSwitcher(
        label: 'September 2026',
        onPrevious: () => previous++,
        onNext: null,
      ),
    );

    await tester.tap(find.byTooltip('Previous month'));
    await tester.tap(find.byTooltip('Next month'));

    expect(previous, 1);
    expect(find.text('September 2026'), findsOneWidget);
    final next = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Next month'),
        matching: find.byType(IconButton),
      ),
    );
    expect(next.onPressed, isNull);
  });

  testWidgets('the action bar shows its summary beside the action', (
    tester,
  ) async {
    await _pump(
      tester,
      ActionBar(
        summaryLabel: 'Total',
        summaryValue: '40,80 €',
        child: FilledButton(onPressed: () {}, child: const Text('Save')),
      ),
    );

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('40,80 €'), findsOneWidget);
  });

  testWidgets('a level bar clamps its value and survives a non-number', (
    tester,
  ) async {
    await _pump(
      tester,
      const SizedBox(
        width: 100,
        child: Column(
          children: [
            LevelBar(value: 1.8, color: Colors.green),
            LevelBar(value: double.nan, color: Colors.red),
          ],
        ),
      ),
    );

    final levels = tester
        .widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .map((box) => box.widthFactor)
        .toList();
    expect(levels, [1.0, 0.0]);
  });
}
