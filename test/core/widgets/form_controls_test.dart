import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/core/widgets/form_controls.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('a segmented picker reports the segment that was tapped', (
    tester,
  ) async {
    String? chosen;
    await _pump(
      tester,
      SegmentedPicker<String>(
        segments: const [
          Segment(value: 'kg', label: 'kg'),
          Segment(value: 'g', label: 'g'),
        ],
        selected: 'kg',
        onChanged: (value) => chosen = value,
      ),
    );

    await tester.tap(find.text('g'));

    expect(chosen, 'g');
  });

  testWidgets('a disabled segmented picker ignores taps', (tester) async {
    await _pump(
      tester,
      const SegmentedPicker<String>(
        segments: [Segment(value: 'kg', label: 'kg')],
        selected: null,
        onChanged: null,
      ),
    );

    await tester.tap(find.text('kg'));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the checkbox toggles and announces its state', (tester) async {
    bool? changedTo;
    await _pump(
      tester,
      AppCheckbox(
        checked: false,
        semanticLabel: 'Got milk',
        onChanged: (value) => changedTo = value,
      ),
    );

    expect(
      tester.getSemantics(find.byType(AppCheckbox)),
      matchesSemantics(
        label: 'Got milk',
        hasCheckedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(find.byType(AppCheckbox));

    expect(changedTo, isTrue);
  });

  testWidgets('a chosen pill shows its check and a plain one does not', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: [
          ChoicePill(label: 'Dairy', selected: true, onTap: () {}),
          ChoicePill(label: 'Bakery', selected: false, onTap: () {}),
        ],
      ),
    );

    expect(find.byIcon(Icons.check), findsNothing);
    expect(
      find.descendant(
        of: find.widgetWithText(ChoicePill, 'Dairy'),
        matching: find.byType(Icon),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ChoicePill, 'Bakery'),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
  });

  testWidgets('a labeled field shows its label and helper', (tester) async {
    await _pump(
      tester,
      const LabeledField(
        label: 'Daily usage',
        helper: 'kg a day',
        child: TextField(),
      ),
    );

    expect(find.text('Daily usage'), findsOneWidget);
    expect(find.text('kg a day'), findsOneWidget);
  });
}
