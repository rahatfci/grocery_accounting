# Coding Standards

> Your conventions. Tuned to this project by `/onboard` on 2026-09-20. Flutter
> 3.44.4, Dart 3.12.2, sound null safety, `flutter_lints` ^6.0.0.
>
> `AGENTS.md` carries the public summary of these conventions. Keep the two in
> step when you change a rule here.

## Dart

- Sound null safety on. Never use `!` to silence a nullable you have not checked.
- Prefer `final` for locals and fields. Use `const` wherever the value allows it.
- No `dynamic` unless decoding genuinely untyped data, and narrow it immediately.
- Model classes are immutable with `copyWith`, not mutable bags of fields.
- Prefer sealed classes or enums over string constants for closed sets of states.
- Follow `flutter analyze` with the project's lint set. A new lint warning is a
  build failure, not a style note.

## Widgets

- Prefer `StatelessWidget`. Reach for `StatefulWidget` only when the widget owns
  state that survives a rebuild.
- `const` constructors wherever possible. This is the single highest-value
  rebuild optimization in Flutter and it is free.
- Keep `build()` free of business logic, I/O, and allocation-heavy work. It runs
  often and unpredictably.
- Extract a widget rather than a `_buildSomething()` method returning a Widget.
  Extracted widgets get their own rebuild boundary; helper methods do not.
- Always `dispose()` controllers, focus nodes, animation controllers, and stream
  subscriptions. A missing dispose is a leak, and it is the most common review
  finding in Flutter code.
- Give `Key`s to widgets in lists that reorder, insert, or delete.

## State management

**Bloc is the established solution.** `flutter_bloc` for state, `get_it` with
`injectable` for dependency injection. Do not introduce a second state
management library.

The packages are decided but not yet in `pubspec.yaml`; they land with the first
feature that needs them.

- One bloc or cubit per feature concern, not one per screen. Use `Cubit` when the
  feature has no events worth naming, `Bloc` when it does.
- States are sealed classes with an exhaustive `switch`, not one class carrying
  nullable fields and an `isLoading` boolean.
- Events are named for what the user did (`ReceiptConfirmed`), not for what the
  bloc should do (`UpdateStock`).
- Blocs orchestrate. They call repositories and pure functions and emit states.
  They hold no calculations and never touch Firebase directly.
- Business logic lives outside widgets **and outside blocs**, as pure Dart, so it
  is unit testable without a `WidgetTester` or a bloc harness.
- Close every `StreamSubscription` a bloc opens in its `close()` override.
- Inject dependencies through constructors registered in `get_it`. Never reach
  for `GetIt.instance` inside a widget or a bloc body: it hides the dependency
  and makes the class untestable.

## File organization

Clean architecture per feature, with the domain layer deliberately omitted.
`lib/` currently holds only `main.dart`; create each directory when a feature
needs it, not in advance.

```
lib/
  core/                    # DI container, theme, failures, formatters
  features/
    <feature>/
      data/                # Firestore datasource, DTOs, repository
      logic/               # pure Dart calculations
      presentation/        # bloc, pages, widgets
```

- **`data/`** owns everything that knows Firebase exists. DTOs map to and from
  Firestore, and no `DocumentSnapshot` escapes this layer. The repository's
  abstract interface sits next to its implementation here, so a fake can be
  registered in tests.
- **`logic/`** is pure Dart with no Flutter and no Firebase imports. Stock maths,
  run out dates, receipt parsing, monthly settlement. This is where the unit
  tests land, and a calculation that ends up in a widget or a bloc is in the
  wrong place.
- **`presentation/`** is bloc plus UI. Pages compose widgets; widgets stay small.
- **`core/`** holds only what more than one feature needs. Shared widgets go in
  `core/widgets/`.
- `lib/main.dart` stays thin: bootstrap Firebase, configure `get_it`, run the app.

**There is no `domain/` layer, by decision.** Entities live with the feature and
repository interfaces live in `data/`. A separate abstract layer is not worth the
file count on a project this size, and `logic/` already provides the pure,
framework-free place that makes the business rules testable.

Theme tokens (seed color `0xFF244F3D`, `CenturyGothic` font family) are inline in
`lib/main.dart` today. Move them into `core/` the first time a second file needs
them, not before.

## Naming

- Files: `snake_case.dart`, matching the primary class where there is one
- Classes and types: `PascalCase`
- Members and locals: `camelCase`
- Private members: leading underscore
- Constants: `lowerCamelCase` (Dart convention, not `SCREAMING_SNAKE_CASE`)

## Platform channels and native code

- Wrap every `MethodChannel` call in a typed Dart method with explicit error
  handling. A `PlatformException` must never reach the widget tree raw.
- Every channel needs both an iOS and an Android implementation before the
  feature is done. A channel implemented on one side is a half-built feature,
  not a working one.
- Guard platform-only code with `Platform.isIOS` / `Platform.isAndroid`, or
  better, `defaultTargetPlatform`, so tests can override it.

## Async

- Never swallow errors in a `Future`. Handle them or let them propagate.
- Check `mounted` before calling `setState` after an `await`.
- Cancel `StreamSubscription`s in `dispose`.
- Prefer `FutureBuilder` and `StreamBuilder` over manual state juggling for
  simple one-shot loads.

## Testing

The blueprint installs no extra test runner. Flutter ships one. Testing is on by
default for this stack because `flutter test` exists in every project.

**The opt-in switch is one signal: a `test` command in the Commands section of
`AGENTS.md`.** For Flutter that command is present from install, so tests are a
gate for logic-bearing steps.

**Current state: the suite is empty and `flutter test` exits 1.** `/onboard`
deleted the stale `flutter create` counter test, which asserted against a screen
`lib/main.dart` no longer has. That red gate is correct, not a bug to route
around: an empty suite should fail. The first feature adding logic or a screen
ships the first real test and turns it green.

- **Unit tests** for pure logic: parsers, formatters, validators, mappers,
  repository logic with a faked data source. Fast, no `WidgetTester`.
- **Widget tests** for rendering and interaction on a single screen or component:
  what is on screen, what a tap does, what a failed load shows. These run
  headless in seconds and are the workhorse of this stack.
- **Golden tests** only for components whose exact visual output is the
  requirement. They are brittle across platforms and font versions, so keep them
  few and regenerate deliberately.
- **Integration tests** (`integration_test/`) for flows crossing screens,
  plugins, or real platform behavior. These need a device or simulator and take
  minutes, so they are a `/check` tier, not a per-step gate.
- **The gate:** a step that adds logic or a screen must ship a passing unit or
  widget test in the same reviewable diff. `flutter test` must be green before
  the step is approved and before `/complete` merges.
- Test files mirror source: `lib/features/cart/cart_total.dart` gets
  `test/features/cart/cart_total_test.dart`.
- An empty suite should fail, not pass.

## Performance

- Watch for jank in lists: use `ListView.builder`, not a `ListView` with a mapped
  children list, for anything unbounded.
- Do not rebuild whole subtrees to change one value. Push state down or use a
  targeted listenable.
- Decode and resize images to their display size. Full-resolution images in a
  list are the most common cause of memory pressure on low-end Android.
- Profile with `flutter run --profile` on a real device, never in debug mode.
  Debug builds are not representative and a performance claim from a debug build
  is not evidence.

## Code Quality

- No commented-out code unless specified
- No unused imports or variables
- Keep functions and `build()` methods short. Extract rather than nest.

## Comments

Write code that explains itself; comment only what the code cannot say.
Over-commenting is a common AI tell, so resist it.

- Comment the **why**, not the **what**. Delete any comment that restates code.
- No banner blocks, section dividers, or step-by-step narration.
- A comment earns its place when it captures a non-obvious decision, a gotcha or
  platform workaround, or a link to an issue. Platform quirks genuinely deserve
  comments; widget structure does not.
- Keep doc comments minimal: one line on an exported type or function.

## Writing

- No em dashes (U+2014) in generated content: docs, comments, commit messages,
  READMEs, specs. They read as AI-generated.
- Use a hyphen for `term - description` separators; rephrase prose with commas,
  parentheses, or a colon. Avoid en dashes and the ellipsis character too.
