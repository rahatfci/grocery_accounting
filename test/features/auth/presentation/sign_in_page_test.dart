import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/auth/logic/auth_failure.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart';
import 'package:grocery_accounting/features/auth/presentation/sign_in_page.dart';

import '../fake_auth_repository.dart';

Future<void> _pumpSignIn(
  WidgetTester tester,
  FakeAuthRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => AuthCubit(repository),
        child: const SignInPage(),
      ),
    ),
  );
}

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  testWidgets('an empty form reports both fields rather than signing in', (
    tester,
  ) async {
    await _pumpSignIn(tester, repository);

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('a malformed email is rejected before Firebase is called', (
    tester,
  ) async {
    await _pumpSignIn(tester, repository);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, 'password');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
  });

  testWidgets('a rejected sign in shows the mapped message', (tester) async {
    repository.signInResult = const Err(InvalidCredentials());
    await _pumpSignIn(tester, repository);

    await tester.enterText(
      find.byType(TextFormField).first,
      'rahat@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is not correct'), findsOneWidget);
  });

  testWidgets('the raw Firebase code never reaches the screen', (tester) async {
    repository.signInThrows = StateError('user-not-found');
    await _pumpSignIn(tester, repository);

    await tester.enterText(
      find.byType(TextFormField).first,
      'rahat@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again'), findsOneWidget);
    expect(find.textContaining('user-not-found'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);
  });

  testWidgets('submitting disables the button and the fields', (tester) async {
    repository.signInGate = Completer<void>();
    await _pumpSignIn(tester, repository);

    await tester.enterText(
      find.byType(TextFormField).first,
      'rahat@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'correct');
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'a second submit must not queue');

    final email = tester.widget<TextField>(find.byType(TextField).first);
    expect(email.enabled, isFalse);

    // Releasing the gate lets the sign in finish, which leaves submitting.
    repository.signInGate?.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('correcting a field clears the previous failure', (tester) async {
    repository.signInResult = const Err(InvalidCredentials());
    await _pumpSignIn(tester, repository);

    await tester.enterText(
      find.byType(TextFormField).first,
      'rahat@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is not correct'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, 'wrong2');
    await tester.pump();

    expect(find.text('Email or password is not correct'), findsNothing);
  });

  testWidgets('the password is obscured and can be revealed', (tester) async {
    await _pumpSignIn(tester, repository);

    TextField passwordField() =>
        tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('the form stays narrow on a wide window', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpSignIn(tester, repository);

    final formWidth = tester.getSize(find.byType(Form)).width;
    expect(formWidth, lessThanOrEqualTo(420));
  });
}
