# Authoritative Move Resolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Return Rust-authored move effects with each applied match move, defer Flutter state adoption until a short replay completes, and derive every board dimension from snapshot tiles.

**Architecture:** Rust will keep `resolve_move` as the sole move interpretation and will project its result into bridge-safe `MoveResult` and `MoveResolution` values.
The Dart controller will validate and cache the next snapshot and its legal moves as a pending result while the page replays that result over the current snapshot.
`RoundBoard` will own a snapshot-derived `BoardGeometry` used consistently for paint, overlays, and tap mapping.

**Tech Stack:** Flutter 3.44, Dart 3.12, flutter_rust_bridge 2.12.0, Rust edition 2024, Flutter widget tests, Rust integration tests.

**Spec:** `docs/specs/2026-08-24-authoritative-move-resolution.md`

## Global Constraints

- Rust remains the sole authority for legality, Pushes, falls, tile transitions, outcomes, and exit directions.
- `match_apply_move` returns `MoveResult` containing the next `MatchSnapshot` and one Rust-authored `MoveResolution`.
- Flutter must not infer action kind, displacement, fall direction, or tile transition from coordinates or snapshot differences.
- The current snapshot remains visible until replay commits the prepared result.
- Normal replay finishes within 0.6 seconds, and reduced motion omits travel while retaining a short transition and the same commit path.
- Rendering and hit testing derive bounds exclusively from snapshot tile coordinates, including Hole tiles.
- Do not hand-edit `lib/src/rust/**` or `engine/src/frb_generated.rs`.
- Regenerate bridge code with `merry run generate` after every approved `engine/src/api.rs` shape change.
- Do not install, launch, or otherwise write to Andrew's daily iPhone without a separate announced approval.

---

## File Structure

| Path                                             | Change                                                                                                                |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `engine/src/lib.rs`                              | Retain the existing rules path and expose its resolved facts to the API layer without snapshot comparison.            |
| `engine/src/api.rs`                              | Define the bridge result structs and make `match_apply_move` return them.                                             |
| `engine/tests/bridge_api.rs`                     | Directly assert normal, Push, fall, and foothold resolution fields.                                                   |
| `lib/src/rust/**`                                | Generated Flutter Rust Bridge output from Task 1 only.                                                                |
| `lib/game/rules/rules_engine.dart`               | Change the value boundary to `MoveResult`.                                                                            |
| `test/support/match_fixtures.dart`               | Supply deterministic `MoveResult` values from the fake rules engine.                                                  |
| `lib/game/match/match_controller.dart`           | Prepare, validate, commit, and retry pending results without owning animation.                                        |
| `test/game/match/match_controller_test.dart`     | Verify deferred adoption, atomic validation, retry, and human or bot parity.                                          |
| `lib/game/view/round_board.dart`                 | Add `BoardGeometry` and render Rust-provided transient move effects.                                                  |
| `test/game/view/round_board_test.dart`           | Verify non-zero-origin rectangular geometry, irregular void, hit mapping, and resolution rendering.                   |
| `lib/game/view/game_page.dart`                   | Own short-lived replay, interaction locking, reduced-motion handling, stale callback protection, and feedback timing. |
| `test/game/view/game_page_test.dart`             | Verify old-state visibility, lockout, normal and reduced-motion commits, bot replay, retry, and disposal.             |
| `integration_test/rules_engine_parity_test.dart` | Read the resolution payload on real Android and iOS runtimes in addition to the canonical snapshot hash.              |
| `CLAUDE.md`                                      | Update the bridge API inventory so it states the new return contract.                                                 |

## Bridge Contract

`MoveResult` contains `snapshot: MatchSnapshot` and `resolution: MoveResolution`.
`MoveResolution` contains `actionKind: normal | push`, the mover's piece ID and exact origin and destination, an optional displaced piece, and one exact foothold transition.
An optional displaced piece contains its piece ID, exact origin, either a destination or a fall, and an `exitDirection` when it falls.
The current game rules permit at most one displaced piece, so an optional singular displacement is the smallest truthful schema.
The fixed replay order is mover travel, Push impact and displacement or fall, then foothold transition.
All values in that order are Rust-authored fields, not Flutter deductions.

### Task 1: Produce and prove the Rust move-resolution contract

**Files:**

- Modify: `engine/src/lib.rs`
- Modify: `engine/src/api.rs`
- Modify: `engine/tests/bridge_api.rs`
- Modify: `CLAUDE.md`

**Interfaces:**

- Consumes: `ResolvedMove`, `MatchState::apply_move`, `GameState::apply_move`, `GameTileKind`, and `GameDirection`.
- Produces: `MoveResult`, `MoveResolution`, `MoveActionKind`, `PieceTravel`, `PieceDisplacement`, and `TileTransition` returned by `match_apply_move`.

- [ ] **Step 1: Add a failing bridge API test for a normal move.**

```rust
let result = match_apply_move(initial_match(), game_move(0, GameDirection::Down)).unwrap();

assert_eq!(result.resolution.action_kind, MoveActionKind::Normal);
assert_eq!(result.resolution.mover, PieceTravel { piece_id: 0, from_x: 1, from_y: 0, to_x: 1, to_y: 1 });
assert_eq!(result.resolution.displaced, None);
assert_eq!(result.resolution.tile_transition, TileTransition { x: 1, y: 0, from: GameTileKind::Normal, to: GameTileKind::Damaged });
assert_eq!(result.snapshot.round.snapshot_hash, "540736b5048c5f9f");
```

- [ ] **Step 2: Run the single test and confirm that `MoveResult` is unavailable.**

Run: `cargo test --manifest-path engine/Cargo.toml value_api_returns_a_normal_move_resolution`

Expected: FAIL because `match_apply_move` still returns `MatchSnapshot` and the result fields do not exist.

- [ ] **Step 3: Extend the existing Rust resolution path without comparing snapshots.**

```rust
pub(crate) struct AppliedRoundMove {
    pub next: GameState,
    pub resolved: ResolvedMove,
}

pub(crate) fn apply_move_with_resolution(state: &GameState, mv: Move) -> Result<AppliedRoundMove, IllegalMove> {
    let resolved = resolve_move(state, mv)?;
    let next = apply_resolved_move(state, mv, &resolved);
    Ok(AppliedRoundMove { next, resolved })
}

fn apply_resolved_move(state: &GameState, mv: Move, resolved: &ResolvedMove) -> GameState {
    let mut next = state.clone();
    let departure_tile = next.tiles.get_mut(&resolved.moving_piece.position).expect("a piece must occupy a playable tile");
    *departure_tile = match *departure_tile {
        Tile::Normal => Tile::Damaged,
        Tile::Damaged => Tile::Hole,
        Tile::Hole => unreachable!("a piece cannot occupy a hole"),
    };
    next.pieces.get_mut(&mv.piece).expect("the moving piece must remain in the cloned state").position = resolved.destination;
    if resolved.knockout {
        next.pieces.remove(&resolved.pushed_piece.expect("only a push can knock a piece out").id);
        next.outcome = Outcome::Winner(state.current_player, WinReason::Knockout);
        return next;
    }
    if let Some(pushed_piece) = &resolved.pushed_piece {
        next.pieces.get_mut(&pushed_piece.id).expect("the pushed piece must remain in the cloned state").position = resolved.destination.step(mv.direction).expect("the validated push destination must be on the board");
        next.counter_push = Some(CounterPush { pusher: mv.piece, pushed: pushed_piece.id });
    } else {
        next.counter_push = None;
    }
    next.current_player = state.current_player.opponent();
    if legal_moves(&next).is_empty() {
        next.outcome = Outcome::Winner(state.current_player, WinReason::Immobilization);
    }
    next
}
```

Add an equivalent `MatchState::apply_move_with_resolution` that settles the returned round into its next match state.
Keep the existing state-only `apply_move` functions as wrappers over the corresponding resolution-aware functions for existing rule callers.
Use the pre-mutation departure tile and `ResolvedMove` fields to project `MoveResolution` in `engine/src/api.rs`.
Never diff `MatchSnapshot` values to populate an effect.

- [ ] **Step 4: Define the bridge-safe result values and return them.**

```rust
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MoveResult {
    pub snapshot: MatchSnapshot,
    pub resolution: MoveResolution,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MoveResolution {
    pub action_kind: MoveActionKind,
    pub mover: PieceTravel,
    pub displaced: Option<PieceDisplacement>,
    pub tile_transition: TileTransition,
}
```

For a knockout, set `PieceDisplacement.destination` to `None` and `exit_direction` to the original move direction.
For an ordinary Push, set `destination` and leave `exit_direction` as `None`.
For a normal move, set `displaced` to `None`.

- [ ] **Step 5: Add direct Push, fall, and damaged-to-hole assertions.**

```rust
assert_eq!(result.resolution.action_kind, MoveActionKind::Push);
assert_eq!(result.resolution.displaced.as_ref().unwrap().piece_id, pushed_piece_id);
assert_eq!(result.resolution.displaced.as_ref().unwrap().exit_direction, Some(GameDirection::Right));
assert_eq!(result.resolution.tile_transition.to, GameTileKind::Hole);
```

Build fixtures from valid Rust-owned `MatchState` values inside the API test module when the baseline sequence cannot produce the required tile state directly.
Retain the existing snapshot-hash rejection tests and adapt their successful calls to `result.snapshot`.

- [ ] **Step 6: Run focused Rust evidence and make the direct assertions fail once.**

Run: `cargo test --manifest-path engine/Cargo.toml --test bridge_api`

Expected: PASS after implementation.

Temporarily change one expected `MoveActionKind::Push` assertion to `MoveActionKind::Normal`, rerun its single test, confirm the exact assertion failure, and restore the correct expectation before continuing.

- [ ] **Step 7: Align the authoritative documentation and commit the contract.**

Update the `CLAUDE.md` bridge inventory from “returns the resulting snapshot” to “returns a `MoveResult` with the next snapshot and Rust-authored resolution.”

```sh
git add engine/src/lib.rs engine/src/api.rs engine/tests/bridge_api.rs CLAUDE.md
git commit -m "feat(engine): return authoritative move resolution"
```

### Task 2: Regenerate the Dart bridge and defer controller adoption

**Files:**

- Modify: `lib/src/rust/**` through `merry run generate`
- Modify: `engine/src/frb_generated.rs` through `merry run generate`
- Modify: `lib/game/rules/rules_engine.dart`
- Modify: `lib/game/match/match_controller.dart`
- Modify: `test/support/match_fixtures.dart`
- Modify: `test/game/match/match_controller_test.dart`

**Interfaces:**

- Consumes: generated `rust.MoveResult`, existing `MatchSnapshot` contract validator, and `RulesEngine.legalMoves`.
- Produces: `RulesEngine.applyMove -> MoveResult`, `MatchController.prepareHumanMove`, `MatchController.prepareBotMove`, `MatchController.commitPendingMove`, and `MatchController.pendingResolution`.

- [ ] **Step 1: Regenerate the bridge before changing hand-written Dart.**

Run: `merry run generate`

Expected: generated Rust and Dart values contain `MoveResult` and `MoveResolution`, and no generated file is edited by hand.

- [ ] **Step 2: Add a failing controller test for deferred adoption.**

```dart
expect(controller.prepareHumanMove(move), isTrue);
expect(controller.snapshot, initial);
expect(controller.pendingResolution, resolution);
expect(controller.legalMoves, initialLegalMoves);

controller.commitPendingMove();

expect(controller.snapshot, next);
expect(controller.legalMoves, nextLegalMoves);
expect(controller.pendingResolution, isNull);
```

- [ ] **Step 3: Run the controller test and confirm immediate adoption violates it.**

Run: `flutter test test/game/match/match_controller_test.dart --plain-name "prepares a move without publishing its snapshot"`

Expected: FAIL because the current controller assigns the next snapshot inside `applyMove`.

- [ ] **Step 4: Change the Dart boundary and fake engine to use result values.**

```dart
abstract interface class RulesEngine {
  rust.MoveResult applyMove(rust.MatchSnapshot state, rust.GameMove move);
}

final class FrbRulesEngine implements RulesEngine {
  @override
  rust.MoveResult applyMove(rust.MatchSnapshot state, rust.GameMove move) =>
      rust.matchApplyMove(snapshot: state, gameMove: move);
}
```

Make `FakeRulesEngine.moveResults` return generated `MoveResult` values or throw its configured error.
Add a `moveResultOf` fixture helper that receives an explicit next match and explicit resolution.

- [ ] **Step 5: Implement prepare, commit, retry, and lock state in `MatchController`.**

```dart
bool prepareHumanMove(GameMove move);
bool prepareBotMove();
MoveResolution? get pendingResolution;
bool get hasPendingMove;
void commitPendingMove();
bool retry();
```

Validate `result.snapshot` and fetch its legal moves before storing one private pending tuple of result and next legal moves.
Keep `_snapshot`, `_legalMoves`, and selection unchanged until `commitPendingMove`.
Reject selection, move preparation, opponent changes, round advance, and restart while a pending move exists.
On preparation or legal-move refresh failure, preserve the old visible state and install a retry closure that repeats preparation rather than committing an incomplete result.

- [ ] **Step 6: Add and run controller regression tests one at a time.**

```dart
expect(controller.prepareBotMove(), isTrue);
expect(controller.snapshot, initialBotTurn);
controller.commitPendingMove();
expect(controller.snapshot, botNext);
```

Cover a human move, a bot move, failed result production, failed next legal-move refresh, retry, and refusal of every control while pending.

Run: `flutter test test/game/match/match_controller_test.dart`

Expected: PASS with all existing controller behavior adapted to explicit commit timing.

- [ ] **Step 7: Commit the bridge consumer boundary.**

```sh
git add engine/src/frb_generated.rs lib/src/rust lib/game/rules/rules_engine.dart lib/game/match/match_controller.dart test/support/match_fixtures.dart test/game/match/match_controller_test.dart
git commit -m "feat(match): defer move state adoption"
```

### Task 3: Replace fixed board dimensions with snapshot geometry

**Files:**

- Modify: `lib/game/view/round_board.dart`
- Modify: `test/game/view/round_board_test.dart`
- Modify: `test/game/view/game_page_test.dart`

**Interfaces:**

- Consumes: `GameSnapshot.tiles`, the available widget size, and tile or piece coordinates.
- Produces: `BoardGeometry.fromSnapshot`, `cellRect`, `cellCenter`, and `cellAt` for paint, transient overlays, and taps.

- [ ] **Step 1: Add a failing geometry test with a non-zero-origin rectangular board.**

```dart
final geometry = BoardGeometry.fromSnapshot(
  const GameSnapshot(
    currentPlayer: GamePlayer.first,
    tiles: [
      GameTile(x: 4, y: 7, kind: GameTileKind.normal),
      GameTile(x: 6, y: 7, kind: GameTileKind.hole),
      GameTile(x: 6, y: 8, kind: GameTileKind.normal),
    ],
    pieces: [],
    snapshotHash: 'irregular',
  ),
  const Size(300, 200),
);

expect(geometry.columnCount, 3);
expect(geometry.rowCount, 2);
expect(geometry.cellAt(geometry.cellCenter(6, 8)), (6, 8));
```

- [ ] **Step 2: Run the geometry test and confirm `_boardLength` prevents it.**

Run: `flutter test test/game/view/round_board_test.dart --plain-name "derives rectangular non-zero-origin geometry from tiles"`

Expected: FAIL because the renderer divides its square canvas by the fixed value `5`.

- [ ] **Step 3: Implement `BoardGeometry` in `round_board.dart`.**

```dart
final class BoardGeometry {
  BoardGeometry.fromSnapshot(GameSnapshot snapshot, Size availableSize);

  final int minX;
  final int minY;
  final int columnCount;
  final int rowCount;
  final double cellSize;
  final Offset origin;

  Rect cellRect(int x, int y);
  Offset cellCenter(int x, int y);
  (int, int)? cellAt(Offset point);
}
```

Use every tile, including Hole tiles, to calculate inclusive bounds.
Choose `cellSize` from the smaller available width-per-column and height-per-row, then center the resulting rectangle in the available paint size.
Return no cell for a point outside that rectangle.
Leave absent terrain as void and do not dispatch it as a cell tap.

- [ ] **Step 4: Route all board paint and hit-test paths through `BoardGeometry`.**

Replace `_boardLength`, direct `x * cellSize`, direct `y * cellSize`, and fixed test helpers with geometry methods.
Use the same geometry instance for tile, piece, destination, transition, and tap coordinates within one build.
Preserve tap-up-only behavior so canceled gestures remain non-destructive.

- [ ] **Step 5: Add and run dynamic-board regressions.**

```dart
await tester.tapAt(boardTopLeft + geometry.cellCenter(6, 8));
expect(tappedCell, (6, 8));

await tester.tapAt(boardTopLeft + const Offset(2, 2));
expect(tappedCell, isNot((4, 7)));
```

Cover an irregular layout, a rectangular layout, a Hole tile that contributes bounds, an absent coordinate that remains void, and hit mapping for a non-zero origin.
Use `BoardGeometry` in `game_page_test.dart` tap helpers instead of dividing by five.

Run: `flutter test test/game/view/round_board_test.dart test/game/view/game_page_test.dart`

Expected: PASS with no fixed board-length constant in Flutter rendering or hit testing.

- [ ] **Step 6: Commit snapshot geometry.**

```sh
git add lib/game/view/round_board.dart test/game/view/round_board_test.dart test/game/view/game_page_test.dart
git commit -m "feat(board): derive geometry from snapshot tiles"
```

### Task 4: Replay prepared results before committing the next snapshot

**Files:**

- Modify: `lib/game/view/game_page.dart`
- Modify: `lib/game/view/round_board.dart`
- Modify: `test/game/view/game_page_test.dart`
- Modify: `test/game/view/round_board_test.dart`

**Interfaces:**

- Consumes: `MatchController.pendingResolution`, `RoundBoard` current snapshot, `MediaQuery.disableAnimationsOf`, and `RoundFeedback`.
- Produces: a page-owned replay lifecycle that calls `commitPendingMove` exactly once after normal or reduced-motion playback.

- [ ] **Step 1: Add a failing widget test that the old board remains visible during replay.**

```dart
await tester.tapAt(cellCenter(0, 0));
await tester.tapAt(cellCenter(0, 1));
await tester.pump();

_expectActiveTurn(tester, GamePlayer.first);
expect(find.byKey(const Key('move-resolution-playback')), findsOneWidget);

await tester.pump(const Duration(milliseconds: 540));

_expectActiveTurn(tester, GamePlayer.second);
```

- [ ] **Step 2: Run the widget test and confirm the current page publishes the next state immediately.**

Run: `flutter test test/game/view/game_page_test.dart --plain-name "keeps the current snapshot visible until replay completes"`

Expected: FAIL because the current `applyMove` path replaces the snapshot in the tap handler.

- [ ] **Step 3: Add page-owned replay state with disposal safety.**

```dart
class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  static const _normalReplayDuration = Duration(milliseconds: 540);
  static const _reducedReplayDuration = Duration(milliseconds: 120);

  late final AnimationController _replayController;
  int _replayGeneration = 0;

  Future<void> _playPreparedMove(MoveResolution resolution) async;
}
```

Use `MediaQuery.disableAnimationsOf(context)` to select the duration.
Increment `_replayGeneration` before each replay and in `dispose`.
After the controller completes, commit only when `mounted`, the generation still matches, and `pendingResolution` still equals the resolution that started playback.
Dispose the animation controller and keep the existing bot timer and feedback disposal behavior.

- [ ] **Step 4: Render the Rust-provided move without reading the next snapshot.**

```dart
final class BoardPlayback {
  const BoardPlayback({required this.resolution, required this.progress});

  final MoveResolution resolution;
  final double progress;
}

RoundBoard(
  snapshot: round,
  legalMoves: _controller.legalMoves,
  selectedPieceId: _controller.selectedPieceId,
  playback: BoardPlayback(resolution: resolution, progress: _replayController.value),
  onCellTap: _controller.hasPendingMove ? null : _onCellTap,
)
```

Paint the mover from its provided origin to destination first.
For a Push, show a collision before drawing the Rust-provided displacement or exit-direction fall.
Draw the Rust-provided foothold state transition last.
In reduced motion, suppress travel interpolation but keep the collision or transition indication for 120 milliseconds.

- [ ] **Step 5: Lock every match control and preserve human or bot parity.**

Disable board taps, opponent cycling, Retry, round advance, and New Match while `hasPendingMove` is true.
Have the human destination path and the bot timer path both call the same prepare, replay, and commit sequence.
Dispatch haptic or sound feedback only after commit, using `resolution.actionKind` instead of occupancy reads from the old board.
Schedule a subsequent bot move only after the prior result is committed.

- [ ] **Step 6: Add and run replay behavior tests one at a time.**

```dart
await tester.pumpWidget(_reducedMotionHarness(engine));
await _playSelectedMove(tester);
await tester.pump(const Duration(milliseconds: 119));
_expectActiveTurn(tester, GamePlayer.first);
await tester.pump(const Duration(milliseconds: 1));
_expectActiveTurn(tester, GamePlayer.second);
```

Cover normal move, Push and fall frame data, reduced motion, disabled controls, failed prepare with Retry, bot replay, and disposal before replay completion.
For disposal, replace `GamePage` before the duration elapses and assert no exception or late commit occurs.

Run: `flutter test test/game/view/game_page_test.dart test/game/view/round_board_test.dart`

Expected: PASS with no Flutter computation of Push or fall meaning.

- [ ] **Step 7: Commit visual playback.**

```sh
git add lib/game/view/game_page.dart lib/game/view/round_board.dart test/game/view/game_page_test.dart test/game/view/round_board_test.dart
git commit -m "feat(game): replay authoritative move results"
```

### Task 5: Prove generated and native contract behavior

**Files:**

- Modify: `integration_test/rules_engine_parity_test.dart`
- Verify: generated bridge files from Task 2
- Verify: all files changed by Tasks 1 through 4

**Interfaces:**

- Consumes: real `RustLib.init`, `FrbRulesEngine.applyMove`, and the fixed parity fixture.
- Produces: Android and iOS evidence that snapshot hashes and resolution fields match the same Rust-owned fixture.

- [ ] **Step 1: Extend the parity fixture with a failing resolution assertion.**

```dart
final result = rulesEngine.applyMove(match, move);
expect(result.resolution.mover.pieceId, move.pieceId);
expect(result.resolution.tileTransition.from, GameTileKind.normal);
match = result.snapshot;
```

Assert the fixture's normal move and Push resolution fields before continuing to assert the existing final snapshot hash and bot choices.

- [ ] **Step 2: Run the integration test on an already available non-personal runtime.**

Run `flutter devices` and record one already running Android runtime that is not Andrew's daily iPhone.
Then run the parity test against that recorded runtime.

Expected: PASS after Tasks 1 through 4.

Do not create, boot, install to, or launch on any device in this step without first checking machine load and announcing the exact device write.

- [ ] **Step 3: Run source-quality and generation gates.**

```sh
merry run generate
merry run check
npx cspell --config cspell.json '**/*.md'
```

Expected: PASS.
The aggregate gate proves source, lint, and test quality only. It does not prove `RustLib.init` on a native runtime.

- [ ] **Step 4: Obtain and announce separate device-write approval before iOS validation.**

State the exact target, installer or launch command, and that the existing daily-phone app will be replaced rather than uninstalled.
Wait for Andrew's explicit approval before running any command that installs or launches on `00008140-001938282206801C`.

- [ ] **Step 5: Run and record native bridge evidence.**

```sh
flutter test integration_test/rules_engine_parity_test.dart -d 00008140-001938282206801C --flavor development
```

Run the Android parity command recorded in Step 2 and the iOS command above.
Require the real `RustLib.init` fixture to read the expected snapshot hash and resolution fields on both Android and iOS.
If iOS does not start, check the USB connection and Xcode device ownership before retrying the same command.

- [ ] **Step 6: Commit integration coverage after both runtime results are available.**

```sh
git add integration_test/rules_engine_parity_test.dart
git commit -m "test(bridge): verify native move resolutions"
```

## Final Verification

Run all source-quality checks after the final commit.

```sh
merry run check
npx cspell --config cspell.json '**/*.md'
git status --short
git diff --cached --name-status
```

Then run the Android and separately approved iOS parity commands from Task 5.
The milestone is complete only when all source gates are green, both runtimes read the real bridge, no index changes remain, and each acceptance criterion in `docs/specs/2026-08-24-authoritative-move-resolution.md` has direct evidence.
