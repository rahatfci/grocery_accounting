import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/core/widgets/section_header.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget header) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: header)),
      ),
    ),
  );

  testWidgets('the action sits at the far edge, however short the title', (
    tester,
  ) async {
    await pump(
      tester,
      SectionHeader(title: 'Lines', actionLabel: 'Add line', onAction: () {}),
    );

    final header = tester.getRect(find.byType(SectionHeader));
    final action = tester.getRect(find.byType(TextButton));
    expect(action.right, header.right);
  });

  testWidgets('the count follows the title rather than the action', (
    tester,
  ) async {
    await pump(
      tester,
      SectionHeader(
        title: 'Lines',
        count: 11,
        actionLabel: 'Add line',
        onAction: () {},
      ),
    );

    final title = tester.getRect(find.text('Lines'));
    final count = tester.getRect(find.text('11'));
    expect(count.left - title.right, lessThan(24));
  });

  testWidgets('a long title gives way to the action', (tester) async {
    await pump(
      tester,
      SectionHeader(
        title: 'A section title far too long for one line on a phone',
        count: 3,
        actionLabel: 'See all',
        onAction: () {},
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('See all'), findsOneWidget);
  });
}
