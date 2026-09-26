# App board comparison control — 2026-09-26

## Contract and source

This is a bounded comparison for [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67), following the [baseline seed control](2026-09-26-seed-assignment-control.md).
The [committed declaration](../specs/2026-09-26-board-comparison-control.md) fixed four app boards, Expert self-play, seeds 42 and 2026, default and swapped stream assignment, four rounds per condition, a 200-turn cap, and trace index zero before collection.
All four one-round pilots completed within the declared 120-second limit.

Collection used clean source `1bc4baada0bf3f84efaa4c346de4ee545249ab23`.
The exporter read `BuiltInBoard.values` directly; the simulator consumed those exported definitions instead of a separately maintained layout copy.
The [provenance record](2026-09-26-board-comparison-control/provenance.json) retains exact commands, UTC timestamps, execution durations, source checks, toolchain, binary/input/output hashes, and repeats.
All 36 processes exited zero with empty stderr: four pilots, sixteen four-round conditions, and sixteen complete repeats.
Each repeat matched its canonical report byte for byte.

The main collection has 64 condition/seed observations and 128 executions.
The four pilot executions overlap those conditions and add no independent observations.
Swapped assignments share underlying seed pairs, and the baseline seed ranges overlap earlier experiments.
Do not pool these groups into a population win probability.
Timing is shared-host execution bookkeeping, not a performance benchmark.

## Results

Each row contains four rounds; links open complete reports, including opening frequencies and the selected trace.
Each CLI game is one round starting with First, not a best-of-three match or a match win-rate measurement.

| Board                                                                                                  | Seed | Assignment | First wins | Second wins | Knockout | Immobilization | Mean turns | Maximum | Repetition | Turn limit |
| ------------------------------------------------------------------------------------------------------ | ---- | ---------- | ---------- | ----------- | -------- | -------------- | ---------- | ------- | ---------- | ---------- |
| [baseline](2026-09-26-board-comparison-control/baseline-seed-42-default-canonical.txt)                 | 42   | default    | 0          | 4           | 2        | 2              | 35.000     | 40      | 0          | 0          |
| [baseline](2026-09-26-board-comparison-control/baseline-seed-42-swapped-canonical.txt)                 | 42   | swapped    | 0          | 4           | 3        | 1              | 30.500     | 40      | 0          | 0          |
| [baseline](2026-09-26-board-comparison-control/baseline-seed-2026-default-canonical.txt)               | 2026 | default    | 1          | 3           | 2        | 2              | 34.250     | 43      | 0          | 0          |
| [baseline](2026-09-26-board-comparison-control/baseline-seed-2026-swapped-canonical.txt)               | 2026 | swapped    | 0          | 4           | 3        | 1              | 35.500     | 40      | 0          | 0          |
| [clipped-corners](2026-09-26-board-comparison-control/clipped-corners-seed-42-default-canonical.txt)   | 42   | default    | 2          | 2           | 2        | 2              | 31.500     | 35      | 0          | 0          |
| [clipped-corners](2026-09-26-board-comparison-control/clipped-corners-seed-42-swapped-canonical.txt)   | 42   | swapped    | 1          | 3           | 2        | 2              | 31.250     | 35      | 0          | 0          |
| [clipped-corners](2026-09-26-board-comparison-control/clipped-corners-seed-2026-default-canonical.txt) | 2026 | default    | 2          | 2           | 2        | 2              | 31.500     | 35      | 0          | 0          |
| [clipped-corners](2026-09-26-board-comparison-control/clipped-corners-seed-2026-swapped-canonical.txt) | 2026 | swapped    | 2          | 2           | 0        | 4              | 31.500     | 35      | 0          | 0          |
| [large](2026-09-26-board-comparison-control/large-seed-42-default-canonical.txt)                       | 42   | default    | 2          | 2           | 2        | 2              | 75.500     | 84      | 0          | 0          |
| [large](2026-09-26-board-comparison-control/large-seed-42-swapped-canonical.txt)                       | 42   | swapped    | 1          | 3           | 3        | 1              | 67.250     | 90      | 0          | 0          |
| [large](2026-09-26-board-comparison-control/large-seed-2026-default-canonical.txt)                     | 2026 | default    | 2          | 2           | 2        | 2              | 81.000     | 85      | 0          | 0          |
| [large](2026-09-26-board-comparison-control/large-seed-2026-swapped-canonical.txt)                     | 2026 | swapped    | 2          | 2           | 1        | 3              | 75.000     | 91      | 0          | 0          |
| [large-holes](2026-09-26-board-comparison-control/large-holes-seed-42-default-canonical.txt)           | 42   | default    | 2          | 2           | 1        | 3              | 68.000     | 72      | 0          | 0          |
| [large-holes](2026-09-26-board-comparison-control/large-holes-seed-42-swapped-canonical.txt)           | 42   | swapped    | 3          | 1           | 1        | 3              | 69.750     | 75      | 0          | 0          |
| [large-holes](2026-09-26-board-comparison-control/large-holes-seed-2026-default-canonical.txt)         | 2026 | default    | 3          | 1           | 4        | 0              | 40.750     | 56      | 0          | 0          |
| [large-holes](2026-09-26-board-comparison-control/large-holes-seed-2026-swapped-canonical.txt)         | 2026 | swapped    | 1          | 3           | 1        | 3              | 64.250     | 71      | 0          | 0          |

## Verification

The full local gate passed before collection: 220 Flutter tests at the configured coverage threshold, 91 Rust tests, seven loaded host bridge tests, analysis, formatting, clippy, release version checks, and Trunk.
The host integration exports every current app board, compares the CLI's parsed initial tiles and pieces against the real bridge, and replays a complete CLI round through it.
Native parity explicitly skipped because no simulator or emulator was running; this change touches no mobile packaging, app presentation, rules, or bridge schema.
An initial baseline-equivalence test incorrectly removed board metadata from only one side; symmetric normalization repaired the test, after which the full gate passed.

A separate local reader checks all canonical reports for round accounting, opening totals, seed assignment, maxima, mean-turn arithmetic, initial terrain/pieces, and hashes.
Changing the game count made it reject the report with `Game count mismatch`.
A Dart reader replays all sixteen selected traces through the actual app bridge from the matching catalog board and checks the actor, move legality, terminal winner, and reason.
Changing the first actor made it reject the trace with `Trace actor mismatch`.
A temporary untracked source fixture also proved that the collector refuses a dirty checkout before export.
These checks establish configuration transport and internal consistency; they do not independently prove the Rust rules correct or enumerate alternative replies.
The local readers are not a new shipped analysis service; their hashes are retained in provenance.

## Reproduction

Use a clean checkout at the recorded source and run from its root.
Choose an empty output directory so old exports cannot enter the experiment.

```sh
CARGO_BUILD_JOBS=2 cargo build --release --locked --manifest-path engine/Cargo.toml --bin simulate
dart run tool/export_simulation_boards.dart build/board-comparison-replay
engine/target/release/simulate --games 4 --seed 42 --max-turns 200 --first strategic --second strategic --trace-game 0 --board-file build/board-comparison-replay/large-holes.board
```

Repeat the same command and compare the full output.
Run each of the four board files with seeds 42 and 2026, both with and without `--swap-seeds`; provenance records every exact collection command.
For game index `i`, the default streams are `seed + i` and that value multiplied by `0x9e3779b9`, with unsigned 64-bit wrapping; swapped assignment exchanges those streams without changing seats.

## Interpretation and remaining work

Every baseline condition had three or four second-seat wins out of four rounds, retaining the earlier sampled second-seat signal.
Both clipped corners and large had two wins per seat in three conditions and one first-seat win in the other condition.
Those small, dependent observations justify further investigation, not a claim that either board is balanced.
Large mean lengths ranged from 67.250 to 81.000 turns, compared with 30.500 to 35.500 on baseline.
Adding holes did not uniformly shorten the large board: the seed-42 swapped mean increased from 67.250 to 69.750, while the seed-2026 default mean fell from 81.000 to 40.750.
All conditions had zero recorded repetition and turn-limit outcomes; the largest observed round was 91 turns, not an exhaustive bound.

On large, every recorded first move was down by piece 0, 1, or 2.
The large-holes reports instead include up, left, and down openings.
These are chosen-move frequencies under the declared seeds, not exhaustive opening trees or rankings of opening quality.

Expert uses the existing deterministic state-scaled node budget, capped at a base of 18,000 before the legal-root-move lower bound.
The large layouts change both board size and piece count compared with the baseline, and consequently change the policy's scaled budget.
They are not a controlled test of board size alone.
Clipped corners versus baseline isolates the offered topology change, and large holes versus large isolates the initial terrain change within the same layout and policy, but all observations remain bounded-policy samples.

Retain the baseline default.
No observed winning path is a forced-line certificate: alternative replies were not exhaustively checked.
The next analysis remains representative forced-line/initial-position investigation, broader coverage justified by a specific question, and synthesis with external playtest evidence in [#42](https://github.com/AndrewDongminYoo/ttush_push/issues/42).
No new human evidence was supplied by this experiment, and #67 remains open.
