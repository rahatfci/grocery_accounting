# Feature: Record a purchase

**From build-plan:** feature 3
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/record-a-purchase`

## Goal

Give the household the screen the rest of the app is built around: one form that
records what a shop trip cost, who paid, and what came home in the bags.
Committing it writes the spend and restocks every item on it in a single atomic
write, so the pantry is correct the moment the purchase is saved. Feature 10 only
prefills this screen. This is where a purchase is confirmed and committed, and
nothing reaches the pantry without passing through it.

## In scope

- A `Record a purchase` screen, reached from Home: date, shop, total, payer, and
  a list of lines.
- A line picks an existing catalogue item or creates a new item inline, with a
  quantity in a unit convertible to the item's unit, and a line total.
- Payer chosen from household members, defaulting to the signed-in member.
- Mirroring the Auth account into `users/{userId}` on every successful sign in.
  This is what makes a payer list possible, and it is the question features 1 and
  2 carried forward unresolved.
- Committing writes `purchases/{id}` and every affected `items/{id}` baseline in
  one Firestore `WriteBatch`, so the spend and the restock cannot land apart.
- Restocking through the locked stock contract: a fresh `stockAtBaseline` and
  `baselineDate` pair per purchased item, never a stored live number.
- Blocking an item delete while a purchase references it, the decision feature 2
  deferred, using a new `itemIds` array on each purchase document.
- Loading, empty, invalid, refused and unexpected-error behaviour on the screen.

## Out of scope

- Receipt photography, upload and OCR (features 9 and 10). `receiptImagePath` is
  written as `null` and `source` as `manual`.
- Listing, reopening, editing or deleting a past purchase, and every report
  (features 4 and 12). This feature writes purchases and never lists them.
- `consumptionEvents`. See Open questions.
- The shopping list reacting to a confirmed purchase (feature 8).
- Showing current stock, the daily decrease, recount and adjustment (feature 5),
  and the running-low list (feature 6).
- Shop name autocomplete, the alias table and learned mapping (feature 11).
- Editing a member's `displayName`, any account management UI, and any change to
  `firestore.rules` or `storage.rules`.
- Splitting or settling costs. The equal share in the overview is a feature 4
  report, not a stored balance.

## Build loop

`workflow.stepReview` is `every`, so stop for approval after each step.
`workflow.checkpointCommits` is `enabled`, so offer a checkpoint commit after a
step passes. `/complete` makes the final feature commit and merge.

## Build steps

- [x] **Step 1 - Purchase domain, unit conversion and the stock formula** -
  create `lib/features/purchases/logic/`: `purchase.dart` (`Purchase` and
  `PurchaseLine`), `purchase_source.dart` (`manual` and `scanned` with stored
  keys and a `fromKey` fallback, mirroring `ItemUnit`), `purchase_draft.dart`
  (`PurchaseDraft`, `PurchaseDraftLine`, and the per-item aggregation of
  restock quantities), `purchase_validation.dart`, and `money.dart`
  (`formatEuro`, `formatPurchaseDate`). Create
  `lib/features/items/logic/stock.dart` with `currentStock` and
  `restockedBaseline`, and `quantity_conversion.dart` with `convertToItemUnit`
  and `unitsFor`. Pure Dart, no Flutter and no Firebase imports. Reuse
  `parseDecimal` from `items/logic/item_validation.dart` rather than writing a
  second parser.
  *Done when:* `flutter test` is green with new unit tests covering every
  conversion (`kg` to `g`, `g` to `kg`, `pcs` through `avgPieceWeight`, and each
  unconvertible pair returning null), `currentStock` at, before and long after
  `baselineDate`, the clamp at zero on restock, two lines for one item summing
  into one baseline, every validation rule including the two-decimal money rule
  and both decimal separators, and EUR and `dd/MM/yyyy` formatting.
  `flutter analyze` is clean. (tier 1)

- [x] **Step 2 - Household members and the sign-in mirror** - create
  `lib/features/members/`: `logic/household_member.dart`,
  `data/member_repository.dart`, `data/member_dto.dart` and
  `data/firestore_member_repository.dart` registered with
  `@LazySingleton(as: MemberRepository)`. `watchMembers()` streams `users`
  ordered by `displayName` and maps errors to `DataFailure` exactly as
  `FirestoreItemRepository` does. `upsertCurrentMember(AppUser)` writes the
  mirror document. Provide it from `main.dart` through `app.dart` as a
  `RepositoryProvider`, call the upsert from `AuthGate` when the state becomes
  `AuthSignedIn`, and re-run `build_runner` for `injection.config.dart`.
  *Done when:* `flutter test` is green with a DTO round-trip test, a failure
  mapping test, and an `AuthGate` widget test asserting exactly one upsert per
  sign in, none while signed out, and that a refused upsert leaves the app
  usable rather than surfacing an error. The live document is proven in step 8,
  not here. (tier 1)

- [x] **Step 3 - Purchase repository, DTO and the batch commit** - create
  `lib/features/purchases/data/`: `purchase_dto.dart`,
  `purchase_repository.dart` and `firestore_purchase_repository.dart`.
  `commit()` builds one `WriteBatch` holding the `purchases` document, a `set`
  for each inline-created item, and an `update` of `stockAtBaseline` and
  `baselineDate` for each existing item. `isItemReferenced(itemId)` queries
  `purchases` with `arrayContains` on `itemIds`. Add an optional
  `stockAtBaseline` parameter to `newItemToFirestore` in
  `items/data/item_dto.dart` so an inline item starts at the quantity just
  bought instead of zero.
  *Done when:* `flutter test` is green with DTO round-trip tests covering lines,
  `itemIds`, a null `receiptImagePath`, an unknown `source` key, a missing
  `lines` field and wrongly typed values, plus failure mapping tests; the
  existing `item_dto_test.dart` still passes unchanged on the default baseline
  of `0.0`. Analyze clean. (tier 1)

- [x] **Step 4 - RecordPurchaseCubit** - create
  `lib/features/purchases/presentation/record_purchase_cubit.dart` and
  `record_purchase_state.dart`. It subscribes to `watchItems()` and
  `watchMembers()`, holds the draft, exposes the date, shop, total and payer
  setters plus line add, edit and remove, and `commit()`. The payer list is the
  members stream unioned with the signed-in member, so the current user is
  always selectable even before the mirror write has synced. Sealed states, as
  everywhere else in this codebase.
  *Done when:* cubit tests against hand-written fakes cover loading until both
  streams have reported, later item and member updates, a stream failure and
  `retry()`, every draft edit, two lines for one item aggregating, a commit
  refused by each validation rule, a successful commit, a refused commit mapped
  to a `DataFailure`, and `close()` cancelling both subscriptions. (tier 1)

- [x] **Step 5 - The Record a purchase screen** - create
  `record_purchase_page.dart`: header fields (date picker, shop, total, payer),
  the line list, an add and edit line sheet with an item picker and a `New item`
  option, per-line remove, the lines-versus-total hint, and the commit button.
  Use the same 600 ms refusal window as `ItemFormPage`, because with persistence
  on an offline write never completes. Errors render through `FailureMessage`.
  Every field carries a label, and each validation error is associated with its
  field rather than announced alone.
  *Done when:* widget tests cover loading, stream failure and retry, an empty
  catalogue still allowing an inline item, each validation error, adding,
  editing and removing a line, the saving state, a refused commit staying on the
  screen with the mapped message, and a successful commit popping the screen.
  Nothing overflows at 400 px width. (tier 1)

- [x] **Step 6 - Home entry point** - replace Home's `Nothing here yet`
  placeholder with a primary `Record a purchase` action, keeping the catalogue
  and sign-out actions where they are. Update `home_page_test.dart`.
  *Done when:* a widget test proves the tap pushes the screen, and the existing
  Home tests still pass. (tier 1)

- [x] **Step 7 - Block deleting an item a purchase references** - add
  `ReferenceInUse` to `core/data_failure.dart`, give `ItemsCubit` the
  `PurchaseRepository`, and check before the confirm dialog in `ItemFormPage`:
  a referenced item shows the message and is never offered the dialog, and a
  check that cannot be completed refuses the delete and says so rather than
  deleting unverified. Update `ItemListPage`, `app.dart`, `main.dart`, and the
  items tests and fakes.
  *Done when:* `flutter test` is green with new tests for an allowed delete, a
  blocked delete and an unverifiable check, every existing items test still
  passes, and deleting an unreferenced item still closes the form. (tier 1)

- [x] **Step 8 - Device pass** - run the whole flow on one mobile target per the
  device verification policy: sign in, record a purchase with one existing item
  and one inline-created item, then try to delete one of those items from the
  catalogue. Confirm in the Firebase console that `purchases/{id}` carries the
  lines and `itemIds`, that both items' `stockAtBaseline` and `baselineDate`
  moved, and that `users/{uid}` exists.
  *Done when:* the platform matrix below is filled in with the tier actually
  used, the run log shows no exception and no overflow stripes, the commit
  button is reachable with the keyboard up, and the blocked delete shows its
  message. (tier 3)

## Files / areas

**New**

- `lib/features/purchases/logic/purchase.dart`, `purchase_source.dart`,
  `purchase_draft.dart`, `purchase_validation.dart`,
  `quantity_conversion.dart`, `money.dart`
- `lib/features/purchases/data/purchase_dto.dart`, `purchase_repository.dart`,
  `firestore_purchase_repository.dart`
- `lib/features/purchases/presentation/record_purchase_cubit.dart`,
  `record_purchase_state.dart`, `record_purchase_page.dart`
- `lib/features/members/logic/household_member.dart`,
  `data/member_repository.dart`, `data/member_dto.dart`,
  `data/firestore_member_repository.dart`
- `lib/features/items/logic/stock.dart`
- Mirrored test files under `test/`, plus `test/features/purchases/fake_purchase_repository.dart`
  and `test/features/members/fake_member_repository.dart`

**Changed**

- `lib/core/data_failure.dart` - add `ReferenceInUse`
- `lib/features/items/data/item_dto.dart` - optional `stockAtBaseline` on `newItemToFirestore`
- `lib/features/items/presentation/items_cubit.dart` - the delete guard
- `lib/features/items/presentation/item_form_page.dart` - check before the confirm dialog
- `lib/features/items/presentation/item_list_page.dart` - build the cubit with both repositories
- `lib/features/home/presentation/home_page.dart` - the entry point
- `lib/features/auth/presentation/auth_gate.dart` - the sign-in mirror write
- `lib/app.dart`, `lib/main.dart` - provide the two new repositories
- `lib/core/di/injection.config.dart` - regenerated, never edited by hand
- `test/features/items/fake_item_repository.dart` and the items tests that construct `ItemsCubit`

**Untouched:** `firestore.rules`, `storage.rules`, `pubspec.yaml`. `intl` is
already a dependency and no new package is needed.

## Data / contracts

**`purchases/{purchaseId}`** - written by this feature, read by features 4 and 12.

| Field | Type | Rule |
| --- | --- | --- |
| `date` | Timestamp | The day the member picked, at local midnight. Defaults to today, never in the future. |
| `shopName` | string | Required, trimmed, free text. No enum: the overview lists shops as usage context, not a fixed set. |
| `total` | double | EUR, greater than zero, at most two decimals. The receipt total, authoritative for reports. |
| `paidByUserId` | string | A `users/{userId}` id. Required, defaults to the signed-in member. |
| `receiptImagePath` | string, nullable | Always `null` in this feature. |
| `source` | string | Always `manual` here. Stored keys `manual` and `scanned`. |
| `lines` | array of map | May be empty. |
| `itemIds` | array of string | **New field, not yet in the plan's data model.** The distinct `itemId`s in `lines`, so the delete guard can query them. Firestore cannot query a field inside an array of maps, which is why it is denormalized. |

**PurchaseLine** (embedded map): `itemId` (string, nullable in the contract,
always set by this feature), `rawText` (string, the item name as picked or
typed, because a manual line has no receipt wording), `quantity` (double,
greater than zero), `unit` (the same `ItemUnit` keys as items: `kg`, `g`, `pcs`,
`l`), `lineTotal` (double, zero or more, at most two decimals).

**An empty `lines` array is valid.** The problem statement is accounting first,
inventory second, so a purchase that records only the spend is legitimate and
simply restocks nothing. Committing with lines requires every line to be
matched to an item; the nullable `itemId` in the contract is kept for feature 10
and is never null here.

**Restock, from the locked stock contract:**

```
currentStock = stockAtBaseline - dailyUsage * daysSince(baselineDate)
newBaseline  = max(0, currentStock) + quantity converted to the item's unit
```

- `daysSince` is fractional elapsed days, floored at zero for a future
  `baselineDate`. `currentStock` itself is never clamped, so a staple past empty
  reads negative honestly; only the restock clamps, otherwise buying 1 kg three
  days after running out would credit less than a kilo.
- `baselineDate` is written as a client timestamp of the commit moment, not
  `FieldValue.serverTimestamp()`. Offline a server timestamp resolves at sync
  time, which could be days after the number it is paired with, and the pair has
  to stay internally consistent.
- The restock baselines at commit time even when the purchase date is older, so
  backdating a purchase does not replay consumption. Feature 5 owns that if it
  ever matters.
- Conversion uses `avgPieceWeight`, which is expressed in the item's own unit:
  `pcs` to `kg` or `g` is `quantity * avgPieceWeight`. `pcs` and `l` items accept
  only their own unit. The line unit picker offers only convertible units, so an
  unconvertible pair cannot be entered; validation still rejects it, and commit
  is blocked rather than silently skipping a line.
- Two lines for the same item are summed into one baseline update before the
  batch is built. A batch must not write the same document twice.

**`users/{userId}`** - `displayName` (string), `email` (string), `createdAt`
(timestamp). Written on each successful sign in: if the document is absent, a
full write with `FieldValue.serverTimestamp()` for `createdAt`; if present, a
merge of `displayName` and `email` only, so `createdAt` survives. The document id
is the Firebase Auth uid. `displayName` is the email local part, because the
Firebase console creates accounts with no display name and no feature edits it.

**Atomicity and trust.** The purchase document, the inline item creates and the
item baseline updates go in one `WriteBatch`. A transaction is wrong here: it
needs a server round trip and fails offline, and offline capture is a stated
requirement. Inline items get client-generated document ids from `doc()`, so no
network call is needed before the batch and an abandoned purchase leaves no
stray item. The trusted actor is `request.auth.uid`; there are no roles, no
ownership and no tenant scope, and any signed-in member may record a purchase
paid by any member. `firestore.rules` already covers this and does not change.
Conflict behaviour is Firestore last write wins, as the usage model states: two
members restocking the same item at once leaves the later write's baseline.

**The delete guard is best effort offline.** `isItemReferenced` reads from the
local cache when there is no connection, so it can miss a purchase this device
has never seen. A check that fails or cannot reach the server refuses the
delete rather than allowing an unverified destructive write.

## Testing

`flutter test` is the gate, green at 132 tests on `main` at `75c7744` with
`flutter analyze` clean. Every step keeps both that way.

- Unit, `logic/`: unit conversion including every unconvertible pair, the stock
  formula and the restock clamp, per-item aggregation, all validation rules
  (required fields, the two-decimal money rule, both decimal separators, a
  future date, an unmatched line), EUR and `dd/MM/yyyy` formatting.
- Unit, `data/`: purchase DTO round-trip including `itemIds`, an empty `lines`
  array, a null `receiptImagePath`, an unknown `source` key and wrongly typed
  fields; `DataFailure` mapping; the unchanged default in `newItemToFirestore`.
- Unit, `presentation/`: `RecordPurchaseCubit` state sequences against fakes,
  including both stream failures and `close()` cleanup, and `ItemsCubit`'s three
  delete outcomes.
- Widget: screen states (loading, failure, empty catalogue, populated), line add,
  edit and remove, validation errors, saving, refused commit, successful commit,
  Home navigation, and the blocked delete message on `ItemFormPage`.
- No new test dependency. `flutter_test` and hand-written fakes cover all of it.

**Platform matrix.** Per the device verification policy in `AGENTS.md`, this is
substantial UI work in identical Dart with no plugin, permission, deep link or
system back surface, so one mobile platform is exercised and the others assumed.
The keyboard inset check is done on that same platform rather than escalating,
because this is a form of the same shape as feature 2's, which was already
proven there.

**Exercised on iOS**, on Rahat's iPhone, iOS 26.5, debug build installed over
the cable on 2026-09-22 (`flutter run -d 00008140-0006183E3EDB801C`, Xcode build
27.9s). Android and web were not run and are recorded as assumed, never as a
pass.

| Done-when | iOS (physical) | Web | Android |
| --- | --- | --- | --- |
| A committed purchase appears in `purchases` with its lines and `itemIds` | pass (t3) | assumed | assumed |
| Both items' `stockAtBaseline` and `baselineDate` move in the same commit | pass (t3) | assumed | assumed |
| An inline-created item exists with the bought quantity as its baseline | pass (t3) | assumed | assumed |
| `users/{uid}` exists after sign in and the payer picker lists it | pass (t3) | assumed | assumed |
| Deleting a referenced item is blocked with its message | pass (t3) | assumed | assumed |
| Commit button reachable with the keyboard up, no overflow, clean log | pass (t3) | assumed | assumed |
| Screen states, validation and cubit behaviour | tier 1 unit and widget tests, all platforms | | |

**Who observed what.** The build, install and run log were mine: clean from
launch through the whole flow, with no exception, no overflow stripe and no
Firestore warning. The `Lost connection to device` line at the end of the log is
the run being stopped from this session, not a crash. The on-screen steps and the
four Firestore documents were confirmed by the user in the app and the Firebase
console; I did not read the console myself.

An Android emulator was available (`emulator-5554`, API 37) and deliberately not
used: per the device verification policy this is substantial UI work in identical
Dart, with no plugin, permission, deep link or system back surface, so one mobile
platform is exercised and the others assumed.

## Quality gates

- `flutter test`: 284 passed. `flutter analyze`: clean. Run on 2026-09-22, after
  the last step.
- Audit, check and try guide are `manual` in `blueprint/config.json` and were not
  run. The device evidence above came from build step 8 rather than from
  `/check`.
- **Independent review was selected and waived.** `independentReview` is
  `when-sensitive`, and this work is sensitive: it writes a new shared
  collection, mutates item baselines, mirrors user identity into `users/{uid}`,
  and changes what deleting an item does. The gate was offered with the
  checkpoint commit it requires, and the user chose on 2026-09-22 to skip it and
  go straight to `/complete`. No review was requested, so
  `blueprint/context/review.md` is empty rather than pending. Nothing in this
  feature has been read by a second reviewer.

## Notes for the AI

- `logic/` stays pure Dart. No `package:flutter`, no `cloud_firestore`, no
  `DateTime.now()` inside a function under test: pass `now` in, so the stock math
  is deterministic.
- Reuse before adding: `parseDecimal`, `formatDecimal`, `validateRequiredAmount`
  and `availableCategories` from the items feature, `Result`, `DataFailure`,
  `FailureMessage`, and the `ItemUnit` keys. Do not write a second decimal
  parser or a second failure type.
- Bloc only. No second state management solution, no router package: three
  screens still do not justify one.
- No widget reaches into `getIt`. `main.dart` resolves, `app.dart` provides,
  screens read from the provider, exactly as the catalogue does.
- The 600 ms refusal window exists because an offline write never completes. Do
  not await a commit indefinitely and do not block navigation on it.
- A raw `FirebaseException` code, message or stack trace never reaches the user.
  `ReferenceInUse` carries text written here, never text from Firebase.
- Inline item creation writes `dailyUsage: 0`, `lowThreshold: 0` and a null
  `avgPieceWeight`, so a new item is a valid input to the stock formula from its
  first write. It is not a place to invent defaults.
- `dispose()` every controller on the screen and cancel both subscriptions in
  the cubit.
- Do not touch `injection.config.dart` by hand. Run
  `dart run build_runner build --delete-conflicting-outputs`.
- No em dashes in code comments, commits or docs.

## Open questions

None of these block implementation. Each is recorded so a later feature does not
have to rediscover it.

- **`itemIds` is not in the plan's data model.** The blocking delete guard the
  user chose on 2026-09-21 needs it, and `project-plan.md` should gain the field
  with `/overview` re-run afterwards, so the overview stays the source of truth.
- **This feature writes no `consumptionEvents`.** Its `type` enum is
  `consumed | adjustment | recount`, and none of those describes a restock;
  adding a fourth value would invent a contract feature 5 owns. The purchase
  document is already the record of what came in. The overview's own open
  question, that the collection has no reader, is still open.
- **`displayName` has no editor.** It is derived from the email local part, so a
  member who wants a different name in feature 4's reports has no way to set one
  yet.
- **Item delete is guarded, not referentially safe.** Offline the check reads the
  local cache, and nothing stops a member deleting an item on one device while
  another records a purchase for it. Feature 4 should render a line from
  `rawText` when `itemId` resolves to nothing.
- **A backdated purchase restocks from now.** The purchase date is recorded
  faithfully for reports, but the stock baseline is stamped at commit time.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":23148,"specSha256":"6180683915a3d3ffdbec1a4223966bf575f59fa775845d3a4d8e25bee4583736","branch":"refs/heads/feature/record-a-purchase","head":"75c7744a665df55ae690b7a872c04f9c62f5ed19","baseRef":"refs/heads/main","baseCommit":"75c7744a665df55ae690b7a872c04f9c62f5ed19","sourceTree":"d4f57b5b34380be59d3de4c36110f890c8e123d9","absentOptional":[]} -->
