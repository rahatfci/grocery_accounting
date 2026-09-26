import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/theme/app_theme.dart';
import 'package:grocery_accounting/features/auth/presentation/splash_view.dart';

void main() {
  testWidgets('the splash names the app and tells a screen reader it loads', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SplashView()),
    );

    expect(find.text('Grocery Accounting'), findsOneWidget);
    expect(find.text('di Quattro Nero'), findsOneWidget);
    expect(find.text('Spend · Pantry · Shopping list'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Loading')), findsOneWidget);
    semantics.dispose();
  });
}
