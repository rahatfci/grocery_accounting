# Feature: Item catalogue

**From build-plan:** feature 2
**Build attempt:** 1
**Branch:** feature/item-catalogue
**Status:** verified

## Goal

Give the household a catalogue of the things it buys. A signed-in member opens
the catalogue, sees every item sorted by name, adds a new one, and edits an
existing one. Six fields per item: name, unit, category, average piece weight,
daily usage, low threshold.

This is the first feature that reads and writes Firestore, so it also settles
how documents are shaped, how Firestore failures reach the user, and how the
offline cache behaves on web.

Nothing about stock is shown or calculated here. The catalogue is the identity
half of `items/{itemId}`; the pantry half arrives with feature 5.

## In scope

- `Item` entity, `ItemUnit` enum, the built-in category set, and field
  validation as pure Dart in `logic/`.
- A category picker offering the nine built-ins plus any category already in
  use, and an "Add category" path so a member can introduce a new one and
  select it again afterwards.
- `ItemRepository` over the `items` collection: watch, create, update.
- `DataFailure`, mapping Firestore error codes to user-facing text, mirroring
  how `AuthFailure` already handles auth.
- Catalogue list screen: loading, empty, error, and populated states, reachable
  from Home.
- Item form used for both create and edit, with validation and error feedback.
- Deleting an item from the edit form, behind a confirmation. Added after the
  spec was approved, at the user's explicit request; see the note under Out of
  scope for what that decision defers.
- Writing `stockAtBaseline` and `baselineDate` on create so every document
  satisfies the locked stock contract from the moment it exists.
- Enabling the multi-tab persistence manager on web, which resolves finding
  F-07 at the point it starts to matter.

## Out of scope

- ~~**Deleting an item.**~~ **Moved into scope after approval**, at the user's
  explicit request, as step 7. The original exclusion reasoned that a delete
  "would orphan the `itemId` references that features 3 and 4 depend on". That
  cost is not payable yet: features 3 and 4 do not exist, so no document
  references `itemId` today and a delete orphans nothing.
  **The deferred decision stands and belongs to feature 3:** once purchases
  reference an item, deleting it must either be blocked, soft-deleted, or
  allowed to leave historical purchases pointing at a missing item. Feature 3
  must settle that before it stores its first `itemId`. See Open questions.
- Anything about stock: current stock, running low, recount, adjustment,
  consumption log. All of that is features 5 and 6, and the item detail screen
  belongs to feature 5.
- Search, filter, grouping by category, and sort orders other than by name.
  Fifty to eighty items in one scrollable list does not need them yet.
- Creating items inline from the purchase screen. That is feature 3.
- Any change to `users/{userId}`, which is still unresolved. See Open questions.
- Repairing finding F-01. The Firebase project still accepts anonymous account
  creation, which is accepted and recorded, not fixed. It is a `/fix`, not
  something to bury here. See Notes for the AI.

## Build loop

`workflow.stepReview` is `every`, so stop for approval after each step.
`workflow.checkpointCommits` is `enabled`, so offer a checkpoint commit after a
step passes. `/complete` makes the final feature commit and merge.

## Build steps

- [x] **1. Item entity, enums, and validation as pure logic**
  Add `lib/features/items/logic/item_unit.dart`: `enum ItemUnit { kg, g, pcs, l }`
  with a `label` for display (`kg`, `g`, `pcs`, `L`) and a stable `key` for
  storage. Add `lib/features/items/logic/item_category.dart`:
  `enum ItemCategory` with exactly these stable keys and labels, in this order:
  `produce`/Produce, `dairy`/Dairy & Eggs, `meat_fish`/Meat & Fish,
  `bakery`/Bakery, `pantry`/Pantry & Dry Goods, `frozen`/Frozen,
  `drinks`/Drinks, `household`/Household & Cleaning, `other`/Other.
  These nine are built in, but the stored field is a plain string so a member can
  add their own. Add `categoryLabel(String stored)` returning the built-in label
  for a built-in key and the stored text verbatim otherwise, and
  `normalizeCategory(String input)` which trims and collapses internal
  whitespace. `availableCategories(Iterable<Item> items)` returns the nine
  built-ins plus every distinct non-built-in category already in use, sorted with
  the built-ins first.
  Add `lib/features/items/logic/item.dart`: an immutable `Item` with `id`,
  `name`, `unit`, `category`, `avgPieceWeight` (nullable), `dailyUsage`,
  `lowThreshold`, `stockAtBaseline`, `baselineDate`, using `equatable` and a
  `copyWith`.
  Add `lib/features/items/logic/item_validation.dart` with pure validators and
  `parseDecimal(String)`, which accepts both `.` and `,` as the decimal
  separator because the household reads prices with a decimal comma.
  No Flutter and no Firebase imports anywhere in `logic/`.
  - **Done when:** `flutter test` passes with unit tests covering every
    validator, both decimal separators, rejection of non-numeric and negative
    input, round-tripping every enum through its stable key, and the category
    helpers: a built-in key resolving to its label, a custom value returning
    itself, whitespace normalization, and `availableCategories` deduplicating
    case-insensitively without dropping built-ins; `flutter analyze` clean
    (tier 1).

- [x] **2. Firestore repository, failure mapping, and DI**
  Add `lib/core/data_failure.dart`: a sealed `DataFailure` plus
  `dataFailureFromCode(String)` mapping `permission-denied` to "You do not have
  access to this data", `unavailable` to "No connection. Check your network and
  try again", and anything else to "Something went wrong. Try again". Same
  contract as `AuthFailure`: no raw Firebase code or message ever reaches the
  user.
  Add `lib/features/items/data/item_repository.dart` (abstract) and
  `firestore_item_repository.dart`:
  `Stream<List<Item>> watchItems()` ordered by `name`,
  `Future<Result<void, DataFailure>> create(Item)`,
  `Future<Result<void, DataFailure>> update(Item)`.
  Add `item_dto.dart` with `toFirestore` and `fromFirestore` as pure map
  conversions so they are testable without Firestore. No `DocumentSnapshot`
  leaves `data/`. Register the repository with `injectable` and regenerate.
  In `lib/main.dart`, add `webPersistentTabManager:
  const WebPersistentMultipleTabManager()` to the Firestore `Settings`, which
  resolves F-07: without it only one browser tab holds the IndexedDB lease and a
  second tab silently runs without persistence.
  - Check the exact `cloud_firestore` 6.10 name and import path for the
    multi-tab manager before writing it rather than assuming.
  - **Done when:** `flutter test` passes with unit tests for every
    `DataFailure` code and for DTO round-tripping including a null
    `avgPieceWeight`; `dart run build_runner build` regenerates the DI config
    with `ItemRepository` registered; `flutter analyze` clean (tier 1).

- [x] **3. Items cubit with sealed states**
  Add `lib/features/items/presentation/items_state.dart` with sealed
  `ItemsLoading`, `ItemsEmpty`, `ItemsLoaded(List<Item>)`,
  `ItemsFailure(DataFailure)`, and `items_cubit.dart` taking `ItemRepository`
  through its constructor. It subscribes to `watchItems()` on creation, cancels
  the subscription in `close()`, and handles the stream's `onError` by emitting
  `ItemsFailure`, which is the mistake finding F-03 records against
  `AuthCubit`; do not repeat it here.
  Add `save(Item)` covering both create and update, returning the `Result` so
  the form can react.
  - **Done when:** `flutter test` passes with cubit tests against a hand-written
    fake repository covering the empty stream, a populated stream, a stream
    error, save success, save failure, and subscription cleanup on `close()`;
    `flutter analyze` clean (tier 1).

- [x] **4. Catalogue list screen, reachable from Home**
  Add `lib/features/items/presentation/item_list_page.dart`. States: a centred
  progress indicator while loading; an empty state that explains the catalogue
  is empty and offers the same add action; the mapped message plus a retry for
  `ItemsFailure`; otherwise a scrolling list showing each item's name with its
  category label and unit, one column on phone and constrained to a readable
  width on a wide window. Long names truncate with an ellipsis rather than
  overflowing.
  Add an app bar action on `HomePage` that pushes the catalogue with
  `Navigator.push`. No router package: three screens do not justify one, and
  adding it would be a dependency without a current requirement.
  - **Done when:** `flutter test` passes with widget tests for the loading,
    empty, failure and populated states and for the Home action pushing the
    page; `flutter analyze` clean (tier 1).

- [x] **5. Item form, creating a new item**
  Add `item_form_page.dart`, pushed from the list's add action. Fields: name
  (text, required, trimmed); unit (dropdown, defaults to `kg` as the data model
  specifies); category (dropdown, no preselected value, required, listing the nine
  built-ins plus every category already in use, with a final "Add category"
  entry that reveals a text field); average piece
  weight (optional decimal, must be greater than zero when present); daily usage
  (decimal, required, zero or more, defaults to `0` because non-staples use `0`);
  low threshold (decimal, required, zero or more).
  A new category is trimmed and whitespace-collapsed, rejected when empty, and
  when it matches an existing option case-insensitively the existing one is
  selected instead of creating a near-duplicate. That is the whole defence
  against the fragmentation the overview warns about, so it is not optional.
  Every field is labelled, invalid fields show `errorText` tied to that field,
  the save button shows progress and is disabled while saving, a failed save
  shows the mapped `DataFailure` message where a screen reader announces it, and
  editing a field clears the previous failure. Dispose every controller and
  focus node.
  On save, set `stockAtBaseline: 0` and `baselineDate` to the server timestamp,
  so the document satisfies the locked stock contract from creation. A new item
  has no stock until a purchase restocks it, and `0 - (dailyUsage * days)`
  yields that correctly.
  **Do not await the Firestore write before navigating back.** With persistence
  on, a write's future only completes when the server acknowledges it, so
  awaiting it offline hangs forever. The local cache applies the write
  immediately and the stream emits, which is what the list should react to.
  - **Done when:** `flutter test` passes with widget tests covering an empty
    submit showing every required field's error, a rejected decimal, a failed
    save showing the mapped message, the disabled saving state, and that a
    created document carries `stockAtBaseline: 0` and a `baselineDate`;
    `flutter analyze` clean (tier 1).

- [x] **6. Editing an existing item**
  Tapping a row in the list opens the same form prefilled from that `Item`, and
  saving calls `update` rather than `create`.
  **The update must not write `stockAtBaseline` or `baselineDate`.** Those
  belong to feature 5, and rewriting them here would silently reset an item's
  stock every time someone corrected its name.
  - **Done when**, on one mobile platform and on Chrome: adding an item makes it
    appear in the list without a manual refresh; editing its name and saving
    shows the new name; reopening the app still shows both changes; the run log
    is clean with no overflow stripes (tier 3). Plus `flutter test` passing with
    widget tests for the prefilled form and for update leaving the two baseline
    fields untouched.

- [x] **7. Deleting an item**
  Added after approval at the user's request. Add
  `Future<Result<void, DataFailure>> delete(Item)` to `ItemRepository` and
  `FirestoreItemRepository`, and `delete(Item)` to `ItemsCubit`, both mirroring
  the existing write contract: mapped `DataFailure`, never a raw Firebase code.
  Add a delete action to the edit form's app bar, shown only when editing, and
  guard it with a confirmation dialog naming the item. Deleting is the one
  destructive operation in this feature and it cannot be undone, so it is never
  a single unconfirmed tap.
  The list needs no change: the stream emits without the deleted document and
  the existing empty state covers deleting the last item.
  - **Done when:** `flutter test` passes with tests for the cubit delete paths
    (success, mapped failure, unexpected throw) and widget tests for the action
    being absent when creating, the confirmation appearing, cancelling leaving
    the item alone, and confirming removing it and closing the form;
    `flutter analyze` clean (tier 1).

## Files / areas

```
lib/core/data_failure.dart                             new
lib/features/items/logic/item.dart                     new
lib/features/items/logic/item_unit.dart                new
lib/features/items/logic/item_category.dart            new
lib/features/items/logic/item_validation.dart          new
lib/features/items/data/item_repository.dart           new
lib/features/items/data/firestore_item_repository.dart new
lib/features/items/data/item_dto.dart                  new
lib/features/items/presentation/items_state.dart       new
lib/features/items/presentation/items_cubit.dart       new
lib/features/items/presentation/item_list_page.dart    new
lib/features/items/presentation/item_form_page.dart    new
lib/features/home/presentation/home_page.dart          modified, catalogue action
lib/main.dart                                          modified, web tab manager
lib/core/di/injection.config.dart                      regenerated
test/features/items/...                                new, mirroring lib
```

## Data / contracts

**Collection `items`, document id:** Firestore auto-generated. `Item.id` carries
it; it is never written into the document body.

| Field | Type | Rule |
| --- | --- | --- |
| `name` | string | required, trimmed, non-empty |
| `unit` | string | stable enum key, one of `kg`, `g`, `pcs`, `l`, default `kg` |
| `category` | string | a built-in key from the nine above, or a member-supplied label, trimmed and whitespace-collapsed; required |
| `avgPieceWeight` | double or null | greater than zero when present |
| `dailyUsage` | double | zero or more, `0` for non-staples |
| `lowThreshold` | double | zero or more |
| `stockAtBaseline` | double | written as `0` on create, never touched on update |
| `baselineDate` | timestamp | server timestamp on create, never touched on update |

**Stored keys, not labels, for the built-ins.** `category: "meat_fish"`, never
`"Meat & Fish"`, so relabelling a built-in is a code change with no data
migration. The same holds for `unit`. A member-added category has no separate
key: its stored value is the text they typed, and that same text is its label.
Resolution is therefore "built-in key if it matches one, otherwise show the
stored string verbatim".

**A category exists only while an item uses it.** The picker is derived from the
items already streamed, so nothing new is stored and no seventh collection is
added to the six the overview documents. The consequence is that a custom
category with no items left in it disappears from the list. That is the price of
not adding a collection, and it is recoverable by typing it again.

**The locked stock contract** from the overview is
`currentStock = stockAtBaseline - (dailyUsage * daysSince(baselineDate))`.
Feature 2 does not compute it, but every document it creates must be a valid
input to it, which is why create writes the baseline pair.

**Trusted actor:** `request.auth.uid`, through the deployed Firestore rules. All
signed-in members read and write every item, with no roles and no ownership.
That is the stated design, not an omission.

**Failure surface:** `FirebaseException.code` becomes a sealed `DataFailure`.
Presentation renders only mapped English text. A raw code, message or stack
trace never reaches the user.

## Testing

`flutter test` is the gate and is green at 31 tests. Every step must keep it
green.

- Unit, `logic/`: validators, both decimal separators, enum key round-trips.
- Unit, `data/`: `DataFailure` mapping, DTO round-trip including a null
  `avgPieceWeight` and the baseline fields.
- Unit, `presentation/`: cubit state sequences against a hand-written fake
  repository, including the stream-error path and `close()` cleanup.
- Widget: list states (loading, empty, failure, populated), Home navigation,
  form validation, saving state, failed save, prefilled edit.
- No new test dependency. `flutter_test` and hand-written fakes cover all of it.

**Platform matrix.** Per the Device verification policy in `AGENTS.md`, this is
substantial UI work, so one mobile platform is exercised and the others assumed.
Web is exercised as well, but only for step 6, because Firestore persistence on
web is a different implementation (IndexedDB and the tab manager changed in step
2) and assuming it from a mobile pass would be assuming across the exact
divergence the policy says to escalate on.

| Done-when | Mobile (Android or iOS) | Web | Other mobile |
| --- | --- | --- | --- |
| Item appears in the list after create | required | required | assumed |
| Edit persists and survives relaunch | required | required | assumed |
| Clean run log, no overflow | required | required | assumed |
| List, empty, failure states render | tier 1 widget tests, all platforms | | |

## Notes for the AI

- **Finding F-01 is live.** The Firebase project still accepts anonymous
  `accounts:signUp`, so any stranger can obtain a session that these rules trust
  completely. This feature is the first to store real household data, which is
  what makes it matter. It is accepted and out of scope here; do not quietly fix
  it, and do not pretend it is fixed.
- Do not repeat F-03: give every stream subscription an `onError` that emits a
  renderable state.
- Do not repeat F-04: when catching, bind the error and stack trace and report
  through `addError`, then emit the mapped message.
- Use `BlocProvider.value` for an externally owned cubit, per F-06.
- No router package, no new dependency of any kind.
- `logic/` imports neither Flutter nor Firebase. `data/` is the only place
  `cloud_firestore` appears.
- Sealed states with exhaustive `switch`, never a class with nullable fields and
  an `isLoading` flag.
- Never `!` a nullable you have not checked. `avgPieceWeight` is genuinely
  nullable and must be handled, not asserted away.
- Keep Home otherwise untouched. Its real layout belongs to features 6, 8 and 9.

## Amendments after approval

Recorded so the archive shows what changed after the spec was reviewed, and on
whose authority.

- **2026-09-21, by the user: delete was added as step 7.** The approved spec
  excluded it. The user asked for it explicitly before completion. The original
  exclusion reasoned about orphaning `itemId`; that cost is not payable yet
  because features 3 and 4 do not exist. The deferred decision is carried into
  Open questions rather than dropped.
- **2026-09-21, by the user: independent review waived.** `qualityGates.regular
  .independentReview` is `when-sensitive`, and this work was read as selecting
  it: first feature to persist shared household data, authorization resting
  entirely on the deployed Firestore rules, fourteen new files. The user stated
  no further review was needed. No independent review was run and no receipt
  exists.
- **2026-09-21: web done-whens were verified by the user, not by the agent.**
  The agent's own web evidence reached build-and-boot only: the app compiles,
  loads and reports zero console errors or warnings, which proves the
  `WebPersistentMultipleTabManager` setting is accepted at startup. It does not
  prove create, edit, delete, persistence across a reload, or that two tabs
  share the IndexedDB lease. The agent was blocked at the sign-in screen with no
  credentials; the user stated they had tested everything. See Verification.

## Verification

| Done-when | Android | Web | iOS |
| --- | --- | --- | --- |
| Item appears in the list after create | pass (tier 3) | user-reported | assumed |
| Edit persists and survives relaunch | pass (tier 3) | user-reported | assumed |
| Delete removes it behind a confirmation | pass (tier 3) | user-reported | assumed |
| Clean run log, no overflow stripes | pass (tier 3) | pass, zero console errors | assumed |
| List, empty, failure, form states | pass (tier 1, 132 tests) | pass (tier 1) | pass (tier 1) |

- **Android**, `sdk gphone16k arm64`, Android 17 (API 37), debug, full rebuild
  and install. Screenshots captured for launch, empty state, form, category
  menu, live field validation, create, prefilled edit, edit result, cold
  relaunch, and delete.
- **Web**, Chromium via Playwright at `127.0.0.1:8080`, `flutter run -d
  web-server`. Build and load only, zero console errors or warnings.
- **iOS** was not run. ML Kit has no arm64 simulator slices, so a physical
  iPhone is the only iOS target, and it was not exercised. Recorded as assumed,
  never as a pass.
- `flutter analyze` clean and `flutter test` green at 132 tests.

## Open questions

- **Editing `dailyUsage` silently rewrites history.** Because current stock is
  derived from the baseline pair, raising `dailyUsage` retroactively reduces the
  computed stock for the whole period since `baselineDate`. Feature 2 is
  unaffected, since it displays no stock and every item starts at
  `stockAtBaseline: 0`. Feature 5 must decide whether changing `dailyUsage`
  rebaselines the item, which is the only place the question becomes visible.
  Recorded here because feature 2 is what makes the field editable.
- **What does deleting an item mean once purchases reference it?** Step 7 added
  a hard delete with no tombstone. Nothing references `itemId` today, so nothing
  is orphaned. Feature 3 stores the first `itemId` and must decide before it
  does: block the delete while purchases reference the item, soft-delete it so
  history still resolves a name, or accept purchases pointing at a missing item.
  This is the decision the original out-of-scope note deferred, and it is now
  load-bearing for feature 3.
- **Who creates `users/{userId}`?** Carried forward unresolved from feature 1.
  Feature 2 touches no user document, so it stays blocked only for feature 3.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":22638,"specSha256":"e741ecdf0397c5a68c5ede7ef263a6ab01cdb4eb1cda13eb1faf98bfcea62722","branch":"refs/heads/feature/item-catalogue","head":"791f782565e7f7038a0b24bdd082811c60f05843","baseRef":"refs/heads/main","baseCommit":"a6a37041f348a0fd501f62b23105c9b025899ef9","sourceTree":"4a8da8a6a0fd65754f11ecff4fee99d62548b461","absentOptional":[]} -->
