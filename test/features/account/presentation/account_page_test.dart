import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/account/presentation/account_page.dart';

import '../../members/fake_member_repository.dart';
import '../../purchases/fake_purchase_repository.dart';
import '../../shell/shell_harness.dart';

Future<void> _openAccount(WidgetTester tester, ShellFakes fakes) async {
  usePhone(tester);
  await pumpShell(tester, fakes);
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
}

void main() {
  late ShellFakes fakes;

  setUp(() {
    fakes = ShellFakes();
    fakes.members.initialMembers = [
      testMember(displayName: 'Rahat'),
      testMember(id: 'u2', displayName: 'Giulia', email: 'g@example.com'),
    ];
  });

  testWidgets('shows who is signed in and the household', (tester) async {
    await _openAccount(tester, fakes);

    expect(find.byType(AccountPage), findsOneWidget);
    expect(find.text('rahat@example.com'), findsOneWidget);
    expect(find.text('Giulia'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('says when every receipt photo has uploaded', (tester) async {
    await _openAccount(tester, fakes);

    expect(find.text('All uploaded'), findsOneWidget);
  });

  testWidgets('the reminders row lists what this phone will remind about', (
    tester,
  ) async {
    await _openAccount(tester, fakes);

    await tester.tap(find.text('Run-out reminders'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No staple is due to run out yet'),
      findsOneWidget,
    );
  });

  testWidgets('exporting shares the month on screen as CSV', (tester) async {
    final now = DateTime.now();
    fakes.purchases.initialPurchases = [
      testPurchase(date: DateTime(now.year, now.month, 1, 12)),
    ];
    await _openAccount(tester, fakes);

    await tester.tap(find.text('Export a month'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 purchase'), findsOneWidget);

    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();

    expect(fakes.sharer.shared, hasLength(1));
  });

  testWidgets('an empty month cannot be exported', (tester) async {
    await _openAccount(tester, fakes);

    await tester.tap(find.text('Export a month'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing was recorded this month'), findsOneWidget);
    await tester.tap(find.text('Export CSV'));
    await tester.pumpAndSettle();
    expect(fakes.sharer.shared, isEmpty);
  });

  testWidgets('a failed sign out says so and stays', (tester) async {
    fakes.auth.signOutThrows = StateError('offline');
    await _openAccount(tester, fakes);

    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Could not sign out. Try again.'), findsOneWidget);
    expect(find.byType(AccountPage), findsOneWidget);
  });
}
