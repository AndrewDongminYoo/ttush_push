# Built-in board validation — 2026-09-26

## Scope and source

This validates [#72](https://github.com/AndrewDongminYoo/ttush_push/issues/72) against the [board-selection contract](../specs/2026-09-26-built-in-board-selection.md).
The baseline remains the default, with the 21-cell clipped-corner board as an optional configuration.
The [seed-assignment experiment](2026-09-26-seed-assignment-control.md) did not measure the candidate's balance.
No human playtest or forced-line conclusion follows from these checks.

Implementation source is identified by the file hashes in the [validation provenance](2026-09-26-board-selection-validation/provenance.json).
The source hashes include the picker, both catalog definitions, localization inputs, integration harness, host fixture, driver, and dependency lockfile.
These checks used the existing workspace based on `b32b5bf0e484580561339a600943fd3c93991b89` before the feature commit.

## Local checks

The picker regression first failed because `start-board-clipped-corners` matched no widget before implementation.
After implementation, 17 focused setup and catalog tests passed.
The full local gate passed 208 Flutter tests, the configured 100% included-source coverage threshold, Rust checks, five host bridge tests, release version-guard tests, Trunk, and Android parity.
`flutter analyze` reported no issues.
The final aggregate gate was run after both native runtimes were shut down, so its parity step skipped.
The successful Android and iOS runs below supply the native evidence.

The widget tests read the actual definition received by the engine after navigation, including a return to the mounted setup page and a fresh app state.
They also scroll both board options and Start into view in English and Korean at text scale 2.0.
The catalog checks compare every cell and starting piece to independent expected values.
Existing irregular geometry, board reset, and stale AI/replay replacement regressions also ran in the full suite.

The host bridge returned the complete 25/21-cell configurations and the four expected starting pieces.
Each offered board produced a legal Expert move in 452 ms, including a concurrent 450 ms pacing delay.
The two-second assertion applies to the completed response; a stalled call fails at the outer test timeout.
This is a host observation, not a mobile CPU benchmark.

## Native gameplay

Each runtime runs four scenarios: English local play and Korean Expert play at Flutter text scale 2.0, once for each board.
Every scenario selects its board through the real setup controls and compares displayed snapshots with an independent FRB engine consumer.
Hard-coded topology and piece expectations keep the reader independent of the catalog's configuration values.

The local scenarios play a full best-of-three match, advance rounds, restart the match, and exercise leave confirmation.
The Expert scenarios play a full match and record board-specific response waits.
Each next round and local restart checks complete topology, undamaged tiles, and starting pieces.
The clipped-corner local scenario dismisses the coach, selects an actual piece, and taps the absent top-left cell, checking that the snapshot and selection remain unchanged.

Native screenshots are inspected separately from snapshot assertions.
The tested large-text setting is a Flutter test override, not evidence of changing the operating system's accessibility settings.
Expert timing logs measure wall-clock waits across test pumps and include presentation scheduling.
They are bounded gameplay observations, not a device benchmark or proof about all positions.

## Runtime results and reproduction

Both platform drivers exited zero with all four gameplay scenarios passing.
Each saved 34 PNG captures, identified by filename and SHA-256 in the provenance record.
Screenshots are local artifacts under `build/screenshots/board-selection-android/` and `build/screenshots/board-selection-ios/`.
They are not committed binary assets.
The two native parity runs also passed all three bridge tests.

| Runtime                            | Board           | Observed Expert responses | Wall-clock wait range |
| ---------------------------------- | --------------- | ------------------------- | --------------------- |
| Android17 Pixel10 emulator         | baseline        | 8                         | 1048–1406 ms          |
| Android17 Pixel10 emulator         | clipped-corners | 20                        | 1042–1285 ms          |
| iPadOS26.5 iPad Pro11 M5 simulator | baseline        | 8                         | 1064–1294 ms          |
| iPadOS26.5 iPad Pro11 M5 simulator | clipped-corners | 20                        | 1039–1177 ms          |

The initial Android execution observed waits of 1,176–10,785 ms on the baseline and 1,029–6,035 ms on clipped corners.
Those values are preserved separately in the provenance record.
The table above reports the later execution after the copy correction, without a search-policy change.
The iPad simulator completed its observed responses within two seconds.
These runs do not establish physical-device performance or a response bound for all positions.
The different positions, response counts, host load, and runtimes prevent interpreting these numbers as a comparative board-performance benchmark.
No search-policy or rule change was made to address performance in this slice.

The initial Android capture exposed an awkward final-character wrap in the Korean description at text scale 2.0.
The description was shortened, localization regenerated, and the focused tests repeated successfully before final native captures.
One initial Android board capture contained only the background despite later selected-board frames rendering correctly.
That initial image is excluded from visual evidence.
Final selected setup, board, and result captures were inspected separately from the test verdicts.

```sh
CARGO_BUILD_JOBS=2 flutter drive --driver=test_driver/ios_gameplay_flow_driver.dart --target=integration_test/ios_gameplay_flow_test.dart -d emulator-5554 --flavor production
CARGO_BUILD_JOBS=2 flutter test integration_test/rules_engine_parity_test.dart -d 9B40EF49-8D4C-4FEC-B09A-EA0AA68E2373 --flavor production
CARGO_BUILD_JOBS=2 flutter drive --driver=test_driver/ios_gameplay_flow_driver.dart --target=integration_test/ios_gameplay_flow_test.dart -d 9B40EF49-8D4C-4FEC-B09A-EA0AA68E2373 --flavor production
```

Run one heavy native job at a time and check host load before starting it.
An initial iOS launch was interrupted after the simulator boot caused host load to exceed the core count.
The test was restarted after load and memory checks recovered.
No physical phone was used.
Android parity passed before a Flutter teardown uninstall warning, `DELETE_FAILED_INTERNAL_ERROR`; that warning is not a failed bridge assertion.

## Review and limits

Independent static reviews found no actionable issue in the app implementation or native acceptance harness.
A separate audit checked all #67 report hashes, aggregates, trace replay, and interpretation limits.
The recorded project precedent in `wiki/entities/ttush-push.md` and `wiki/sources/ttush_push--claude.md` confirmed the existing configuration boundary: Dart supplies board data and Rust owns validation and rules.
No new bridge fields, rules layer, storage, or dependency was needed.

The rendered selector and board still require operator visual approval before merge.
External playtest synthesis remains in #42 and #67.
