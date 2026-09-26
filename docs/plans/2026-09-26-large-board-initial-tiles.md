# Large board implementation plan

## Ownership

The root owns the plan, Git operations, generation, Flutter catalog and setup, native harness, final verification, and PR lifecycle.
A bounded implementation worker owns `engine/src/lib.rs`, `engine/src/api.rs`, `engine/tests/rules.rs`, `engine/tests/bridge_api.rs`, and `engine/tests/strategic_bot.rs`.
Review agents are read-only and must not delegate.
All work uses the existing main checkout on `codex/large-board-initial-tiles`.

## Steps and verification

1. Add failing catalog and engine behavior checks, with only compile-enabling API scaffolding if necessary.
   Verify the expected missing-preset or incorrect-state failure, not a syntax failure.
2. Retain validated initial tile maps in Rust and serialize them with match values.
   Verify Rust rules and bridge tests, tamper rejection, reset behavior, and unchanged round parity fixtures.
3. Generate the pinned bridge, add the two catalog options, and localize their labels.
   Verify focused Flutter setup and catalog tests and the loaded host bridge.
4. Extend native fixtures to inspect the exact six-piece opening and initial holes independently of production definitions.
   Verify real gameplay, resets, large text, and Expert turns on Android and iOS sequentially.
5. Review the engine boundary and app behavior independently, then repair supported findings.
   Verify `merry run check`, scoped formatting, Markdown spelling, and the final diff.
6. Commit coherent concerns, push, create a PR, and complete current-head hosted review and CI.
   Preserve screenshots and request operator visual approval and merge.

## Risks

Reset metadata must not be reconstructed from a damaged current round.
Hash coverage must include the initial tile map.
Existing API callers must retain normal initial tiles when overrides are absent.
Larger positions can alter search latency and game length, so actual runtime checks must use the new definitions.
The small-screen cell size and long setup list need rendered inspection.
