# Feature: Firebase and sign in

**From build-plan:** feature 1
**Build attempt:** 1
**Branch:** feature/firebase-and-sign-in
**Status:** verified

## Goal

Turn the current Firebase-initialized demo scaffold into a signed-in app shell.
A household member opens the app, signs in with an account created by hand in
the Firebase console, and lands on Home. The session survives a relaunch. Sign
out returns to the sign-in screen. Firestore and Storage reject every read and
write from an unauthenticated client.

Nothing else in the product is built here. Home is a shell with a placeholder
body; the capture button, running low and the shopping list arrive with their
own features.

## In scope

- `lib/main.dart` reduced to bootstrap: Firebase init, Firestore settings, DI,
  `runApp`.
- Theme tokens moved out of `main.dart` into `core/`, unchanged in value.
- Firestore offline persistence enabled at bootstrap on all three platforms.
- `Result` sealed type and `AuthFailure` sealed type with a pure code-to-failure
  mapper, plus the first passing tests in the suite.
- `AuthRepository` interface and its Firebase implementation, registered through
  `get_it` with `injectable`.
- `AuthCubit` with sealed states, subscribed to Firebase auth state changes.
- Sign-in screen: email and password, validation, loading, failure messages,
  responsive width.
- Auth gate choosing between sign-in and Home, and a sign-out action on Home.
- `firestore.rules` and `storage.rules` requiring `request.auth != null`, plus
  the `firebase.json` and `.firebaserc` needed to deploy them, and the deploy
  itself.

## Out of scope

- Any signup, invitation, password reset or account management UI. The overview
  lists these as explicit non-requirements; accounts are created by hand.
- Writing or reading `users/{userId}`. No Firestore document is read or written
  by this feature. See Open questions.
- Roles, permissions, per-user ownership rules or multi-tenancy. The rules are
  flat and authentication-only by decision.
- Home content: receipt capture, running low, shopping list, reports.
- A router package. Two screens do not need one.
- Repairing the two pre-existing repo defects (font filename case, empty
  `assets/`). They are real, they are recorded in `AGENTS.md` under Known issues,
  and they do not block any done-when below on this machine. They belong in
  `/fix`, not buried in this feature.
  - **Amended 2026-09-21 by the user:** the font filename case fix was already
    present as an uncommitted worktree change when implementation began, and the
    user chose to keep it in this feature's commit rather than split it into a
    `/fix`. `pubspec.yaml` now declares `.TTF`, matching the files on disk, so
    the build no longer breaks on a case-sensitive filesystem and that entry has
    been removed from `AGENTS.md`. The empty `assets/` defect is untouched and
    still open.
- macOS desktop. `firebase_options.dart` throws `UnsupportedError` there on
  purpose and macOS is not a shipped target, even though `flutter devices` lists
  it.

## Build loop

`workflow.stepReview` is `every`, so stop for approval after each step below.
`workflow.checkpointCommits` is `enabled`, so offer a checkpoint commit on the
feature branch after a step passes. `/complete` makes the final feature commit
and merge.

## Build steps

- [x] **1. Bootstrap, theme, and app shell**
  Move the seed color `0xFF244F3D`, the `CenturyGothic` family and the app bar
  theme from `lib/main.dart` into `lib/core/theme/app_theme.dart` with their
  current values. Add `lib/app.dart` holding the root `MaterialApp`. Reduce
  `lib/main.dart` to: ensure bindings, `Firebase.initializeApp`, enable Firestore
  offline persistence, configure DI (added in step 3, so leave the call out for
  now), `runApp`. Keep the existing placeholder body so the app still renders.
  - Check the exact `cloud_firestore` 6.10 API for enabling persistence on web
    versus mobile before writing it; do not guess between `Settings` and a
    `enablePersistence` call.
  - **Done when:** `flutter analyze` is clean; the app launches on Rahat's iPhone
    and on Chrome showing the same deep green app bar and title as before, with
    no new exceptions in the run log (tier 3, because bootstrap and plugin
    initialization do not hot reload).

- [x] **2. Result, AppUser, and auth failure mapping, with the first tests**
  Add `lib/core/result.dart` with a sealed `Result<T>` (`Ok` / `Err`). Add
  `lib/features/auth/logic/app_user.dart` with `AppUser(uid, email)` using
  `equatable`. Add `lib/features/auth/logic/auth_failure.dart` with a sealed
  `AuthFailure` and a pure `authFailureFromCode(String code)`. No Flutter and no
  Firebase imports in `logic/`.
  Map at least these `FirebaseAuthException` codes to distinct failures with
  user-facing English text:
  `invalid-credential`, `invalid-email`, `user-not-found`, `wrong-password` ->
  "Email or password is not correct"; `user-disabled` -> "This account has been
  disabled"; `too-many-requests` -> "Too many attempts. Wait a moment and try
  again"; `network-request-failed` -> "No connection. Check your network and try
  again"; any unrecognised code -> "Something went wrong. Try again".
  Add `test/features/auth/logic/auth_failure_test.dart` covering every mapped
  code and one unknown code.
  - **Done when:** `flutter test` passes and is no longer an empty red suite;
    `flutter analyze` is clean (tier 1).

- [x] **3. Auth repository and DI**
  Add `lib/features/auth/data/auth_repository.dart` with the abstract
  `AuthRepository`: `Stream<AppUser?> authStateChanges()`,
  `Future<Result<AppUser>> signIn({required String email, required String
  password})`, `Future<void> signOut()`. Add the Firebase implementation beside
  it; it is the only file that imports `firebase_auth`, catches
  `FirebaseAuthException`, and calls `authFailureFromCode(e.code)`. No
  `firebase_auth` type escapes this layer. Add `lib/core/di/injection.dart` with
  `get_it` plus `injectable`, run
  `dart run build_runner build --delete-conflicting-outputs`, and call the
  configure function from `main.dart`.
  - **Done when:** `flutter analyze` is clean; `flutter test` still passes;
    `injection.config.dart` is generated and committed; the app still launches on
    iPhone and Chrome with no new log errors (tier 3, because DI runs at
    startup).

- [x] **4. AuthCubit with sealed states**
  Add `lib/features/auth/presentation/auth_state.dart` with sealed states
  `AuthInitial`, `AuthSignedOut`, `AuthSubmitting`, `AuthSignInFailure(AuthFailure)`,
  `AuthSignedIn(AppUser)`, and `auth_cubit.dart` taking `AuthRepository` through
  its constructor. The cubit subscribes to `authStateChanges()` on creation and
  cancels that subscription in `close()`. `signIn` emits `AuthSubmitting` then
  either `AuthSignInFailure` or lets the stream drive `AuthSignedIn`. `signOut`
  calls the repository.
  Add `test/features/auth/presentation/auth_cubit_test.dart` using a hand-written
  fake `AuthRepository` and `expectLater` with `emitsInOrder`. Do not add
  `bloc_test`, `mockito` or `mocktail`; nothing here needs them.
  - **Done when:** `flutter test` passes with tests covering a successful sign
    in, a failed sign in, sign out, and that `close()` cancels the subscription;
    `flutter analyze` is clean (tier 1).

- [x] **5. Sign-in screen**
  Add `lib/features/auth/presentation/sign_in_page.dart`. One column on phone,
  and on a wide window the form is centred and constrained rather than stretched
  edge to edge, because the overview requires responsive from the start.
  Required behaviour:
  - Email field: `TextInputType.emailAddress`, autofill hint, labelled.
  - Password field: obscured, labelled, visibility toggle, autofill hint,
    keyboard submit action triggers sign in.
  - Empty or malformed email, or empty password: field-level error text tied to
    that field through the form field's `errorText`, not a snackbar only.
  - `AuthSubmitting`: the button shows progress and is disabled; fields are not
    editable; a second submit cannot be queued.
  - `AuthSignInFailure`: the mapped message is shown in a place a screen reader
    announces, never the raw `FirebaseAuthException` message or code.
  - Editing either field clears the previous failure message.
  - Dispose both `TextEditingController`s and any `FocusNode`.
  Add `test/features/auth/presentation/sign_in_page_test.dart` with a fake
  repository: empty submit shows both validation errors; a failing sign in shows
  the mapped message; the button is disabled while submitting; typing clears the
  previous error.
  - **Done when:** `flutter test` passes with those widget tests; `flutter
    analyze` is clean (tier 1). Live platform evidence is deliberately deferred
    to step 6, where the screen is first reachable.

- [x] **6. Auth gate, Home shell, and sign out**
  Add `lib/features/auth/presentation/auth_gate.dart`: a `BlocBuilder` over
  `AuthCubit` with an exhaustive switch - `AuthInitial` shows a centred progress
  indicator, `AuthSignedOut` / `AuthSubmitting` / `AuthSignInFailure` show
  `SignInPage`, `AuthSignedIn` shows `HomePage`. Provide the cubit above the gate
  in `lib/app.dart`. Add `lib/features/home/presentation/home_page.dart`: a
  `Scaffold` with the app bar, the signed-in email, a sign-out action, and a
  short placeholder body. No capture button, no running low, no shopping list.
  - **Done when**, on iPhone, on an Android emulator and on Chrome:
    signing in with a valid console-created account lands on Home; a wrong
    password shows "Email or password is not correct" and stays on sign in;
    sign out returns to the sign-in screen; killing and relaunching while signed
    in lands on Home without re-entering credentials; on Android the system back
    gesture on Home does not drop the user onto the sign-in screen; the run log
    is clean and no overflow stripes appear at phone width or Chrome desktop
    width (tier 3). If no Android emulator is running, start one; if none can be
    started, record the Android column as unverifiable rather than inferring it
    from iOS.
  - **Evidence 2026-09-21:** Android emulator and Chrome proven at tier 3 for
    every interactive done-when, including process death and page reload. iOS
    proven at tier 3 for build, install, launch and a clean run log; its
    interactive done-whens were **not exercised and are assumed** under the
    verification-cost policy in `platform.md`. `flutter screenshot` refuses on a
    physical iPhone and there is no XCUITest harness, so driving iOS needs a
    person.

- [x] **7. Firestore and Storage security rules**
  Add `firestore.rules`:
  `rules_version = '2';` with `match /databases/{database}/documents { match
  /{document=**} { allow read, write: if request.auth != null; } }`.
  Add `storage.rules`: `rules_version = '2';` with `match /b/{bucket}/o { match
  /{allPaths=**} { allow read, write: if request.auth != null; } }`.
  Add `firebase.json` pointing at both, and `.firebaserc` with project
  `grocery-accounting-993ed`.
  Deploying is a user action: the Firebase CLI is **not installed on this
  machine** (`which firebase` finds nothing, Node 26.3.0 is available). The user
  installs `firebase-tools`, runs `firebase login`, confirms that Firestore and
  the default Storage bucket are provisioned in the console, then runs
  `firebase deploy --only firestore:rules,storage`.
  - **Done when:** both rules files are committed and contain exactly the
    authentication-only contract above with no role or ownership clauses; the
    deploy reports success; and in the Firebase console Rules Playground an
    unauthenticated `get` of `/databases/(default)/documents/items/test` is
    denied while the same request with an authenticated uid is allowed, and the
    equivalent unauthenticated Storage read is denied.
  - **Partial 2026-09-21.** Firestore: deployed and proven. `firebase deploy
    --only firestore:rules` reported "released rules firestore.rules to
    cloud.firestore". Verified against the live REST API: an unauthenticated
    read of `/items/test` returns 403 PERMISSION_DENIED, the same read with a
    real ID token returns 404 NOT_FOUND, so the rule admits the request and only
    the document is missing.
    **Storage: deployed, behaviour unproven.** After the bucket was created, the
    CLI still refused with "Firebase Storage has not been set up" while
    `firebase.json` used the object form for `storage`. Naming the bucket
    explicitly fixed it, so `firebase.json` keeps the array form with
    `"bucket": "grocery-accounting-993ed.firebasestorage.app"`. The deploy then
    reported "released rules storage.rules to firebase.storage". The rule's
    deny behaviour is **not empirically proven**: the Storage REST API returns
    404 for both a missing object and a denied read, so unauthenticated and
    authenticated GETs are indistinguishable. Confirm in the console Rules
    Playground, or by uploading one object and reading it anonymously.

## Files / areas

```
lib/main.dart                                          modified, thin bootstrap
lib/app.dart                                           new
lib/core/theme/app_theme.dart                          new
lib/core/result.dart                                   new
lib/core/di/injection.dart                             new
lib/core/di/injection.config.dart                      generated, committed
lib/features/auth/logic/app_user.dart                  new
lib/features/auth/logic/auth_failure.dart              new
lib/features/auth/data/auth_repository.dart            new
lib/features/auth/data/firebase_auth_repository.dart   new
lib/features/auth/presentation/auth_state.dart         new
lib/features/auth/presentation/auth_cubit.dart         new
lib/features/auth/presentation/sign_in_page.dart       new
lib/features/auth/presentation/auth_gate.dart          new
lib/features/home/presentation/home_page.dart          new
firestore.rules                                        new
storage.rules                                          new
firebase.json                                          new
.firebaserc                                            new
test/features/auth/logic/auth_failure_test.dart        new
test/features/auth/presentation/auth_cubit_test.dart   new
test/features/auth/presentation/sign_in_page_test.dart new
```

Untouched and already correct: `lib/firebase_options.dart`,
`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, the
`com.google.gms.google-services` Gradle plugin, iOS deployment target 15.5, and
`web/index.html`, which correctly carries no hand-written Firebase script tags.

## Data / contracts

**Firestore and Storage documents:** none. This feature reads and writes no
application data. `users/{userId}` is untouched.

**Authentication:** Firebase Auth email and password only, against accounts
created by hand in the Firebase console. No self registration, no password
reset, no profile editing. Project `grocery-accounting-993ed`.

**Trusted actor:** `request.auth.uid` from Firebase Auth. There are no roles and
no per-document ownership, by explicit decision in the overview's usage model.
Every signed-in household member may read and write everything.

**Security rules contract:**

| Surface | Unauthenticated | Authenticated |
| --- | --- | --- |
| Any Firestore document | denied, read and write | allowed, read and write |
| Any Storage object | denied, read and write | allowed, read and write |

**Failure surface:** the repository converts `FirebaseAuthException.code` into a
sealed `AuthFailure`. Presentation renders only mapped English text. A raw
Firebase message, code or stack trace is never shown or logged to the user.

**Offline:** Firestore persistence is enabled at bootstrap on iOS, Android and
Web. This feature stores nothing, so persistence has no data to survive on yet;
it is wired here because bootstrap is the only place it can be set, and its real
behaviour is first observable in feature 2.

## Testing

`flutter test` is the gate and is **red today with an empty suite**, which is the
intended state. Step 2 is the step that turns it green, and every step after it
must keep it green.

- Unit, `test/features/auth/logic/auth_failure_test.dart`: every mapped code plus
  an unknown code.
- Unit, `test/features/auth/presentation/auth_cubit_test.dart`: state sequences
  for success, failure, sign out, and subscription cleanup on `close()`, against
  a hand-written fake `AuthRepository`.
- Widget, `test/features/auth/presentation/sign_in_page_test.dart`: validation
  errors, mapped failure message, disabled submitting state, error clearing.
- No new test dependency. `flutter_test` and hand-written fakes cover all of it.
- No `integration_test/` directory exists and this feature does not create one.
  Cross-screen and real-device behaviour is proven at tier 3 by hand in step 6.

**Platform matrix.** The done-whens must hold on iOS, Android and Web.

| Done-when | iOS | Android | Web |
| --- | --- | --- | --- |
| App boots with Firebase initialized, clean log | required | required | required |
| Sign in with a valid account reaches Home | required | required | required |
| Wrong password shows the mapped message | required | required | required |
| Sign out returns to sign in | required | required | required |
| Session survives relaunch | required | required | required |
| System back on Home does not fall back to sign in | skip | required | skip |
| Form is constrained and centred at desktop width | skip | skip | required |
| Rules deny unauthenticated access | console proof, platform independent | | |

Targets confirmed on 2026-09-20: Rahat's iPhone (iOS 26.5, wireless) and Chrome
153. **No Android device or emulator is currently connected.** Start one before
claiming the Android column, or report it unverifiable.

## Notes for the AI

- `flutter analyze` is clean right now. Keep it clean; a new warning is a
  failure, not a style note.
- Do not run the app on macOS desktop. `flutter devices` lists it, and
  `DefaultFirebaseOptions.currentPlatform` throws `UnsupportedError` there by
  design. Always pass `-d`.
- No router package. The gate is a conditional root driven by `AuthCubit`; that
  is not a second state management solution, it is the established one.
- Never call `GetIt.instance` inside a widget or a bloc body. Inject through
  constructors.
- Sealed states with an exhaustive `switch`, not one class with nullable fields
  and an `isLoading` flag.
- `logic/` has no Flutter and no Firebase imports. `data/` is the only place
  `firebase_auth` appears.
- Keep Home a placeholder. Later features own its content.
- The two recorded repo defects stay out of this branch: `pubspec.yaml` declares
  `fonts/CenturyGothic.ttf` while the files on disk are `.TTF`, and `assets/` is
  declared but empty so a fresh clone fails to build. Neither affects this work
  on macOS, iPhone or Chrome. Raise them with `/fix`.
- Do not commit any additional Firebase credential file. The values in
  `firebase_options.dart` are client identifiers and are already tracked;
  the security boundary is Auth plus the rules from step 7.

## Open questions

- **Who creates `users/{userId}`?** The data model says the collection "mirrors
  hand-created Firebase Auth accounts" but never says whether the app upserts the
  document on first sign in or whether it is typed into the console beside the
  Auth account. This is shared persisted data, so it is a product decision, not
  an implementation detail. It does not block this feature, which touches no
  Firestore document, and Home shows the Auth email rather than a stored
  `displayName`. It must be answered before feature 3, which needs a payer list,
  and feature 4, which reports per person by name.

## Findings

### 1/F-01 [P1] accepted - Nothing bounds which accounts satisfy `request.auth != null`

**File:** firestore.rules:8, storage.rules:7
**Found:** 2026-09-21 by /audit (scope: current; lens: security)
**Why it matters:** The flat, role-free rules are correct against the stated
requirement. `project-overview.md` says "No roles, no per user ownership rules",
and roles, multi-tenancy and adversarial users are explicit non-requirements.
That part is confirmed and is not a finding.

What is not bounded is membership. The overview also says "Firebase is internet
facing, so authentication is a real boundary", and `request.auth != null` admits
any account the Firebase project will mint, not only the five hand-created ones.
"Accounts are created by hand in the console" is a property of the app's UI, not
of the backend: Identity Toolkit's `accounts:signUp` endpoint is callable by
anyone holding the public Web API key whenever the Email/Password provider is
enabled and sign-up has not been explicitly disabled, and that key is necessarily
public (it ships in `lib/firebase_options.dart`, in the Firebase Hosting web
bundle named under Deployment, and in every distributed binary). If sign-up is
open, a stranger mints an account and then has full read and write on every
Firestore collection and every Storage object, including the receipt photographs
feature 9 will store. Nothing in this delta, in `firebase.json`, or in
`.firebaserc` constrains that set.

Status is `unverified` rather than `open`: whether sign-up is actually open is a
Firebase console setting, not repository state, and confirming it needs a network
call against the live project that this read-only review must not make.

**Suggested fix:** Check Firebase console > Authentication > Settings > User
actions and confirm "Enable create (sign-up)" is off. If it is off, close this as
`invalid` and record the console evidence. If it is on, either turn it off, or
pin the boundary in the rules themselves, for example
`allow read, write: if request.auth != null && request.auth.uid in [<the five uids>];`
which keeps the flat, role-free model the overview asked for while making
membership explicit and reviewable in Git. No current requirement is lost either
way; the overview never asked for open registration, it asked for the opposite.

**Verified open 2026-09-21.** Promoted from `unverified` to `open` on live
evidence. A `POST accounts:signUp` with the public Web API key from
`lib/firebase_options.dart` succeeded and returned an `idToken`, creating a real
account on `grocery-accounting-993ed`. The account was deleted immediately via
`accounts:delete` and its absence confirmed (`INVALID_LOGIN_CREDENTIALS`). This
was run after the user reported disabling sign-up in the console, so the console
change had not taken effect on the endpoint at that moment. The exposure is real
and currently live: anyone holding the public API key can mint an account and
gain full read and write on every Firestore collection and Storage object.
**Resolution:** Accepted by the user on 2026-09-21, in the current chat, after
being shown live evidence that `accounts:signUp` still succeeds and after being
offered two remedies. Their instruction was "merge anyway". No code or console
change was made, so the exposure described above is unchanged and live at merge
time: anyone holding the public Web API key can mint an account and gain full
read and write on every Firestore collection and Storage object. Reopen this as a
`/fix` before the web build is hosted or any real spending or receipt data is
entered.

## Independent review

**Status:** passed
**Target commit:** ec315a599c5aff823655c63c96136bd0d7b275a8
**Base commit:** dac84b844966f79ec94cdd85ed1e9b3ef9b50647
**Base ref:** main
**Spec hash:** a72ff83f9df184642eaec88c4d3d9ee8dd282028c1d0ed82c0f6471aeaed72fa
**Prepared by:** claude
**Builder model:** claude-opus-5
**Requested reviewer:** claude
**Requested model:** runtime default (exact model not known until reviewer starts)
**Requested execution:** automatic
**Requested at:** 2026-09-21T08:09:27Z
**Workflow:** regular
**Check required:** no
**Reviewer adapter:** claude
**Reviewer model:** claude-opus-5
**Reviewer context:** fresh subagent
**Actual execution:** automatic
**Reviewed at:** 2026-09-21T08:16:51Z
**Scope:** current
**Lenses:** quality, security, performance, tests
**Verdict:** passed
**Check result:** not-required

## Commands

- `git rev-parse HEAD`: pass, equals Target commit
- `git merge-base main ec315a599c5aff823655c63c96136bd0d7b275a8`: pass, equals Base commit
- `shasum -a 256 blueprint/context/current-feature.md`: pass, equals Spec hash
- `git status --porcelain`: pass, only `blueprint/context/review.md` differs from the target
- `git diff --stat dac84b844966f79ec94cdd85ed1e9b3ef9b50647..ec315a599c5aff823655c63c96136bd0d7b275a8`: pass, 30 files, 1635 insertions, 49 deletions, all read
- `flutter analyze`: pass, "No issues found!"
- `flutter test`: pass, 31 of 31 across 4 test files
- `dart format --output=none --set-exit-if-changed lib test`: pass, 21 files, 0 changed
- `grep` for `!` null assertions, `GetIt.instance` in widgets or blocs, em dashes, skipped or focused tests: pass, none present
- `firebase emulators:exec` rules unit tests: unavailable, the Firebase CLI is not installed on this machine
- `flutter build` for any platform: not run
- `/check` device or browser verification: not run, Check is not required for this request

## Evidence

- All 30 files in the delta were read at their current contents, not only as a diff. All four lenses were applied to the whole range.
- Security, rules: `firestore.rules:8` and `storage.rules:7` are exactly the authentication-only contract the spec specifies, with no role or ownership clause. Checked against `project-overview.md`: the usage model states "No roles, no per user ownership rules" and lists roles, multi-tenancy and adversarial users as explicit non-requirements, so the flat shape is correct and is not under-restrictive for the data model. Any signed-in member being able to rewrite another member's `users/{userId}` or a purchase's `paidByUserId` is the stated design, not a defect. What the rules do not bound is which accounts exist, raised as F-01.
- Security, message leakage: confirmed clean. `authFailureFromCode` returns one of five fixed English strings; `FirebaseAuthException.message` and `.code` are never read outside `firebase_auth_repository.dart:36`; the cubit's catch discards the exception object entirely. Asserted by `auth_failure_test.dart:49-62` and `sign_in_page_test.dart:72-87`.
- Security, secrets: no credential or secret is introduced. `firebase_options.dart` is untouched by this delta, and Firebase client identifiers are public by design.
- Quality, `_onAuthStateChanged` suppression (auth_cubit.dart:53): refuted as a defect. `AuthGate` maps `AuthSubmitting` and `AuthSignInFailure` to `SignInPage` (auth_gate.dart:19-21), so neither suppressed state can leave a signed-out user on a signed-in screen. A signed-out event arriving while state is `AuthSignedIn` is not suppressed and correctly returns the user to sign in.
- Quality, `Result<T, E>` against the spec's `Result<T>`: sound deviation. The second parameter makes `AuthFailure` explicit in the repository signature rather than implicit, costs nothing, and is more strongly typed than the spec's prose. Not raised.
- Quality, standards compliance: no `!` null assertion anywhere in `lib/` or `test/`; `_SignInPageState.dispose` disposes both controllers and the focus node before `super.dispose()`; `AuthCubit.close()` cancels the subscription, proved by `auth_cubit_test.dart:166`; `GetIt` appears only in `injection.dart` and `main.dart`, never in a widget or bloc; `logic/` imports neither Flutter nor Firebase; `data/` is the only place `firebase_auth` appears; no em dashes in added content.
- Performance: no findings beyond F-07. The feature performs one auth call and holds one stream subscription, with no lists, images, queries or unbounded work. `SignInPage` wraps its whole form in one `BlocBuilder` with no `buildWhen`, which is technically the "do not rebuild whole subtrees" pattern the standards warn about, but the subtree is two fields and a button, keystrokes do not emit once the failure is cleared, and pushing state down would add widgets for no measurable gain. Considered and deliberately not raised as proportional.
- Tests: the 31 tests constrain behaviour rather than execute it. They carry negative assertions (`find.textContaining('user-not-found'), findsNothing`), `reason` strings that state the invariant being protected, a real submitting-state gate via `Completer`, a wide-window layout assertion, and a subscription-cleanup assertion. No skipped, focused or placeholder tests; no shared mutable state between tests; `setUp` builds a fresh fake each time. The one real gap is `FirebaseAuthRepository`, raised as F-05. `FakeAuthRepository` never closes its `StreamController`, which is harmless in a single-shot test process and was not raised.
- Spec conformance: every in-scope item in `current-feature.md` is present in the delta, including the amended `.TTF` font-case fix in `pubspec.yaml:43,45`. Nothing out of scope was built: Home is a placeholder, no router was added, no Firestore document is read or written, and no `bloc_test`, `mockito` or `mocktail` dependency appeared.

## Findings

- F-01 [P1] unverified - Nothing bounds which accounts satisfy `request.auth != null`
- F-02 [P2] open - `AuthSubmitting` has no exit unless the auth stream delivers a user
- F-03 [P2] open - The auth subscription has no error handler, stranding the app on the startup spinner
- F-04 [P2] open - The bare `catch (_)` discards the error and its stack trace
- F-05 [P3] open - `FirebaseAuthRepository` has no test, including its null-user branch
- F-06 [P3] open - `BlocProvider` takes ownership of a cubit it did not create
- F-07 [P3] open - Web Firestore persistence takes the default single-tab manager
- F-08 [P3] open - The sign-out future is dropped at the call site
- F-09 [P3] open - `blueprint/` and `.claude/` are tracked, against the stated local-only contract

## Remaining risk

- **F-01 is the one to resolve first and it does not block this receipt only because its status is `unverified`.** Whether the Firebase project accepts anonymous `accounts:signUp` is console state, not repository state, and the one call that would settle it is a network write against the live project that a read-only review must not make. Confirm it by hand before merge.
- `firebase emulators:exec` with `@firebase/rules-unit-testing` could not run: the Firebase CLI is not installed on this machine (`which firebase` finds nothing; Node 26.3.0 is present). Both rules files are therefore reviewed by reading only, never executed against an emulator, so nothing in this review proves the deployed rules match the committed files.
- The Storage rule's deny behaviour remains unproven, as step 7 of the spec itself records: the Storage REST API returns 404 for both a missing object and a denied read, so the two are indistinguishable without the console Rules Playground. A failed or misapplied deploy would most likely leave Firebase's own default, which is no more permissive, so the risk is low but it is not zero and it is not proven.
- No `flutter build` was run for any platform, so this review carries no compilation evidence beyond `flutter analyze` and the headless test run.
- No device, emulator or browser was driven from this session. Check was not required for this request, and the iOS interactive done-whens in step 6 remain recorded by the spec as assumed rather than proven.
- No dependency vulnerability scan was run, and no scanner output exists in the project to inspect. Reading `pubspec.yaml` is not a vulnerability scan.
- The two `unverified`-adjacent conditions behind F-02 and F-03 (a dropped or erroring auth-stream event) cannot be reproduced from the repository, so their severity rests on code reading rather than on an observed failure.
- The pre-existing empty `assets/` defect recorded in `AGENTS.md` is untouched by this delta and still breaks a fresh clone. Correctly out of scope here, but still open.
