# Feature: Spending reports

**From build-plan:** feature 4
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/spending-reports`

## Goal

Answer the question the household could not answer before the app existed: what
did we spend this month, who paid it, on what, and where. One screen, one level
down from Home, reading the `purchases` documents feature 3 writes. It compares
each member's spend against an equal share and this month against last, without
becoming a settle-up ledger, which the plan excludes by name.

Reports are read occasionally and sitting down. Web and tablet are the surface
that matters most here, so the layout uses the width when it has it.

## In scope

- A `Spending` screen reached from Home's app bar, alongside Catalogue.
- A month frame: previous and next, defaulting to the current month, never
  paging into a future month.
- The month total, taken from `purchase.total`.
- By person: every household member's paid total, the equal share, and the
  difference, with the divisor named on screen.
- By category: line totals grouped by the purchased item's category, with a
  bucket for lines whose item cannot be resolved and a remainder row for
  whatever the lines do not account for.
- By shop: month totals grouped by shop name, matched case-insensitively.
- Month to month: the previous month's total and the change.
- Loading, empty month, and failure with retry, all inside the month frame so
  the month can still be changed.
- Responsive: one column on a phone, two columns from 720 logical pixels.

## Out of scope

- A settle-up ledger, balances, or who owes whom. An explicit non-requirement.
- Budgets, targets, or spending alerts. Also an explicit non-requirement.
- Charts. The plan asks for totals, and a row with an amount is a total.
- Date ranges other than a calendar month, and any year or all-time view.
- Drilling into a row to list the individual purchases behind it.
- Editing or deleting a purchase from this screen. Nothing here writes.
- Category management, renaming, or merging. `items.category` stays a free
  string, as the overview's own open question records.
- A `displayName` editor. Report names are whatever feature 3 mirrored.
- CSV export (feature 12), stock or pantry figures (features 5 to 7), and the
  large-screen pass (feature 13) beyond the two-column layout specified here.

## Build loop

`workflow.stepReview` is `every`, so stop after each step with the diff, a short
explanation, and the checks that were run. `workflow.checkpointCommits` is
`enabled`, so offer a checkpoint commit after an approved step. `/complete`
makes the final feature commit and merge.

**Branch base.** Feature 3 is committed on `feature/record-a-purchase` but has
not been merged: `main` is still at `75c7744 feat: item catalogue`, one commit
behind, and the feature 3 archive reads `Status: verified`. Every file this
feature reads from, `Purchase`, `PurchaseLine`, `PurchaseRepository` and
`purchaseFromFirestore`, exists only on that unmerged branch. Cut
`feature/spending-reports` from a base that contains `f7529c8`, not from
today's `main`. The clean route is to finish feature 3 with `/complete` first,
which fast-forwards `main`; branching from `feature/record-a-purchase` also
works and leaves feature 3's merge still owed.

There is no `Verify` command in this project, so the final gate is the declared
fallback: `flutter analyze` then `flutter test`, run once after the last step.
The baseline at spec time was 284 tests passing.

`verification.uiEvidence` is `when-available` and `qualityGates.regular.check`
is `manual`, so per-step UI done-whens are met by widget tests. Device evidence
is gathered once at `/check`, against the platform matrix below.

## Build steps

- [x] **Step 1 - Month window maths** - create
  `lib/features/reports/logic/report_month.dart`: `monthStart`, `nextMonth`,
  `previousMonth`, `canViewNextMonth({required DateTime now})`, and
  `monthLabel` formatting `MMMM yyyy`. Pure Dart, no Flutter and no Firebase
  imports. Windows are local time, because a purchase date is written as a
  client timestamp from the same local clock.
  **Done when:** `flutter test test/features/reports/logic/report_month_test.dart`
  is green covering December to January and January back to December, a month
  boundary landing on the first instant of the month, `canViewNextMonth` false
  for the current month and any later one and true for an earlier one, and the
  label text; `flutter analyze` is clean.

- [x] **Step 2 - Report aggregation** - create
  `lib/features/reports/logic/spending_report.dart` with `ReportRow`,
  `MemberSpend`, `SpendingReport` and `buildSpendingReport`, all `Equatable`
  and pure Dart. It takes the selected month, the purchases spanning the
  previous month start to the next month start, the catalogue, and the members,
  and partitions by month itself. Rules are in Data / contracts below.
  **Done when:** `flutter test test/features/reports/logic/spending_report_test.dart`
  is green covering a member who paid nothing, a `paidByUserId` with no member
  document, an empty member list, a line whose `itemId` is null, a line whose
  `itemId` matches no catalogue item, a purchase with no lines at all, line
  totals summing under and over the receipt total, two shop spellings differing
  only in case, a previous month of zero, and an entirely empty month;
  `flutter analyze` is clean.

- [x] **Step 3 - The purchase window query** - add
  `watchPurchasesBetween({required DateTime from, required DateTime toExclusive})`
  to `PurchaseRepository`, implement it in `FirestorePurchaseRepository` with a
  single-field range on `date` plus `orderBy('date')`, map documents through
  the existing `purchaseFromFirestore`, and map stream errors with
  `handleError` and `dataFailureFromError` exactly as `watchMembers` does. Add
  the method to `FakePurchaseRepository`, recording the requested window and
  replaying a scripted list or error.
  **Done when:** `flutter analyze` is clean and the full `flutter test` suite is
  still green. The real query shape is reviewed, not unit tested: no Firestore
  fake is installed and this spec does not authorize adding one. The query is
  proved against real data at `/check`.

- [x] **Step 4 - Reports cubit and state** - create `reports_state.dart`
  (sealed: `ReportsLoading`, `ReportsLoaded`, `ReportsFailure`, the latter two
  both carrying the selected month and whether next is available) and
  `reports_cubit.dart`. It subscribes to items and members once and to one
  purchase window covering the previous and selected months, re-subscribing the
  window on a month change, emits loaded only once all three streams have
  reported, and exposes `showPreviousMonth`, `showNextMonth`, `retry`. `now` is
  injected as `DateTime Function()`. Every subscription is cancelled in
  `close()`.
  **Done when:** `flutter test test/features/reports/presentation/reports_cubit_test.dart`
  is green covering loading until all three streams report, a month change
  requesting the new window, `showNextMonth` refusing to leave the current
  month, each stream failing separately mapping to `ReportsFailure` with the
  month preserved, `retry` resubscribing after a failure, and an empty month
  loading as a zero report; `flutter analyze` is clean.

- [x] **Step 5 - The screen frame** - create `reports_page.dart` with
  `ReportsPage` building the cubit from the repositories already provided in
  `app.dart`, and a `@visibleForTesting ReportsView` without it, matching
  `ItemListPage` and `ItemListView`. The frame is the app bar, the month bar
  with its two chevrons and label, the month total, and the three body states.
  Failures render through `core/widgets/failure_message.dart` with a retry.
  **Done when:** widget tests cover the spinner while loading, the empty-month
  message with the month bar still usable, the failure message and a retry that
  calls the cubit, the disabled next chevron on the current month, and a
  previous tap moving the label back one month; `flutter analyze` is clean.

- [x] **Step 6 - The four sections and the responsive layout** - add the person,
  category, shop and comparison sections as extracted widgets, not
  `_build` methods, and a `LayoutBuilder` that lays them in two columns from
  720 logical pixels and one below it, inside a 960 max width. Amounts use
  `formatEuro`; a difference against the share carries an explicit sign. All
  member, shop and category text is plain `Text` with `maxLines: 1` and
  `TextOverflow.ellipsis`.
  **Done when:** widget tests at 400x800 and at 1200x900 are green, asserting
  the section contents in both and no overflow in either, and asserting the
  equal-share line names its divisor; `flutter analyze` is clean.

- [x] **Step 7 - The way in** - add a `Reports` `IconButton` to the Home app bar
  next to Catalogue, pushing `ReportsPage` with a `MaterialPageRoute`, the same
  pattern the Catalogue button already uses.
  **Done when:** the Home widget test asserts the button is present and that
  tapping it pushes the reports screen; `flutter analyze` is clean and the full
  `flutter test` suite is green.

## Files / areas

New:

- `lib/features/reports/logic/report_month.dart`
- `lib/features/reports/logic/spending_report.dart`
- `lib/features/reports/presentation/reports_state.dart`
- `lib/features/reports/presentation/reports_cubit.dart`
- `lib/features/reports/presentation/reports_page.dart`
- `test/features/reports/logic/report_month_test.dart`
- `test/features/reports/logic/spending_report_test.dart`
- `test/features/reports/presentation/reports_cubit_test.dart`
- `test/features/reports/presentation/reports_page_test.dart`

Changed:

- `lib/features/purchases/data/purchase_repository.dart` - one read method
- `lib/features/purchases/data/firestore_purchase_repository.dart` - its query
- `lib/features/home/presentation/home_page.dart` - the Reports button
- `test/features/purchases/fake_purchase_repository.dart` - the new method
- `test/features/home/presentation/home_page_test.dart` - the navigation test

Deliberately unchanged:

- `firestore.rules` - reads are already allowed to any signed-in member, and
  this feature adds no new access.
- `pubspec.yaml` - no new dependency. `intl` and `equatable` are installed.
- `lib/core/di/injection.config.dart` - no new injectable type. `ReportsCubit`
  is built in the widget tree like `ItemsCubit`, so no `build_runner` run.
- `lib/app.dart` - all three repositories are already provided.

## Data / contracts

Read only. No document is written, no field is added, and no collection is
created. Authorization is unchanged: `firestore.rules` restricts every read to
a signed-in member, there are no roles and no per-document ownership, and
`AuthGate` already gates the whole tree.

**The query.** `purchases` where `date >= from` and `date < toExclusive`,
ordered by `date`. One range field with a matching `orderBy` needs no composite
index. `from` is the previous month start and `toExclusive` the next month
start, so one stream serves both the selected month and its comparison, and the
partition happens in pure Dart. Documents are read through the existing
defensive `purchaseFromFirestore`; do not write a second mapper. Stream errors
surface as `DataFailure`, never as a `FirebaseException`.

**The month total** is the sum of `purchase.total` for the selected month.
`total` is the receipt figure and is authoritative; it is never re-derived from
`lines`.

**By person.** One row per document in `users`, in the display-name order the
repository already returns, with `paid` summing `total` where `paidByUserId`
matches. `share` is `monthTotal / members.length`, guarded to zero when the
list is empty. `difference` is `paid - share`. A `paidByUserId` seen in the
month with no matching member, including an empty one, gets a trailing
`Unknown member` row carrying its paid total and no share, so no spend
disappears from a section that otherwise sums to the month total. The member
list is `watchMembers()` as it stands; unlike the payer picker, this screen
does not inject the signed-in member, because the report describes the
household rather than offering a choice.

**By category.** For every line of every selected-month purchase, resolve
`line.itemId` to a catalogue item and take `categoryLabel(normalizeCategory(item.category))`,
reusing the existing helpers. A null `itemId`, an `itemId` matching no item, or
a blank category falls into `Uncategorised`. Amounts sum `lineTotal`. A final
`Not itemised` row carries `monthTotal - sum(lineTotal)` when that exceeds half
a cent, so the section reconciles to the month total. The remainder is real and
routine: `validateLineTotal` permits a zero line and a purchase may carry no
lines at all. When the remainder is zero or negative the row is omitted.
Ordering is real categories by amount descending, label ascending on a tie,
then `Uncategorised`, then `Not itemised`.

**By shop.** Selected-month purchases grouped by `shopName.trim()`, keyed on
its lowercase form and labelled with the first spelling seen, the same
technique `availableCategories` already uses, so `conad` and `Conad` are one
shop. A blank name becomes `Unknown shop`. Amounts sum `total`. Ordering is
amount descending, label ascending on a tie.

**Month to month.** The previous month's total, the difference, and the
percentage change, which is null when the previous month was zero and is
rendered as a dash rather than an infinity.

**Money.** Doubles throughout, as everywhere else in this project, formatted by
the existing `formatEuro`. Comparisons against zero use a half-cent epsilon
rather than an exact `> 0`.

**Text.** Shop names, custom categories and display names are member-supplied
free text. Flutter's `Text` renders a string as a string, so there is no markup
or injection surface; the real risk is layout, and every such string is capped
with `maxLines: 1` and `TextOverflow.ellipsis`.

## Testing

`flutter test` is the gate, and this feature is logic-heavy, so the aggregation
carries most of the coverage. Test files mirror source.

- `report_month_test.dart` - month arithmetic across year boundaries, the
  future guard, the label.
- `spending_report_test.dart` - every rule in Data / contracts, including the
  unknown payer, the empty member list, the unresolvable line, the remainder in
  both directions, the case-insensitive shop grouping, and a zero previous
  month.
- `reports_cubit_test.dart` - state transitions, month switching, per-stream
  failure and retry, using the existing `FakePurchaseRepository`,
  `FakeItemRepository` and `FakeMemberRepository` with an injected clock.
- `reports_page_test.dart` - every rendered state, the month bar, and the
  layout at both widths.

No integration test. There is no `integration_test/` directory and this spec
does not add one.

**Platform matrix.** Reports are a new screen with a width-dependent layout, so
per the device verification rule this is substantial UI work, and web is the
surface the plan names for reviewing spending.

    Done-when                             iOS            Web            Android
    Month frame and navigation            to verify      to verify      assumed
    Sections render real Firestore data   to verify      to verify      assumed
    Two-column layout above 720px         n/a            to verify      n/a
    Empty month and failure states        to verify      assumed        assumed

iOS is the physical iPhone; there is no arm64 simulator on this machine. Web is
Chrome. There is no Android target connected, so Android is recorded as
`assumed` and never as a pass. `/check` fills this in with observed tiers.

## Notes for the AI

- **Feature 3 is not merged.** See Build loop. Do not start this feature on
  today's `main`.
- `total` is authoritative for the month, person and shop figures. Re-deriving
  any of them from `lines` is a defect, not an optimisation.
- `purchaseFromFirestore` already exists and is already defensive about missing
  and wrongly typed fields. This feature is its first production caller.
- Feature 3 left the note that feature 4 should render a line from `rawText`
  when `itemId` resolves to nothing. This feature has no line-level display, so
  `rawText` has no surface here. The money on such a line is still counted,
  under `Uncategorised`, so nothing is silently dropped. A purchase detail view
  would be where `rawText` earns its keep, and no build-plan item asks for one
  yet.
- `displayName` is still the email local part, because feature 3 shipped no
  editor. Names in this report are whatever was mirrored.
- Business rules go in `logic/`, pure Dart, no Flutter and no Firebase imports.
  The cubit orchestrates and holds no arithmetic.
- Extract a widget rather than returning one from a `_build` method.
- Cancel every subscription in `close()`.
- No new dependency, no `build_runner` run, no second state management library.
- No em dashes in code, comments, commits or docs.

## Open questions

None of these block implementation. Each is recorded so it is not rediscovered
later, following the pattern feature 3 set.

- **The equal-share divisor is the live member count, not a hardcoded five.**
  The plan says each user owes `total / 5` and describes "around five members".
  A `users` document only appears once a member has signed in at least once, so
  the live count can be short of the real household for a while, and a
  hardcoded five would be wrong for a household of four. The screen therefore
  names its divisor, "split across N members", so whichever it is, it is
  legible rather than mysterious. If the household wants a fixed divisor, that
  is a one-line change and a plan edit.
- **The category section needs a remainder row to reconcile.** Line totals are
  optional and independent of the receipt total, so a category breakdown built
  from lines is systematically short of the month total. `Not itemised` closes
  the gap. The alternative, showing categories that quietly do not add up, was
  rejected as misleading.
- **`items.category` is still a free string.** The overview's own open question
  flagged that typos fragment this report. This feature reports what is stored
  and does not manage the category set, so the exposure is now visible rather
  than theoretical.
- **`consumptionEvents` still has no reader.** Unchanged by this feature, which
  reads only `purchases`, `items` and `users`.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":18491,"specSha256":"e23120b0dfe19a6105de4fd4899444e0413ada86e0b1dea34e5ac2f866b8345e","branch":"refs/heads/feature/spending-reports","head":"f7529c8b99879b58c3696c4d79cba389dc87b892","baseRef":"refs/heads/main","baseCommit":"75c7744a665df55ae690b7a872c04f9c62f5ed19","sourceTree":"b1f10a652e3cdd3440f6cf782a18e25b5be16498","absentOptional":[]} -->
