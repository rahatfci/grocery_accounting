import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_accounting/core/result.dart';
import 'package:grocery_accounting/features/auth/logic/auth_failure.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_cubit.dart';
import 'package:grocery_accounting/features/auth/presentation/auth_state.dart';

import '../fake_auth_repository.dart';

class _RecordingObserver extends BlocObserver {
  final errors = <(Object, StackTrace)>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add((error, stackTrace));
    super.onError(bloc, error, stackTrace);
  }
}

_RecordingObserver _installObserver() {
  final previous = Bloc.observer;
  final observer = _RecordingObserver();
  Bloc.observer = observer;
  addTearDown(() => Bloc.observer = previous);
  return observer;
}

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

  test('a successful sign in is claimed from the returned user', () async {
    final cubit = AuthCubit(repository);
    final states = <AuthState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.signIn(email: 'rahat@example.com', password: 'correct');
    expect(
      cubit.state,
      const AuthSignedIn(testUser),
      reason: 'the form must not wait on the stream to leave submitting',
    );

    // The stream confirming the same session is an equal state.
    repository.emitAuthState(testUser);
    await Future<void>.delayed(Duration.zero);

    expect(states, [const AuthSubmitting(), const AuthSignedIn(testUser)]);

    await subscription.cancel();
    await cubit.close();
  });

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
    'a throwable the repository does not map reaches the user and is reported',
    () async {
      final observer = _installObserver();
      final thrown = StateError('platform channel died');
      final thrownTrace = StackTrace.fromString('#0 platformChannel');
      repository
        ..signInThrows = thrown
        ..signInThrowsStackTrace = thrownTrace;
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
      expect(observer.errors, hasLength(1));
      expect(observer.errors.single.$1, same(thrown));
      expect(observer.errors.single.$2, same(thrownTrace));
      await cubit.close();
    },
  );

  test('a stray signed-out event does not interrupt a sign in', () async {
    repository.signInGate = Completer<void>();
    final cubit = AuthCubit(repository);

    final signingIn = cubit.signIn(
      email: 'rahat@example.com',
      password: 'correct',
    );
    repository.emitAuthState(null);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const AuthSubmitting());

    repository.signInGate?.complete();
    await signingIn;
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

  test('a stream error before any session is known offers a retry', () async {
    final observer = _installObserver();
    final cubit = AuthCubit(repository);
    final thrown = StateError('channel died');

    repository.emitAuthError(thrown);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const AuthSignInFailure(UnexpectedAuthFailure()));
    expect(observer.errors.single.$1, same(thrown));

    await cubit.close();
  });

  test('a stream error during a sign in ends the submitting state', () async {
    repository.signInGate = Completer<void>();
    final cubit = AuthCubit(repository);

    final signingIn = cubit.signIn(
      email: 'rahat@example.com',
      password: 'correct',
    );
    repository.emitAuthError(StateError('channel died'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const AuthSignInFailure(UnexpectedAuthFailure()));

    repository.signInGate?.complete();
    await signingIn;
    await cubit.close();
  });

  test('a stream error does not sign out a signed-in member', () async {
    final observer = _installObserver();
    final cubit = AuthCubit(repository);
    repository.emitAuthState(testUser);
    await Future<void>.delayed(Duration.zero);

    repository.emitAuthError(StateError('channel died'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const AuthSignedIn(testUser));
    expect(
      observer.errors,
      hasLength(1),
      reason: 'the error is still reported',
    );

    await cubit.close();
  });

  test('the auth stream keeps working after an error', () async {
    final cubit = AuthCubit(repository);

    repository.emitAuthError(StateError('channel died'));
    repository.emitAuthState(testUser);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, const AuthSignedIn(testUser));

    await cubit.close();
  });

  test('signing out delegates to the repository', () async {
    final cubit = AuthCubit(repository);

    expect(await cubit.signOut(), isTrue);
    expect(repository.signOutCalls, 1);

    await cubit.close();
  });

  test('a failed sign out is reported and returns false', () async {
    final observer = _installObserver();
    final thrown = StateError('channel died');
    repository.signOutThrows = thrown;
    final cubit = AuthCubit(repository);

    expect(await cubit.signOut(), isFalse);
    expect(observer.errors.single.$1, same(thrown));

    await cubit.close();
  });

  test('closing cancels the auth subscription', () async {
    final cubit = AuthCubit(repository);
    expect(repository.hasListener, isTrue);

    await cubit.close();

    expect(repository.hasListener, isFalse);
  });
}
