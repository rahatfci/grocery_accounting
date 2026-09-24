# Fix: Sign in can strand the user or lose the error

**Type:** Fix
**Status:** verified
**Branch:** `fix/sign-in-can-strand-the-user-or-lose-the-error`
**Fixes:** F-02, F-03, F-04

## The problem

All three findings are in `lib/features/auth/presentation/auth_cubit.dart`.

- **F-02 - no way out of submitting.** On `Ok`, `signIn` emits nothing and
  waits for the auth stream to report the user. Until it does, `SignInPage`
  shows disabled fields and a disabled button with no message. If the stream
  never reports, the user is stuck.
- **F-03 - no error handler on the auth stream.** `.listen(_onAuthStateChanged)`
  (line 15) has no `onError`. An error before the first event leaves the state
  at `AuthInitial`, and `AuthGate` shows a bare spinner forever, including on
  every relaunch that hits the same failure.
- **F-04 - the error and stack trace are thrown away.** `catch (_)` (line 30)
  turns every unexpected error into "Something went wrong" and reports it
  nowhere.

The app has no `BlocObserver` registered, so `addError` on its own does not
record anything either. The default observer ignores it.

## The fix

1. **F-02:** on `Ok(:final value)`, emit `AuthSignedIn(value)`. The repository
   only returns `Ok` when Firebase gave back a non-null user, so the app still
   never claims a session Firebase has not confirmed. `AuthSignedIn` is
   `Equatable` over `AppUser`, so the stream event that follows produces an
   equal state and `Cubit` drops it. `AuthGate`'s member mirror still runs
   exactly once, on the move into `AuthSignedIn`.
2. **F-03:** add an `onError` to the subscription. It always calls
   `addError(error, stackTrace)`. If the session is still unknown
   (`AuthInitial`) or a sign-in is in flight (`AuthSubmitting`), it emits
   `AuthSignInFailure(const UnexpectedAuthFailure())`, which the gate already
   renders as `SignInPage` with a message and a retry. In any other state it
   changes nothing. In particular, a stream error while signed in must not send
   the user back to the sign-in screen.
3. **F-04:** change to `catch (error, stackTrace)` and call
   `addError(error, stackTrace)` before the existing emit. The message the user
   sees stays the same.
4. **Make `addError` reach someone:** add a small `BlocObserver` in `lib/core/`
   whose `onError` forwards to `FlutterError.reportError`, and register it in
   `main` before the cubits are created. That prints the error in debug and
   goes through Flutter's normal error path in release. It adds no dependency
   and no crash-reporting service.

Must not break:

- The sign-in form's field validation and its mapped failure messages.
- A stray signed-out event still must not overwrite `AuthSubmitting` or
  `AuthSignInFailure`.
- The raw error text must still never reach the screen
  (`sign_in_page_test.dart:72`).

## Build steps

### [x] Step 1 - Always leave submitting, and survive stream errors (F-02, F-03)

- `signIn` emits `AuthSignedIn` on `Ok`.
- The subscription gets an `onError` with the state rules above.
- Update `auth_cubit_test.dart:48`: the success test now expects
  `AuthSignedIn(testUser)` straight after `Ok`, and a matching stream event
  afterwards emits nothing more. Update the comment at
  `sign_in_page_test.dart:111`.
- New cubit tests:
  - A stream error during `AuthInitial` leads to the unexpected failure.
  - A stream error during `AuthSubmitting` leads to the unexpected failure.
  - A stream error while `AuthSignedIn` leaves the state unchanged.
  - The subscription keeps working after an error: a later user event still
    signs in.

**Done when:** `flutter analyze` is clean and `flutter test` passes with the
new tests.

### [x] Step 2 - Keep the evidence (F-04)

- `catch (error, stackTrace)` plus `addError` in `signIn`, and `addError` in
  the stream `onError` from step 1.
- Add the observer in `lib/core/` and register it in `main`.
- Tests: extend the existing `StateError` cubit test
  (`auth_cubit_test.dart:87`) to assert that the error and stack trace reach an
  observer installed for the test, as well as the existing user-facing failure.
  Add a unit test that the observer forwards to `FlutterError.reportError`, by
  swapping `FlutterError.onError` inside the test.

**Done when:** `flutter analyze` is clean, `flutter test` passes, and an
unexpected sign-in error shows up in the debug console with its stack trace.

## Verify

- `flutter analyze` and `flutter test` pass.
- No device run is needed. The change is logic-only, and no screen, layout or
  plugin changes. Under the device-verification table every platform is
  `assumed`.
- Optional spot check on the Android emulator: sign in with a correct password
  and confirm Home appears as before, then with a wrong password and confirm the
  mapped message still shows.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":4798,"specSha256":"5390c8b3d05d59613c0e82e3ee4e414fadb6426a7b76a70761e65125778bbac9","branch":"refs/heads/fix/sign-in-can-strand-the-user-or-lose-the-error","head":"8a5906b2daebf5da31199f241dddfe1e346420cb","baseRef":"refs/heads/main","baseCommit":"d8bb6b6520d33ba7a29dce175036f681e0b467ca","sourceTree":"9f0ec93d2c5305c7641e3305fb2d28d584b9f181","absentOptional":[]} -->

## Findings

### sign-in-can-strand-the-user-or-lose-the-error/F-02 [P2] closed - `AuthSubmitting` has no exit unless the auth stream delivers a user

**File:** lib/features/auth/presentation/auth_cubit.dart:24-29
**Found:** 2026-09-21 by /audit (scope: current; lens: quality)
**Why it matters:** On `Ok`, `signIn` emits nothing by design, leaving the cubit
in `AuthSubmitting` until `_onAuthStateChanged` receives a non-null user. While
that state holds, `AuthGate` shows `SignInPage` with both fields `enabled: false`
and the submit button `onPressed: null` (sign_in_page.dart:95, 113, 204), so the
user cannot retry, cannot edit, and sees no message. There is no timeout and no
fallback, so `AuthSubmitting` is terminal for anything that stops the stream from
reporting: a dropped platform-channel event, a stream error (see F-03), or a
successful re-authentication Firebase does not treat as a state change. The
project's own widget test documents the property at
`test/features/auth/presentation/sign_in_page_test.dart:110`: "Without this the
page never leaves submitting."

Against real Firebase the stream does fire, so this is fragility rather than a
reproduced defect, but the cost of the fragility is a screen with no way out.

**Suggested fix:** Emit on `Ok` as well:
`if (result case Ok(:final value)) emit(AuthSignedIn(value));`. This does not
weaken the intended property, because `AuthSignedIn` is `Equatable` over
`AppUser`, so the stream event that follows carries an equal state and `Cubit`
drops it. The invariant "never show Home for a session Firebase has not
confirmed" still holds: the repository returns `Ok` only when Firebase returned a
non-null `User`. No current requirement is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/sign-in-can-strand-the-user-or-lose-the-error` (step 1): emits `AuthSignedIn` on `Ok`. Awaiting /audit to close.
Closed 2026-09-24 by /audit independent at 8a5906b: `signIn` now switches over
the result and emits `AuthSignedIn(value)` on `Ok` (auth_cubit.dart:31-36), so
`AuthSubmitting` always resolves when the repository returns. `AppUser` is
`Equatable`, so the following stream event is dropped and `AuthGate`'s mirror
still fires once. Covered by `a successful sign in is claimed from the returned
user`. No new defect introduced.

### sign-in-can-strand-the-user-or-lose-the-error/F-03 [P2] closed - The auth subscription has no error handler, stranding the app on the startup spinner

**File:** lib/features/auth/presentation/auth_cubit.dart:15
**Found:** 2026-09-21 by /audit (scope: current; lens: quality)
**Why it matters:** `.listen(_onAuthStateChanged)` passes no `onError`, so an
error on the Firebase auth stream (the plugin forwards platform-channel failures
through it) goes to the zone as an unhandled exception and the cubit's state does
not move. If that happens before the first event, the state is still
`AuthInitial`, and `AuthGate` renders `_SessionUnknown`, a bare
`CircularProgressIndicator` with no text, no retry and no timeout
(auth_gate.dart:18, 33). Relaunching takes the same path. The user gets a
permanently spinning app and no signal about why.

`coding-standards.md` requires errors in async work to be handled or allowed to
propagate deliberately; this path does neither.

**Suggested fix:** Add an `onError` to the subscription that emits a state the
gate can render, for example `AuthSignInFailure(const UnexpectedAuthFailure())`,
which `AuthGate` already maps to `SignInPage` and which gives the user a retry,
and forward the error and stack to `addError` so it reaches `BlocObserver`
instead of vanishing. No current requirement is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/sign-in-can-strand-the-user-or-lose-the-error` (step 1): the subscription has an `onError`; `AuthInitial` and `AuthSubmitting` move to the unexpected failure, other states are left alone. Awaiting /audit to close.
Closed 2026-09-24 by /audit independent at 8a5906b: `listen(..., onError:
_onAuthStreamError)` (auth_cubit.dart:15-18, 68-75) reports via `addError` and
moves only `AuthInitial`/`AuthSubmitting` to `AuthSignInFailure(
UnexpectedAuthFailure())`, which `AuthGate` renders as `SignInPage`. A
signed-in member is left alone, and `cancelOnError` stays false so later events
still arrive. Covered by four new cubit tests. No new defect introduced.

### sign-in-can-strand-the-user-or-lose-the-error/F-04 [P2] closed - The bare `catch (_)` discards the error and its stack trace

**File:** lib/features/auth/presentation/auth_cubit.dart:30-34
**Found:** 2026-09-21 by /audit (scope: current; lens: quality)
**Why it matters:** `catch (_)` catches `Object`, so it catches `Error` subtypes
as well as the `Exception`s it is aimed at. `FirebaseAuthRepository` catches only
`FirebaseAuthException` (firebase_auth_repository.dart:35), so this is the net for
everything else, which is the right shape. The problem is that it binds neither
the error nor the stack trace and forwards neither anywhere. A `TypeError` in
`_toAppUser`, a `StateError` from a misused plugin, and a `PlatformException` all
become the same "Something went wrong. Try again" with zero diagnostics, in debug
as well as release. `test/features/auth/presentation/auth_cubit_test.dart:87-105`
and `sign_in_page_test.dart:72-87` encode exactly that: a `StateError` is
swallowed into a user message, and no test asserts it is reported anywhere
because nowhere reports it.

Showing the user a mapped message is correct and must stay. Throwing away the
evidence is what costs: the first field bug on this path will be unactionable.

**Suggested fix:** `catch (error, stackTrace)`, then `addError(error, stackTrace)`
before the `emit`. `Cubit.addError` routes to `BlocObserver.onError`, needs no new
dependency, and changes nothing the user sees. No current requirement is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/sign-in-can-strand-the-user-or-lose-the-error` (step 2): `catch (error, stackTrace)` calls `addError`, and `ErrorReportingBlocObserver` (registered in `main`) forwards bloc errors to `FlutterError.reportError`. Awaiting /audit to close.
Closed 2026-09-24 by /audit independent at 8a5906b: `catch (error, stackTrace)`
now calls `addError` before the unchanged user-facing emit
(auth_cubit.dart:37-43), and `Bloc.observer` is set in `main` before any cubit
is created (main.dart:33). The raw error still never reaches the screen
(sign_in_page_test.dart). The weak stack trace assertion in the covering test
is recorded separately as F-15 and does not keep this open.

## Independent review

**Status:** passed
**Target commit:** 8a5906b2daebf5da31199f241dddfe1e346420cb
**Base commit:** d8bb6b6520d33ba7a29dce175036f681e0b467ca
**Base ref:** main
**Spec hash:** 5390c8b3d05d59613c0e82e3ee4e414fadb6426a7b76a70761e65125778bbac9
**Prepared by:** claude
**Builder model:** claude-opus-5-5
**Requested reviewer:** claude
**Requested model:** claude-opus-5-5
**Requested execution:** automatic
**Requested at:** 2026-09-24T13:01:54Z
**Workflow:** regular
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5-5
**Reviewer context:** fresh subagent
**Actual execution:** automatic
**Reviewed at:** 2026-09-24T13:03:46Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

## Commands

- `git rev-parse HEAD`, `git merge-base main HEAD`, `shasum -a 256 blueprint/context/current-feature.md`, `git status --porcelain --untracked-files=all`: pass (HEAD, merge base and spec hash match the request; only `blueprint/context/review.md` differs)
- `flutter analyze`: pass (No issues found)
- `flutter test`: pass (724 tests, all passed)

## Evidence

- Reviewed the full `d8bb6b6..8a5906b` delta: `lib/features/auth/presentation/auth_cubit.dart`, `lib/core/error_reporting_bloc_observer.dart`, `lib/main.dart`, `test/core/error_reporting_bloc_observer_test.dart`, `test/features/auth/fake_auth_repository.dart`, `test/features/auth/presentation/auth_cubit_test.dart`, `test/features/auth/presentation/sign_in_page_test.dart`, and the spec and ledger changes.
- Followed callers and contracts: `auth_gate.dart` (listener fires once on entry to `AuthSignedIn`; `AuthSignInFailure` renders `SignInPage`), `auth_state.dart` and `app_user.dart` (Equatable, so the stream echo after `Ok` is dropped), `firebase_auth_repository.dart` (`Ok` only with a non-null Firebase user).
- Checked every existing `addError` site in `lib/` that the new global observer now routes to `FlutterError.reportError`; no hot-path or user-visible effect found, and tests install their own observers.
- bloc 9.2.1: `addError` routes to `BlocObserver.onError` without rethrowing.
- F-02, F-03, F-04 re-examined against the repaired code and closed.

## Findings

- F-02 [P2] closed
- F-03 [P2] closed
- F-04 [P2] closed
- F-15 [P3] open - the sign-in error test does not prove the stack trace is forwarded

## Remaining risk

- No `Verify` command is defined for this project (unavailable).
- No integration tests exist (`integration_test/` absent); unavailable.
- Check was not required and no device run was performed; all platforms assumed. Real FlutterFire auth stream error behaviour (whether the stream closes after an error) is not exercised; if it closes, a later `signOut` would not move the state, which relies on the stream as before this change.
