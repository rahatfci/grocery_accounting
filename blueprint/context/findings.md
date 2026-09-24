# Findings

> **Generated file.** The findings ledger: review findings raised by `/audit`
> against the work in progress, each with a durable ID, severity (P0-P3), and
> status. `/implement` marks repaired findings `fixed`, a later `/audit` pass
> moves them to `closed`, and `/complete` refuses to merge while any P0 or P1
> finding is `open` or `fixed`, then archives resolved findings with the work
> and resets this file.

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

### F-17 [P3] open - The failed sign-out cubit test does not prove the stack trace is forwarded

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
**Resolution:**

### F-18 [P3] open - A successful sign out is never checked to show no failure snackbar

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
**Resolution:**
