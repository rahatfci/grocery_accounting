# Findings

> **Generated file.** The findings ledger: review findings raised by `/audit`
> against the work in progress, each with a durable ID, severity (P0-P3), and
> status. `/implement` marks repaired findings `fixed`, a later `/audit` pass
> moves them to `closed`, and `/complete` refuses to merge while any P0 or P1
> finding is `open` or `fixed`, then archives resolved findings with the work
> and resets this file.

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

### F-13 [P3] open - Receipt comments still describe Firebase Storage and overwriting uploads

**File:** lib/features/receipts/data/receipt_store.dart:5-8
**Found:** 2026-09-24 by /audit independent (scope: current; lens: quality)
**Why it matters:** The `ReceiptStore` doc says photos go to "Firebase
Storage" and that implementations "own every Firebase and file system type",
but the only implementation is `SupabaseReceiptStore` over the Storage REST
API. `receiptStoragePath` (lib/features/receipts/logic/receipt.dart:19-20)
says a retried upload "overwrites itself", which contradicts the spec's Upload
contract and `uploadReceiptToSupabase` (lib/features/receipts/data/supabase_receipt_store.dart:31-34):
the upload never overwrites and a 409 counts as stored. A reader relying on the
comment could add `x-upsert` or expect a replacement photo to land, which the
bucket has no update policy for.
**Suggested fix:** Reword both comments to Supabase Storage and to "an object
already at this path is the same photo and counts as stored". Comments only; no
current requirement is lost.
**Resolution:**

### F-14 [P3] fixed - A refused purchase can still leave an uploaded receipt object

**File:** lib/features/receipts/data/supabase_receipt_store.dart:137-139
**Found:** 2026-09-24 by /audit independent (scope: current; lens: quality, security)
**Why it matters:** The spec's queue contract says `discard` runs "when the
commit is refused, so a refused purchase never uploads a photo". On web,
`keep` uploads before the commit starts and `discard` is a no-op
(supabase_receipt_store.dart:156-158), so a refused commit leaves the object in
the bucket, and each retry mints a new purchase id
(lib/features/purchases/presentation/record_purchase_cubit.dart:147) and
uploads another copy. On phones, a flush already iterating the queue (a
previous commit's flush or Home's resume flush) can list and upload a file
`keep` just renamed into place before that purchase's commit is refused, and
`discard` then removes only the local copy. Nothing can delete objects with the
publishable key, so these orphans are permanent. Impact is storage clutter and
receipt images with no purchase, not data loss.
**Suggested fix:** Needs a user decision for web, since uploading before the
commit is the chosen web design: either record the web orphan as accepted in
the spec, or upload after the commit on web too. For phones, have `keep` leave
the file under a name `flush` ignores (for example the existing `.partial`
form) and rename it to `{id}.img` only once the commit succeeds or passes the
refusal window. No current requirement is lost.
**Resolution:** fixed on 2026-09-24 by fix `refused-purchases-leave-uploaded-receipt-photos`.
The user chose to upload after saving on web. `ReceiptStore.keep` now uploads
nothing on either platform. On phones it writes `{id}.img.new`, which `flush`
ignores, and `confirm` renames it into the queue only after the commit
succeeds or passes the refusal window. On web it holds the bytes, `confirm`
uploads them after the commit, and `setReceiptImagePath` then links the path.
A refused commit discards the photo without confirming it. Covered by store
tests, including a flush racing a new keep, and by cubit tests on both
platforms. Awaiting an `/audit` pass to close.

### F-15 [P3] open - The sign-in error test does not prove the stack trace is forwarded

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
**Resolution:**

### F-16 [P3] open - `ItemsLoaded.now` doc still says it is taken only when the stream reports

**File:** lib/features/items/presentation/items_state.dart:29-30
**Found:** 2026-09-24 by /audit independent (scope: current; lens: quality)
**Why it matters:** The field doc reads "Taken when the stream reported, so
every row on screen is derived against the same instant." After this fix,
`ItemsCubit.refresh()` (items_cubit.dart:46-50) also re-stamps `now` on app
resume with no stream emission. A reader trusting the comment would conclude
that stale stock is still possible, or that `now` changing implies new item
data, which is exactly the assumption F-11 was about.
**Suggested fix:** Reword to say `now` is taken when the stream reports and
again when the catalogue is refreshed on resume, still one instant for every
row. Comment only; no current requirement is lost.
**Resolution:**
