# Grocery Accounting - Project Overview

<!-- blueprint:source-hash 1c1d9c9858f3b932b351775305cda8b1bef6992c8ea8124af87c94fab9a30f9e -->

> A Flutter app for one five person household: photograph the scontrino, and the
> spend, the payer, the pantry and the shopping list all update from that one
> action.

## Problem

Groceries are bought by several people at several shops with no shared record.
Nobody knows the month's spend or who paid until the bank statement arrives,
staples run out with no warning, and people buy what is already in the cupboard.
One habit fixes all three: photograph the receipt after shopping. Accounting
first, inventory second.

## Users

Around five members of one household, all known personally, all accounts created
by hand. No signup, no invitations, no public audience. Every user sees and edits
everything.

- **Phone, in or just after a shop** - fast, one handed, poor signal. Capture a
  receipt, tick off the list, log that a chicken was cooked.
- **Web, sitting down** - review spending, set up items, correct stock, export a
  month.

## Usage model

- Around five users, known and trusted, accounts created by hand
- One household, one shared dataset, no tenancy
- Firebase is internet facing, so authentication is a real boundary: Firestore
  rules restrict all access to signed-in users. No roles, no per user ownership
  rules. Receipt photos in Supabase Storage are the accepted exception: they are
  uploaded with the publishable key under a bucket policy
- Offline capture matters. Firestore persistence on, receipt photos queue
- EUR only. Costs split equally, so each user owes `total / 5`
- Shops in scope: In's, Conad, Lidl, independent alimentari, frutteria

**Explicit non-requirements:** signup or account management UI, multi-tenancy,
roles or permissions, a settle-up ledger with balances, budgets or spending
alerts, barcode scanning, recipes or meal planning, adversarial users, audit or
compliance constraints, conflict resolution beyond Firestore last write wins.

## Features

Build-plan order. Spend tracking precedes the pantry so the app is useful before
50 to 80 items have been typed in.

1. **Firebase and sign in** - Firebase wiring, sign in with a manual account, app shell, security rules requiring auth.
2. **Item catalogue** - create, edit and list items with unit, category, average piece weight, daily usage, low threshold.
3. **Record a purchase** - the review and commit screen: date, shop, total, payer, lines, inline item creation; writes the spend and restocks in one action.
4. **Spending reports** - monthly totals by person, category and shop, each person against an equal share, month to month comparison.
5. **Stock tracking** - derived stock, automatic daily decrease for staples, consumption logging, recount, ad hoc adjustment.
6. **Running low** - items under threshold on the home screen, calculated, self-clearing.
7. **Run out notifications** - predicted empty date, scheduled local notification.
8. **Shared shopping list** - manual entries live across devices, removed when a confirmed purchase matches.
9. **Receipt capture** - photograph the scontrino, store it, attach it to a purchase, queue the upload offline.
10. **On device receipt reading** - the headline feature. ML Kit text recognition plus a parser prefills the review screen on Android and iOS.
11. **Learned receipt mapping** - the alias table, so a line mapped once resolves automatically every time after.
12. **CSV export** - export a month of purchases and share it.
13. **Large screen and web layout pass** - responsive reports, and the manual entry path on web where ML Kit does not exist.

**The headline feature is 10, built ninth on purpose.** The pipeline is
`capture -> extract -> review -> commit`, and the review screen built in feature 3
is the actual feature; the extractor only prefills it. Nothing reaches the pantry
without passing review, because a silently wrong quantity corrupts stock and then
the low stock notifications start lying.

## Data model

Cloud Firestore. Six flat collections, no subcollections, no household scope.

### users/{userId}

- `displayName` (string)
- `email` (string)
- `createdAt` (timestamp)

Mirrors hand-created Firebase Auth accounts. No self registration.

### items/{itemId}

Catalogue and pantry in one document, because identity and stock level are never
needed apart.

- `name` (string)
- `unit` (enum: `kg` | `g` | `pcs` | `L`) - `kg` by default
- `category` (string)
- `avgPieceWeight` (double, nullable) - converts "one chicken" or "2 onions" into `unit`
- `dailyUsage` (double) - per day, `0` for anything that is not a staple
- `lowThreshold` (double) - below this the item appears as running low
- `stockAtBaseline` (double)
- `baselineDate` (timestamp)

> **Locked contract. Features 5, 6 and 7 all depend on it:**
>
> ```
> currentStock = stockAtBaseline - (dailyUsage * daysSince(baselineDate))
> ```
>
> Stock is never stored as a live number. Every purchase, consumption event and
> recount writes a fresh `stockAtBaseline` and `baselineDate` pair. Nothing writes
> daily, the value is correct whether the app was opened or not, and it works
> offline. `dailyUsage: 0` makes the same formula cover non-staples unchanged.

### purchases/{purchaseId}

- `date` (timestamp)
- `shopName` (string)
- `total` (double, EUR)
- `paidByUserId` (string) -> `users/{userId}`
- `receiptImagePath` (string, nullable) -> object path in the Supabase `Grocery Accounting` bucket
- `source` (enum: `manual` | `scanned`)
- `lines` (array of PurchaseLine, embedded)

**PurchaseLine**

- `itemId` (string, nullable) -> `items/{itemId}`, null while unmatched
- `rawText` (string) - the original receipt wording, kept after matching so a
  mis-mapping stays diagnosable later
- `quantity` (double)
- `unit` (enum, as on items)
- `lineTotal` (double, EUR)

Drives features 3, 4 and 12.

### consumptionEvents/{eventId}

- `itemId` (string) -> `items/{itemId}`
- `quantity` (double)
- `unit` (enum)
- `date` (timestamp)
- `userId` (string) -> `users/{userId}`
- `type` (enum: `consumed` | `adjustment` | `recount`)
- `note` (string, nullable)

Audit trail only. Not read when computing stock, since the item baseline already
carries it. It exists so a wrong number can be explained.

### shoppingList/{entryId}

- `text` (string)
- `itemId` (string, nullable) -> `items/{itemId}`
- `addedByUserId` (string) -> `users/{userId}`
- `addedAt` (timestamp)
- `done` (bool)

Created only by hand. Nothing auto populates it. Confirming a scontrino marks
matching entries done and removes them. Live across devices via snapshots.

### aliases/{aliasId}

- `rawTextNormalized` (string, indexed) - the lookup key
- `itemId` (string) -> `items/{itemId}`
- `defaultQuantity` (double)
- `defaultUnit` (enum)
- `shopName` (string, nullable)

The learning table behind feature 11. A line mapped once by hand, together with
the quantity the receipt failed to state, resolves automatically from then on.
Without it, receipt scanning is a demo that gets abandoned in week two.

### Not stored

Low stock suggestions are calculated from `items`, never persisted. Restocking
pushes stock above the threshold and the suggestion disappears on its own, so
there is no suggestion state to clean up.

## Tech stack

- **Flutter 3.44.4 / Dart 3.12.2** - iOS, Android and Web from one codebase
- **flutter_bloc** - state management; established, never a second solution
- **get_it with injectable** - dependency injection through constructors
- **Firebase Auth** - sign in for hand-created accounts
- **Cloud Firestore** - all six collections, offline persistence on
- **Supabase Storage** - scontrino images, uploaded over its REST API with `http`,
  because Firebase Storage needs the Blaze plan here
- **google_mlkit_text_recognition** - on device OCR, Android and iOS only
- **Dart 3 sealed classes** - `Result` and bloc states, not `dartz`
- **equatable** - value equality; `freezed` only if the codegen earns its place
- **image_picker, flutter_local_notifications, share_plus, intl** - capture,
  notifications, CSV sharing, and EUR / `dd/MM/yyyy` formatting

**Deliberately excluded:** Cloud Functions, the Firebase Blaze plan, and any
cloud AI extraction. On device only. This costs accuracy on handwritten
alimentari and frutteria receipts and means parser rules need tuning per chain.
It buys zero running cost, no payment method, offline capture, and no receipt
image leaving the household's own bucket.

Code structure is `core/` plus `features/<feature>/{data,logic,presentation}`.
There is no `domain/` layer. `logic/` is pure Dart with no Flutter or Firebase
imports and is where business rules and their tests live.

## Monetization

Not in v1. Personal project, one household, no ads, no subscriptions. If it ever
goes public this gets rewritten.

## UI/UX

- Seed color `0xFF244F3D` deep green, `CenturyGothic` with `CenturyGothicBold` at
  weight 700, Material 3
- Interface language English. EUR, decimal comma on receipts, `dd/MM/yyyy` dates
- Responsive from the start, not retrofitted: phone is one column and thumb
  reachable, web and tablet use the width for tables and multi column reports
- **Home is built around one action.** The receipt capture button is the largest
  thing on it, with running low and the shopping list below. Reports sit one
  level down, because receipts are photographed weekly and reports are read
  occasionally
- **The review screen is the most important screen in the app.** Fast to correct,
  with unmatched lines visually obvious so they are never confirmed by accident

Screens implied by the feature list, names not yet fixed:

- Sign in
- Home - capture button, running low, shopping list
- Receipt review and commit
- Item catalogue, and item detail carrying recount, adjustment and consumption log
- Spending reports

## Deployment

No public store distribution. Five known users. The Firebase Spark plan is
sufficient, since there are no Cloud Functions.

| Target | Approach |
| --- | --- |
| Web | Firebase Hosting, `flutter build web` |
| Android | `flutter build appbundle` or APK, internal distribution |
| iOS | TestFlight internal testers, or direct install |

- Firebase project holds Auth and Firestore; Supabase holds receipt photos
- Env vars: none beyond the generated `firebase_options.dart` and the Supabase
  URL and publishable key, which ship in the app
- No workers, no cron jobs, no health check path, no custom domain
- Firestore rules are required, not optional, restricting all reads and writes
  to authenticated users. The Supabase bucket is governed by its storage
  policies instead

## Open questions

> Resolve these in the plans, then re-run `/overview`.

- **`consumptionEvents` has no reader.** Features 3 and 5 write it and the plan
  calls it the audit trail, but no build-plan feature ever displays it. Either a
  history view is missing from the build plan, or the collection is write-only by
  design. Decide before feature 5 locks the write shape.
- **`shoppingList.done` may be redundant.** Confirming a scontrino marks entries
  done *and* removes them, so the flag is only ever transient. Keep it for manual
  ticking while standing in the shop, or drop it.
- **`items.category` is a free string** and no feature manages the set. Feature 4
  reports by category, so typos will silently fragment the report. Worth fixing
  to an enum when feature 2 is specced.
- **Feature 13 has no matching line in project-plan.md section 3.** It traces to
  the UI/UX and Deployment sections instead. Not a conflict, but it is a platform
  pass rather than a product feature.
- **The planned stack is not installed.** `pubspec.yaml` still holds only
  `cupertino_icons`. Feature 1 has to add flutter_bloc, get_it, injectable and the
  Firebase packages before anything compiles.
- **Two repo defects block a clean build**, recorded in project-plan.md section
  10: `pubspec.yaml` declares `fonts/CenturyGothic.ttf` while the files on disk
  are `.TTF`, which fails on a case sensitive filesystem such as a Linux CI
  runner; and `assets/` is declared but empty, so a fresh clone fails to build.
  `flutter test` also exits 1 on an empty suite, which is intentional until the
  first real test lands.
