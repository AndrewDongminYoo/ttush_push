# Bounded alternative replies — 2026-09-26

## Source and question

This analysis continues [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67) after the [four-board self-play comparison](2026-09-26-board-comparison-control.md).
The [declaration](../specs/2026-09-26-forced-line-analysis.md) was committed before collection at clean source `bdc8b67a1e1d0df90fcb765d9a6d2cbf6f16bc61`.
It selected the seed-42 default trace on each of four boards, at the initial position and eight and four moves before its recorded terminal.
Every root alternative received depth eight including that root move, at most 100,000 visited states, and a 120-second process timeout.

All twelve position commands and their complete repeats exited zero with empty stderr and byte-identical reports.
Four additional full-path commands verified the original recorded terminal outcomes before suffix selection, for 28 processes in total.
The [provenance](2026-09-26-forced-line-analysis/provenance.json) records exact commands, times, source and binary hashes, input hashes, outputs, repeats, and local verification readers.
These are selected positions from four existing traces, not twelve independent games or new self-play observations.
The two suffix positions on a board share the same game.

## Results

`first` or `second` means that player has a winning strategy established from terminal outcomes within this search bound.
`unknown` means the search did not establish either winner; it does not mean draw, balance, or absence of a winning strategy.
Node counts are the sum over independently budgeted root alternatives, not a single per-position cap.

| Board / position                                                                                   | Moves replayed | Mover  | Result  | Root alternatives | Nodes   | Depth cutoffs | Node cutoffs |
| -------------------------------------------------------------------------------------------------- | -------------- | ------ | ------- | ----------------- | ------- | ------------- | ------------ |
| [baseline / initial](2026-09-26-forced-line-analysis/baseline-initial-canonical.txt)               | 0              | first  | unknown | 6                 | 600000  | 496446        | 106          |
| [baseline / last8](2026-09-26-forced-line-analysis/baseline-last8-canonical.txt)                   | 30             | first  | second  | 3                 | 118     | 16            | 0            |
| [baseline / last4](2026-09-26-forced-line-analysis/baseline-last4-canonical.txt)                   | 34             | first  | second  | 2                 | 8       | 0             | 0            |
| [clipped-corners / initial](2026-09-26-forced-line-analysis/clipped-corners-initial-canonical.txt) | 0              | first  | unknown | 4                 | 308723  | 248474        | 22           |
| [clipped-corners / last8](2026-09-26-forced-line-analysis/clipped-corners-last8-canonical.txt)     | 22             | first  | second  | 3                 | 210     | 0             | 0            |
| [clipped-corners / last4](2026-09-26-forced-line-analysis/clipped-corners-last4-canonical.txt)     | 26             | first  | second  | 2                 | 12      | 0             | 0            |
| [large / initial](2026-09-26-forced-line-analysis/large-initial-canonical.txt)                     | 0              | first  | unknown | 12                | 1200000 | 1090043       | 520          |
| [large / last8](2026-09-26-forced-line-analysis/large-last8-canonical.txt)                         | 76             | first  | second  | 4                 | 1210    | 283           | 0            |
| [large / last4](2026-09-26-forced-line-analysis/large-last4-canonical.txt)                         | 80             | first  | second  | 3                 | 34      | 0             | 0            |
| [large-holes / initial](2026-09-26-forced-line-analysis/large-holes-initial-canonical.txt)         | 0              | first  | unknown | 12                | 1200000 | 1080901       | 481          |
| [large-holes / last8](2026-09-26-forced-line-analysis/large-holes-last8-canonical.txt)             | 63             | second | first   | 3                 | 1029    | 393           | 0            |
| [large-holes / last4](2026-09-26-forced-line-analysis/large-holes-last4-canonical.txt)             | 67             | second | first   | 2                 | 14      | 0             | 0            |

Every initial position remained unknown.
All eight suffix positions proved a loss for the side to move: every legal root alternative had the same proved opposing winner.
The winner was Second for baseline, clipped corners and large, and First for large holes.
This locates unavoidable losses at the selected late positions without locating the first losing decision or solving any initial position.

Some resolved positions still have depth cutoffs in other explored branches.
This is sound because the winning player needs one proved continuation at its own turn, while every defensive reply must lose.
The solver can discard unresolved alternatives at a winning player's node once it has a proved winning choice; it never discards an unresolved defense when claiming that the defender must lose.
The report does not claim every branch ended, a shortest forced win, or a portable proof certificate.

## Representative continuations

These are the last four observed moves of each original trace, starting at the listed proved losing position.
The proof covers alternatives to those chosen moves; these displayed paths alone would not establish that proof.
Piece identifiers and directions use the engine coordinates and are not screen-relative instructions.

| Board           | Starting prefix | Recorded continuation                                     |
| --------------- | --------------- | --------------------------------------------------------- |
| baseline        | 34              | first:0 up; second:3 up; first:1 down; second:3 down      |
| clipped-corners | 26              | first:0 left; second:2 right; first:0 up; second:2 up     |
| large           | 80              | first:0 down; second:4 down; first:1 left; second:3 right |
| large-holes     | 67              | second:3 up; first:0 down; second:3 down; first:0 right   |

## Independent checks

The [full local gate log](2026-09-26-forced-line-analysis/local-gate.log) records the pre-commit candidate check: 220 Flutter tests, 105 Rust tests, seven loaded host bridge tests, analysis, formatting, clippy, release guard, and Trunk.
Native parity explicitly skipped because no simulator or emulator was running; this change does not alter native packaging, the app, bridge schema, rules, or bot policy.
The Cargo package default still selects `simulate`; regenerating the lockfile after that metadata change produced no lockfile diff.

Small-board tests compare each search alternative against an independent exhaustive solver and known literal outcomes.
Mutations that ignored unknown replies or inspected a terminal beyond the node budget failed their regressions before restoration.
The CLI rejects malformed files, wrong actors, illegal moves, post-terminal moves, invalid bounds, and duplicate arguments without printing a report.
The [collector source snapshot](2026-09-26-forced-line-analysis/readers/collector.py.txt) rejects dirty source, and its report reader rejected a forged proved result whose only reply was unknown.

A separate local Dart reader replays all sixteen canonical reports through the actual app bridge and compares initial terrain, pieces, actors, paths and complete root move lists.
For the eight suffixes it evaluates every legal branch to depth eight, without the Rust analyzer's early winning-child return or node-budget pruning, and matches every reported reply winner.
That reader retained a separate one-million-node safety stop per report and did not reach it.
Its [output](2026-09-26-forced-line-analysis/bridge-verification.txt) records the actual node counts.
Changing a reported reply winner caused `Proof result mismatch`; the original reports all passed.
For the four initial positions it verifies transport and root enumeration only, not an independent initial-position proof.
Both implementations use the same Rust rule engine, so agreement does not independently prove those rules correct.
The [local reader source snapshot](2026-09-26-forced-line-analysis/readers/verify_bridge.dart.txt) and its hash are retained in provenance; it is a verification aid rather than a shipped app feature.
To run that snapshot from the repository root, copy it to a temporary `.dart` file and use `dart --packages=.dart_tool/package_config.json run <reader.dart> <canonical-report>`.
The collector snapshot retains its original absolute workspace and output paths; adapt those paths when reproducing collection elsewhere.

## Reproduction and limits

Build the analyzer at the pinned source and use the committed move input and prior board input:

```sh
cargo build --release --locked --manifest-path engine/Cargo.toml --bin analyze
engine/target/release/analyze --board-file docs/notes/2026-09-26-board-comparison-control/boards/baseline.board --moves-file docs/notes/2026-09-26-forced-line-analysis/inputs/baseline-last8.moves --depth 8 --nodes 100000
```

At the pinned implementation source, the new evidence directory has not yet been committed; copy the desired `.moves` file from this evidence commit into a temporary location and pass that location instead.
The move file contains only the initial header and a prefix of an already recorded complete path; it preserves counter-push and damage state by replay rather than fabricating a snapshot.
Use the corresponding board and move files to reproduce each other row, then compare the entire output with its canonical report.

Keep the baseline default and #67 open.
No board is shown balanced, no complete opening tree is solved, no draw theorem is established, and no human evidence is added.
The bounded follow-up question is where these selected traces first leave a defensible position, if a larger declared search can resolve that boundary.
Synthesis with [#42](https://github.com/AndrewDongminYoo/ttush_push/issues/42) still requires external playtest evidence; an unbounded perfect solver or larger sampling run is not implied by this result.
