# Rust Engine Checkpoint Implementation Plan

**Goal:** Implement the standalone Rust rules engine, executable v0.1 specifications, and deterministic random-round simulator described in [the checkpoint specification](../specs/2026-08-21-rust-engine-checkpoint.md).

**Architecture:** Keep the `engine` package dependency-free. Put pure state transitions and the minimal match wrapper in `src/lib.rs`, rule examples in an integration test, and command-line parsing plus random simulation in `src/bin/simulate.rs`.

**Tech Stack:** Rust 2024 edition and the Rust standard library only.

## Constraints

- Modify only `engine/` and the checkpoint documents.
- Preserve all Flutter and Flame files unchanged.
- Use `BoardConfig` for topology and starting layouts.
- Treat the 5 by 5 layout as a simulator baseline, not a gameplay invariant.
- Add no third-party dependencies.
- Write each behavior test first and observe its expected failure before production code is added.

## File Map

- `engine/src/lib.rs`: owns the game types, move enumeration, pure transition, outcome calculation, baseline configuration, and best-of-three wrapper.
- `engine/src/bin/simulate.rs`: parses arguments, owns deterministic pseudo-random selection, and formats aggregate results.
- `engine/tests/rules.rs`: executable examples for movement, push, tiles, counter-push, outcomes, and match reset.
- `engine/tests/simulation.rs`: invokes the binary twice to prove seeded output is stable.

### Task 1: Define Core Round State

**Files:**

- Create: `engine/tests/rules.rs`
- Create: `engine/src/lib.rs`

**Interfaces:**

- Produces: `Player`, `Position`, `Direction`, `Tile`, `Piece`, `BoardConfig`, `GameState`, `Move`, `IllegalMove`, `Outcome`, `legal_moves()`, `apply_move()`, and `outcome()`.

- [x] Add a failing empty-cell movement test with a literal source and destination expectation.
- [x] Run `cargo test --test rules normal_move_changes_position_and_damages_only_departure_tile` and confirm it fails because the engine API does not exist.
- [x] Implement the smallest copyable state types and pure normal-move transition.
- [x] Run the targeted test and confirm it passes.
- [x] Add and run failing tests for off-board movement, holes, friendly occupancy, and damaged-to-hole departure behavior.
- [x] Implement only the validation and tile transition needed by those tests.
- [x] Run `cargo test --test rules`.

### Task 2: Specify Push and Round Outcomes

**Files:**

- Modify: `engine/tests/rules.rs`
- Modify: `engine/src/lib.rs`

**Interfaces:**

- Consumes: Task 1's state and pure transition API.
- Produces: one-piece push behavior, counter-push restriction, knockout and immobilization outcomes, and best-of-three `MatchState`.

- [x] Add failing literal-fixture tests for normal pushes, blocked pushes, pushes into holes, pushes outside topology, and passive displacement leaving tiles unchanged.
- [x] Run each targeted test and confirm failure before changing production code.
- [x] Implement one-piece push resolution, knockout outcome, and no-chain-push rejection.
- [x] Add failing tests for the specific immediate counter-push restriction, allowed alternative response, restriction expiry, and immobilization outcome.
- [x] Implement the restriction and post-move legal-move outcome check.
- [x] Add and run a failing test for match reset, loser-starts-next-round, and two-round match victory.
- [x] Implement the narrow `MatchState` wrapper.
- [x] Run `cargo test`.

### Task 3: Add Deterministic Simulation

**Files:**

- Create: `engine/src/bin/simulate.rs`
- Create: `engine/tests/simulation.rs`

**Interfaces:**

- Consumes: Task 2's `GameState::baseline()`, `legal_moves()`, `apply_move()`, and `Outcome`.
- Produces: `simulate --games <positive integer> --seed <u64> [--max-turns <positive integer>]` through Cargo's `simulate` binary.

- [x] Add a failing binary integration test that supplies the same games, seed, and turn limit twice and compares complete stdout.
- [x] Run `cargo test --test simulation` and confirm the missing binary causes the expected failure.
- [x] Implement manual argument parsing, a fixed standard-library pseudo-random generator, independent round execution, repetition detection, a configurable safety limit, and stable text output.
- [x] Run the integration test and then `cargo run --release -- --games 100000 --seed 42`.

### Task 4: Audit Checkpoint Evidence

**Files:**

- Verify only: `engine/` and the two checkpoint documents.

- [x] Run `rustfmt --check --edition 2024 src/lib.rs src/bin/simulate.rs tests/rules.rs tests/simulation.rs` from `engine/`.
- [x] Run `TMPDIR="$PWD/target/test-tmp" cargo test` from `engine/`.
- [x] Run `cargo run --release -- --games 100000 --seed 42` twice and compare the captured output byte-for-byte.
- [x] Run `git diff --check` and inspect the path-limited diff and status for unintended Flutter edits.
