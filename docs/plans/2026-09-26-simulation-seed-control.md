# Simulation seat seed control implementation

## Contract and ownership

Follow [the seed-control specification](../specs/2026-09-26-simulation-seed-control.md) as the next bounded #67 slice after PR88.
Base revision: `8d18f999ae2959c9e936b6ab24e37551b4b05e94`.
Use the current workspace; preserve unrelated `.gitignore` and `pubspec.lock` edits.
The implementation worker owns only `engine/src/bin/simulate.rs` and `engine/tests/simulation.rs`.
The root owns this plan, the specification, the existing simulation protocol, review, final checks, staging, commits, and the PR lifecycle.

Oracle retrieved the project precedent that printed settings cannot substitute for observable policy choices from the project memory `engine-comments-are-assertions.md`.
The exact returned source path is retained in the Git-local task state.
Its provider revision was `c1681868ac634e4b2414874716bb75a7864113c4`, with current wiki freshness unverified.
This confirms using independent policy replay and a deliberate wrong-constructor-seed mutation, separately from output compatibility checks.
No specific prior swapped-stream design decision was found.

## Steps and verification

1. Capture three representative parent reports before implementation: default Random, a nonzero wrapping trace, and the existing Strategic terminal fixture.
   Verify: preserve exact arguments and bytes in Git-local task evidence.
2. Write focused CLI integration tests before implementation.
   Verify: observe failure from the unsupported flag, then implement parsing, seed assignment, and opt-in reporting only.
3. Check actual policy moves rather than only seed labels.
   Verify: independent Random policies reproduce both seats' trace moves; a fixed default/swapped fixture differs; incorrect constructor wiring fails while metadata remains correct.
4. Extend the existing protocol with paired policy-and-seed reversal commands and interpretation limits.
   Verify: default outputs match the captured parent bytes and swapped output repeats exactly, with and without a trace.
5. Run the complete local gate and an independent structured review.
   Verify: Rust tests, formatting and Clippy, Flutter/host checks, Trunk and Markdown spelling pass; record native parity coverage or an explicit skip.
6. Commit one coherent feature change, open a PR, and complete current-head CI and hosted review.
   Verify: zero unresolved review findings before requesting operator merge; #67 stays open for the remaining analysis and human evidence.

## Boundaries

No dependency, generated bridge, board catalog, rule, UI, persistence, or policy-budget changes.
Do not run another balance workload or report a new balance conclusion as part of this harness change.
