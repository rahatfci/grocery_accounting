import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/auth/logic/auth_failure.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_state.dart';

import '../fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());

  test('starts unknown until the auth stream reports', () {
    final cubit = AuthCubit(repository);

    expect(cubit.state, const AuthInitial());

    cubit.close();
  });

  test('an existing session is picked up from the stream', () async {
    final cubit = AuthCubit(repository);
    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([const AuthSignedIn(testUser)]),
    );

    repository.emitAuthState(testUser);

    await expectation;
    await cubit.close();
  });

  test('no session leaves the user signed out', () async {
    final cubit = AuthCubit(repository);
    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([const AuthSignedOut()]),
    );

    repository.emitAuthState(null);

    await expectation;
    await cubit.close();
  });

  test(
    'a successful sign in is only claimed once the stream confirms',
    () async {
      final cubit = AuthCubit(repository);
      final expectation = expectLater(
        cubit.stream,
        emitsInOrder([const AuthSubmitting(), const AuthSignedIn(testUser)]),
      );

      await cubit.signIn(email: 'rahat@example.com', password: 'correct');
      expect(
        cubit.state,
        const AuthSubmitting(),
        reason: 'the repository returning Ok is not itself a session',
      );
      repository.emitAuthState(testUser);

      await expectation;
      await cubit.close();
    },
  );

  test('a rejected sign in surfaces the mapped failure', () async {
    repository.signInResult = const Err(InvalidCredentials());
    final cubit = AuthCubit(repository);
    final expectation = expectLater(
      cubit.stream,
      emitsInOrder([
        const AuthSubmitting(),
        const AuthSignInFailure(InvalidCredentials()),
      ]),
    );

    await cubit.signIn(email: 'rahat@example.com', password: 'wrong');

    await expectation;
    await cubit.close();
  });

  test(
    'a throwable the repository does not map still reaches the user',
    () async {
      repository.signInThrows = StateError('platform channel died');
      final cubit = AuthCubit(repository);
      final expectation = expectLater(
        cubit.stream,
        emitsInOrder([
          const AuthSubmitting(),
          const AuthSignInFailure(UnexpectedAuthFailure()),
        ]),
      );

      await cubit.signIn(email: 'rahat@example.com', password: 'whatever');

      await expectation;
      await cubit.close();
    },
  );

  test('a stray signed-out event does not interrupt a sign in', () async {
    final cubit = AuthCubit(repository);

    await cubit.signIn(email: 'rahat@example.com', password: 'correct');
    repository.emitAuthState(null);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const AuthSubmitting());

    await cubit.close();
  });

  test('a stray signed-out event does not wipe a failure message', () async {
    repository.signInResult = const Err(InvalidCredentials());
    final cubit = AuthCubit(repository);

    await cubit.signIn(email: 'rahat@example.com', password: 'wrong');
    repository.emitAuthState(null);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const AuthSignInFailure(InvalidCredentials()));

    await cubit.close();
  });

  test('correcting the form clears the failure', () async {
    repository.signInResult = const Err(InvalidCredentials());
    final cubit = AuthCubit(repository);

    await cubit.signIn(email: 'rahat@example.com', password: 'wrong');
    cubit.failureAcknowledged();

    expect(cubit.state, const AuthSignedOut());

    await cubit.close();
  });

  test('acknowledging does nothing when there is no failure', () async {
    final cubit = AuthCubit(repository);
    repository.emitAuthState(testUser);
    await Future<void>.delayed(Duration.zero);

    cubit.failureAcknowledged();

    expect(cubit.state, const AuthSignedIn(testUser));

    await cubit.close();
  });

  test('signing out delegates to the repository', () async {
    final cubit = AuthCubit(repository);

    await cubit.signOut();

    expect(repository.signOutCalls, 1);

    await cubit.close();
  });

  test('closing cancels the auth subscription', () async {
    final cubit = AuthCubit(repository);
    expect(repository.hasListener, isTrue);

    await cubit.close();

    expect(repository.hasListener, isFalse);
  });
}
