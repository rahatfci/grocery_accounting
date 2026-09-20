# Project Plan

## 1. Problem - What problem are we solving?

Groceries for a five person household are bought by several different people, at
several different shops, with no shared record of what was spent or what is
already in the kitchen. Three things go wrong repeatedly:

- Nobody knows the month's grocery spend until the bank statement arrives, and
  nobody knows who paid for what.
- Staples run out with no warning, because nothing tracks that the rice bag is
  nearly empty.
- People buy things already in the cupboard, or forget the one thing they went
  out for.

The app solves all three from a single habit: photograph the scontrino after
shopping. That one action records the spend, records who paid, restocks the
kitchen inventory, and clears the shopping list. Everything else in the app is
either a consequence of that record or a way to read it back.

The name is literal. This is accounting first, inventory second.

## 2. Users - Who is this for?

Around five members of one household, all known personally and all created by
hand. There is no signup, no invitation flow, no public audience.

Two usage contexts:

- **Phone, standing in a shop or just back from one.** Fast, one handed, poor
  signal. Photographing a receipt, ticking something off the list, logging that
  a chicken was cooked.
- **Web, sitting down.** Reviewing where the money went, setting up pantry
  items, correcting stock levels, exporting a month.

Going public later so any household could configure their own copy is a possible
future, not a v1 requirement. The data is scoped so a household identifier could
be introduced later without a rewrite, but no multi-tenancy is built now.

## 3. Features - What does the MVP need?

- Sign in with a manually created account.
- An item catalogue: name, unit, category, low threshold, daily usage.
- Record a purchase: date, shop, total, who paid, and what was bought.
- Attach the scontrino photo to the purchase and keep it.
- Read the scontrino automatically on device and prefill the purchase for review.
- Remember what each receipt line means, so the same line is recognised next time.
- Track stock: automatic daily decrease for staples, manual logging for the rest.
- Correct stock with a recount, and adjust it ad hoc for events.
- Show what is running low on the home screen.
- Notify locally before something runs out.
- A fully manual shopping list, shared live, whose entries are ticked off
  and removed automatically when a confirmed scontrino matches them.
- Spending reports by month, person, category and shop.
- Show what each person paid against an equal five way share.
- Export a month to CSV.

## 4. Data - What are we storing?

Cloud Firestore. Six collections.

### `users/{userId}`
`displayName`, `email`, `createdAt`. Created by hand. No self registration.

### `items/{itemId}`
The catalogue and the pantry in one document, because an item's identity and its
stock level are never needed apart.

| Field | Notes |
| --- | --- |
| `name` | "Rice", "Chicken", "Eggs" |
| `unit` | `kg` by default, or `pcs`, `L`, `g` |
| `category` | Dairy, meat, vegetables, household, and so on |
| `avgPieceWeight` | Optional. Lets "one chicken" or "2 onions" convert into kg |
| `dailyUsage` | Amount consumed per day. `0` for anything not a staple |
| `lowThreshold` | Below this, the item appears as running low |
| `stockAtBaseline` | Stock level at the moment of the last event |
| `baselineDate` | When that level was true |

**Stock is derived, never stored as a live number:**

```
currentStock = stockAtBaseline - (dailyUsage * daysSince(baselineDate))
```

Every purchase, consumption event and recount writes a new
`stockAtBaseline` and `baselineDate` pair. Nothing writes to the database daily,
the value is correct whether the app was opened or not, and it works offline.
Non staples have `dailyUsage: 0`, so the same formula covers every item.

### `purchases/{purchaseId}`
`date`, `shopName`, `total`, `paidByUserId`, `receiptImagePath`,
`source` (`manual` or `scanned`), and a `lines` array of
`{ itemId, rawText, quantity, unit, lineTotal }`.

`rawText` keeps the original receipt wording even after it is matched, because
that is what makes a mis-mapping diagnosable later.

### `consumptionEvents/{eventId}`
`itemId`, `quantity`, `unit`, `date`, `userId`, `type`
(`consumed`, `adjustment`, `recount`), optional `note`. This is the audit trail.
It is not used to compute current stock, since the item's baseline already
carries that, but it is what makes a wrong number explainable.

### `shoppingList/{entryId}`
`text`, optional `itemId`, `addedByUserId`, `addedAt`, `done`. Live across
devices via Firestore snapshots. Entries are created only by hand. Nothing
auto populates this list; confirming a scontrino marks matching entries done
and removes them.

### `aliases/{aliasId}`
`rawTextNormalized`, `itemId`, `defaultQuantity`, `defaultUnit`, optional
`shopName`. This is the learning table. The first time `POMODORI PELATI 400G`
appears, it is mapped by hand in the review screen along with the quantity the
receipt failed to state. Every later occurrence resolves automatically.

Without this table, receipt scanning is a demo that gets abandoned in week two.

### Not stored
Low stock suggestions are calculated from `items`, never persisted. Buying the
item moves its stock above the threshold and the suggestion disappears on its
own, so there is no suggestion state to clean up.

## 5. Tech - What stack are we using?

| Layer | Choice |
| --- | --- |
| Framework | Flutter 3.44.4, Dart 3.12.2 |
| State | `flutter_bloc` |
| Dependency injection | `get_it` with `injectable` |
| Backend | Firebase: Auth, Firestore, Storage |
| OCR | `google_mlkit_text_recognition`, on device, Android and iOS only |
| Result type | Dart 3 sealed classes, not `dartz`, which is unmaintained |
| Equality | `equatable`, adding `freezed` only if codegen earns its place |
| Other | `image_picker`, `flutter_local_notifications`, `share_plus`, `intl` |

### Structure

```
lib/
  core/                  # DI, theme, failures, formatters
  features/
    auth/
    items/
      data/              # Firestore datasource, models, repository
      logic/             # pure Dart calculations, unit tested
      presentation/      # bloc, pages, widgets
    purchases/
    shopping_list/
    spending/
```

No separate domain layer, by decision. The `logic/` folder is what keeps the
project honest: stock maths, run out dates and monthly settlement live there as
plain Dart with no Flutter or Firebase imports, so they are unit testable
without a `WidgetTester`. Any calculation that ends up inside a widget or a bloc
is in the wrong place.

### Receipt pipeline

    capture -> extract -> review -> commit

Only the extract step varies by platform. The review screen is the feature; the
extractor is a detail behind it. This is why the review screen gets built before
any scanning exists.

- **Android and iOS:** ML Kit reads the text on device, a parser finds the
  price pattern, the `TOTALE` line, the date, and quantity lines such as
  `2 x 1,29` or `0,450 kg x 5,90`. Results prefill the review screen.
- **Web:** ML Kit does not exist. The photo uploads and the review screen is
  filled in by hand. Identical screen, identical commit path.

Nothing is ever written to the pantry without passing through the review screen.
A silently wrong quantity corrupts stock, and then the low stock notifications
start lying, which is worse than having no notifications at all.

### Deliberately not used

Cloud Functions, and therefore the Firebase Blaze plan, and therefore any cloud
AI extraction. On device only. This costs accuracy, especially on handwritten
receipts from an alimentari or frutteria, and it means parser rules need tuning
per chain. It buys zero cost, no payment method, offline capture and no receipt
image leaving the device except into the household's own Storage bucket.

## 6. Monetize - How will this make money?

It does not. Personal project, one household, no business model, no ads, no
subscriptions. If it ever goes public this section gets rewritten.

## 7. UI/UX - How should this look and feel?

Existing theme tokens, already in `lib/main.dart`, stay:

- Seed colour `0xFF244F3D`, a deep green
- `CenturyGothic`, with `CenturyGothicBold` at weight 700
- Material 3

**Home screen is built around one action.** The receipt capture button is the
largest, most obvious thing on it. Below it: what is running low, and the
shopping list. Reports are deliberately one level down, because they are read
occasionally and the receipt is photographed weekly.

**The review screen is the most important screen in the app.** It is where OCR
guesses get corrected, unknown receipt lines get mapped to items, and missing
quantities get filled in. It has to be fast to correct, and it has to make
unmatched lines visually obvious so they are not confirmed by accident.

**Responsive from the start, not retrofitted.** Phone is one column and thumb
reachable. Web and tablet use the width for tables and multi column reports
rather than stretching phone layouts.

Language and formatting are Italian context: EUR, decimal comma on receipts,
`dd/MM/yyyy` dates. Interface language is English.

## 8. Deployment - Where and how will this ship?

No public store distribution. Five known users.

| Target | Approach |
| --- | --- |
| Web | Firebase Hosting, `flutter build web` |
| Android | `flutter build appbundle` or APK, internal distribution |
| iOS | TestFlight internal testers, or direct install |

Firebase project holds Auth, Firestore and Storage. Spark plan is sufficient,
since there are no Cloud Functions. No environment variables beyond the
generated `firebase_options.dart`. No workers, no cron jobs, no health check, no
custom domain.

**Firestore and Storage security rules are required, not optional.** The
database sits on the public internet whatever the app does. Rules restrict all
reads and writes to authenticated users. That is the whole boundary. No roles,
no per user ownership rules, no field level validation beyond what stops an
accident, because all five users are trusted and share the same data by design.

## 9. Usage model and constraints

**Established:**

- Around five users, all known and trusted, accounts created by hand
- One household, one shared dataset
- Internet facing only in the sense that Firebase is, so authentication is
  genuinely required
- Offline capture matters: shops have poor signal. Firestore persistence is on,
  and receipt photos queue for upload
- EUR only
- Costs are split equally. Every user owes the same share of the month's
  total, so settlement is each person's spend measured against that share
- Shops in scope: In's, Conad, Lidl, independent alimentari, frutteria

**Explicit non requirements:**

- No signup, invitations, password reset flow or account management UI
- No multi tenancy or household isolation
- No roles or permissions. Every user can see and edit everything
- No adversarial users, no audit or compliance requirements
- No settle up ledger with balances and "mark as paid"
- No budget limits or spending alerts
- No barcode scanning
- No recipe or meal planning features
- No conflict resolution beyond Firestore's last write wins

## 10. Known risks and open questions

**Setup burden is the main adoption risk.** A real kitchen is 50 to 80 items,
each needing a name, unit, category, threshold and daily usage. Typing that in
one evening is where this app is most likely to die before it starts. The
mitigation is designed in: start with the handful of staples that actually
matter when they run out, and let the review screen create items on the fly as
receipts get scanned. The catalogue fills itself over a few weeks.

**Stock drift.** Automatic decrement diverges from reality after a holiday or an
event. Handled by the recount action and ad hoc adjustments rather than by a
pause feature.

**OCR accuracy on small shops.** Handwritten alimentari and frutteria receipts
will mostly fail to parse. Accepted. The review screen takes manual entry.

**Per chain parser maintenance.** Lidl, Conad and In's each need their own
tuning, and a format change breaks it. Accepted as the cost of staying on
device.

**Existing repository issues, from `AGENTS.md`, to fix before any CI runs:**

- `pubspec.yaml` declares `fonts/CenturyGothic.ttf` but the file on disk is
  `.TTF`. Works on macOS, fails on a case sensitive Linux runner.
- `assets/` is declared but empty, so Git does not track it and a fresh clone
  fails to build.
- `flutter test` currently exits 1 on an empty suite. The first feature that
  adds logic ships the first real test and turns the gate green.

**No open planning TODOs.** The three questions left open during discovery are
settled: the interface is English, costs split equally five ways, and the
manual shopping list never auto populates. Low stock suggestions on the home
screen and the manual list stay two separate things.
