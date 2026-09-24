# AGENTS.md

Instructions for AI coding agents working in this project. This is the cross-tool
entry point: Codex, OpenCode, Cursor, GitHub Copilot, Gemini CLI, Aider, Zed,
Windsurf, and others read `AGENTS.md`.

AI tools must not add AI attribution to commits or pull requests, including AI
`Co-Authored-By` trailers or generated-by signatures. Preserve genuine human
attribution.

## What this is

Grocery Accounting, a Flutter app for tracking grocery spending.

> TODO: replace this with the real problem statement and target users once the
> planning docs are filled in.

## Stack

| Item | Value |
| --- | --- |
| Framework | Flutter 3.44.4 (stable), Dart 3.12.2 |
| SDK constraint | `^3.12.2` |
| Package manager | `flutter pub` (`pubspec.lock` committed) |
| Lints | `flutter_lints` ^6.0.0 via `analysis_options.yaml` |
| Ships on | iOS, Android, Web |
| State management | Bloc (`flutter_bloc`), DI via `get_it` + `injectable` |
| Entry point | `lib/main.dart` |

Theme tokens currently live inline in `lib/main.dart`: seed color `0xFF244F3D`
and the `CenturyGothic` font family declared in `pubspec.yaml`.

## Proportional engineering

Build for established requirements, not hypothetical scale, threats, or future
flexibility. Reuse existing code, the standard library, native platform features,
and installed dependencies before adding machinery.

- Unknown scale or extensibility defaults to the smaller reversible design. Do
  not infer enterprise, multi-tenant, hostile-user, or compliance requirements.
- Derive trust and data-integrity boundaries from actual reachability: untrusted
  input, auth/session/ownership, shared persisted data, destructive operations,
  payments, secrets, and sensitive data.
- Ask only when an unknown materially changes behavior, architecture, persisted
  data, interoperability, a real security boundary, or cost. Otherwise choose the
  simplest repository-native implementation.
- Add an abstraction, dependency, service, configuration surface, compatibility
  layer, or security mechanism only for a current requirement.
- Simplicity never removes real trust-boundary validation, data-loss prevention,
  accessibility, explicit security requirements, configured tests, or project rules.

## Commands

Confirmed against this project on 2026-09-20.

| Purpose | Command |
| --- | --- |
| Run | `flutter run` (add `-d <device-id>` to target one device) |
| Devices | `flutter devices` |
| Analyze | `flutter analyze` |
| Format | `dart format .` |
| Unit and widget tests | `flutter test` |
| Build Android debug | `flutter build apk --debug` |
| Build iOS simulator | `flutter build ios --simulator --no-codesign` |
| Build web | `flutter build web` |
| Build Android release | `flutter build appbundle --release` |
| Build iOS release | `flutter build ipa --release` |

Not available yet:

- **Verify** - no combined verification command is defined for this project.
- **Integration tests** - there is no `integration_test/` directory. Set one up
  deliberately rather than adding a runner mid-feature.

## Testing gate

`flutter test` is the test command, so tests are a gate for logic-bearing work.

**The suite is currently empty and `flutter test` exits 1.** The default
`flutter create` counter test was deleted during onboarding because it asserted
against a counter screen that `lib/main.dart` no longer has. An empty suite
failing is intentional: it should fail, not pass. The first feature that adds
logic or a screen must ship the first real test, which turns the gate green.

Test files mirror source: `lib/features/cart/cart_total.dart` gets
`test/features/cart/cart_total_test.dart`.

## Device verification

Scale device verification to the size of the change. Building and driving three
platforms costs minutes per step, and most UI work is identical Dart across all
of them. Every step is reviewed by a human, so a wrong assumption is caught and
fixed at review rather than paid for up front on every step.

| Change | What to run |
| --- | --- |
| Simple UI edit: copy, a text field, spacing, a colour | Nothing. Assume it renders. |
| Substantial UI work: new screens, layouts, components | One platform only, Android or iOS. Assume the rest. |
| Large feature, plugin, or native-only behaviour | Each platform individually. |

- Say which platform was exercised and which were assumed. An assumed platform
  is reported as `assumed`, never as a pass.
- Escalate past this table regardless of change size when the work touches
  plugins, permissions, keyboard insets, safe areas, system back, deep links, or
  web-only gaps. Those diverge even when the Dart is identical, and text metrics
  differ per platform, so an overflow can appear on one and not another.
- `flutter analyze` and `flutter test` still run on every logic-bearing step.
  This rule reduces device runs, not the automated gates.

## Conventions

- Sound null safety. Never use `!` to silence a nullable you have not checked.
- Prefer `final` for locals and fields; `const` wherever the value allows it.
- Prefer `StatelessWidget`; reach for `StatefulWidget` only for state that
  survives a rebuild.
- `const` constructors wherever possible.
- Keep `build()` free of business logic, I/O, and allocation-heavy work.
- Extract a widget rather than a `_buildSomething()` method returning a Widget.
- Always `dispose()` controllers, focus nodes, and stream subscriptions.
- Business logic lives outside widgets so it is unit testable without a
  `WidgetTester`.
- Bloc is the established state management solution. Do not introduce a second.
- Feature folders are `data/`, `logic/`, `presentation/`. There is no `domain/`
  layer. `logic/` is pure Dart with no Flutter or Firebase imports, and it is
  where business rules and their tests live.
- Files `snake_case.dart`, types `PascalCase`, members `camelCase`, constants
  `lowerCamelCase`.
- `flutter analyze` must be clean. A new lint warning is a build failure, not a
  style note.
- No em dashes in generated content: docs, comments, commit messages, READMEs.
  Use a hyphen for `term - description` separators.

## Known issues

- **The Firebase plugins apply the Kotlin Gradle Plugin, which Flutter is
  removing support for.** Every Android build prints: "Your app uses the
  following plugins that apply Kotlin Gradle Plugin (KGP): firebase_auth,
  firebase_core. Future versions of Flutter will fail to build if your app uses
  plugins that apply KGP." (`firebase_storage` was in that list until receipts
  moved to Supabase.) Builds are fine today. This is a future hard failure on
  packages the whole project depends on, and it is
  fixed by the plugin authors, not here. Watch their changelogs before upgrading
  Flutter.
- **ML Kit has no arm64 simulator slices, so iOS simulators are unusable on
  Apple Silicon.** `google_mlkit_text_recognition` pulls in GoogleMLKit,
  MLImage, MLKitCommon and MLKitVision, none of which support arm64 for iOS 26+
  simulators. A physical iPhone is therefore the only iOS target for this
  project, for every feature and not just the ones using OCR. Budget for the
  phone being present whenever iOS evidence is needed. The same plugins also do
  not support Swift Package Manager.
