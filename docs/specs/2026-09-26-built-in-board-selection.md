# Built-in board selection

## Contract

Issue #72 adds one bounded board choice to the existing match setup.
The baseline remains the default.
The second board removes the four corners of the existing five-by-five board, leaving 21 playable cells.
Piece IDs, owners, and coordinates remain the baseline values: First at (1, 0) and (3, 0), Second at (1, 4) and (3, 4).
Both boards use the current background asset.

The clipped-corner board preserves horizontal reflection and half-turn symmetry while shortening the outer files.
This is a topology and edge-pressure hypothesis for playtest evaluation, not a correction proven to eliminate the baseline self-play seat signal.
The [controlled #67 experiment](../notes/2026-09-26-seed-assignment-control.md) uses only the baseline, so it cannot measure the new board's balance.
External-player evidence and any broader product balance decision remain in #42 and #67.

## Ownership and state

A typed built-in catalog associates stable IDs `baseline` and `clipped-corners` with `BoardDefinition` values.
Keep the existing `BoardDefinition` constructor compatible.
Dart owns configuration and presentation.
Rust still validates cells and pieces and decides every move, round, and match.
Pass the selected definition through the existing `GamePage` constructor.
Do not add bridge fields, rule logic, dependencies, a board editor, or storage.

Selection stays in the mounted setup page, including when the player returns from a match.
A new app/setup state starts with the baseline.
There are no stored IDs to migrate or parse, so unknown-ID fallback is not needed in this slice.

## Acceptance

- Verify both catalog IDs and complete topology/starting-piece values.
- Select either board through localized setup controls and observe the definition received by the engine.
- Retain selection on return and restore the default in fresh setup state.
- Keep choices and Start usable in English and Korean at a Flutter text scale of 2.0.
- Exercise missing-cell hit testing, reset and next-round topology, and stale AI/replay invalidation through existing regressions and real-engine fixtures.
- Run each offered board through native gameplay, including Expert responses and large text, on Android and iOS runtimes.
- Inspect captured native screens and retain runtime, source, command, timing, and screenshot evidence.
- Obtain operator approval of the rendered choice and board before merge.

## Precedent

The personal project precedent in `wiki/entities/ttush-push.md` and `wiki/sources/ttush_push--claude.md` treats topology as configuration and keeps rules in Rust.
The current `CLAUDE.md` confirms that boundary.
That precedent supports reusing the existing definition seam instead of adding another rules layer.
No indexed precedent selected this exact topology or its persistence policy.
