# Tactile Feedback Specification

> **Status:** Historical milestone snapshot.
> Names, paths, and non-goals below describe this milestone and are not current repository guidance; use [CLAUDE.md](../../CLAUDE.md) and the current source for the active contract.

## Goal

Let a player feel and hear what the board just did, so a move, a push, and a won round are distinguishable without watching for the change.

## Why this replaces the animation milestone

The playtest asked three questions about whether immediate state transitions are readable.

- Is a move too instantaneous to follow?
- Does a push go unnoticed?
- Does a broken foothold go unnoticed?

All three came back clear, so the animation work they were meant to justify is not built.
Interpreting a snapshot diff to drive animation would also have put rule meaning back into Flutter, which remains the boundary this project protects.
Haptics and sound need none of that: they fire from the action the player just took, not from a comparison of two states.

## Scope

Four distinct events, each tied to an action the player performs, and each felt as a vibration paired with its own sound effect.

- Selecting one of your own pieces.
- Applying a move onto an empty destination.
- Applying a move onto a destination an opposing piece occupies, felt more strongly than an ordinary move.
- Ending a round, felt as the strongest of the four.

A move applied by retrying one the bridge rejected feels the same as one applied by a tap, because the board advances either way.

Nothing fires for a rejected tap, a cleared selection, a re-tap of the piece already selected, a bridge failure, or a retry of initialization.

## Non-Goals

No animation, no transition model, and no presentation state that outlives a snapshot replacement.
No settings screen, no music, and no change to the Rust rules, the bridge API, or generated code.
Sound follows the ringer switch instead of getting its own toggle: these effects are decoration, and silencing the device is the control a player already has.

## Architecture

`RoundController` stays Flutter-independent and gains nothing.
`GamePage` reports the event, because it is the layer that already knows which action the player took, and a `RoundFeedback` implementation alone decides how that event is felt.
Keeping the two apart means a change of intensity, or dropping one channel, happens in one place rather than at every call site.

The sound effects are synthesized by `tool/generate_sfx.dart` rather than sourced, so the repository stays self-contained and each sound's provenance is the script that made it.
One player is kept per effect and reused, and a repeat stops the previous playback rather than layering over it.

Distinguishing a push from an ordinary move reuses the rule already stated for the board's destination markers: a destination occupied by any piece in the current snapshot is a push.
This is a read of the snapshot before the move is applied, not a computation of what the push does.

Because a rejected move can still be applied later through Retry, that classification is held until the move actually lands, then consumed.
It is cleared on restart. This is the one piece of state that outlives the tap, and it describes an action rather than a board position, so it does not reintroduce diffing between snapshots.

Ending a round is read from the snapshot the engine returns, by the same `winner` field the result overlay uses.

## Acceptance Criteria

- Selecting, moving, pushing, and winning each produce a different vibration and a different sound.
- A tap that changes nothing produces none, including a re-tap of the selected piece.
- A move that lands on retry feels the same as one that landed on the first attempt.
- The four events are distinguishable in the hand and in the ear on a physical device. No test can assert this; it is confirmed by a device pass.
- Silencing the device silences the effects.
- Every branch is covered, and `merry run check` passes.
