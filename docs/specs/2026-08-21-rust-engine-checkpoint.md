# Rust Engine Checkpoint Specification

## Goal

Build only the deterministic Rust rules engine and a headless random simulation command needed to assess the current game loop.

The Flutter and Flame scaffold remains outside this checkpoint.

## Sources and Scope

This specification normalizes the v0.1 rules agreed in [the preserved design conversation](../../.claude/cache/push_push.md).

It implements the three requested checkpoint outcomes: an `engine` crate containing `GameState`, `Move`, and `apply_move()`; executable rule specifications; and a seeded `simulate` CLI that can run 100,000 rounds.

Time control, UI, animation, audio, networking, matchmaking, bots beyond uniform random selection, search, and production board tuning are not part of this checkpoint.

## Stable Rules

1. A player chooses one of their pieces and moves it exactly one orthogonal cell.
2. A normal destination must be playable, non-hole, and unoccupied.
3. Moving into an adjacent opposing piece attempts a one-cell push in the same direction.
4. A push is illegal when the displaced piece has another piece behind it.
5. A push never displaces more than one piece.
6. Only the actively moved piece damages its departure tile: `Normal -> Damaged -> Hole`.
7. A passively displaced piece does not change either its departure tile or its destination tile.
8. Pushing an opponent outside the topology or into a hole immediately wins the round.
9. The pushed piece may not push its specific pusher back on its immediately following turn.
10. The restriction in rule 9 does not prevent another move, another push, or a move by another piece.
11. After any legal response by that player, the restriction expires.
12. If the next player has no legal move after a non-knockout move, the player who moved wins by immobilization.
13. The engine has no draw rule, turn clock, score, or maximum-turn rule.

## State Model

`GameState` represents one round and contains the immutable `BoardConfig`, mutable tile conditions, placed pieces, side to move, optional immediate-counter-push restriction, and round outcome.

`BoardConfig` owns topology and initial placements so board shape and starting layout stay balance inputs rather than rules.

The baseline configuration is deliberately an experiment: a fully playable 5 by 5 board with two pieces per player at `(1, 0)`, `(3, 0)`, `(1, 4)`, and `(3, 4)`.

The first mover owns the top-row pair and is `Player::First`.

This configuration is not a game rule and must be replaceable without changing movement or outcome logic.

`MatchState` is a small wrapper for the agreed best-of-three product rule.

It records round wins, resets the round after a winner, starts the next round with the previous round loser, and ends after two round wins.

## Public API

```rust
pub struct GameState;
pub struct Move;

pub fn legal_moves(state: &GameState) -> Vec<Move>;
pub fn apply_move(state: &GameState, mv: Move) -> Result<GameState, IllegalMove>;
pub fn outcome(state: &GameState) -> Outcome;
```

`apply_move()` is a pure state transition.

It never reads time, random state, files, UI state, or network state.

## Simulation Contract

`cargo run --release -- --games 100000 --seed 42` simulates independent rounds from the baseline configuration with a reproducible uniform-random legal-move bot.

The command prints requested games, first- and second-mover wins, knockout and immobilization wins, total and maximum turns, repeated-state count, and turn-limit count.

Repeated states and the configurable simulation turn limit are measurement safeguards only.

They do not modify `GameState` or add a draw rule to v0.1.

## Acceptance Criteria

1. `cargo test` in `engine/` executes rule examples covering every stable rule, match reset behavior, and deterministic transitions.
2. The simulation command accepts `--games` and `--seed`, produces identical output for identical arguments, and completes 100,000 rounds.
3. The engine has no dependency on the Flutter application or on an external runtime service.
