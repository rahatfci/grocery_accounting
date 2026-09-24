# Fix: Displayed stock goes stale in the background

**Type:** Fix
**Status:** verified
**Branch:** `fix/displayed-stock-goes-stale-in-the-background`
**Fixes:** F-11

## The problem

`ItemsLoaded.now` is taken only when `watchItems()` emits
(`lib/features/items/presentation/items_cubit.dart:124-125`). The catalogue
rows and the item detail screen derive current stock from that instant. A
Firestore listener does not re-emit on its own, so if the catalogue stays on the
stack while the app sits in the background overnight, the stock on screen is
still yesterday's number when the member comes back. Staples are meant to
visibly run down day by day, and a member can log use against the stale number.

The write path is unaffected: `recordStockEvent` already passes a fresh
`_clock()`.

## The fix

Follow the existing Home pattern (`_RefreshOnResume` in
`lib/features/home/presentation/home_page.dart`, which calls
`RunningLowCubit.refresh()` on resume):

- `ItemsCubit.refresh()` re-emits `ItemsLoaded(items, now: _clock())` when the
  state is `ItemsLoaded`, and does nothing in any other state.
- `ItemListView` wraps its content in a small private widget holding an
  `AppLifecycleListener` whose `onResume` calls `refresh()`. It lives in
  `ItemListView` rather than `ItemListPage` so a test can drive it with an
  injected clock. The detail screen reads the same cubit and the list view stays
  mounted under it, so both refresh.

No timer and no new dependency. Must not break: the injected clock, the stream
error handling, and the existing catalogue and detail tests.

## Build steps

### [x] Step 1 - Refresh the stock instant on resume

- Add `refresh()` to `ItemsCubit` and the resume listener to `ItemListView`,
  disposed with its state.
- Cubit tests: `refresh` after a load re-emits with the clock's new time;
  `refresh` while loading, empty or failed emits nothing.
- Widget test: with the catalogue shown, advancing the clock and sending a
  resume lifecycle event moves the cubit's `now` to the new time and the row's
  stock runs down.

**Done when:** `flutter analyze` is clean and `flutter test` passes with the new
tests.

## Verify

- `flutter analyze` and `flutter test`.
- Logic plus a non-visual listener; no layout changes. Every platform is
  `assumed`.


<!-- blueprint:completion {"schemaVersion":1,"specBytes":2288,"specSha256":"8f63e6b8863e2564db2e364932dfe9976bfca64110070456d37997066bb1cb6d","branch":"refs/heads/fix/displayed-stock-goes-stale-in-the-background","head":"1649d1580394bfd9fc29092b370bbb94e5206ea1","baseRef":"refs/heads/main","baseCommit":"64fd3410a67b4b208acc2c6b4bcbd3a9cf1171a3","sourceTree":"0999031991bba142e586ee71c2b264fad2542eee","absentOptional":[]} -->

## Findings

### displayed-stock-goes-stale-in-the-background/F-09 [P3] accepted - `blueprint/` and `.claude/` are tracked, against the stated local-only contract

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
**Resolution:** Accepted 2026-09-24 by the user's explicit decision in chat: keep `blueprint/`, `.claude/` and `CLAUDE.md` tracked in the repository rather than untracking them. The local-only wording in `CLAUDE.md` and `blueprint/context/workflow.md` was left as is.

### displayed-stock-goes-stale-in-the-background/F-11 [P2] closed - Displayed stock is frozen at the last stream emission

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
Fixed 2026-09-24 by /implement on `fix/displayed-stock-goes-stale-in-the-background`: `ItemsCubit.refresh()` re-derives a loaded catalogue at `_clock()`, and `ItemListView` calls it from an `AppLifecycleListener` on resume. Covered by cubit tests and a widget resume test. Awaiting /audit to close.
Closed 2026-09-24 by /audit independent at 1649d15: `ItemsCubit.refresh()`
(items_cubit.dart:46-50) re-emits `ItemsLoaded(items, now: _clock())` only from
`ItemsLoaded`, and `_RefreshOnResume` in `ItemListView`
(item_list_page.dart:79-107) calls it from an `AppLifecycleListener` disposed
with its state. The detail screen is only opened through `_openDetail` on the
same cubit with the list view mounted beneath, so it refreshes too. The widget
test moves a row from 2.5 kg to 2 kg on resume and would fail without the
listener. The injected clock, stream error handling and write path are
unchanged; `flutter analyze` clean and `flutter test` 729 passing. The repair
introduced no new defect beyond the doc-comment drift recorded as F-16.

## Independent review

**Status:** passed
**Target commit:** 1649d1580394bfd9fc29092b370bbb94e5206ea1
**Base commit:** 64fd3410a67b4b208acc2c6b4bcbd3a9cf1171a3
**Base ref:** main
**Spec hash:** 8f63e6b8863e2564db2e364932dfe9976bfca64110070456d37997066bb1cb6d
**Prepared by:** claude
**Builder model:** claude-opus-5-5
**Requested reviewer:** claude
**Requested model:** claude-opus-5-5
**Requested execution:** automatic
**Requested at:** 2026-09-24T14:56:06Z
**Workflow:** regular
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5-5
**Reviewer context:** fresh subagent
**Actual execution:** automatic
**Reviewed at:** 2026-09-24T14:57:12Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

## Handoff

Review the active spec and the complete `64fd3410a67b4b208acc2c6b4bcbd3a9cf1171a3..1649d1580394bfd9fc29092b370bbb94e5206ea1` delta in a fresh
session or isolated subagent without the builder conversation. Run all Audit lenses from scratch.
Run Check when required above. Do not edit product code, accept findings, or
reuse the existing findings as the review scope.

## Commands

- `git rev-parse HEAD`, `git merge-base main HEAD`, `shasum -a 256 blueprint/context/current-feature.md`, `git status --porcelain --untracked-files=all`: pass (HEAD, merge base and spec hash match the request; only `blueprint/context/review.md` differs)
- `flutter analyze`: pass (no issues found)
- `flutter test`: pass (729 tests, all passed)
- `dart format --output=none --set-exit-if-changed` on the four changed Dart files: pass (0 changed)

## Evidence

- Delta 64fd341..1649d15 reviewed in full: `items_cubit.dart` (`refresh()`), `item_list_page.dart` (`_RefreshOnResume` around `ItemListView`), four cubit `refresh` tests, one widget resume test, and spec/ledger updates.
- `refresh()` emits only from `ItemsLoaded` and uses the injected `_clock()`; stream error handling, `retry()` and the write path are unchanged.
- The `AppLifecycleListener` is created in `initState` and disposed in `dispose`; the detail screen is reachable only via `_openDetail` on the same cubit with the list view mounted beneath, so both refresh.
- Widget test moves a row from 2.5 kg to 2 kg on resume with no item emission, which fails without the listener.
- Security: no new input, persistence, auth or network surface. Performance: one re-emit per resume, no timer or new subscription.
- F-11 re-examined and closed.

## Findings

- F-11 [P2] closed - displayed stock now re-derived on resume.
- F-16 [P3] open - `ItemsLoaded.now` doc comment still says it is taken only when the stream reports.

## Remaining risk

- Check not required and not run; every platform is `assumed`, including real OS resume delivery on Android, iOS and web visibility changes.
- No `Verify` command and no integration tests exist for this project.
- The detail screen's refresh is covered by reasoning (shared cubit, mounted list view), not by a dedicated test.
