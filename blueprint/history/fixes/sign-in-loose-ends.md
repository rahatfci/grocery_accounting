# Fix: Sign-in loose ends

**Type:** Fix
**Status:** verified
**Branch:** `fix/sign-in-loose-ends`
**Fixes:** F-05, F-06, F-08, F-15

## The problem

Four small gaps around sign in and sign out:

- **F-05** - `FirebaseAuthRepository` (`lib/features/auth/data/firebase_auth_repository.dart`)
  has no test. Its null-user branch on sign in and the null mapping on the auth
  stream are written but never exercised. `FirebaseAuth` is too wide to fake by
  hand, and the project uses no mocking package.
- **F-06** - `lib/app.dart` passes the externally created `authCubit` to
  `BlocProvider(create: ...)`, which makes the provider own and close it.
- **F-08** - Home's sign-out button drops the future from
  `AuthCubit.signOut()`, which does not catch. A failing sign out becomes an
  unhandled async error, and the member stays on Home with no feedback.
- **F-15** - the cubit test for an unexpected sign-in error checks that the
  exact error reaches the observer, but not the exact stack trace.

## The fix

- **F-05:** move the translation from Firebase's user into the domain into
  pure functions in `lib/features/auth/logic/app_user.dart`:
  `appUserFrom({uid, email})` (null when there is no user) and
  `signInResultFrom(AppUser?)` (the unexpected failure when sign in returned no
  user). The repository keeps only the Firebase calls and uses them for both
  the stream and sign in. Test the functions in
  `test/features/auth/logic/app_user_test.dart`. The error-code mapping is
  already covered by `authFailureFromCode`'s tests.
- **F-06:** `BlocProvider.value(value: authCubit, ...)`.
- **F-08:** `AuthCubit.signOut()` catches, reports through `addError`, and
  returns whether it worked. Home's button awaits it and, on failure, shows
  "Could not sign out. Try again." in a snackbar. A successful sign out is
  still driven by the auth stream, as before.
- **F-15:** the fake repository throws with a known stack trace
  (`Error.throwWithStackTrace`), and the test compares it with `same`.

No new dependency. Must not break the sign-in states or the gate's member
mirror.

## Build steps

### [x] Step 1 - Close the four gaps

- The changes above, plus tests:
  - The logic tests for both helpers.
  - The cubit's sign out reporting a failure and returning false, and
    returning true on success.
  - A Home widget test showing the snackbar when sign out fails.
  - The tightened F-15 assertion.

**Done when:** `flutter analyze` is clean and `flutter test` passes.

## Verify

- `flutter analyze` and `flutter test`.
- One snackbar is added on an existing screen, a simple UI edit. Every platform
  is `assumed`.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":2632,"specSha256":"532639faca664b52fef7b10a1104f1aafb3869001582007a034ac885579769ab","branch":"refs/heads/fix/sign-in-loose-ends","head":"1efdf9051b453bec61301133dacf52e538d51822","baseRef":"refs/heads/main","baseCommit":"952932b0b81f5f2e917945e5c4c4f2b55dcb2b26","sourceTree":"615aba52b4d33819c4a9c420caf9b9896e48f5f0","absentOptional":[]} -->

## Findings

### sign-in-loose-ends/F-05 [P3] closed - `FirebaseAuthRepository` has no test, including its null-user branch

**File:** lib/features/auth/data/firebase_auth_repository.dart:21-43
**Found:** 2026-09-21 by /audit (scope: current; lens: tests)
**Why it matters:** This is the only place a Firebase type is translated into the
domain, and the only file in the delta with no coverage. Three behaviours go
unasserted: `FirebaseAuthException.code` reaching `authFailureFromCode`, the
`credential.user == null` branch returning `Err(UnexpectedAuthFailure())` (a
guard that is written but never exercised, so a regression in it would go
unnoticed), and `authStateChanges()` mapping a null `User` to a null `AppUser`.
The 31 tests that do exist are strong and assertive rather than mirror-shaped, so
this is the one real gap and not a pattern.

The spec rules out `mockito` and `mocktail`, and `FirebaseAuth` is a concrete
class with a wide surface, so a hand-written fake is genuinely expensive.

**Suggested fix:** Either extract the translation into a pure helper in `logic/`
that takes the already-extracted uid, email and error code and test that, or
accept the gap explicitly and record the reason, since `authFailureFromCode`
itself is thoroughly covered. If accepted, no current requirement is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/sign-in-loose-ends`: `appUserFrom` and `signInResultFrom` in `lib/features/auth/logic/app_user.dart` now hold the translation, including the null-user branch; the repository only calls Firebase. Tested in `test/features/auth/logic/app_user_test.dart`. Awaiting /audit to close.
Closed 2026-09-24 by /audit independent (scope: current; target 1efdf90): re-examined `firebase_auth_repository.dart` and `app_user.dart`. Both the stream and sign in now route through `appUserFrom`/`signInResultFrom`, whose null-user and member branches are asserted in `app_user_test.dart`; the code mapping stays covered by `authFailureFromCode`'s tests. Only the one-line `user?.uid`/`user?.email` wiring remains untested, which the suggested fix anticipated. No new defect introduced.

### sign-in-loose-ends/F-06 [P3] closed - `BlocProvider` takes ownership of a cubit it did not create

**File:** lib/app.dart:16-17
**Found:** 2026-09-21 by /audit (scope: current; lens: quality)
**Why it matters:** `BlocProvider(create: (_) => authCubit)` hands an
externally-owned instance to the `create` constructor, which makes the provider
close it on dispose. `flutter_bloc` provides `BlocProvider.value` for exactly this
case. It is harmless today because `GroceryAccountingApp` is the root and is never
remounted, but it is the pattern the next feature will copy into a screen-level
provider, where a remount closes a cubit someone else still holds.

**Suggested fix:** `BlocProvider.value(value: authCubit, child: ...)`. One line,
no behaviour change at the root. No current requirement is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/sign-in-loose-ends`: `lib/app.dart` uses `BlocProvider.value(value: authCubit)`. Awaiting /audit to close.
Closed 2026-09-24 by /audit independent (scope: current; target 1efdf90): `lib/app.dart:88-89` uses `BlocProvider.value`, so the provider no longer owns or closes the cubit. No new defect introduced.

### sign-in-loose-ends/F-08 [P3] closed - The sign-out future is dropped at the call site

**File:** lib/features/home/presentation/home_page.dart:25
**Found:** 2026-09-21 by /audit (scope: current; lens: quality)
**Why it matters:** `onPressed: () => context.read<AuthCubit>().signOut()`
discards the returned future, and `AuthCubit.signOut` forwards
`_repository.signOut()` with no `try`/`catch` (auth_cubit.dart:37). A throwing
`signOut` therefore becomes an unhandled async error, and the user stays on Home
with no feedback and no indication the tap did nothing. `coding-standards.md`
states errors in a future are handled or propagate deliberately; this does
neither, and `flutter_lints` does not enable `unawaited_futures`, so
`flutter analyze` stays clean over it.

**Suggested fix:** Catch inside `AuthCubit.signOut` and surface a state, or at
minimum report through `addError` so the failure is visible. No current
requirement is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/sign-in-loose-ends`: `AuthCubit.signOut` catches, reports through `addError` and returns false; Home awaits it and shows "Could not sign out. Try again." on failure. Covered by cubit and Home widget tests. Awaiting /audit to close.
Closed 2026-09-24 by /audit independent (scope: current; target 1efdf90): `AuthCubit.signOut` (auth_cubit.dart:48-56) catches and reports through `addError`; `_signOut` (home_page.dart:296-304) captures the messenger before the await and uses no `BuildContext` after it, so the snackbar is safe whether or not Home is still mounted. The future is no longer dropped. Test gaps in the new sign-out tests are recorded separately as F-17 and F-18.

### sign-in-loose-ends/F-15 [P3] closed - The sign-in error test does not prove the stack trace is forwarded

**File:** test/features/auth/presentation/auth_cubit_test.dart:127-128
**Found:** 2026-09-24 by /audit independent (scope: current; lens: tests)
**Why it matters:** F-04 was about the error and its stack trace being thrown
away, and the spec asks the extended `StateError` test to assert that both reach
the observer. The test checks the error with `same(thrown)`, but the stack trace
only with `toString()` being non-empty. `Cubit.addError`'s stack trace parameter
is optional and defaults to `StackTrace.current`, so a regression to
`addError(error)` (dropping the caught trace for the call-site one) still
passes. The observer unit test does check `same(stackTrace)`, so only the cubit
half is unguarded.
**Suggested fix:** Assert the recorded trace points at the throw site, for
example `contains('fake_auth_repository.dart')`, or have the fake throw with a
known trace via `Error.throwWithStackTrace` and compare with `same`. Test only;
no current requirement is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/sign-in-loose-ends`: The fake throws with a known trace via `Error.throwWithStackTrace` and the cubit test compares it with `same`. Awaiting /audit to close.
Closed 2026-09-24 by /audit independent (scope: current; target 1efdf90): auth_cubit_test.dart:113-131 sets `signInThrowsStackTrace` and asserts `same(thrownTrace)`; a regression to `addError(error)` would record `StackTrace.current` and fail. `flutter test` passes, confirming the trace survives the async boundary.

## Independent review

**Status:** passed
**Target commit:** 1efdf9051b453bec61301133dacf52e538d51822
**Base commit:** 952932b0b81f5f2e917945e5c4c4f2b55dcb2b26
**Base ref:** main
**Spec hash:** 532639faca664b52fef7b10a1104f1aafb3869001582007a034ac885579769ab
**Prepared by:** claude
**Builder model:** claude-opus-5-5
**Requested reviewer:** claude
**Requested model:** claude-opus-5-5
**Requested execution:** automatic
**Requested at:** 2026-09-24T15:00:12Z
**Workflow:** regular
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5-5
**Reviewer context:** fresh subagent
**Actual execution:** automatic
**Reviewed at:** 2026-09-24T15:01:35Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

## Commands

- `flutter analyze`: pass (No issues found)
- `flutter test`: pass (736 tests, All tests passed)
- `shasum -a 256 blueprint/context/current-feature.md`: pass (matches Spec hash)
- `git rev-parse HEAD` / `git merge-base main HEAD` / `git status --porcelain`: pass (target, base, and clean tree except review.md confirmed)

## Evidence

- Reviewed the full `952932b..1efdf90` delta: lib/app.dart, lib/features/auth/data/firebase_auth_repository.dart, lib/features/auth/logic/app_user.dart, lib/features/auth/presentation/auth_cubit.dart, lib/features/home/presentation/home_page.dart, and the four touched test files.
- `logic/app_user.dart` imports only `core/result.dart`, `auth_failure.dart`, and `equatable`; no Flutter or Firebase import.
- `_signOut` captures the `ScaffoldMessenger` before the await and touches no `BuildContext` after it.
- `AuthCubit.signOut` has one caller (home_page.dart:298); the changed `Future<bool>` return breaks no other call site.
- Security: no new input, auth boundary, persisted data, or secret; sign out still delegates to `FirebaseAuth.signOut`. Performance: no new work on hot paths.
- F-05, F-06, F-08, F-15 re-examined against the repaired code and closed.

## Findings

- F-05 [P3] closed
- F-06 [P3] closed
- F-08 [P3] closed
- F-15 [P3] closed
- F-17 [P3] open - failed sign-out cubit test does not assert the stack trace
- F-18 [P3] open - successful sign-out widget test does not assert the absence of the failure snackbar

## Remaining risk

- Check not required and not run; the snackbar is exercised only by a widget test, every platform assumed.
- No Verify command and no integration tests are defined for this project.
- The `user?.uid`/`user?.email` wiring in `FirebaseAuthRepository` still has no direct test (FirebaseAuth is not faked).
- `flutter analyze` resolved dependencies before analyzing; `pubspec.lock` was unchanged.
