import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/data_failure.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_gate.dart';
import 'package:grocery_accounting/features/auth/presentation/sign_in_page.dart';
import 'package:grocery_accounting/features/home/presentation/home_page.dart';
import 'package:grocery_accounting/features/items/data/item_repository.dart';
import 'package:grocery_accounting/features/members/data/member_repository.dart';
import 'package:grocery_accounting/features/reminders/data/run_out_notifier.dart';
import 'package:grocery_accounting/features/shopping_list/data/shopping_list_repository.dart';

import '../../items/fake_item_repository.dart';
import '../../members/fake_member_repository.dart';
import '../../reminders/fake_run_out_notifier.dart';
import '../../shopping_list/fake_shopping_list_repository.dart';
import '../fake_auth_repository.dart';

Future<void> _pumpGate(
  WidgetTester tester,
  FakeAuthRepository repository,
  FakeMemberRepository members,
) async {
  await tester.pumpWidget(
    MaterialApp(
      // Home watches the catalogue for running low and run-out reminders, and
      // the shopping list, as soon as it mounts.
      home: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<MemberRepository>.value(value: members),
          RepositoryProvider<ItemRepository>.value(
            value: FakeItemRepository()..initialItems = const [],
          ),
          RepositoryProvider<RunOutNotifier>.value(value: FakeRunOutNotifier()),
          RepositoryProvider<ShoppingListRepository>.value(
            value: FakeShoppingListRepository()..initialEntries = const [],
          ),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(repository),
          child: const AuthGate(),
        ),
      ),
    ),
  );
}

void main() {
  late FakeAuthRepository repository;
  late FakeMemberRepository members;

  setUp(() {
    repository = FakeAuthRepository();
    members = FakeMemberRepository();
  });

  testWidgets('waits rather than showing sign in before the session is known', (
    tester,
  ) async {
    await _pumpGate(tester, repository, members);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
    expect(find.byType(HomePage), findsNothing);
  });

  testWidgets('no session shows sign in', (tester) async {
    await _pumpGate(tester, repository, members);

    repository.emitAuthState(null);
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsOneWidget);
  });

  testWidgets('an existing session goes straight to home', (tester) async {
    await _pumpGate(tester, repository, members);

    repository.emitAuthState(testUser);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('rahat@example.com'), findsOneWidget);
  });

  testWidgets('signing out returns to sign in', (tester) async {
    await _pumpGate(tester, repository, members);
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

  testWidgets('a new session mirrors the account into users', (tester) async {
    await _pumpGate(tester, repository, members);

    repository.emitAuthState(testUser);
    await tester.pumpAndSettle();

    expect(members.upserted, [testUser]);
  });

  testWidgets('no session writes nothing', (tester) async {
    await _pumpGate(tester, repository, members);

    repository.emitAuthState(null);
    await tester.pumpAndSettle();

    expect(members.upserted, isEmpty);
  });

  testWidgets('mirrors once per session, not once per rebuild', (tester) async {
    await _pumpGate(tester, repository, members);

    repository.emitAuthState(testUser);
    await tester.pumpAndSettle();
    repository.emitAuthState(testUser);
    await tester.pumpAndSettle();

    expect(members.upserted, hasLength(1));

    // Signing out and back in is a new session, so the mirror is written again.
    repository.emitAuthState(null);
    await tester.pumpAndSettle();
    repository.emitAuthState(testUser);
    await tester.pumpAndSettle();

    expect(members.upserted, hasLength(2));
  });

  testWidgets('a refused mirror write does not block the session', (
    tester,
  ) async {
    members.upsertResult = const Err(PermissionDenied());
    await _pumpGate(tester, repository, members);

    repository.emitAuthState(testUser);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('a mirror write that throws does not break the session', (
    tester,
  ) async {
    members.upsertThrows = StateError('offline in a way nobody mapped');
    await _pumpGate(tester, repository, members);

    repository.emitAuthState(testUser);
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
  });
}
