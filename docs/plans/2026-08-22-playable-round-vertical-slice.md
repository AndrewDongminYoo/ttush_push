# Playable Round Vertical Slice Implementation Plan

> **Status:** Historical milestone snapshot.
> Names, paths, and non-goals below describe this milestone and are not current repository guidance; use [CLAUDE.md](../../CLAUDE.md) and the current source for the active contract.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local hot-seat 5-by-5 round that renders only Rust snapshots, accepts only Rust legal moves, shows terminal results, and restarts.

**Architecture:** `RoundController` is plain Dart and owns the value-based `RulesEngine` interaction, selection, UI-safe error state, and snapshot contract validation.
`GamePage` owns that controller and rebuilds after synchronous controller mutations.
`RoundBoard` maps screen coordinates to cells and paints tiles, pieces, selection, and legal destinations without evaluating game rules.

**Tech Stack:** Flutter Material widgets, `CustomPainter`, Dart unit and widget tests, Rust engine tests, flutter_rust_bridge 2.12.0, and Flutter integration tests on iOS and Android.

**Spec:** `docs/specs/2026-08-22-playable-round-vertical-slice.md`

## Global Constraints

- Keep Rust as the only rules authority through `RulesEngine.initialState`, `RulesEngine.legalMoves`, and `RulesEngine.applyMove`.
- Do not add a dependency or change Rust rules, the value-based bridge API, or flutter_rust_bridge generated source.
- Do not introduce Flame, Bloc, `ChangeNotifier`, a game loop, match scoring, online features, Web, sound, or complex animation.
- `RoundController` must not import Flutter and must not calculate push, tile damage, counter-push legality, knockout, or winners.
- Dart may map a legal move direction to an adjacent board coordinate for rendering and hit testing.
- Treat `winner == null` if and only if `winReason == null` as a bridge snapshot invariant.
- Regenerate FlutterGen output from edited asset declarations and regenerate `pubspec.lock` with `flutter pub get`.
- Run one heavy mobile job at a time.

## File Map

| Path                                                                                     | Responsibility                                                                                            |
| ---------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `lib/game/round/round_controller.dart`                                                   | Flutter-independent lifecycle, snapshot contract checks, legal move cache, selection, retry, and restart. |
| `lib/game/view/round_board.dart`                                                         | Board geometry, pointer-to-cell conversion, and `CustomPainter` rendering.                                |
| `lib/game/view/game_page.dart`                                                           | Material round screen, controller ownership, status, errors, terminal presentation, and input wiring.     |
| `lib/app/view/app.dart`                                                                  | Direct Material app entry to `GamePage`.                                                                  |
| `lib/bootstrap.dart`                                                                     | Rust initialization and Flutter error logging without a Bloc observer.                                    |
| `test/game/round/round_controller_test.dart`                                             | Deterministic value-only controller behavior through a fake `RulesEngine`.                                |
| `test/game/view/round_board_test.dart`                                                   | Board coordinate and pointer forwarding behavior.                                                         |
| `test/game/view/game_page_test.dart`                                                     | Ready, selection, error, terminal, and restart widget behavior.                                           |
| `test/app/view/app_test.dart`                                                            | Direct app entry rendering with an injected rules engine.                                                 |
| `engine/tests/bridge_api.rs`                                                             | Rust-owned expected parity fixture hash and counter-push assertion.                                       |
| `integration_test/rules_engine_parity_test.dart`                                         | iOS and Android native bridge execution of the fixed fixture.                                             |
| `pubspec.yaml`, `pubspec.lock`, `.github/workflows/main.yaml`, `lib/gen/assets.gen.dart` | Dependency, generated asset, and CI cleanup after template removal.                                       |

### Task 1: Add the Flutter-Independent Round Controller

**Files:**

- Create: `lib/game/round/round_controller.dart`
- Create: `test/game/round/round_controller_test.dart`
- Modify: `lib/game/game.dart`

**Interfaces:**

- Consumes: `RulesEngine`, `GameMove`, and `GameSnapshot` from `lib/game/rules/rules_engine.dart`.
- Produces: `RoundController`, `RoundStatus`, `selectedPieceId`, `legalMoves`, `moveForTappedDestination`, `retry`, and `restart` for `GamePage`.

- [ ] **Step 1: Write failing controller tests.**

```dart
test('initializes from RulesEngine and exposes only its legal moves', () {
  final controller = RoundController(engine)..initialize();

  expect(controller.status, RoundStatus.ready);
  expect(controller.snapshot, initialSnapshot);
  expect(controller.legalMoves, initialMoves);
});

test('rejects a snapshot with only one terminal field as a bridge error', () {
  final controller = RoundController(engineReturningInvalidSnapshot)..initialize();

  expect(controller.status, RoundStatus.initializationError);
  expect(controller.snapshot, isNull);
  expect(controller.error, isA<FormatException>());
});

test('restart failure keeps the terminal snapshot and retry starts a new round', () {
  final controller = RoundController(engine)..initialize();
  controller.applyMove(terminalMove);
  controller.restart();

  expect(controller.snapshot, terminalSnapshot);
  expect(controller.error, isNotNull);
  controller.retry();
  expect(controller.snapshot, restartedSnapshot);
});
```

- [ ] **Step 2: Run the controller test to verify it fails.**

Run: `flutter test test/game/round/round_controller_test.dart`

Expected: FAIL because `RoundController` and its fake engine do not exist.

- [ ] **Step 3: Implement the smallest plain-Dart controller.**

```dart
enum RoundStatus { initializing, ready, initializationError }

final class RoundController {
  RoundController(this._engine);

  final RulesEngine _engine;
  GameSnapshot? _snapshot;
  List<GameMove> _legalMoves = const [];
  int? _selectedPieceId;
  Object? _error;
  void Function()? _retryAction;
  RoundStatus _status = RoundStatus.initializing;

  GameSnapshot? get snapshot => _snapshot;
  List<GameMove> get legalMoves => _legalMoves;
  int? get selectedPieceId => _selectedPieceId;
  Object? get error => _error;
  RoundStatus get status => _status;

  void initialize();
  void selectPiece(int pieceId);
  void clearSelection();
  GameMove? moveForTappedDestination(int x, int y);
  void applyMove(GameMove move);
  void restart();
  void retry();
}
```

`initialize` clears all state and calls `RulesEngine.initialState`.
`restart` calls the same API but preserves the existing terminal snapshot when it fails.
`_acceptSnapshot` validates the paired terminal fields before assignment, clears selection, and obtains legal moves only through the engine for ongoing snapshots.
`applyMove` ignores a move absent from the current legal-move list.
`moveForTappedDestination` only converts a selected legal move's direction to an adjacent `x` and `y` coordinate.
Every bridge failure stores its error and a retry action without fabricating game state.

- [ ] **Step 4: Complete fake-engine coverage.**

Construct generated Dart value types directly in the fake rather than JSON, serialization, or a native Rust library.
Cover initialization failure and retry, selection replacement, illegal move rejection, returned damaged and hole tiles, terminal input blocking, terminal invariant failure after a valid snapshot, and restart failure followed by success.

- [ ] **Step 5: Run the controller test to verify it passes.**

Run: `flutter test test/game/round/round_controller_test.dart`

Expected: PASS.

- [ ] **Step 6: Export the controller and commit the tested unit.**

Add `export 'round/round_controller.dart';` to `lib/game/game.dart`.

```bash
git add lib/game/game.dart lib/game/round/round_controller.dart test/game/round/round_controller_test.dart
git commit -m "feat: add round controller"
```

### Task 2: Paint and Hit-Test the Board Without Rules Logic

**Files:**

- Create: `lib/game/view/round_board.dart`
- Create: `test/game/view/round_board_test.dart`

**Interfaces:**

- Consumes: `GameSnapshot`, `List<GameMove>`, selected piece identifier, and `void Function(int x, int y) onCellTap`.
- Produces: `RoundBoard` with a `CustomPainter` drawing the complete 5-by-5 snapshot.

- [ ] **Step 1: Write a failing board-coordinate test.**

```dart
testWidgets('forwards the tapped board cell to its callback', (tester) async {
  var tappedCell = (-1, -1);
  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 250,
        height: 250,
        child: RoundBoard(
          snapshot: initialSnapshot,
          legalMoves: const [],
          selectedPieceId: null,
          onCellTap: (x, y) => tappedCell = (x, y),
        ),
      ),
    ),
  );

  await tester.tapAt(const Offset(125, 175));

  expect(tappedCell, (2, 3));
});
```

- [ ] **Step 2: Run the board test to verify it fails.**

Run: `flutter test test/game/view/round_board_test.dart`

Expected: FAIL because `RoundBoard` does not exist.

- [ ] **Step 3: Implement `RoundBoard` and its painter.**

```dart
final class RoundBoard extends StatelessWidget {
  const RoundBoard({
    required this.snapshot,
    required this.legalMoves,
    required this.selectedPieceId,
    required this.onCellTap,
    super.key,
  });

  final GameSnapshot snapshot;
  final List<GameMove> legalMoves;
  final int? selectedPieceId;
  final void Function(int x, int y) onCellTap;
}
```

Use the shortest available side for the square board.
Map `localDx / cellSize` and `localDy / cellSize` with `floor`, and discard coordinates outside `0..4`.
Paint `Normal`, `Damaged`, and `Hole` with distinct fills.
Paint owner, selected piece, and legal destinations only from the supplied snapshot and legal moves.
Do not inspect tile meaning, determine push outcomes, or infer a winner.

- [ ] **Step 4: Add the outside-board assertion and run the test.**

Run: `flutter test test/game/view/round_board_test.dart`

Expected: PASS after an outside-square tap produces no callback.

- [ ] **Step 5: Commit the tested board unit.**

```bash
git add lib/game/view/round_board.dart test/game/view/round_board_test.dart
git commit -m "feat: render round board"
```

### Task 3: Wire the Controller Into the Direct Flutter Round Screen

**Files:**

- Modify: `lib/game/view/game_page.dart`
- Modify: `lib/app/view/app.dart`
- Modify: `lib/bootstrap.dart`
- Modify: `test/game/view/game_page_test.dart`
- Modify: `test/app/view/app_test.dart`

**Interfaces:**

- Consumes: `RoundController`, `RoundBoard`, and the existing `FrbRulesEngine` production adapter.
- Produces: `GamePage({RulesEngine? rulesEngine})` so production defaults to `const FrbRulesEngine()` and tests inject a fake.

- [ ] **Step 1: Replace template widget tests with failing playable-round tests.**

```dart
testWidgets('selects a piece and applies its highlighted move', (tester) async {
  await tester.pumpWidget(GamePage(rulesEngine: fakeEngine));
  await tester.tapAt(pieceZeroCenter);
  await tester.tapAt(pieceZeroDownDestination);
  await tester.pump();

  expect(fakeEngine.appliedMoves, [pieceZeroDown]);
  expect(find.text("Second player's turn"), findsOneWidget);
});

testWidgets('shows Retry when initial state fails', (tester) async {
  await tester.pumpWidget(GamePage(rulesEngine: failingThenReadyEngine));

  expect(find.text('Unable to start round'), findsOneWidget);
  await tester.tap(find.text('Retry'));
  await tester.pump();
  expect(find.byType(RoundBoard), findsOneWidget);
});

testWidgets('blocks input after a terminal snapshot and restarts', (tester) async {
  await tester.pumpWidget(GamePage(rulesEngine: terminalEngine));

  expect(find.text('First wins by knockout'), findsOneWidget);
  await tester.tap(find.text('Restart round'));
  await tester.pump();
  expect(find.text("First player's turn"), findsOneWidget);
});
```

- [ ] **Step 2: Run the app and page tests to verify they fail.**

Run: `flutter test test/app/view/app_test.dart test/game/view/game_page_test.dart`

Expected: FAIL because the Flame `GamePage` has no rules-engine injection, round UI, error state, or terminal controls.

- [ ] **Step 3: Replace the Flame screen with the stateful Material screen.**

```dart
class GamePage extends StatefulWidget {
  const GamePage({super.key, RulesEngine? rulesEngine})
    : _rulesEngine = rulesEngine ?? const FrbRulesEngine();

  final RulesEngine _rulesEngine;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final RoundController _controller;

  @override
  void initState() {
    super.initState();
    _controller = RoundController(widget._rulesEngine)..initialize();
  }
}
```

Build only these states.

```plaintext
initializing without a snapshot -> progress indicator
initializationError without a snapshot -> error text and Retry button
ready or error with a snapshot -> turn status, RoundBoard, optional error and Retry button
terminal snapshot -> winner and reason text, disabled board input, Restart round button
```

In the board callback, use `setState` to select a current-player piece, clear selection, or resolve an already legal destination through `moveForTappedDestination` and `applyMove`.
All button callbacks invoke controller methods inside `setState`.
`AppView` uses `const GamePage()` as `home` without preload or a provider.
`bootstrap` retains `FlutterError` logging and `RustLib.init()` but removes `BlocObserver` and Bloc imports.

- [ ] **Step 4: Make direct app entry testable.**

Add an optional `RulesEngine` argument to `App` and pass it to `GamePage` so `test/app/view/app_test.dart` uses a fake without calling native Rust.
The production default remains `const FrbRulesEngine()`.

- [ ] **Step 5: Run the app and page tests to verify they pass.**

Run: `flutter test test/app/view/app_test.dart test/game/view/game_page_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit the playable Flutter screen.**

```bash
git add lib/app/view/app.dart lib/bootstrap.dart lib/game/view/game_page.dart test/app/view/app_test.dart test/game/view/game_page_test.dart
git commit -m "feat: add playable round screen"
```

### Task 4: Remove the Replaced Template and Its Tooling

**Files:**

- Delete: `lib/loading/`, `lib/title/`, `lib/game/components/`, `lib/game/cubit/`, `lib/game/entities/`, and `lib/game/ttush_push.dart`
- Delete: `test/loading/`, `test/title/`, `test/game/components/`, `test/game/cubit/`, `test/game/entities/`, and `test/helpers/`
- Delete: `assets/audio/background.mp3`, `assets/audio/effect.mp3`, and `assets/images/unicorn_animation.png`
- Modify: `lib/game/game.dart`, `pubspec.yaml`, `pubspec.lock`, `.github/workflows/main.yaml`, and `lib/gen/assets.gen.dart`

**Interfaces:**

- Consumes: completed `GamePage`, `RoundController`, and `RoundBoard` from Tasks 1 through 3.
- Produces: a package and CI workflow with no Flame, audio, or Bloc implementation or linting dependency.

- [ ] **Step 1: Prove template paths are no longer required.**

Run: `rg -n "package:(audioplayers|bloc|equatable|flame|flame_audio|flame_behaviors|flutter_bloc)|Assets\.(audio|images)|PreloadCubit|AudioCubit|TtushPush|TitlePage|LoadingPage" lib test integration_test`

Expected: only template source and tests before deletion.

- [ ] **Step 2: Remove obsolete source and tests.**

Update `lib/game/game.dart` to export only `round/round_controller.dart`, `rules/rules_engine.dart`, and `view/view.dart`.
Keep the Poppins license asset, `google_fonts`, and bootstrap registration because the direct Material theme continues to use `GoogleFonts.poppinsTextTheme()`.
Do not retain a dead title, preload, component, audio, or Unicorn helper merely to preserve template tests.

- [ ] **Step 3: Remove unused package declarations and disable Bloc lint.**

Remove `audioplayers`, `bloc`, `equatable`, `flame`, `flame_audio`, `flame_behaviors`, and `flutter_bloc` from `dependencies`.
Remove `bloc_lint`, `bloc_test`, `bloc_tools`, `flame_test`, `mockingjay`, and `mocktail` from `dev_dependencies` after deleting their tests.
Set `.github/workflows/main.yaml` `run_bloc_lint` to `false`.
Keep existing rules bridge, Flutter localization, Google Fonts, and Very Good analysis dependencies unless a compiler or package-resolution result proves one unused.

- [ ] **Step 4: Regenerate assets and the lockfile.**

Remove only `assets/audio/` and `assets/images/` from the `flutter.assets` declarations.
Run `flutter pub get` to regenerate `pubspec.lock`.
Run the repository FlutterGen command to regenerate `lib/gen/assets.gen.dart` from the remaining Poppins license declaration.
Confirm that `Assets.licenses.poppins.ofl` remains and that `Assets.audio` and `Assets.images` no longer exist.

- [ ] **Step 5: Verify removal and commit cleanup.**

Run: `rg -n "package:(audioplayers|bloc|equatable|flame|flame_audio|flame_behaviors|flutter_bloc)|Assets\.(audio|images)|PreloadCubit|AudioCubit|TtushPush|TitlePage|LoadingPage" lib test integration_test`

Expected: no matches.

```bash
dart format --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
git add -u
git add pubspec.yaml pubspec.lock .github/workflows/main.yaml lib/game/game.dart lib/gen/assets.gen.dart
git diff --cached --name-status
git commit -m "refactor: remove template game stack"
```

### Task 5: Pin and Run the Native Rust Parity Fixture

**Files:**

- Modify: `engine/tests/bridge_api.rs`
- Modify: `integration_test/rules_engine_parity_test.dart`

**Interfaces:**

- Consumes: existing value-only `RulesEngine` and Rust `GameSnapshot.snapshotHash`.
- Produces: a four-move fixture with Rust-owned expected hash `7044880ea390e9a8` for iOS and Android runtime execution.

- [ ] **Step 1: Add failing Rust and Flutter assertions for the complete fixture.**

```rust
assert_eq!(after_push.snapshot_hash, "7044880ea390e9a8");
assert!(
    !legal_moves(after_push)
        .unwrap()
        .contains(&game_move(0, GameDirection::Down))
);
```

```dart
for (final move in fixtureMoves) {
  expect(rulesEngine.legalMoves(snapshot), contains(move));
  snapshot = rulesEngine.applyMove(snapshot, move);
}

expect(snapshot.snapshotHash, '7044880ea390e9a8');
expect(
  rulesEngine.legalMoves(snapshot),
  isNot(contains(const GameMove(pieceId: 0, direction: GameDirection.down))),
);
```

- [ ] **Step 2: Run the Rust bridge fixture to verify the expected hash.**

Run: `cargo test --manifest-path engine/Cargo.toml --test bridge_api value_api_preserves_a_snapshot_across_move_calls`

Expected: PASS with the literal calculated by Rust's canonical snapshot representation.

- [ ] **Step 3: Extend the Flutter integration test without a Dart hash.**

Keep `await RustLib.init()`.
Construct `const GameMove` values using generated Dart types, assert each is legal before applying it, and assert only the Rust-returned `snapshotHash` literal at the end.
Do not call `jsonEncode`, hash Dart fields, or compare generated serialization strings.

- [ ] **Step 4: Run the integration test on iOS.**

Run: `flutter test integration_test/rules_engine_parity_test.dart -d <ios-simulator-id>`

Expected: PASS with final hash `7044880ea390e9a8`.

- [ ] **Step 5: Run the integration test on one Android Emulator.**

First identify the single active emulator with `flutter devices`.
Run: `flutter test integration_test/rules_engine_parity_test.dart -d <android-emulator-id>`

Expected: PASS with final hash `7044880ea390e9a8`.

Do not start an iOS Simulator, Android Emulator, Gradle build, or APK build concurrently with this run.

- [ ] **Step 6: Commit fixture and runtime smoke coverage.**

```bash
git add engine/tests/bridge_api.rs integration_test/rules_engine_parity_test.dart
git commit -m "test: add native rules parity fixture"
```

### Task 6: Final Regression Gate and Human-Play Handoff

**Files:**

- Modify: none unless a verification command identifies a defect in Tasks 1 through 5.

**Interfaces:**

- Consumes: complete PR #3 branch.
- Produces: exact evidence for the Definition of Done without expanding scope.

- [ ] **Step 1: Run the complete local regression set.**

Run: `dart format --set-exit-if-changed lib/app lib/bootstrap.dart lib/game test integration_test && flutter analyze && flutter test && cargo test --manifest-path engine/Cargo.toml && trunk check --no-progress`

Expected: all commands exit zero.

- [ ] **Step 2: Perform one local human-play smoke.**

Run the app on one already-available simulator or device.
Verify initial board rendering, current-player selection, legal highlights, a normal move, a push, Normal-to-Damaged-to-Hole rendering, immediate counter-push suppression, a terminal result, disabled terminal input, and restart.
Record only observed blockers or confusion.

- [ ] **Step 3: Stop UI work after the first 10 to 20 human rounds.**

Collect those play observations before proposing animation, MatchState, BO3, Web, or a new feature.
Do not implement those follow-up ideas in PR #3.

## Plan Self-Review

- [x] The controller task covers Flutter independence, terminal contract validation, initialization failure, retry, and restart failure preservation.
- [x] Board coordinate mapping is separated from rules evaluation and explicitly prohibits game-meaning calculations.
- [x] The screen task covers direct app entry, legal interaction, terminal input blocking, and user-visible error states.
- [x] Template removal is limited to replaced Flame, audio, Bloc, and dependent test tooling, with lockfile and FlutterGen regeneration.
- [x] The parity fixture asserts each move is legal before application and owns its expected hash in Rust rather than Dart serialization.
- [x] Android Emulator execution is required and serialized with other heavy mobile jobs.
- [x] The plan contains no placeholder markers or vague implementation directions.
