# Large board validation — 2026-09-26

## Scope and source

The [contract](../specs/2026-09-26-large-board-initial-tiles.md) adds optional 7 × 7 boards with three pieces per side, including a variant with holes at (1, 3), (3, 3), and (5, 3).
The baseline remains the default, and first knockout still wins each round of the existing best-of-three match.
Initial tile overrides also support damaged tiles through the configuration API; there is no damaged-tile preset or board editor.

The implementation was tested in the existing checkout based on `c97f5747135df5a264aefc75333345153070a75b`.
The [provenance record](2026-09-26-large-board-validation/provenance.json) identifies native source inputs and capture hashes.
Screenshots remain local build artifacts, rather than committed binary assets.

## Local verification

The catalog regression first failed because the large-board selector was absent.
The engine regression first observed Normal where an initial Hole was expected, and the bridge regression first received zero initial tiles instead of 49.
After implementation, the complete `CARGO_BUILD_JOBS=2 merry run check` command exited zero: 212 Flutter tests with the configured coverage threshold, 87 Rust tests, six loaded host bridge tests, analysis, formatting, clippy, release version-guard tests, and Trunk.
Its final native parity step explicitly skipped because all native runtimes were stopped for this run.
Separate native tests provide packaging evidence below.

Rust tests read actual tile states, damaged departure, hole knockout, invalid overrides, next-round restoration, and rejection of edited initial terrain metadata.
Round parity fixtures remain unchanged.
The host bridge compares all offered layouts against independent cell and piece expectations and exercises initial terrain through the generated bridge.
Final host Expert response waits were 551 ms for baseline, 452 ms for clipped corners, 1,285 ms for large, and 1,214 ms for large with holes, all below the existing two-second assertion.
These waits include a concurrent 450 ms pacing delay and are not CPU benchmarks.

An independent core review observed one baseline strategic performance assertion at 2.0568 seconds while Android work was active.
Its isolated rerun, subsequent full Rust suite, and final idle aggregate gate passed.
This transient failure is retained as evidence of load sensitivity, rather than described as an uninterrupted green run.
Independent app and engine reviews found no remaining correctness blocker.

## Native scenarios

Each new board runs English local play and Korean Expert play with Flutter text scale 2.0.
The test selects the actual setup option, compares every opening cell and all six starting pieces with independent expectations, and plays a complete match through rendered board taps.
Local scenarios also verify next rounds, match restart, coach controls, and leave confirmation.
The hole variant selects a piece and taps each initial hole: no move occurs and the existing empty-cell behavior clears selection.
Snapshots and rendered screenshots are inspected separately.

The first Android run exposed an incorrect test expectation that a hole tap would retain selection.
The application already clears selection on present empty or hole cells; only absent topology cells are ignored before that handler.
The harness was corrected without changing gameplay behavior.
That combined run was stopped after the driver stalled while retrieving captures and is excluded from final capture evidence.

The optional `GAMEPLAY_BOARD` define limits capture runs to one board without changing default full-catalog coverage.
An actual Android invocation with `GAMEPLAY_BOARD=unknown` failed with `unknown board`, proving that an invalid filter cannot silently execute zero scenarios.

## Results and reproduction

Android parity passed all four actual bridge tests.
Both new boards passed their two gameplay scenarios and saved 17 fresh PNGs each under `build/screenshots/large-board-android/`.
The final captures show all six pieces, the three initial holes in the variant, and the reachable large-text selector.
At 200% on the Android phone viewport, the Korean descriptions wrap onto a second line; the complete text and Start control remain accessible.

| Runtime                              | Board       | Expert responses | Observed wait  |
| ------------------------------------ | ----------- | ---------------- | -------------- |
| Android 17 Pixel 10 emulator         | large       | 18               | 1,053–2,802 ms |
| Android 17 Pixel 10 emulator         | large-holes | 36               | 1,053–2,468 ms |
| iPadOS 26.5 iPad Pro 11 M5 simulator | large       | 18               | 1,062–2,446 ms |
| iPadOS 26.5 iPad Pro 11 M5 simulator | large-holes | 36               | 1,043–2,355 ms |

iOS parity also passed all four bridge tests, and both per-board gameplay drivers exited zero with all scenarios passing.
Each platform retained 34 fresh PNGs; iOS captures are under `build/screenshots/large-board-ios/`.
Selected setup, initial boards, and result captures were inspected directly on both platforms.
The iPad build was deferred until boot-related host load dropped below the ten-core count.
Only task-owned runtimes were used and shut down after verification.

```sh
CARGO_BUILD_JOBS=2 merry run check
CARGO_BUILD_JOBS=2 flutter test integration_test/rules_engine_parity_test.dart -d <runtime-id> --flavor production
CARGO_BUILD_JOBS=2 flutter drive --driver=test_driver/ios_gameplay_flow_driver.dart --target=integration_test/ios_gameplay_flow_test.dart -d <runtime-id> --flavor production --dart-define=GAMEPLAY_BOARD=large
CARGO_BUILD_JOBS=2 flutter drive --driver=test_driver/ios_gameplay_flow_driver.dart --target=integration_test/ios_gameplay_flow_test.dart -d <runtime-id> --flavor production --dart-define=GAMEPLAY_BOARD=large-holes
```

## Limits and approval

The Android emulator used software graphics after reporting insufficient available memory for its preferred GPU configuration.
It raised the requested 2 GB allocation to 4 GB.
Native timing measures UI response waits across test pumps and presentation scheduling, not physical-device performance or a bound for every position.
Larger layouts are functional options; these checks establish neither balance nor human decision quality.
No physical phone was used.

The scoped Oracle retrieval returned \[no precedent found\]; the current repository architecture and explicit contract govern the configuration boundary.
Operator approval of the actual selector and board screenshots remains required before merge.
