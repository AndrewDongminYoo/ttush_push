# Tactile Feedback Specification

## Goal

Let a player feel what the board just did, so a move, a push, and a won round are distinguishable without watching for the change.

## Why this replaces the animation milestone

The playtest asked three questions about whether immediate state transitions are readable.

- Is a move too instantaneous to follow?
- Does a push go unnoticed?
- Does a broken foothold go unnoticed?

All three came back clear, so the animation work they were meant to justify is not built.
Interpreting a snapshot diff to drive animation would also have put rule meaning back into Flutter, which remains the boundary this project protects.
Haptics need none of that: they fire from the action the player just took, not from a comparison of two states.

## Scope

Four distinct sensations, each tied to an action the player performs.

- Selecting one of your own pieces.
- Applying a move onto an empty destination.
- Applying a move onto a destination an opposing piece occupies, felt more strongly than an ordinary move.
- Ending a round, felt as the strongest of the four.

A move applied by retrying one the bridge rejected feels the same as one applied by a tap, because the board advances either way.

Nothing fires for a rejected tap, a cleared selection, a re-tap of the piece already selected, a bridge failure, or a retry of initialization.

## Non-Goals

No animation, no transition model, and no presentation state that outlives a snapshot replacement.
No sound: it would mean reintroducing an audio dependency removed in the playable-round milestone, and it is a separate decision from whether the device should buzz.
No settings screen to turn haptics off, and no change to the Rust rules, the bridge API, or generated code.

## Architecture

`RoundController` stays Flutter-independent and gains nothing.
`GamePage` fires the feedback, because it is the layer that already knows which action the player took.

Distinguishing a push from an ordinary move reuses the rule already stated for the board's destination markers: a destination occupied by any piece in the current snapshot is a push.
This is a read of the snapshot before the move is applied, not a computation of what the push does.

Because a rejected move can still be applied later through Retry, that classification is held until the move actually lands, then consumed.
It is cleared on restart. This is the one piece of state that outlives the tap, and it describes an action rather than a board position, so it does not reintroduce diffing between snapshots.

Ending a round is read from the snapshot the engine returns, by the same `winner` field the result overlay uses.

## Acceptance Criteria

- Selecting, moving, pushing, and winning each produce a different platform feedback call.
- A tap that changes nothing produces none, including a re-tap of the selected piece.
- A move that lands on retry feels the same as one that landed on the first attempt.
- The four sensations are distinguishable in the hand on a physical device. No test can assert this; it is confirmed by a device pass.
- Every branch is covered, and `merry run check` passes.
