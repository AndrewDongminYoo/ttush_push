# Alternative-reply execution plan

## Scope and ownership

Use the current workspace and `codex/forced-line-analysis`.
Root owns the CLI, integration tests, specification, evidence, Git, and final verification.
A bounded worker owns only `engine/src/bin/analyze/search.rs`, including its internal behavioral tests.
No core rules, public API, app, dependencies, or native files change.
Set only Cargo package `default-run = "simulate"` so adding a second binary preserves existing `cargo run` commands; regenerate the lockfile and verify it stays unchanged.

## Steps and checks

1. Implement the bounded terminal-only search with TDD, checking winning, losing and unknown outcomes against small reachable fixtures.
2. Add the strict offline CLI with failing integration tests for replay, every root alternative, resource limits and input rejection.
3. Run focused Rust checks and the full local gate; review search soundness and input/report transport independently.
4. Commit the implementation and frozen declaration before collecting the twelve declared positions and exact repeats from clean source.
5. Inspect all results and record hashes, source paths, unknown outcomes and limitations in `docs/notes/`.
6. Validate documentation, commit evidence, publish the PR and complete current-head CI and hosted review.
7. Ask the operator to merge; do not close #67 or start unrelated product decisions.

## Limits

No native packaging changed, so host verification is applicable and a native parity skip must stay explicit.
The analysis proves only the positions and bounds actually resolved by terminal-only search.
