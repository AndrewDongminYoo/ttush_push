# Board Definition Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start each match from one typed Dart BoardDefinition while Rust validates its playable cells and starting pieces.

**Architecture:** A Dart BoardDefinition keeps the bundled background asset path and one generated `GameBoardDefinition` value.
The generated Rust input contains only playable cells and starting pieces.
Rust converts that input to the existing `BoardConfig`, validates it, and returns the existing value-owned MatchSnapshot.

**Tech Stack:** Flutter 3.44, Dart 3.12, Rust edition 2024, flutter_rust_bridge 2.13.0, Flutter widget tests, Rust integration tests.

**Spec:** `docs/specs/0002-board-definition/spec.md`

## Global Constraints

- Keep one built-in baseline BoardDefinition.
- Keep background asset metadata out of the Rust bridge input.
- Keep Rust as the only owner of board validation, move legality, match state, and canonical hashes.
- Keep MatchSnapshot, move resolution, BoardGeometry, and replay behavior unchanged.
- Do not add a dependency, a runtime configuration loader, a board picker, or persistence.
- Do not hand-edit `lib/src/rust/**` or `engine/src/frb_generated.rs`.
- Regenerate generated bridge output with `merry run generate` after an `engine/src/api.rs` change.
- Do not install, launch, or otherwise write to the operator's daily iPhone.
- Commit changes only after explicit operator authorization.

---

## File Structure

| Path                                             | Responsibility                                                                   |
| ------------------------------------------------ | -------------------------------------------------------------------------------- |
| `engine/src/api.rs`                              | Defines bridge-safe board input and converts it into a validated BoardConfig.    |
| `engine/tests/bridge_api.rs`                     | Proves valid, irregular, and invalid board definitions at the Rust API boundary. |
| `engine/src/frb_generated.rs`                    | Contains regenerated Rust bridge code only.                                      |
| `lib/src/rust/**`                                | Contains regenerated Dart bridge code only.                                      |
| `lib/game/board/board_definition.dart`           | Defines the one Dart-owned baseline BoardDefinition and its background metadata. |
| `lib/game/rules/rules_engine.dart`               | Passes the generated board input to the Rust start API.                          |
| `lib/game/match/match_controller.dart`           | Reuses one configured input for initial load, retry, and restart.                |
| `lib/game/view/game_page.dart`                   | Injects the board definition and reads its background asset path.                |
| `test/support/match_fixtures.dart`               | Records the BoardDefinition received by FakeRulesEngine.                         |
| `test/game/match/match_controller_test.dart`     | Proves controller configuration forwarding and retry behavior.                   |
| `test/game/view/game_page_test.dart`             | Proves GamePage reads its configured background path.                            |
| `tool/rules_engine_host_test.dart`               | Proves an irregular input crosses the generated host bridge.                     |
| `integration_test/rules_engine_parity_test.dart` | Exercises the new input on Android and iOS runtimes.                             |
| `CLAUDE.md`                                      | Records the current board-configuration ownership and start API contract.        |

## Task 1: Define and prove the Rust board input boundary

**Files:**

- Modify: `engine/src/api.rs`
- Modify: `engine/tests/bridge_api.rs`

**Interfaces:**

- Consumes: `BoardConfig::new`, `GamePiece`, and `MatchState::new`.
- Produces: `GameBoardCell`, `GameBoardDefinition`, and `initial_match(board_definition) -> Result<MatchSnapshot, String>`.

- [x] **Step 1: Write a failing irregular-definition bridge test.**

```rust
let definition = GameBoardDefinition {
    playable_cells: vec![
        GameBoardCell { x: 4, y: 7 },
        GameBoardCell { x: 5, y: 7 },
        GameBoardCell { x: 5, y: 8 },
    ],
    starting_pieces: vec![
        GamePiece { id: 7, owner: GamePlayer::First, x: 4, y: 7 },
        GamePiece { id: 9, owner: GamePlayer::Second, x: 5, y: 8 },
    ],
};

let snapshot = initial_match(definition).unwrap();

assert_eq!(snapshot.round.tiles.len(), 3);
assert_eq!(snapshot.starting_pieces.len(), 2);
assert_eq!(snapshot.round.tiles[0].x, 4);
```

- [x] **Step 2: Run the bridge API test and confirm the expected failure.**

Run: `cargo test --manifest-path engine/Cargo.toml --test bridge_api value_api_accepts_an_irregular_board_definition`

Expected: FAIL because `initial_match` accepts no definition and the generated input types do not exist.

- [x] **Step 3: Add the smallest bridge-safe input types and conversion helper.**

```rust
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GameBoardCell {
    pub x: u8,
    pub y: u8,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GameBoardDefinition {
    pub playable_cells: Vec<GameBoardCell>,
    pub starting_pieces: Vec<GamePiece>,
}

fn board_config_from_definition(
    definition: GameBoardDefinition,
) -> Result<BoardConfig, String> {
    let playable_cells = definition
        .playable_cells
        .iter()
        .map(|cell| Position::new(cell.x, cell.y))
        .collect::<BTreeSet<_>>();
    if playable_cells.len() != definition.playable_cells.len() {
        return Err("invalid board definition: duplicate playable cell".to_owned());
    }
    let starting_pieces = definition
        .starting_pieces
        .into_iter()
        .map(|piece| Piece::new(PieceId(piece.id), piece.owner.into(), Position::new(piece.x, piece.y)))
        .collect();
    BoardConfig::new(playable_cells, starting_pieces)
        .map_err(|error| format!("invalid board definition: {error:?}"))
}
```

Make `initial_match` return `Result<MatchSnapshot, String>` after it calls `board_config_from_definition`.
Do not add background fields to either Rust input type.

- [x] **Step 4: Add direct invalid-input regressions.**

```rust
assert_eq!(
    initial_match(GameBoardDefinition {
        playable_cells: vec![
            GameBoardCell { x: 1, y: 1 },
            GameBoardCell { x: 1, y: 1 },
        ],
        starting_pieces: vec![],
    })
    .unwrap_err(),
    "invalid board definition: duplicate playable cell",
);
```

Add separate tests for an empty cell list, an overlapping pair of pieces, a duplicate piece ID, and a piece outside the listed cells.
Keep a `baseline_definition()` test helper and update existing `initial_match()` calls to use it.
Retain the existing baseline initial snapshot-hash assertion.

- [x] **Step 5: Run the focused Rust tests and prove a direct assertion is live.**

Run: `cargo test --manifest-path engine/Cargo.toml --test bridge_api`

Expected: PASS.

Change the irregular test's expected tile count from `3` to `4`, run its single test, confirm the exact assertion failure, and restore `3`.

## Task 2: Regenerate the bridge and carry one definition through Dart

**Files:**

- Modify through generation: `engine/src/frb_generated.rs`
- Modify through generation: `lib/src/rust/**`
- Create: `lib/game/board/board_definition.dart`
- Modify: `lib/game/rules/rules_engine.dart`
- Modify: `lib/game/match/match_controller.dart`
- Modify: `test/support/match_fixtures.dart`
- Modify: `test/game/match/match_controller_test.dart`

**Interfaces:**

- Consumes: generated `rust.GameBoardDefinition`, `RulesEngine`, and `MatchController` initialization paths.
- Produces: `BoardDefinition`, `baselineBoardDefinition`, and `RulesEngine.initialMatch(rust.GameBoardDefinition definition)`.

- [x] **Step 1: Regenerate the bridge before editing its Dart consumers.**

Run: `merry run generate`

Expected: generated Dart and Rust output contains `GameBoardCell`, `GameBoardDefinition`, and a parameterized `initialMatch` bridge method.

- [x] **Step 2: Write a failing controller forwarding test.**

```dart
final engine = FakeRulesEngine.playing(initial: matchOf(round()));
final definition = irregularDefinition();

MatchController(engine, definition.rules).initialize();

expect(engine.initialDefinitions, [definition.rules]);
```

Run: `flutter test test/game/match/match_controller_test.dart --plain-name 'forwards its board definition to RulesEngine'`

Expected: FAIL because MatchController and FakeRulesEngine do not receive a definition.

- [x] **Step 3: Add the built-in Dart data definition.**

```dart
final class BoardDefinition {
  const BoardDefinition({
    required this.backgroundAssetPath,
    required this.rules,
  });

  final String backgroundAssetPath;
  final rust.GameBoardDefinition rules;
}
```

Define `baselineBoardDefinition` with the current five-by-five cells, four current starting pieces, and the current background path.
Keep this file data-only.
Do not derive moves, tile transitions, or outcomes in Dart.

- [x] **Step 4: Forward the same generated input through each start path.**

Change RulesEngine and FrbRulesEngine so `initialMatch` accepts a `rust.GameBoardDefinition`.
Give MatchController one constructor argument for that value.
Use it in `initialize` and `restart`.
Change FakeRulesEngine to record the exact received object before it returns its configured result.
Keep `retry` routed through the same `initialize` method.

Add a controller test that configures FakeRulesEngine to fail once, calls `retry`, and asserts that both initialization attempts received the identical generated definition object.

- [x] **Step 5: Run the focused Dart controller tests.**

Run: `flutter test test/game/match/match_controller_test.dart`

Expected: PASS.

## Task 3: Bind BoardDefinition to the match page and prove presentation ownership

**Files:**

- Modify: `lib/game/view/game_page.dart`
- Modify: `test/game/view/game_page_test.dart`

**Interfaces:**

- Consumes: `BoardDefinition.rules`, `BoardDefinition.backgroundAssetPath`, and the existing injected RulesEngine seam.
- Produces: a GamePage that starts its MatchController with the selected rule input and renders its selected Flutter background asset.

- [x] **Step 1: Write a failing GamePage configuration test.**

```dart
final definition = BoardDefinition(
  backgroundAssetPath: 'assets/images/air_ruins_twilight.png',
  rules: irregularDefinition().rules,
);
final engine = FakeRulesEngine.playing(initial: matchOf(irregularRound()));

await tester.pumpWidget(
  MaterialApp(home: GamePage(boardDefinition: definition, rulesEngine: engine)),
);

expect(engine.initialDefinitions, [definition.rules]);
final image = tester.widget<Image>(find.byKey(const Key('air-ruins-background')));
expect((image.image as AssetImage).assetName, definition.backgroundAssetPath);
```

Run: `flutter test test/game/view/game_page_test.dart --plain-name 'uses its BoardDefinition for rules and background'`

Expected: FAIL because GamePage has no BoardDefinition parameter and the background path is hardcoded.

- [x] **Step 2: Make the smallest page change.**

Add an optional public `boardDefinition` parameter to GamePage that defaults to `baselineBoardDefinition`.
Construct MatchController with `boardDefinition.rules`.
Pass `boardDefinition.backgroundAssetPath` into `_AirRuinsBackground`.
Change `_AirRuinsBackground` to require that value and use it in `Image.asset`.

- [x] **Step 3: Run the focused page and geometry tests.**

Run: `flutter test test/game/view/game_page_test.dart test/game/view/round_board_test.dart`

Expected: PASS.

## Task 4: Prove the generated input on host and mobile runtimes

**Files:**

- Modify: `tool/rules_engine_host_test.dart`
- Modify: `integration_test/rules_engine_parity_test.dart`
- Modify: `test/support/rules_engine_parity.dart`
- Modify: `CLAUDE.md`

**Interfaces:**

- Consumes: `baselineBoardDefinition`, `GameBoardDefinition`, and the generated FrbRulesEngine.
- Produces: host and native runtime evidence that the generated input reaches Rust.

- [x] **Step 1: Write a failing host-bridge irregular-definition test.**

```dart
final snapshot = const FrbRulesEngine().initialMatch(irregularDefinition().rules);

expect(snapshot.round.tiles.map((tile) => (tile.x, tile.y)), contains((4, 7)));
expect(snapshot.startingPieces.map((piece) => piece.id), containsAll([7, 9]));
```

Run: `flutter test tool/rules_engine_host_test.dart --plain-name 'accepts an irregular board definition through the host bridge'`

Expected: FAIL until the generated method accepts the input and the host test uses the Dart definition.

- [x] **Step 2: Add the same input assertion to native parity.**

Keep the baseline move fixture unchanged.
Pass `baselineBoardDefinition.rules` to that fixture.
Add a second assertion that an irregular definition returns its stated cells and starting pieces through FrbRulesEngine.
Do not build a fake snapshot for this test.

- [x] **Step 3: Update current architecture guidance.**

Update `CLAUDE.md` to state that Dart owns built-in board and presentation configuration, Rust validates its rule input, and `initial_match` accepts `GameBoardDefinition`.
Retain the existing generated-code and mobile-parity guidance.

- [x] **Step 4: Run host evidence and the full local gate.**

Run: `merry run bridge host`

Run: `merry run check`

Expected: PASS. The aggregate gate reads formatting, analysis, test coverage, Rust checks, the host bridge, and Trunk checks.

- [x] **Step 5: Run native parity only on non-daily-phone runtimes.**

Before each heavy runtime start, run `uptime` and confirm that the one-minute load does not exceed the core count.
Run iOS Simulator and Android Emulator checks sequentially.

```sh
flutter test integration_test/rules_engine_parity_test.dart -d <ios-simulator-id> --flavor development
flutter test integration_test/rules_engine_parity_test.dart -d <android-emulator-id> --flavor development
```

Do not target `00008140-001938282206801C`.
If either non-daily-phone runtime is unavailable, record that runtime as `[PARTIAL]` and keep the passed host evidence distinct from mobile packaging evidence.

## Plan Self-Review

- Spec coverage: Tasks 1 through 4 cover every requirement in `docs/specs/0002-board-definition/spec.md`.
- Placeholder scan: This plan has no `TBD`, `TODO`, or deferred implementation steps.
- Type consistency: Dart uses `BoardDefinition` for presentation plus `rust.GameBoardDefinition` for the bridge. Rust exposes `GameBoardCell` and `GameBoardDefinition`.
