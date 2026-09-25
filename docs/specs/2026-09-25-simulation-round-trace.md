# Representative simulation round traces

## Problem and scope

[Issue #67](https://github.com/AndrewDongminYoo/ttush_push/issues/67) needs representative lines that can be investigated after opening statistics identify a question.
The simulator currently reports aggregate and first-move outcomes, but cannot emit the actual continuation of one sampled round.
Add an optional round trace without changing rules, policies, seeds, board configuration, dependencies, or bridge APIs.
This is a further prerequisite for analysis, not completion of #67 or proof of a forced win.

## CLI contract

Accept `--trace-game <u64>` as a zero-based index into the rounds selected by `--games`.
Validate the index after parsing all options, regardless of flag order; it must be strictly less than `games`.
Malformed, negative, missing, and out-of-range values fail with a diagnostic and the existing error exit code.
For a successful run without the option, preserve the complete existing output byte for byte.
With the option, append one trace block after the unchanged aggregate and opening rows.

The trace contains these unique keys:

- `trace.game_index`: the selected zero-based index.
- `trace.first_seed` and `trace.second_seed`: the actual seeds used to construct the two policies, retaining existing unsigned wrapping arithmetic.
- `trace.move.<n>.player`, `trace.move.<n>.piece`, and `trace.move.<n>.direction`: the acting player (`first` or `second`), piece ID, and lowercase direction for each successfully applied move, with contiguous one-based move numbers.
- `trace.turns`: the number of applied moves.
- `trace.termination`: `knockout`, `immobilization`, `turn_limit`, `repetition`, or `policy_none` for the existing unexpected no-move exit.
- `trace.winner`: `first`, `second`, or `none`; capped, repeated, or policy-none results have no winner.

Capture moves from the actual simulation, without calling a policy again for reporting.
Retain moves only for the selected round, not every round.
Preserve the existing termination precedence: a win on the last allowed move is a win, not a capped result.
The existing report supplies the board, policies, base seed, and turn cap; the protocol supplies source revision and search-budget provenance.
No state hash, list of all alternative moves, or generic replay format is required.

## Acceptance and limits

Replay a completed trace with `GameState::baseline()`, `apply_move`, and `outcome`, checking acting players, every move, count, and final winner/reason.
Check a nonzero selected index, seed wrapping, repeatability, unchanged statistics, and invalid option diagnostics.
Contrast the known Strategic second-seat terminal fixture with a shorter cap and test a win exactly at the cap.
Compare untraced output against output captured from the parent revision before implementation.
Run Rust tests, formatting, Clippy, and the repository's applicable local and hosted gates.
No visual approval is needed for CLI output.
The record describes one policy-selected path; alternative replies, forced-line proofs, board-variant experiments, and human play evidence remain open.
