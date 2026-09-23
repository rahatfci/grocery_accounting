# Findings

> **Generated file.** The findings ledger: review findings raised by `/audit`
> against the work in progress, each with a durable ID, severity (P0-P3), and
> status. `/implement` marks repaired findings `fixed`, a later `/audit` pass
> moves them to `closed`, and `/complete` refuses to merge while any P0 or P1
> finding is `open` or `fixed`, then archives resolved findings with the work
> and resets this file.

### F-02 [P2] open - `AuthSubmitting` has no exit unless the auth stream delivers a user

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
**Resolution:**

### F-03 [P2] open - The auth subscription has no error handler, stranding the app on the startup spinner

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
**Resolution:**

### F-04 [P2] open - The bare `catch (_)` discards the error and its stack trace

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
**Resolution:**

### F-05 [P3] open - `FirebaseAuthRepository` has no test, including its null-user branch

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
**Resolution:**

### F-06 [P3] open - `BlocProvider` takes ownership of a cubit it did not create

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
**Resolution:**

### F-07 [P3] fixed - Web Firestore persistence takes the default single-tab manager

**File:** lib/main.dart:15-17
**Found:** 2026-09-21 by /audit (scope: current; lens: performance)
**Why it matters:** `Settings(persistenceEnabled: true)` with no
`webPersistentTabManager` resolves, on web, to
`persistentLocalCache(PersistentCacheSettings())` with the JS SDK's default
single-tab manager (confirmed in
`cloud_firestore_web-5.7.3/lib/cloud_firestore_web.dart:155-180`). Only one
browser tab can hold the IndexedDB lease; a second tab fails with
`failed-precondition` and runs without persistence. The overview names web as a
real surface ("Web, sitting down - review spending, set up items, correct stock,
export a month"), which is the kind of session people open in a second tab.

No impact today: this feature stores nothing, as the spec itself notes. The cost
lands in feature 2 onwards.

**Suggested fix:** Decide deliberately when feature 2 adds the first reads: either
pass `webPersistentTabManager: const WebPersistentMultipleTabManager()`, or record
single-tab as accepted behaviour. No current requirement is lost now.
**Resolution:** fixed in feature 2, step 2. `lib/main.dart` now passes
`webPersistentTabManager: WebPersistentMultipleTabManager()` alongside
`persistenceEnabled: true`. The name and import path were confirmed against the
installed `cloud_firestore_platform_interface-8.0.7/lib/src/settings.dart:210`
rather than assumed. Verified only as far as startup: the web app boots with
zero console errors or warnings, which proves the setting is accepted, not that
two tabs now share the lease. Awaiting an `/audit` pass to close.

### F-08 [P3] open - The sign-out future is dropped at the call site

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
**Resolution:**

### F-09 [P3] open - `blueprint/` and `.claude/` are tracked, against the stated local-only contract

**File:** .gitignore:47-53
**Found:** 2026-09-21 by /audit (scope: current; lens: quality)
**Why it matters:** `CLAUDE.md` and `blueprint/context/workflow.md` both state
this project runs in local-only visibility and that `.claude/`, `blueprint/` and
`CLAUDE.md` are gitignored, with `AGENTS.md` kept free of workflow contents. In
fact 15 `blueprint/` files and 35 `.claude/` files are tracked against the remote
`github.com/rahatfci/grocery_accounting`, and this commit adds 355 lines of spec
to `blueprint/context/current-feature.md` plus a workflow-verification section to
`blueprint/context/platform.md`. The only path this delta actually ignored is
`blueprint/.state/run.json`, which it correctly untracked.

No secret is exposed: the spec carries the project id, device names and process
notes, all non-sensitive, and `.firebaserc` carries the same project id by
design. This is a contract mismatch, not a leak.

**Suggested fix:** Pick one and make the two agree. Either ignore and untrack the
two trees as the contract says, or amend `CLAUDE.md` and
`blueprint/context/workflow.md` to say the Blueprint is tracked on this project.
The first removes shipped state from the repo, so it needs an explicit user
decision rather than an automatic repair. No current requirement is lost either
way.
**Resolution:**

### F-11 [P2] open - Displayed stock is frozen at the last stream emission

**File:** lib/features/items/presentation/items_cubit.dart:124-125
**Found:** 2026-09-23 by /audit independent (scope: current; lens: quality)
**Why it matters:** `ItemsLoaded.now` is taken only when `watchItems()` emits,
and both the catalogue row and the detail screen derive current stock from it.
A Firestore snapshot listener does not re-emit on its own, so if the catalogue
or detail screen stays on the stack (for example the app is backgrounded
overnight and resumed), the shown stock stays at the old instant until some
write to `items` arrives. The spec's goal is that staples "visibly run down day
by day". The write path is unaffected (the cubit passes a fresh `_clock()` to
the repository), so the member can log use against a number that is hours or a
day stale, and the result then jumps. The repository doc comment says the new
stock "is computed from the number on their screen", which is only true while
the screen is fresh.

**Suggested fix:** Refresh `now` without new data: re-emit
`ItemsLoaded(items, now: _clock())` when the app resumes (an
`AppLifecycleListener` on the page calling a small cubit method), or on a coarse
periodic timer cancelled in `close()`. Either keeps the injected clock and the
existing tests. No current requirement is lost.
**Resolution:** Re-examined 2026-09-23 by /audit independent at 3813c40: still
present, `now` is taken only in `_onItemsChanged` (items_cubit.dart:124-125).
Remains open at P2.
Re-examined 2026-09-23 by /audit independent at 6f3ea7a: unchanged, still
open at P2. The write path still uses a fresh `_clock()` (items_cubit.dart:109).

### F-12 [P3] open - The purchase screen's shopping list failure report is never asserted

**File:** test/features/purchases/presentation/record_purchase_cubit_test.dart:453-481
**Found:** 2026-09-24 by /audit independent (scope: current; lens: tests)
**Why it matters:** The spec's Data / contracts section states that a shopping
list stream failure on the purchase screen "is reported through `addError` and
is never shown". `RecordPurchaseCubit._onShoppingListError`
(lib/features/purchases/presentation/record_purchase_cubit.dart:152-155) does
both, and the two new tests prove the "never shown" half (the state stays
`RecordPurchaseReady` and nothing is cleared). Neither installs a
`BlocObserver`, so deleting the `addError` line would leave the suite green and
the failure would vanish silently. `shopping_list_cubit_test.dart` already
asserts the equivalent report for its items stream with a recording observer,
so the pattern exists and was just not applied here.
**Suggested fix:** In `a list failure neither blocks nor fails the screen`,
install a recording `BlocObserver` (as `shopping_list_cubit_test.dart:13-21`
does) and expect `[const ConnectionUnavailable()]` to have been reported. No
current requirement is lost.
**Resolution:**
