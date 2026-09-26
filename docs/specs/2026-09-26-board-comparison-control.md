# Board comparison and controlled self-play

## Problem and boundary

Issue #67 can measure only the engine baseline, while the app offers four typed boards.
Compare the actual app definitions without copying their layouts into the simulator or moving their ownership out of Dart.
The operator approved drift reconciliation, board comparison support, and a bounded controlled experiment.

## Contract

- A Dart command exports every `BuiltInBoard` directly from the current catalog to a specified directory.
- Each UTF-8 file starts with `ttush-board-v1 <board-id>`, then whitespace-separated `cell <x> <y>`, `piece <id> <first|second> <x> <y>`, and optional `tile <x> <y> <normal|damaged|hole>` rows.
- Coordinates and piece IDs fit `u8`; identifiers use ASCII letters, digits, and hyphens.
- The Rust simulator accepts optional `--board-file <path>` and validates the full input before running any rounds.
- Reject malformed/unknown rows, unknown versions and enums, duplicate cells, invalid pieces, and invalid terrain through syntax checks and existing `BoardConfig` validation.
- Without the option, preserve the baseline behavior and report bytes.
- With the option, report the board ID and complete initial tile/piece values from the state actually used, including normal cells omitted from the sparse overrides.
- All existing policies, seed assignment, opening groups, complete selected traces, and termination reporting apply to the selected board.

This is an offline experiment input, not the app file-loading feature in #73.
Do not change app UI, rules, default board, AI budget, dependencies, generated bridge files, or native packaging.
No visual approval or new device write is needed for this scope.

## Acceptance

1. Missing board selection fails a behavior test before implementation.
2. Exported topology, pieces, and terrain reach the Rust CLI unchanged; a host integration test compares the CLI's initial values with the real app bridge and replays a full reported round.
3. Invalid input exits nonzero without simulation output; no fallback to the baseline.
4. Baseline file input preserves its round outcomes; all app boards produce repeatable reports.
5. Run `CARGO_BUILD_JOBS=2 merry run check`, scoped formatting, documentation spelling, and internal-link checks.
6. Record clean source, binary/input/output hashes, exact commands, repeats, and limits for the experiment.

## Declared experiment

Question: under the unchanged bounded Expert policy, how do the four offered layouts differ in seat outcomes, opening groups, termination causes, and round length?
Use Expert versus Expert, seeds 42 and 2026, default and swapped stream assignment, a 200-turn cap, and trace index zero for every board.
Run one pilot round per board before collection.
If each pilot completes within 120 seconds, collect four rounds per board/seed/assignment condition, then repeat every condition once.
If any pilot exceeds that limit, stop before the main collection and report the runtime constraint; do not silently change the sample or policy.
The full declared collection has 64 condition/seed observations and 128 executions; repeated runs and swapped streams are not independent observations.
The seed ranges overlap earlier baseline samples, which must not be counted as new independent evidence.
Report groups separately, with no pooled population win-rate claim or best-board selection.

The selected traces show legal paths, not forced-line certificates.
Keep #67 open for broader coverage, alternative-reply/initial-position analysis, and synthesis with external human evidence from #42.
Retain the baseline default regardless of these small samples.

## Precedent

Personal Oracle searches for `simulation` and `BoardConfig` returned `[no precedent found]` at source revision `c1681868ac634e4b2414874716bb75a7864113c4`.
Current repository source establishes Dart catalog ownership and Rust rule validation.
