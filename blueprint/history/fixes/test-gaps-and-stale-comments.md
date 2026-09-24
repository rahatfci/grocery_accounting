# Fix: Test gaps and stale comments

**Type:** Fix
**Status:** verified
**Branch:** `fix/test-gaps-and-stale-comments`
**Fixes:** F-12, F-13, F-16, F-17, F-18, F-19

## The problem

Six small review findings, all test assertions or comments:

- **F-12** - `a list failure neither blocks nor fails the screen`
  (`test/features/purchases/presentation/record_purchase_cubit_test.dart`)
  never checks that the shopping list failure is reported through `addError`.
- **F-13** - `ReceiptStore`'s doc (`lib/features/receipts/data/receipt_store.dart`)
  still says Firebase Storage, and `receiptStoragePath`
  (`lib/features/receipts/logic/receipt.dart`) says a retried upload overwrites
  itself. Photos go to Supabase Storage, and an upload never overwrites: an
  object already at the path counts as stored.
- **F-16** - the doc on `ItemsLoaded.now`
  (`lib/features/items/presentation/items_state.dart`) says it is taken only
  when the stream reports, but `ItemsCubit.refresh()` now also sets it on
  resume.
- **F-19** - the `commit()` doc in
  `lib/features/purchases/presentation/record_purchase_cubit.dart` still says
  the photo is kept first "so the purchase can point at it" and that keeping
  it on web is an upload. Since the F-14 fix, keeping uploads nothing, and the
  photo is confirmed only after the commit succeeds.
- **F-17** - the failed sign-out cubit test checks the error but not the stack
  trace.
- **F-18** - the successful sign-out Home test never checks that the failure
  snackbar is absent.

## The fix

- **F-12:** install the file's `_RecordingObserver` in that test and expect
  `[const ConnectionUnavailable()]` to have been reported.
- **F-13:** reword both comments to Supabase Storage and to "an object already
  at this path is the same photo and counts as stored".
- **F-16:** reword the comment to say it is taken when the stream reports or
  the catalogue is refreshed.
- **F-19:** reword the `commit()` doc to the keep, confirm and discard flow.
- **F-17:** the fake throws sign-out errors with an optional known trace, and
  the test compares it with `same`.
- **F-18:** the success test expects the snackbar text to be absent.

Tests and comments only. No product behaviour changes.

## Build steps

### [x] Step 1 - Tighten the tests and fix the comments

**Done when:** `flutter analyze` is clean and `flutter test` passes.

## Verify

- `flutter analyze` and `flutter test`.
- No runtime change. Every platform is `assumed`.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":2468,"specSha256":"9584996043c64ea7f7df2ff6bf6f3c4d20c5843b5d81a164d3eb9d0e24fc3108","branch":"refs/heads/fix/test-gaps-and-stale-comments","head":"e0159f228f742d4924b44d2bc0783852899551a6","baseRef":"refs/heads/main","baseCommit":"5703c0adbeab2b393f6cb534e92417abe90f4a27","sourceTree":"f9fb3a661f43c6ceb7e41e4d785f8cb6856c38ec","absentOptional":[]} -->

## Findings

### test-gaps-and-stale-comments/F-07 [P3] closed - Web Firestore persistence takes the default single-tab manager

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
Closed on 2026-09-24 by /audit (scope: lib/main.dart, lib/features/receipts,
record_purchase_cubit.dart; lens: all). At HEAD 5703c0a `lib/main.dart:27-33`
sets `const Settings(persistenceEnabled: true, webPersistentTabManager:
WebPersistentMultipleTabManager())` before any other Firestore use. The locked
`cloud_firestore_web` 5.7.3 setter (`cloud_firestore_web.dart:159-165`) maps
that exact type to `persistentMultipleTabManager()`, so the single-tab default
branch is no longer taken. The field is web-only, so phones are unaffected. No
new defect in the file. Two-tab sharing is still not exercised on a device.

### test-gaps-and-stale-comments/F-12 [P3] closed - The purchase screen's shopping list failure report is never asserted

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
**Resolution:** Fixed 2026-09-24 by /implement on `fix/test-gaps-and-stale-comments`: the test installs `_RecordingObserver` and expects `[const ConnectionUnavailable()]` reported. Awaiting /audit to close.
Closed on 2026-09-24 by /audit independent (scope: current; lens: all), against HEAD e0159f2. The test at `record_purchase_cubit_test.dart:489-507` installs the file's own `_RecordingObserver` (the pattern already used at lines 628, 681, 798 and 904) and asserts `observer.reported` equals `[const ConnectionUnavailable()]` after the shopping list emits that error. `_onShoppingListError` forwarding through `addError` is now the only way the list can be non-empty, so dropping that call would fail the test. The exact-list assertion also proves nothing else was reported. `flutter test` passes. No new defect in the file.

### test-gaps-and-stale-comments/F-13 [P3] closed - Receipt comments still describe Firebase Storage and overwriting uploads

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
**Resolution:** Fixed 2026-09-24 by /implement on `fix/test-gaps-and-stale-comments`: `ReceiptStore` and `receiptStoragePath` docs now say Supabase Storage and that an object already at the path counts as stored. Awaiting /audit to close.
Closed on 2026-09-24 by /audit independent (scope: current; lens: all), against HEAD e0159f2. `receipt_store.dart:5-8` now says Supabase Storage and "every storage and file system type"; `receipt.dart:17-21` now says an upload never overwrites and an object already at the path counts as stored. Both match `uploadReceiptToSupabase` (supabase_receipt_store.dart:29-68): a POST with no `x-upsert` header, where a 409 maps to `Ok`. Comments only, no behaviour change. One more stale "Firebase Storage" comment outside these two files is recorded separately as F-20.

### test-gaps-and-stale-comments/F-14 [P3] closed - A refused purchase can still leave an uploaded receipt object

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
Closed on 2026-09-24 by /audit (scope: lib/main.dart, lib/features/receipts,
record_purchase_cubit.dart; lens: all), against HEAD 5703c0a. Phones: `keep`
(supabase_receipt_store.dart:140-163) lands the file on `{id}.img.new`, and
`purchaseIdFromPendingName` (receipt.dart:28-34) rejects any name not ending
in `.img`, so neither `.new` nor `.partial` can be flushed; only `confirm`
(166-184) renames it into the queue. Web: `keep` only holds bytes and
`discard` drops them. `RecordPurchaseCubit.commit`
(record_purchase_cubit.dart:229-292) calls `confirm` only on `Ok` (including
the refusal-window timeout, as the spec intends) and `discard` on `Err` or a
throw, so a refused purchase uploads nothing on either platform. Covered at
HEAD by store tests (including the flush-during-keep race) and cubit tests on
both platforms. The kill-before-confirm edge is recorded as accepted in the
fix spec. The repair left one pre-existing doc comment stale, recorded
separately as F-19; it changes no behaviour.

### test-gaps-and-stale-comments/F-16 [P3] closed - `ItemsLoaded.now` doc still says it is taken only when the stream reports

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
**Resolution:** Fixed 2026-09-24 by /implement on `fix/test-gaps-and-stale-comments`: the `ItemsLoaded.now` doc now says it is taken when the stream reports or the catalogue is refreshed. Awaiting /audit to close.
Closed on 2026-09-24 by /audit independent (scope: current; lens: all), against HEAD e0159f2. `items_state.dart:29-31` now says `now` is taken when the stream reports or the catalogue is refreshed, which matches the two places that build `ItemsLoaded`: the stream listener and `ItemsCubit.refresh()` (items_cubit.dart:46-50), both stamping one `_clock()` value for all rows. Comment only. No new defect in the file.

### test-gaps-and-stale-comments/F-17 [P3] closed - The failed sign-out cubit test does not prove the stack trace is forwarded

**File:** test/features/auth/presentation/auth_cubit_test.dart:263-273
**Found:** 2026-09-24 by /audit independent (scope: current; lens: tests)
**Why it matters:** The new `signOut` catch calls `addError(error, stackTrace)`
(lib/features/auth/presentation/auth_cubit.dart:52-54), but its test checks only
the error with `same(thrown)`. Because `addError`'s stack trace is optional and
defaults to `StackTrace.current`, a regression to `addError(error)` still
passes. This is the same gap F-15 closed for sign in, repeated in the new code.
**Suggested fix:** Give the fake a `signOutThrowsStackTrace` thrown via
`Error.throwWithStackTrace`, as `signIn` now does, and assert
`observer.errors.single.$2` is `same` as it. Test only; no current requirement
is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/test-gaps-and-stale-comments`: the fake throws sign-out errors with a known trace and the test compares it with `same`. Awaiting /audit to close.
Closed on 2026-09-24 by /audit independent (scope: current; lens: all), against HEAD e0159f2. `FakeAuthRepository.signOut` (fake_auth_repository.dart:60-70) now rethrows through `Error.throwWithStackTrace` when `signOutThrowsStackTrace` is set, mirroring the sign-in field, and `auth_cubit_test.dart:263-277` sets a known trace and asserts `observer.errors.single.$2` is `same(thrownTrace)`. A regression of `AuthCubit.signOut` (auth_cubit.dart:48-56) to `addError(error)` would supply `StackTrace.current` and fail. The field is optional, so the Home sign-out tests that set only `signOutThrows` are unaffected. `flutter test` passes.

### test-gaps-and-stale-comments/F-18 [P3] closed - A successful sign out is never checked to show no failure snackbar

**File:** test/features/home/presentation/home_page_test.dart:182-188
**Found:** 2026-09-24 by /audit independent (scope: current; lens: tests)
**Why it matters:** `a failed sign out says so` proves the snackbar appears on
failure, and `signing out is still reachable` only counts `signOutCalls`. If
`_signOut` (lib/features/home/presentation/home_page.dart:296-304) showed the
snackbar unconditionally (for example, the `if (!signedOut)` guard dropped),
both tests stay green while every successful sign out flashes "Could not sign out. Try again." before Home is replaced.
**Suggested fix:** In `signing out is still reachable`, also
`expect(find.text('Could not sign out. Try again.'), findsNothing)`. Test only;
no current requirement is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/test-gaps-and-stale-comments`: the successful sign-out test expects the failure snackbar to be absent. Awaiting /audit to close.
Closed on 2026-09-24 by /audit independent (scope: current; lens: all), against HEAD e0159f2. `signing out is still reachable` (home_page_test.dart:182-190) now also expects the failure text `findsNothing`. The sibling failure test proves one `pump()` after the tap is enough for the snackbar to appear, so the absence assertion is meaningful rather than vacuous; dropping the `if (!signedOut)` guard in `_signOut` (home_page.dart:296-304) would now fail it. No new defect in the file.

### test-gaps-and-stale-comments/F-19 [P3] closed - `commit()` doc still says web uploads the photo before the write

**File:** lib/features/purchases/presentation/record_purchase_cubit.dart:221-228
**Found:** 2026-09-24 by /audit (scope: lib/main.dart, lib/features/receipts, record_purchase_cubit.dart; lens: quality)
**Why it matters:** The doc reads "keeping the receipt photo first so the
purchase can point at it" and "The window covers the Firestore write only, not
keeping the photo, which on web is an upload." Since the F-14 fix, `keep`
uploads nothing on either platform, web commits with no path, and the upload
happens in `confirm` after the write, followed by a second windowed write
(`setReceiptImagePath`, lines 309-311). The comment predates the fix
(unchanged since e30d96f) and now describes the orphaning order F-14 removed.
A reader trusting it could move the upload back before the commit.
**Suggested fix:** Reword to: the photo is kept first but uploaded only after
the purchase is accepted; on web the upload and the path link follow the
write, and the link has its own refusal window. Comment only; no current
requirement is lost.
**Resolution:** Fixed 2026-09-24 by /implement on `fix/test-gaps-and-stale-comments`: the `commit()` doc now describes keep, confirm after a successful commit, and discard on refusal. Awaiting /audit to close.
Closed on 2026-09-24 by /audit independent (scope: current; lens: all), against HEAD e0159f2. The `commit()` doc (record_purchase_cubit.dart:221-229) now says the photo is kept first but kept uploads nothing, is confirmed (queued or uploaded) only once the commit succeeds, and is discarded when refused. That matches the code: `confirm` runs only via `_storeReceipt` on `Ok` (lines 271-275) and `discard` on `Err` or a throw (276-290). "The window covers the Firestore write only" is accurate for the commit write; the web path link has its own window, visible in `_storeReceipt` (309-311). Comment only. No new defect in the file.

## Independent review

**Status:** passed
**Target commit:** e0159f228f742d4924b44d2bc0783852899551a6
**Base commit:** 5703c0adbeab2b393f6cb534e92417abe90f4a27
**Base ref:** main
**Spec hash:** 9584996043c64ea7f7df2ff6bf6f3c4d20c5843b5d81a164d3eb9d0e24fc3108
**Prepared by:** claude
**Builder model:** claude-opus-5-5
**Requested reviewer:** claude
**Requested model:** claude-opus-5-5
**Requested execution:** automatic
**Requested at:** 2026-09-24T15:06:41Z
**Workflow:** regular
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5-5
**Reviewer context:** fresh subagent
**Actual execution:** automatic
**Reviewed at:** 2026-09-24T15:10:00Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

## Commands

- `git rev-parse HEAD`: pass (equals Target commit)
- `git merge-base main HEAD`: pass (equals Base commit)
- `shasum -a 256 blueprint/context/current-feature.md`: pass (equals Spec hash)
- `git status --porcelain --untracked-files=all`: pass (only blueprint/context/review.md differs)
- `flutter analyze`: pass (No issues found)
- `flutter test`: pass (736 tests, all passed)

## Evidence

- Delta reviewed in full: 8 files outside the two evidence paths (4 doc comments in lib/, 4 test files), plus the tracked spec.
- Product changes are comments only; no executable line in lib/ changed.
- F-12: record_purchase_cubit_test.dart:489-507 asserts `[const ConnectionUnavailable()]` reported via the file's `_RecordingObserver`.
- F-17: fake_auth_repository.dart:60-70 rethrows with `Error.throwWithStackTrace`; auth_cubit_test.dart:263-277 asserts the trace with `same`.
- F-18: home_page_test.dart:182-190 asserts the failure snackbar is absent; the sibling failure test proves one pump suffices for it to appear.
- F-13, F-16, F-19: reworded comments checked against supabase_receipt_store.dart:29-68, items_cubit.dart:46-50 and record_purchase_cubit.dart:229-311.
- Security and performance: no new input, network, persistence, or hot-path code in the delta.

## Findings

- F-12, F-13, F-16, F-17, F-18, F-19 [P3]: closed this pass.
- F-20 [P3] open: `Purchase.receiptImagePath` doc still says Firebase Storage (lib/features/purchases/logic/purchase.dart:66). Non-blocking.
- F-07, F-14: unchanged (already closed).

## Remaining risk

- Verify command unavailable: the project defines no combined Verify command.
- Integration tests unavailable: no integration_test/ directory.
- Check not required and not run; no device evidence (every platform assumed, per spec).
