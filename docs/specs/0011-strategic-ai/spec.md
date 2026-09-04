# Spec: Strategic AI

## Status

Approved for implementation by the operator on 2026-09-04.

## Problem

The strongest current policy searches two plies and scores a leaf only by the active player's legal move count.
This policy can miss longer forced wins and traps.
The synchronous Flutter-to-Rust call also makes a larger search unsuitable for the UI thread.

## Goal

Add an `Expert` opponent that feels extremely difficult to beat during normal play.
The opponent must adapt to future `BoardDefinition` topology and starting-layout changes without board-specific Rust code.
The opponent must preserve deterministic move selection for the same snapshot and policy.

## Product Contract

1. Add `Expert` after `Hard` in every opponent selector.
2. Keep `Easy`, `Normal`, and `Hard` behavior unchanged.
3. Start the Expert search when its turn starts.
4. Run the existing 450 millisecond pacing delay at the same time as the search.
5. Apply the move after the pacing delay and search both finish.
6. Target a total AI-turn delay below one second on normal supported devices.
7. Require a total AI-turn delay below two seconds on the performance-reference device or environment.
8. Treat the latency limits as release acceptance criteria, not as wall-clock search cutoffs.
9. Keep the board unavailable for human input while the Expert owns the turn.

## Search Architecture

1. Add `BotPolicy::Strategic` and a matching `Opponent.strategic` value.
2. Keep the simple policies in `engine/src/bot.rs`.
3. Put the new search implementation in `engine/src/bot/strategic.rs`.
4. Use iterative-deepening root-player minimax with alpha-beta pruning.
5. Use a transposition table keyed by the complete `GameState` value.
6. Order moves by an immediate win, a transposition-table best move, an immediate-loss block, and the stable engine move order.
7. Use a deterministic node budget.
8. Select one committed node budget during implementation from release-mode measurements.
9. Scale the budget down deterministically when tile or piece counts increase beyond the baseline board.
10. Return the best move from the last completed depth when the next depth exhausts the budget.
11. Always complete a one-ply pass before a deeper search starts.
12. Keep snapshot-derived tie-breaking so the same snapshot and policy return the same move on every supported native runtime.
13. Add no search, random-number, or machine-learning dependency.

## Evaluation

Terminal wins and losses outrank every positional score.
The positional evaluation uses only current state and rule-derived values.
It must not use fixed coordinates, a rectangular-board assumption, a five-by-five assumption, or a fixed piece count.

The evaluation includes these features from the searching player's point of view:

- The signed legal move count for the side to move.
- The signed safe move count after one reply.
- Immediate knockout and immobilization wins for the side to move.
- Pieces that the side to move can knock out on the next move.
- Reachable foothold durability, normalized by the current playable-cell count.

All non-terminal feature totals must remain below the terminal score range.

## Bridge and Flutter Flow

1. Keep Rust responsible for policy selection, legal moves, state transitions, evaluation, and the chosen move.
2. Change the generated Dart contract for `choose_bot_move` from a synchronous result to a `Future` result.
3. Run the CPU-heavy Rust function through the asynchronous flutter_rust_bridge worker path.
4. Change `RulesEngine.chooseBotMove` and its fake implementations to return `Future<GameMove?>`.
5. Let `MatchController` prepare a bot move asynchronously without publishing a new snapshot early.
6. Let `GamePage` start the search and the pacing timer together.

Before the result is applied, verify all of these values:

- The widget is still mounted.
- The controller generation is unchanged.
- The current snapshot hash matches the search input hash.
- The selected opponent policy matches the search input policy.
- The second player still owns the turn.
- No move is already pending.

7. Discard a stale result without showing an error.
8. Regenerate flutter_rust_bridge output through `merry run generate`.
9. Do not edit generated bridge files by hand.

## Budget and Failure Behavior

Node-budget exhaustion is normal completion.
It returns the last completed iterative-deepening result.

If Rust cannot reconstruct or validate the input snapshot:

- Preserve the currently displayed match.
- Surface the existing recoverable bridge error.
- Keep the existing retry action.

If the board definition changes while a search is running:

- Invalidate the old controller generation.
- Ignore the old result when it returns.
- Do not let the result mutate the replacement match.

The first implementation does not add cross-bridge cooperative cancellation.
Each search has a deterministic bounded workload, and a board replacement starts with the human player's turn.

## Strength Acceptance

1. Add late-round fixtures that an independent exhaustive test solver can finish.
2. Require `StrategicBot` to choose an optimal move in every solver-classified fixture.
3. Include forced wins beyond the current two-ply horizon.
4. Include traps where a locally strong mobility score loses after multiple replies.
5. Include knockout and immobilization wins.
6. Include baseline, irregular, and larger board topologies.
7. Add a fixed production-equivalent league that runs both seat assignments from a committed corpus of reachable states.
8. Require Strategic to score more match points than Hard on every topology group.
9. Require Strategic to score at least 70 percent of all available match points across the complete corpus.
10. Keep the corpus and policy choices deterministic so a result change identifies an engine change instead of random variation.

## Test Strategy

### Rust unit tests

- Prove legal output or `None` for every policy.
- Prove deterministic output for identical state and budget.
- Prove terminal scores outrank positional scores.
- Prove node-budget exhaustion returns the last completed depth.
- Prove the transposition table does not change the selected move.
- Prove the evaluation works on non-rectangular and non-zero-origin topology.

### Rust integration tests

- Compare Strategic decisions with the exhaustive solver corpus.
- Run the deterministic league against Hard from both seats.
- Record expanded nodes and completed depth for diagnostic output on failure.
- Measure release-mode search latency on baseline and representative variant states.

### Dart and Flutter tests

- Prove `Expert` maps to `BotPolicy::Strategic` and appears after `Hard`.
- Prove the search and 450 millisecond pacing delay overlap.
- Prove a fast result waits for the pacing delay.
- Prove a slower result applies when it completes without adding another delay.
- Prove a board replacement or disposed page ignores the old result.
- Prove a bridge failure preserves the existing retry behavior.
- Prove only one search can prepare a move for one snapshot.

### Native evidence

- Run the existing bridge parity test with the new policy on Android and iOS when the runtimes are available.
- Assert that both runtimes choose the same move for the parity fixture.
- Record end-to-end Expert-turn latency on the performance-reference environment.
- Do not install or launch the app on the operator's daily iPhone without separate approval for each device write.

## Expected Source Scope

The implementation is expected to modify these owned source areas:

- `engine/src/bot.rs`
- `engine/src/bot/strategic.rs`
- `engine/src/api.rs`
- Focused Rust bot and bridge tests.
- `lib/game/match/match_controller.dart`
- `lib/game/rules/rules_engine.dart`
- `lib/game/view/game_page.dart`
- `lib/game/view/opponent_label.dart`
- `lib/game/start/start_page.dart`
- English localization input and generated localization output.
- Focused Dart and Flutter tests.
- Generator-owned flutter_rust_bridge output.

The implementation must preserve author-unknown changes outside this scope.

## Non-goals

- A mathematically perfect solver for every board.
- A board-specific opening book.
- A trained model or online service.
- New gameplay rules or `BoardDefinition` fields.
- A player-visible depth, time, node-budget, or evaluation-weight control.
- Difficulty persistence changes.
- Matchmaking, accounts, ranking, or telemetry.
- A new loading screen or AI-thinking animation.
- Broad refactoring of the existing simple policies or match UI.

## Verification

The implementation must run focused RED and GREEN checks before the aggregate gate.
The aggregate verification is:

```shell
dart format --output=none --set-exit-if-changed <changed-dart-files>
flutter analyze
cargo test --manifest-path engine/Cargo.toml
cargo test --release --manifest-path engine/Cargo.toml
merry run generate
merry run check
```

The release-mode latency check must state which environment it measured.
A host or simulator measurement does not prove latency on an untested physical device.

## Oracle Precedent

`[no precedent found]`

The Oracle search found no project precedent for a board-generic strong search policy or its latency contract.
This Spec establishes the first project precedent for both topics.
