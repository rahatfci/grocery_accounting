# Feature: Mobile redesign

**From build-plan:** features 14 to 22 (Milestone 7 - Mobile redesign), built as one work item on request
**Build attempt:** 1
**Status:** verified
**Branch:** `feature/mobile-redesign`

## Goal

Rebuild every screen on the Figma design (project plan, section 7): light
surfaces, navy text, the seed green for actions, colour that follows meaning,
a bottom navigation shell, and the data each new screen needs. The receipt
flow stays the centre of the app: Home is built around the scan hero, review
groups unmatched lines on top, and a save ends on a summary of what it did.

## Design reference

Figma file `uALv1vykqOmzhUvG8FsHxk` (Screens page `6:2`, Components `6:3`,
Foundations `6:4`). One render per screen, 390x844:

- `blueprint/reference/figma/01-splash.png`, `02-sign-in.png`
- `03-home.png`, `04-home-first-run.png`, `05-add-a-purchase.png`
- `06-review-reading-receipt.png`, `07-review-ready-to-save.png`,
  `08-review-match-line.png`, `09-review-new-item.png`, `10-purchase-saved.png`
- `11-pantry.png`, `12-item-detail.png`, `13-adjust-stock.png`, `14-new-item.png`
- `15-shopping-list.png`
- `16-spending.png`, `17-purchases.png`, `18-purchase-detail.png`
- `19-account.png`

## In scope

- Tokens from the Figma variables: `AppColors`, spacing, radii, shadows, the
  13 text styles on CenturyGothic 400/700 mapped to the Material 3 roles, and
  component themes. Icons from Material Symbols Rounded (`material_symbols_icons`),
  the exact match the design names.
- Splash while the session is unknown; restyled sign in.
- App shell: Home, Pantry, List and Spending tabs (bottom navigation on a phone,
  a rail from 720dp), pushed screens hide the bar, system back returns to Home
  before leaving. Account opens from the Home avatar.
- Home: greeting, month glance (spend, change on last month, your balance
  against the share), scan hero (take photo, gallery, manual, and the Add a
  purchase sheet), first-run card, running low rows with add to list, shopping
  list preview.
- Review: receipt strip (reading, read, attached, none), shop/date/total,
  payer chips, "To match" unmatched lines, matched lines with Matched, Learned
  and New item states, lines against the total, action bar. Match line sheet
  with item search, create new, quantity and unit, the learning note. New
  pantry item sheet.
- Saved summary: spend recorded, pantry restocked, new items, list entries
  cleared, lines learned, spend-only lines, and the receipt photo state.
- Pantry: filters with counts, category groups, status per item, search, Add
  item. Item detail with the derived stock, gauge, run-out date, reminder,
  log use / adjust / recount sheets with a new-stock preview, add to the
  shopping list, and a history read from `consumptionEvents` and purchases.
  New / edit item form.
- Shopping list tab: shared-with avatars, add, entries that show ticked for a
  moment before they go, running-low suggestions added with one tap.
- Spending: month switcher, total with change and month comparison bars, who
  paid against the equal share, by category, by shop, recent purchases.
  Purchases by day. Purchase detail with lines and the receipt photo.
- Account: profile, household, reminders on this phone, receipt upload state,
  export a month, sign out.

## Out of scope

- Dark theme (the design is light only).
- Any change to the stock formula, the Firestore collections' existing fields,
  or the security rules.
- A settle-up ledger, budgets, barcode scanning, recipes (project non-goals).
- Editing a purchase after it is saved (the design's purchase detail is
  read-only).

## Build steps

- [x] **Step 1 - Tokens and theme** - `AppColors`, spacing, radii, shadows,
  text theme, component themes, shared widgets, icon package. *Done when:*
  analyze and tests pass with the new theme applied app wide.
- [x] **Step 2 - Splash and sign in** - *Done when:* the unknown session shows the
  splash and sign in matches `02-sign-in.png`; sign in tests pass.
- [x] **Step 3 - Household** - member initials and avatar tones, display names
  that survive a sign in, a household cubit. *Done when:* logic tests pass.
- [x] **Step 4 - App shell and Account** - tabs, rail, nested navigator, back
  handling, Account page. *Done when:* tabs switch, Account opens from the
  avatar, sign out works; widget tests pass.
- [x] **Step 5 - Home** - *Done when:* Home and first run match `03`/`04`, the
  Add a purchase sheet matches `05`; tests pass.
- [x] **Step 6 - Shopping list tab** - *Done when:* matches `15`, ticking shows
  the moment before removal, suggestions add linked entries; tests pass.
- [x] **Step 7 - Pantry and item detail** - filters, groups, status, history,
  sheets, form. *Done when:* matches `11` to `14`; logic and widget tests pass.
- [x] **Step 8 - Review screen** - *Done when:* matches `06` to `09`; the
  learned state comes from the alias; tests pass.
- [x] **Step 9 - Saved summary** - *Done when:* matches `10` with counts from
  the commit; tests pass.
- [x] **Step 10 - Spending, purchases, purchase detail** - *Done when:* match
  `16` to `18`; the receipt photo loads from the queue or Supabase; tests pass.
- [x] **Step 11 - Wide layouts, polish, verification** - *Done when:* Verify
  passes and the phone screens are exercised on the Android emulator.

## Files / areas

- `lib/core/theme/*`, `lib/core/widgets/*`, `lib/app.dart`, `pubspec.yaml`
- `lib/features/shell/` (new), `lib/features/account/` (new)
- `lib/features/home/`, `items/`, `members/`, `purchases/`, `receipts/`,
  `reports/`, `shopping_list/`, `auth/presentation/`
- Tests mirroring each changed logic and screen file.

## Data / contracts

- No new collections, no new fields on existing documents.
- New reads: `consumptionEvents` by `itemId` and `purchases` by
  `itemIds array-contains`, both on automatic single-field indexes and sorted
  on the device; one `purchases/{id}` document watch.
- `users/{uid}` mirror: an existing `displayName` edited by hand is kept; only
  an empty one, or the one the app derived from the email, is rewritten.
- Receipt photos are read back from the phone's upload queue when still
  pending, otherwise downloaded from the Supabase bucket with the publishable
  key (needs a read policy on the bucket, like the upload needs an insert one).
- `PurchaseDraftLine` carries whether a learned alias matched it; the commit
  outcome carries a `PurchaseSummary`.

## Testing

- Unit tests for every new pure function: stock status, pantry filtering,
  history merge, greeting, spend glance, purchase summary, day grouping,
  initials and avatar tones, display-name mirroring, suggested item names,
  list suggestions and entry meta.
- Widget tests for each rebuilt screen's states and main interactions.
- `flutter analyze && flutter test && flutter build apk --debug` (Verify).
- Device: Android emulator (`Pixel_10`); iOS and web assumed unless a target is
  available, and reported as assumed.

## Notes for the AI

- CenturyGothic is wider than the Figma stand-in (Urbanist): rows must truncate
  or wrap rather than overflow.
- Business rules stay in `logic/` as pure Dart; blocs orchestrate only.
- Never block navigation on a Firestore write future: keep the refusal window.

## Verification (2026-09-27)

- Verify (`flutter analyze && flutter test && flutter build apk --debug`):
  pass, 950 tests. Rerun on the committed code (`f502f50`): analyze clean,
  950 tests pass, debug APK builds.
- Android (tier 3, Pixel_10 emulator, debug build, signed-in household):
  Home, Add a purchase sheet, review screen (manual), line sheet, new pantry
  item view, Pantry, item detail, List, Spending, Purchases, purchase detail
  with a receipt photo downloaded from the bucket, the full-size photo view,
  Account, and landscape (rail, two-column Spending) exercised. Nothing was
  saved on the device. Two layout bugs found there and fixed: section header
  actions sat mid-row, and the review date field was shorter than the total.
- Not exercised on a device: camera and gallery capture, reading a real
  receipt, the saved summary, sign in and sign out (covered by widget tests).
- iOS and web: assumed.



<!-- blueprint:completion {"schemaVersion":1,"specBytes":8182,"specSha256":"ca79a481ef3771156a4d79464b5e8b2a287374f87ba66fdb6b11fead8e62b735","branch":"refs/heads/feature/mobile-redesign","head":"cccb4e6043328494081fe38a11e911833d5e502b","baseRef":"refs/heads/main","baseCommit":"0e0ca270f51437818e61b6464a9e24a55775a0bc","sourceTree":"d5e88d57544a18b436cbc138b6b5e4612e8b2695","absentOptional":[]} -->

## Independent review

**Status:** passed
**Target commit:** cccb4e6043328494081fe38a11e911833d5e502b
**Base commit:** 0e0ca270f51437818e61b6464a9e24a55775a0bc
**Base ref:** origin/main
**Spec hash:** ca79a481ef3771156a4d79464b5e8b2a287374f87ba66fdb6b11fead8e62b735
**Prepared by:** claude
**Builder model:** claude-opus-5-5
**Requested reviewer:** claude
**Requested model:** claude-opus-5-5
**Requested execution:** automatic
**Requested at:** 2026-09-26T23:57:03Z
**Workflow:** regular
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5-5
**Reviewer context:** fresh session
**Actual execution:** manual
**Reviewed at:** 2026-09-27T09:36:00Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

### Commands

- `flutter analyze`: pass (no issues)
- `flutter test`: pass (950 tests)
- `flutter build apk --debug`: pass

### Evidence

- Freshness verified before and after the gates: HEAD, merge base from `origin/main`, spec SHA-256, and a clean tree apart from `review.md`.
- Reviewed the full `0e0ca27..cccb4e6` delta (194 files), with focus on the data layer (stock event and purchase watches, member display-name mirror, Supabase receipt download and queue read), logic (history, pantry view, stock status, purchase summary, review lines, spending view, household), cubits (record purchase save flow, purchase detail, item history, household, shell), shell back handling, and disposal of controllers, timers and subscriptions.
- The tests mirror the new logic and screen files. No skipped or focused tests.
- Automatic execution fell back to a manual fresh session: this reviewer session started without the builder transcript and completed the pending request directly.

### Findings

- F-01 [P3] open - saved summary emits after the review screen may have closed

### Remaining risk

- Check was not run (not required). Camera and gallery capture, reading a real receipt, the saved summary, and sign in and sign out were not exercised on a device, per the spec.
- iOS and web are assumed, not verified.
- The Supabase bucket read policy that receipt download needs lets anyone holding the publishable key read receipts, and on Supabase a SELECT policy also allows listing. This is accepted in the project plan (2026-09-24). The live policy was not inspected.
- No integration tests exist in this project.
