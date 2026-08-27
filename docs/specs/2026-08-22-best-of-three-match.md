# Best-of-Three Match Specification

> **Status:** Historical milestone snapshot.
> Names, paths, and non-goals below describe this milestone and are not current repository guidance; use [CLAUDE.md](../../CLAUDE.md) and the current source for the active contract.

## Goal

Turn a single round into a match: two people play until one of them has won two rounds, seeing after each round who won it and how, with the score visible throughout.

## What already exists

`MatchState` in `engine/src/lib.rs` already implements the rules — it counts round wins, resets the board with the loser starting, and ends the match at two wins, with tests covering both.
It has never been exposed across the bridge.

It cannot be exposed as it stands. `settle_terminal_rounds` advances past a finished round inside the same call that finishes it, so the state a caller receives already holds the next round's opening board. There is no moment at which the position that ended the round can be shown.
`MatchOutcome::Winner(player)` also drops the deciding round's `WinReason`, which the round screen already displays.

## Scope

### Engine

The match gains an explicit phase, and advancing is a caller's decision rather than a side effect.

```rust
enum MatchPhase {
    Playing,
    RoundOver { winner: Player, reason: WinReason },
    MatchOver { winner: Player, reason: WinReason },
}
```

Applying a move that ends a round leaves the match in `RoundOver` with that round's final board intact.
`advance_round` starts the next round; it is rejected in any phase but `RoundOver`.
A match reaching two wins for either player is `MatchOver`, which also carries the deciding round's reason, and accepts no further move or advance.

The reset board can itself be immobilized on arrival, which is why the current code loops.
That case survives as an observable state rather than a hidden iteration: `advance_round` may land directly in `RoundOver` again, and a caller advances through it.
After any `advance_round`, the match is either `Playing` with at least one legal move, or `RoundOver`. It is never `Playing` with no legal move.

### Bridge

The bridge exposes the match, and the round-only functions are removed rather than kept beside it.
Once the screen plays matches, `initialState`, `legalMoves` and `applyMove` have no caller, and leaving two parallel value APIs invites the next change to pick the wrong one.

```rust
fn initial_match() -> MatchSnapshot
fn match_legal_moves(snapshot: MatchSnapshot) -> Result<Vec<GameMove>, String>
fn match_apply_move(snapshot: MatchSnapshot, game_move: GameMove) -> Result<MatchSnapshot, String>
fn advance_round(snapshot: MatchSnapshot) -> Result<MatchSnapshot, String>
```

`MatchSnapshot` carries the current round's `GameSnapshot`, both players' round wins, the phase, the round winner and reason when a round has ended, and the match winner when it has.

**The match snapshot carries its own hash.** The existing `snapshot_hash` covers only the round's value fields, so a snapshot that embedded it unchanged would leave the score editable from Dart while the round stayed tamper-proof. `MatchSnapshot` is hashed under its own prefix over the inner round hash plus every match field, and is rejected on mismatch exactly as the round snapshot is.

### Presentation

The score is visible during play, in each player's panel, as rounds won.
When a round ends, the final board stays on screen under a result overlay naming the round's winner and reason, with a control to start the next round.
When the match ends, that overlay says who won the match instead, still naming how the last round ended, with a control to start a new match.

## Non-Goals

No animation or transition effects: PR #5 established that immediate transitions read fine, and the round-over screen is static for the same reason.
No change to the round rules themselves — push resolution, tile damage, counter-push and win detection are untouched.
No match history, no statistics, no best-of-five or configurable length, no online play, accounts, rankings, or settings.
No new package dependency.

## Architecture

Rust remains the sole rules authority, and the match is a rule.
Dart must not count round wins, decide when a match is over, decide who starts the next round, or decide whether advancing is allowed.
The tripwire list in `CLAUDE.md` gains these shapes: a Dart function that increments a score, compares it to two, or picks the next round's starting player is the same violation as one that resolves a push.

`RoundController` becomes `MatchController` and holds a `MatchSnapshot`. It stays plain Dart with no Flutter imports, and its existing responsibilities carry over unchanged: selection, the legal-move cache, the bridge-failure and retry behaviour, and validating the snapshot contract.

The invariants it enforces grow with the phase:

- Round winner and round reason are both present or both absent, as today.
- A match winner implies a round winner, because a match ends only by a round ending.
- A match winner implies that player has two round wins.
- Moves are refused unless the phase is `Playing`; advancing is refused unless it is `RoundOver`.

## Acceptance Criteria

- Two people can play a match to two round wins, seeing after each round who won it and why before the next one starts.
- The board that ended a round stays visible while its result is shown.
- The score is visible during play without opening anything.
- A round that resets into an immediate immobilization is shown as a round result, not skipped.
- The match result names both the match winner and how the deciding round ended.
- Dart contains no function that counts round wins, decides the match, or chooses the next starting player.
- A snapshot whose score has been edited is rejected by the bridge.
- Every branch is covered, and `merry run check` passes.
