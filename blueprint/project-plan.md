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
| Backend | Firebase: Auth, Firestore. Supabase Storage for receipt photos |
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
image leaving the device except into the household's own storage bucket.

## 6. Monetize - How will this make money?

It does not. Personal project, one household, no business model, no ads, no
subscriptions. If it ever goes public this section gets rewritten.

## 7. UI/UX - How should this look and feel?

The mobile UI is designed in Figma and is the reference for the Flutter
implementation: <https://www.figma.com/design/uALv1vykqOmzhUvG8FsHxk/Grocery-Accounting>.
The Screens page holds 19 phone screens at 390x844 with a clickable prototype
starting at the splash; the Components page holds the component library; the
variables and styles carry the tokens. Light theme only.

**Visual language.** Clean and minimal: light surfaces (`#F5F6F8` background,
white cards), dark navy text (`#0F1D33`), and the existing seed colour
`0xFF244F3D` as the brand green for primary actions. Colour follows meaning for
the household:

- Green (`#1A7F55`) is in the member's or the household's favour: paid over
  the equal share, stock added, spend down on last month.
- Red (`#CF3434`) is against: paid under the share, running low or out, an
  unmatched receipt line, spend up on last month.
- Amber (`#9A5B00`) is soon: runs out within days, a photo waiting to upload.

The Figma variables (`Primitives`, `Color`, `Spacing`, `Radius`) map one to
one to an `AppColors` class and the theme; each variable notes its Flutter name.

**Type.** `CenturyGothic` stays, at the two bundled weights only, 400 and 700.
Century Gothic is not available in Figma, so the file uses Urbanist as a
stand-in with the same geometric single-storey a and g. Its 13 text styles
each name the Material 3 `TextTheme` role they map to.

**Icons.** Material Symbols Rounded in Figma, `Icons.*_outlined` in Flutter,
or `Symbols.*` from `material_symbols_icons` for an exact match. Each icon
component names its Flutter icon.

**Navigation.** A bottom navigation bar with four tabs: Home, Pantry, List and
Spending. Account opens from the avatar on Home and holds the household and
sign out. Pushed screens, such as review, item detail and purchase detail,
hide the bar.

**Home screen is built around one action.** The scan hero is the largest,
most obvious thing on it, with take photo, choose from gallery and enter
manually. Above it sits one line of money: the month's spend, the change on
last month and the member's balance against their share, linking to Spending.
Below it: what is running low, and the shopping list. The full report stays one
level down, because it is read occasionally and the receipt is photographed
weekly.

**The review screen is the most important screen in the app.** It is where OCR
guesses get corrected, unknown receipt lines get mapped to items, and missing
quantities get filled in. Unmatched lines are grouped at the top under "To
match", red with a left accent and a Match button, so they are never confirmed
by accident. Who paid is a row of one-tap member chips. Matching happens on a
sheet with item search, create new item, quantity and unit, and a note that the
mapping will be remembered.

**Saving shows what the one action did.** After a save, a summary lists the
spend recorded, items restocked and created, shopping list entries cleared,
receipt lines learned, lines saved as spend only, and whether the photo is
still waiting for signal.

**Pantry, list and spending.** The pantry is grouped by category with filter
chips and a status per item. Item detail shows the derived stock, the run-out
date, log use, adjust and recount, and the stock history that explains the
number. The shopping list is its own tab; running-low items can be added to it
with one tap, but nothing is ever added automatically. Spending shows the month
total and change, each member against the equal share, spend by category and by
shop, and a purchase history where each purchase opens with its lines and its
receipt photo.

**Responsive from the start, not retrofitted.** Phone is one column and thumb
reachable. Web and tablet use the width for tables and multi column reports
rather than stretching phone layouts.

Language and formatting are Italian context: EUR as `formatEuro` writes it
(`47,85 €`), decimal comma on receipts, `dd/MM/yyyy` dates. Interface language
is English. Stock quantities print with a decimal point today (`0.3 kg`);
switching them to a comma is a small follow-up if wanted.

## 8. Deployment - Where and how will this ship?

No public store distribution. Five known users.

| Target | Approach |
| --- | --- |
| Web | Firebase Hosting, `flutter build web` |
| Android | `flutter build appbundle` or APK, internal distribution |
| iOS | TestFlight internal testers, or direct install |

Firebase project holds Auth and Firestore. Spark plan is sufficient, since
there are no Cloud Functions. Receipt photos live in a Supabase Storage bucket
(`Grocery Accounting`), because Firebase Storage needs the Blaze plan on this
project (decided 2026-09-24). No environment variables beyond the generated
`firebase_options.dart` and the Supabase URL and publishable key, both of which
ship in the app. No workers, no cron jobs, no health check, no custom domain.

**Firestore security rules are required, not optional.** The database sits on
the public internet whatever the app does. Rules restrict all reads and writes
to authenticated users. That is the whole boundary. No roles, no per user
ownership rules, no field level validation beyond what stops an accident,
because all five users are trusted and share the same data by design.

**Receipt photos are the one exception, by decision (2026-09-24).** The app
uploads with the Supabase publishable key, and a bucket policy allows it.
Anyone who extracts that key from the app or the web build could upload to the
bucket, and read it if the policy allows. Accepted for now, because receipts
are low sensitivity and the users sign in with Firebase, not Supabase.

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
