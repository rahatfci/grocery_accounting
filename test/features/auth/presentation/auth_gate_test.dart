import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_gate.dart';
import 'package:grocery_accounting/features/auth/presentation/sign_in_page.dart';
import 'package:grocery_accounting/features/home/presentation/home_page.dart';

import '../fake_auth_repository.dart';

Future<void> _pumpGate(
  WidgetTester tester,
  FakeAuthRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => AuthCubit(repository),
        child: const AuthGate(),
      ),
    ),
  );
}

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  testWidgets('waits rather than showing sign in before the session is known', (
    tester,
  ) async {
    await _pumpGate(tester, repository);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('no session shows sign in', (tester) async {
    await _pumpGate(tester, repository);

    repository.emitAuthState(null);
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
  });

  testWidgets('an existing session goes straight to home', (tester) async {
    await _pumpGate(tester, repository);

    repository.emitAuthState(testUser);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('rahat@example.com'), findsOneWidget);
  });

  testWidgets('signing out returns to sign in', (tester) async {
    await _pumpGate(tester, repository);
    repository.emitAuthState(testUser);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(repository.signOutCalls, 1);

    // Firebase drives the sign out through the auth stream, exactly as it
    // drives the sign in.
    repository.emitAuthState(null);
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
  });
}
