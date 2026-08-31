# Plan Checkbox Drift in docs/plans

Verified against `main` on 2026-08-31, after the board-definition work merged.

## What is stale

Two plans in `docs/plans/` carry unchecked steps although the work they describe is present in the code:

- `2026-08-22-playable-round-vertical-slice.md` — 31 unchecked steps.
  Its seven checked boxes are the Plan Self-Review section, which is filled in while the plan is written, not while it is executed.
- `2026-08-24-authoritative-move-resolution-implementation.md` — 33 unchecked steps.

`2026-08-21-rust-engine-checkpoint.md`, `2026-08-22-playtest-ready-game-screen.md`, `2026-08-25-air-ruins-match-scene-implementation.md`, and `2026-08-30-board-definition-implementation.md` are fully checked and need nothing.

## Why they were not simply checked off

`2026-08-22-playable-round-vertical-slice.md` was **not executed as written**.
Its file table and several steps build `lib/game/round/round_controller.dart`, which does not exist; the controller that survives is `lib/game/match/match_controller.dart`, introduced by a later plan.
Marking those steps complete would record a step that never ran on the artifact it names.

The same caution applies more weakly to the 08-24 plan: its end state is present, but no session confirmed its steps one by one.

## What reconciling it would take

Walk both plans step by step against the current tree, check only the steps whose artifact still exists under the name the step gives, and add a short note where a later plan superseded one.
Treat a plan whose deliverable was renamed as superseded rather than complete.

Until that is done, read an unchecked box in these two files as "unconfirmed", not as "not implemented".
