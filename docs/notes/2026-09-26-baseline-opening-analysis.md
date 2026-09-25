# Baseline opening analysis — 2026-09-26

## Questions and scope

This is a bounded evidence slice of [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67), following the [existing protocol](2026-09-25-strategic-simulation-protocol.md).
It asks whether Expert's advantage over Hard appears in both seats, and whether Expert self-play in the selected seed range favors a seat or concentrates on one first move.
Each game is one engine round, not a best-of-three match.
The first seat always moves first.

The sequence declared before collection was four pilot rounds for each pairing, then 16 rounds per pairing if runtime was practical, with one complete repeat.
The pilots took approximately 18–43 seconds per pairing, so the larger run stayed within the selected budget.
The experiment contains 48 distinct pairing/seed observations; the repeated executions and the pilots that overlap the first four seeds add no independent observations.
All three 16-round reports reproduced byte for byte.
The first round, index zero, was selected for each trace before results were known.
No engine, policy, board, bridge, or app behavior changed for this analysis.

## Source and reproduction

| Input              | Recorded value                                                               |
| ------------------ | ---------------------------------------------------------------------------- |
| Source             | `5c31f44f934762d720fe910180549288f470b58c`                                   |
| Working tree       | Empty tracked and untracked status before and after each recorded run        |
| Board              | `GameState::baseline()`, the engine-owned baseline configuration             |
| Policies           | Expert = `strategic`; Hard = `minimax:2`                                     |
| Base seed / rounds | `42` / `16` per pairing                                                      |
| Turn cap / trace   | `100` / game index `0`                                                       |
| Toolchain          | `rustc 1.97.1 (8bab26f4f 2026-07-14)`; `cargo 1.97.1 (c980f4866 2026-06-30)` |
| Host               | Darwin ARM64                                                                 |
| Binary SHA-256     | `afa41513593a36cf96fd22409f8bfe3280d44a842e6c512664972b450976b0b8`           |

The complete [provenance record](2026-09-26-baseline-opening-analysis/provenance.json) contains UTC timestamps, argument lists, exit codes, output hashes, and observed execution durations.
Wall-clock duration is workload bookkeeping on a shared host, not an AI performance benchmark.
Unrelated `.gitignore` and `pubspec.lock` edits were temporarily preserved outside the checkout and restored byte for byte after the clean-source runs.

Follow the clean-checkout guard in the protocol, then build and run:

```sh
CARGO_BUILD_JOBS=2 cargo build --release --locked --manifest-path engine/Cargo.toml --bin simulate
engine/target/release/simulate --games 16 --seed 42 --max-turns 100 --first strategic --second minimax:2 --trace-game 0
engine/target/release/simulate --games 16 --seed 42 --max-turns 100 --first minimax:2 --second strategic --trace-game 0
engine/target/release/simulate --games 16 --seed 42 --max-turns 100 --first strategic --second strategic --trace-game 0
```

Repeat each command and compare the entire output.
The canonical output is retained once per pairing below; the provenance record preserves each repeat's matching hash and local output filename rather than committing duplicate files.
The first seat receives seeds 42–57; the second receives each corresponding seed multiplied by `0x9e3779b9` with unsigned wrapping.
Reversing the policy names therefore does not swap identical random streams.
Strategic uses its existing deterministic state-scaled node budget, capped at a base of 18,000 before the legal-root-move lower bound; Hard searches to depth two.
These are bounded policies, not optimal-play or exhaustive-search results.

## Outcomes

| First / second  | Rounds | First wins | Second wins | Knockout | Immobilization | Mean turns | Maximum |
| --------------- | ------ | ---------- | ----------- | -------- | -------------- | ---------- | ------- |
| Expert / Hard   | 16     | 16         | 0           | 16       | 0              | 23.250     | 39      |
| Hard / Expert   | 16     | 0          | 16          | 14       | 2              | 27.500     | 36      |
| Expert / Expert | 16     | 1          | 15          | 11       | 5              | 32.562     | 40      |

Mean turns above reproduce the CLI's three-decimal truncation; the self-play total is 521 turns, whose exact mean is 32.5625.
All three reports have zero repetitions and zero turn-limit results.
Every observed round was accounted for by a winner and a termination cause.
Expert won all 16 rounds against Hard from each seat in this sample.
Self-play favored the second seat, 15 of 16 rounds, under this particular policy budget and seed schedule.
That observation warrants further controlled investigation; it does not identify a game-theoretic winner or isolate the rules as the cause.

## Opening frequencies

Keys preserve engine piece IDs and direction names rather than merging symmetric openings.
The numbers below count first moves, not an exhaustive opening tree.

| First move    | Expert / Hard | Hard / Expert | Expert / Expert |
| ------------- | ------------- | ------------- | --------------- |
| Piece 0 down  | 6             | 8             | 6               |
| Piece 0 right | 4             | 0             | 4               |
| Piece 1 down  | 2             | 8             | 2               |
| Piece 1 left  | 4             | 0             | 4               |

Expert opened with four distinct moves in this seed range; none accounts for more than 6 of 16 rounds.
Hard opened with two moves, eight rounds each.
The same first-seat Expert seeds explain the identical Expert opening counts against different opponents; those counts are not independent evidence of opening quality.
In self-play, the sole first-seat win is in the piece-0-down group, which still lost five of its six rounds.
The small, unequal groups do not establish a best opening or its success probability under other replies.

## Sampled continuations and checks

| Complete report                                                           | Selected round | Applied moves | Recorded outcome              |
| ------------------------------------------------------------------------- | -------------- | ------------- | ----------------------------- |
| [Expert / Hard](2026-09-26-baseline-opening-analysis/expert-hard.txt)     | 0              | 27            | First wins by knockout        |
| [Hard / Expert](2026-09-26-baseline-opening-analysis/hard-expert.txt)     | 0              | 34            | Second wins by knockout       |
| [Expert / Expert](2026-09-26-baseline-opening-analysis/expert-expert.txt) | 0              | 38            | Second wins by immobilization |

A separate local reader replayed each recorded move through `GameState::baseline()`, `apply_move`, and `outcome`, checking the acting player and final result.
Changing the first recorded actor to Second made that reader reject the trace with `trace actor mismatch`.
An independent report reader checked opening sums, maximums, win causes, round accounting, mean-turn arithmetic, and the seed schedule.
Changing the report's game count made it reject the data with `Opening total mismatch: games`.
These controls test the readers' ability to reject corrupted evidence; they do not independently prove the engine rules correct.
The full output comparisons test determinism for these inputs, not strategy quality.

Each trace records only the chosen path.
A legal short win or a terminal immobilization is not a forced-line certificate: alternative replies were not enumerated.
The three reports retain every move for later investigation without claiming that all replies lose.

## Interpretation and remaining work

The [historical 100,000-round Random baseline](../specs/2026-08-22-bot-policies.md#why-the-search-terminates) remains a separate baseline for its recorded engine revision.
Its recorded maximum of 47 is an observed sample maximum, not an exhaustive upper bound on all legal games.
This analysis did not rerun or relabel that historical workload as Expert data.

Keep the baseline unchanged for the current playtest while investigating the self-play second-seat signal.
The next bounded question is whether it persists across additional preselected seed ranges and seed-assignment controls before attributing it to a rule or starting-layout defect.
No alternative production board was selected merely to populate a CLI option.
Board-variant support should follow a concrete topology or starting-position hypothesis, using the existing validated engine constructors.

[#42](https://github.com/AndrewDongminYoo/ttush_push/issues/42) still lists external-player matches, comprehension findings, and a written product decision as incomplete when inspected for this run.
No new external playtest evidence was supplied here.
Bot outcomes cannot establish enjoyment, coach comprehension, perceived fairness, or demand for rematches.
Therefore #67 remains open for controlled follow-up, selected board variants, forced-line/initial-position analysis, and synthesis with human evidence.
This is a provisional recommendation to retain the current baseline, not a completed product balance decision or proof that a forced win does not exist.
