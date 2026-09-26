# Baseline seed-assignment control — 2026-09-26

## Contract and source

This is the next bounded control for [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67), following the [opening analysis](2026-09-26-baseline-opening-analysis.md).
Before collection, the run declared Expert against Expert, eight rounds per condition, seed bases 42 and 2026, default and swapped seed assignments, a 100-turn cap, and trace index zero.
Every condition was repeated once in full.
That makes 32 condition/seed observations and 64 round executions, not 64 independent observations.
The 42–49 range overlaps the earlier sample and is not new independent evidence.
Seed-swapped conditions share the underlying seed pair and must not be treated as independent random samples either.

The source was `b32b5bf0e484580561339a600943fd3c93991b89` with empty tracked and untracked status before and after every execution.
The [provenance record](2026-09-26-seed-assignment-control/provenance.json) preserves the declaration timestamp, exact arguments, UTC start times, durations, toolchain, binary hash, exit codes, and all eight output hashes.
All runs exited successfully with empty stderr.
Each repeat matched its canonical report byte for byte.
Repeat files are omitted from the committed artifacts because their hashes and canonical bytes are retained.
Timing records describe shared-host workload, not a performance benchmark.

```sh
CARGO_BUILD_JOBS=2 cargo build --release --locked --manifest-path engine/Cargo.toml --bin simulate
engine/target/release/simulate --games 8 --seed 42 --max-turns 100 --first strategic --second strategic --trace-game 0
engine/target/release/simulate --games 8 --seed 42 --max-turns 100 --first strategic --second strategic --trace-game 0 --swap-seeds
engine/target/release/simulate --games 8 --seed 2026 --max-turns 100 --first strategic --second strategic --trace-game 0
engine/target/release/simulate --games 8 --seed 2026 --max-turns 100 --first strategic --second strategic --trace-game 0 --swap-seeds
```

Use a clean checkout at the recorded source and repeat each command before comparing complete outputs.
For game index `i`, the default first seed is `base + i` and the second is that value multiplied by `0x9e3779b9`, with unsigned 64-bit wrapping.
The swapped condition exchanges those seeds while preserving seats, policies, board, and search budget.
The default report intentionally omits `seed_assignment` for output compatibility, while swapped output declares it.

## Results

| Base / assignment | Rounds | First wins | Second wins | Knockout | Immobilization | Mean turns | Maximum |
| ----------------- | ------ | ---------- | ----------- | -------- | -------------- | ---------- | ------- |
| 42 / default      | 8      | 0          | 8           | 3        | 5              | 35.250     | 40      |
| 42 / swapped      | 8      | 0          | 8           | 7        | 1              | 32.000     | 40      |
| 2026 / default    | 8      | 3          | 5           | 4        | 4              | 36.875     | 43      |
| 2026 / swapped    | 8      | 0          | 8           | 4        | 4              | 36.250     | 42      |

All four conditions had zero repetition and turn-limit outcomes.
The 42–49 control preserves the second-seat signal after swapping seeds.
The 2026–2033 range includes first-seat wins, so the small samples do not support a universal second-seat win claim.
Changing the random streams does not remove the observed second-seat advantage across these conditions, but these results cannot isolate a rules defect from bounded-search behavior.
Do not pool these dependent groups into an estimated population win probability.

## Opening groups

| Base / assignment | Piece / direction | Rounds | First wins | Second wins |
| ----------------- | ----------------- | ------ | ---------- | ----------- |
| 42 / default      | 0 down            | 4      | 0          | 4           |
| 42 / default      | 0 right           | 1      | 0          | 1           |
| 42 / default      | 1 down            | 2      | 0          | 2           |
| 42 / default      | 1 left            | 1      | 0          | 1           |
| 42 / swapped      | 0 down            | 1      | 0          | 1           |
| 42 / swapped      | 0 right           | 4      | 0          | 4           |
| 42 / swapped      | 1 left            | 3      | 0          | 3           |
| 2026 / default    | 0 down            | 4      | 1          | 3           |
| 2026 / default    | 0 right           | 1      | 0          | 1           |
| 2026 / default    | 1 down            | 2      | 2          | 0           |
| 2026 / default    | 1 left            | 1      | 0          | 1           |
| 2026 / swapped    | 0 down            | 7      | 0          | 7           |
| 2026 / swapped    | 0 right           | 1      | 0          | 1           |

These are counts of the first selected move, not exhaustive opening trees.
Unequal, small groups do not establish a best opening or a forced continuation.

## Selected trace checks

| Complete report                                                            | First seed    | Second seed   | Moves | Recorded outcome        |
| -------------------------------------------------------------------------- | ------------- | ------------- | ----- | ----------------------- |
| [42 / default](2026-09-26-seed-assignment-control/seed-42-default.txt)     | 42            | 111486302298  | 38    | second / immobilization |
| [42 / swapped](2026-09-26-seed-assignment-control/seed-42-swapped.txt)     | 111486302298  | 42            | 24    | second / knockout       |
| [2026 / default](2026-09-26-seed-assignment-control/seed-2026-default.txt) | 2026          | 5377886867994 | 36    | second / immobilization |
| [2026 / swapped](2026-09-26-seed-assignment-control/seed-2026-swapped.txt) | 5377886867994 | 2026          | 40    | second / immobilization |

A local report reader checked opening sums, round accounting, winner causes, maximums, mean-turn arithmetic, and the assignment-specific trace seeds.
Changing the game count failed with `Opening total mismatch: games`.
A separate Rust reader replayed each full trace through `GameState::baseline()`, `apply_move`, and `outcome`, checking the acting player and terminal result.
Changing the first recorded actor failed with `trace actor mismatch`.
These controls verify that the readers reject the selected corruptions, not that the engine is independently proved correct.
The complete repeats establish determinism only for these inputs.

## Decision and next work

Retain the baseline as the default.
The next #72 implementation may offer a clipped-corner board as an optional topology hypothesis, preserving the baseline starting pieces and seat symmetry.
This experiment did not simulate that candidate and is not evidence that it is more balanced.
A variant comparison needs a separately declared experiment using the candidate's actual configuration.
Forced-line analysis, broader seed coverage, and synthesis with external playtest results remain open in #67 and #42.
No new human playtest evidence was supplied for this run.
