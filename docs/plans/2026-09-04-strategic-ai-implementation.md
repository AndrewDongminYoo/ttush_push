# Strategic AI Implementation Plan

<!-- cspell:ignore nocapture -->

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic `Expert` opponent that searches deeply enough to dominate the current `Hard` policy and adapts to every supported `BoardDefinition`.

**Architecture:** Rust owns one iterative-deepening root-player minimax search with alpha-beta pruning, deterministic work limits, move ordering, and a transposition table.
flutter_rust_bridge runs move selection outside the Dart UI thread, while `GamePage` overlaps the existing 450 millisecond pacing delay with the search and rejects stale results.

**Tech Stack:** Rust 2024 standard library, flutter_rust_bridge 2.13.0, Dart, Flutter, Flutter widget tests, and the repository's Merry and Trunk gates.

**Spec:** `docs/specs/0011-strategic-ai/spec.md`

## Delivery Constraints

- Preserve the behavior of `Easy`, `Normal`, and `Hard`.
- Expose the new policy as `Expert` in the UI and `Strategic` in code.
- Keep move selection deterministic for an identical snapshot and policy.
- Start with an `18_000` node budget on the baseline board, then scale it down from the board's tile and piece count.
- Always complete a one-ply search even when scaling produces a smaller budget.
- Target less than one second for the full AI turn on the host reference environment and require less than two seconds on every available native reference environment.
- Use a deterministic work budget, not a wall-clock cutoff.
- Add no dependency, opening book, trained model, or board-specific coordinate rule.
- Keep Rust responsible for rules, state transitions, evaluation, and the chosen move.
- Regenerate bridge code through `merry run generate bridge` and localization code through `flutter gen-l10n`.
- Do not hand-edit generated output.
- Do not write to the operator's daily iPhone without separate approval for each install or launch.
- Preserve the author-unknown change in `docs/notes/closed-playtest-tester-kit.md`.
- Do not stage, commit, push, publish, or delete anything in this task.
- Directly assert score ordering, node counts, completed depths, and fallback moves because comments and aggregate gates have not caught reversed engine behavior before.

## File Map

Create:

- `engine/src/bot/strategic.rs`
- `engine/tests/strategic_bot.rs`

Modify:

- `engine/src/bot.rs`
- `engine/src/api.rs`
- `engine/tests/bot.rs`
- `engine/tests/bridge_api.rs`
- `engine/src/frb_generated.rs`
- `lib/src/rust/api.dart`
- `lib/src/rust/frb_generated.dart`
- `lib/src/rust/frb_generated.io.dart`
- `lib/src/rust/frb_generated.web.dart`
- `lib/game/rules/rules_engine.dart`
- `test/support/match_fixtures.dart`
- `lib/game/match/match_controller.dart`
- `test/game/match/match_controller_test.dart`
- `lib/game/view/game_page.dart`
- `test/game/view/game_page_test.dart`
- `lib/game/view/opponent_label.dart`
- `lib/game/start/start_page.dart`
- `lib/l10n/arb/app_en.arb`
- `test/game/start/start_page_test.dart`
- `test/support/rules_engine_parity.dart`

Verify without modifying:

- `integration_test/rules_engine_parity_test.dart`
- `tool/rules_engine_host_test.dart`

If Rust privacy prevents the search module from reading the state shape, add narrow `pub(crate)` accessors in `engine/src/lib.rs` and test them through the search behavior.
Do not widen the public API.

## Task 1: Build the Strategic Search Core

**Files:**

- Create: `engine/src/bot/strategic.rs`
- Modify: `engine/src/bot.rs`
- Modify: `engine/tests/bot.rs`

- [x] **Step 1: Write failing public-policy tests**

Add tests that construct a reachable match, call `StrategicBot`, and assert that the result is legal and deterministic.
Add a compile-time import of `StrategicBot` so the first run fails until the module is exposed.

Run:

```shell
cargo test --manifest-path engine/Cargo.toml --test bot strategic
```

Expected: FAIL because `StrategicBot` does not exist.

- [x] **Step 2: Expose the new bot module**

Add this shape to `engine/src/bot.rs`:

```rust
mod strategic;

pub use strategic::StrategicBot;
```

Keep `RandomBot`, `GreedyBot`, and `MinimaxBot` unchanged.

- [x] **Step 3: Implement deterministic iterative deepening**

Implement `StrategicBot` with these search constants and properties:

```rust
const BASE_NODE_BUDGET: usize = 18_000;
const BASE_COMPLEXITY: usize = 25 + (4 * 4);
const WIN_SCORE: i32 = 1_000_000;

fn scaled_node_budget(tile_count: usize, piece_count: usize, root_moves: usize) -> usize {
    let complexity = tile_count.saturating_add(piece_count.saturating_mul(4)).max(1);
    let scaled = BASE_NODE_BUDGET
        .saturating_mul(BASE_COMPLEXITY)
        .checked_div(complexity)
        .unwrap_or(BASE_NODE_BUDGET)
        .min(BASE_NODE_BUDGET);
    scaled.max(root_moves.saturating_add(1))
}
```

Use root-player minimax rather than negating scores.
The engine's knockout path can leave the winner as `current_player`, so terminal evaluation must compare `state.winner()` with the fixed root player.

Complete every depth before publishing its root move.
When the next depth exhausts the budget, return the best move from the last completed depth.
If only the one-ply pass fits, return its result.

- [x] **Step 4: Add alpha-beta pruning and the transposition table**

Key the table by the complete `GameState` value plus remaining depth and root player.
Store the evaluated score, bound kind, and best move only after a node has completed.
Use exact, lower-bound, and upper-bound entries without treating an interrupted node as exact.

Order legal moves by this stable priority:

1. An immediate terminal win.
2. The transposition-table best move.
3. A move that does not allow an immediate terminal loss.
4. The existing engine move order.

Do not use elapsed time, thread scheduling, or nondeterministic map iteration to break ties.

- [x] **Step 5: Add the board-generic evaluator**

Score from the fixed root player's point of view.
Terminal wins must exceed every positional score, and faster wins must score higher than slower wins.
Slower losses must score higher than faster losses.

Use only rule-derived features:

- Signed legal move count for the side to move.
- Signed safe move count after one reply.
- Immediate knockout and immobilization wins.
- Pieces that can be knocked out on the next move.
- Reachable foothold durability normalized by playable tile count.

Clamp the combined positional score below the terminal range.
Do not inspect fixed coordinates, board width, board height, or a fixed piece count.

- [x] **Step 6: Add direct internal assertions**

Add focused unit tests inside `strategic.rs` that prove:

- A terminal win scores above every positional value.
- A faster win scores above a slower win.
- A slower loss scores above a faster loss.
- Scaling never exceeds `BASE_NODE_BUDGET`.
- Scaling always permits a complete root pass.
- An interrupted deeper search returns the exact move from the last completed depth.
- Enabling the transposition table does not change the chosen move.

Run:

```shell
cargo test --manifest-path engine/Cargo.toml bot::strategic
cargo test --manifest-path engine/Cargo.toml --test bot strategic
```

Expected: PASS.

## Task 4: Make Bot Preparation Race-Safe

**Files:**

- Modify: `lib/game/rules/rules_engine.dart`
- Modify: `test/support/match_fixtures.dart`
- Modify: `lib/game/match/match_controller.dart`
- Modify: `test/game/match/match_controller_test.dart`

- [x] **Step 1: Write failing asynchronous controller tests**

Use a `Completer<GameMove?>` in the fake rules engine and add tests for these observable properties:

- `prepareBotMove` starts one search and returns a `Future<bool>`.
- A second preparation request for the same snapshot does not start another search.
- A completed current request publishes exactly one pending move.
- `cancelBotMovePreparation` makes the in-flight result stale.
- Replacing the match makes the in-flight result stale.
- A stale success or failure does not change the snapshot, pending move, or error state.
- A current bridge failure preserves the existing error and retry behavior.
- Retry awaits a new preparation attempt.

Run:

```shell
flutter test test/game/match/match_controller_test.dart
```

Expected: FAIL because bot preparation is synchronous.

- [x] **Step 2: Change the rules-engine contract**

Change `RulesEngine.chooseBotMove` to return `Future<GameMove?>`.
Change the fake callback type to `FutureOr<GameMove?>` so existing synchronous fixtures remain concise while asynchronous tests can control completion.

- [x] **Step 3: Add controller request identity**

Use an incrementing `_botRequestToken`.
Implement these signatures:

```dart
Future<bool> prepareBotMove()
Future<void> playBotMove()
Future<bool> retry()
void cancelBotMovePreparation()
```

Capture the snapshot hash and opponent before awaiting Rust.
After completion, require the same request token, snapshot hash, opponent, bot turn, and empty pending-move slot.
Ignore stale results without surfacing an error.

Change the retry callback to `FutureOr<void> Function()?` and await it in `retry()`.
Keep existing user-visible errors and recovery semantics for a current request failure.

- [x] **Step 4: Pass the focused controller suite**

```shell
flutter test test/game/match/match_controller_test.dart
```

Expected: PASS.

## Task 5: Overlap Search with the Existing Pacing Delay

**Files:**

- Modify: `lib/game/view/game_page.dart`
- Modify: `test/game/view/game_page_test.dart`

- [x] **Step 1: Write failing timing and stale-result widget tests**

Use controlled futures and fake time to prove:

- Search starts immediately when the bot turn begins.
- A fast search waits until 450 milliseconds have elapsed.
- A slow search applies immediately after completion without another 450 millisecond delay.
- Board replacement ignores the old result.
- Widget disposal ignores the old result.
- Rebuilds do not start duplicate searches for one snapshot.
- The board remains unavailable for human input during the bot turn.

Run:

```shell
flutter test test/game/view/game_page_test.dart
```

Expected: FAIL with the synchronous timer-driven implementation.

- [x] **Step 2: Replace timer ownership with work generation**

Replace `_botTimer` with `_botWorkGeneration` and `_botWorkActive`.
Add `_cancelBotWork()` that increments the generation, clears active work, and invalidates the controller request.

- [x] **Step 3: Run search and pacing concurrently**

In `_scheduleBotMove`, start `controller.prepareBotMove()` and `Future.delayed(_botPause)` before awaiting either.
Await both results.
Before applying the move, require that the widget is mounted, the work generation is unchanged, the controller identity is unchanged, and preparation succeeded.

Make `_retry` asynchronous and await the controller retry path.
Do not add a spinner or new loading UI.

- [x] **Step 4: Pass the focused page suite**

```shell
flutter test test/game/view/game_page_test.dart
```

Expected: PASS.

## Task 6: Expose Expert in the Opponent Selector

**Files:**

- Modify: `lib/game/match/match_controller.dart`
- Modify: `lib/game/view/opponent_label.dart`
- Modify: `lib/game/start/start_page.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `test/game/start/start_page_test.dart`

- [x] **Step 1: Write failing selector and mapping tests**

Assert that the selector shows `Easy`, `Normal`, `Hard`, and `Expert` in that order.
Assert that choosing Expert creates a match with `Opponent.strategic` and maps to `BotPolicy.strategic`.
Assert that internal enum names remain hidden from the UI.

Run:

```shell
flutter test test/game/start/start_page_test.dart test/game/match/match_controller_test.dart
```

Expected: FAIL because the new opponent is absent.

- [x] **Step 2: Add the UI enum, mapping, and label**

Add `Opponent.strategic` after `Opponent.minimax`.
Map it to `BotPolicy.strategic`.
Add `Expert` after `Hard` in the start-page difficulty list.
Add `opponentStrategic` with the English value `Expert` to `app_en.arb`.

- [x] **Step 3: Regenerate localization output**

```shell
flutter gen-l10n
```

Expected: PASS and generated localization accessors compile.

- [x] **Step 4: Pass the selector tests**

```shell
flutter test test/game/start/start_page_test.dart test/game/match/match_controller_test.dart
```

Expected: PASS.

## Task 7: Measure and Run the Complete Gate

**Files:**

- Modify: `engine/tests/strategic_bot.rs`
- Verify: every changed file and generated artifact

- [x] **Step 1: Add the release-mode performance test**

Measure a full Strategic search on committed baseline, irregular, and larger reachable states.
Assert that every measurement is below two seconds.
Print the environment, elapsed duration, completed depth, and expanded nodes.
Report separately whether every measurement is below the one-second target.

Run:

```shell
uname -m
sw_vers
sysctl -n machdep.cpu.brand_string
cargo test --release --manifest-path engine/Cargo.toml --test strategic_bot -- --nocapture
```

Expected: PASS with every individual measurement below two seconds.

- [x] **Step 2: Format only the explicit changed files**

Run Rust formatting in check mode first, then format the Rust package only when needed.
Run Dart formatting with the explicit changed Dart source and test paths.

```shell
cargo fmt --manifest-path engine/Cargo.toml -- --check
dart format --output=none --set-exit-if-changed lib/game/rules/rules_engine.dart test/support/match_fixtures.dart lib/game/match/match_controller.dart test/game/match/match_controller_test.dart lib/game/view/game_page.dart test/game/view/game_page_test.dart lib/game/view/opponent_label.dart lib/game/start/start_page.dart test/game/start/start_page_test.dart test/support/rules_engine_parity.dart
git diff --check
```

Expected: PASS with no unrelated formatting change.

- [x] **Step 3: Run focused verification**

```shell
cargo test --manifest-path engine/Cargo.toml bot::strategic
cargo test --manifest-path engine/Cargo.toml --test bot
cargo test --manifest-path engine/Cargo.toml --test bridge_api
cargo test --manifest-path engine/Cargo.toml --test strategic_bot -- --nocapture
flutter test test/game/match/match_controller_test.dart
flutter test test/game/view/game_page_test.dart
flutter test test/game/start/start_page_test.dart
flutter test tool/rules_engine_host_test.dart
```

Expected: PASS.

- [x] **Step 4: Run the repository gate**

Check machine load before a heavy native job and do not overlap another simulator, emulator, Gradle, Xcode, or SDK job.

```shell
uptime
merry run generate
merry run check
```

Expected: PASS.
State what each gate inspected instead of treating the aggregate result as proof of strength or native latency.

- [x] **Step 5: Gather native parity when available**

```shell
merry run parity
```

Expected: Android and iOS choose the pinned Strategic parity move when those runtimes are available.
Report a skipped runtime as `[PARTIAL]`, not as verified parity.
Do not use the daily iPhone without a new explicit approval for each write.

- [x] **Step 6: Audit final scope**

```shell
git status --short --branch
git diff --stat
git diff --check
git diff -- docs/notes/closed-playtest-tester-kit.md
```

Expected: the pre-existing note remains untouched, only the approved Strategic AI scope changed, and nothing is staged or committed.

## Task 2: Prove Strength Across Board Shapes

**Files:**

- Create: `engine/tests/strategic_bot.rs`
- Modify: `engine/tests/bot.rs`

- [x] **Step 1: Add a test-only exact solver**

Implement a memoized exhaustive solver inside `engine/tests/strategic_bot.rs`.
Return outcome and distance to terminal from the requested player's point of view.
Use the engine's public legal-move and transition functions so the solver does not duplicate gameplay rules.

- [x] **Step 2: Discover and freeze horizon fixtures**

Temporarily add an ignored discovery test that enumerates reachable late-round states from baseline, irregular, and larger boards.
Select literal fixtures where the exact solver proves a forced result that the current two-ply `MinimaxBot` misses.
Delete the discovery test after committing the literals and their exact outcomes.

The permanent tests must include these names:

```rust
strategic_finds_a_forced_win_beyond_two_plies
strategic_matches_the_exact_solver_on_small_late_round_states
strategic_uses_irregular_non_zero_origin_topology
strategic_returns_a_legal_move_on_a_larger_board
```

Run the first test before the implementation is complete.

```shell
cargo test --manifest-path engine/Cargo.toml --test strategic_bot strategic_finds_a_forced_win_beyond_two_plies
```

Expected: FAIL until the search selects an exact-solver optimal move.

- [x] **Step 3: Add the deterministic league**

Create a fixed corpus of reachable snapshots grouped by baseline, irregular, and larger topology.
Run `StrategicBot` against production-equivalent `MinimaxBot::new(2)` from both seat assignments.
Score a win as one match point and a draw as one-half match point.

Assert both properties directly:

- Strategic scores more points than Hard in every topology group.
- Strategic earns at least 70 percent of all available points over the complete corpus.

Print the group totals, expanded node counts, and completed depths when an assertion fails.

- [x] **Step 4: Run the focused strength suite**

```shell
cargo test --manifest-path engine/Cargo.toml --test strategic_bot -- --nocapture
```

Expected: PASS with deterministic totals across repeated runs.

## Task 3: Make the Bridge Asynchronous

**Files:**

- Modify: `engine/src/api.rs`
- Modify: `engine/tests/bridge_api.rs`
- Regenerate: `engine/src/frb_generated.rs`
- Regenerate: `lib/src/rust/api.dart`
- Regenerate: `lib/src/rust/frb_generated.dart`
- Regenerate: `lib/src/rust/frb_generated.io.dart`
- Regenerate: `lib/src/rust/frb_generated.web.dart`
- Modify: `test/support/rules_engine_parity.dart`

- [x] **Step 1: Write failing bridge-policy tests**

Add `BotPolicy::Strategic` expectations to Rust bridge tests.
Pin one Strategic move for the shared parity fixture and assert that the returned move is legal.

Run:

```shell
cargo test --manifest-path engine/Cargo.toml --test bridge_api strategic
```

Expected: FAIL because `BotPolicy::Strategic` does not exist.

- [x] **Step 2: Wire `StrategicBot` into the Rust API**

Add `Strategic` to `BotPolicy` and dispatch it to `StrategicBot`.
Remove `#[frb(sync)]` from `choose_bot_move` only.
Keep the Rust function synchronous so flutter_rust_bridge owns worker execution and generated Dart exposes a `Future`.

- [x] **Step 3: Regenerate bridge code**

```shell
merry run generate bridge
```

Expected: PASS and generated Dart declares `Future<GameMove?> chooseBotMove(...)`.
Inspect the generated handler and confirm that this function no longer uses the synchronous execution path.

- [x] **Step 4: Update parity expectations**

Add the Strategic fixture to `test/support/rules_engine_parity.dart` and keep its expected move literal identical to the Rust bridge test.

Run:

```shell
cargo test --manifest-path engine/Cargo.toml --test bridge_api
flutter test tool/rules_engine_host_test.dart
```

Expected: PASS.
