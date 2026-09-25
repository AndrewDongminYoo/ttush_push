# iPad gameplay validation — 2026-09-25

## Source and runtime

This run addresses [#69](https://github.com/AndrewDongminYoo/ttush_push/issues/69) under the [validation specification](../specs/2026-09-25-ipad-gameplay-validation.md).
Application and engine source: `bb1d366389ee9cd32fb29900e3a09b44eb481e30`, with the integration test, screenshot driver, and production scheme initialization references in this change.
No application rules or layout code changed.
The production scheme references were inserted by Flutter's LLDB migration, matching the development scheme.

| Input                     | Value                                                              |
| ------------------------- | ------------------------------------------------------------------ |
| Runtime                   | iPad Pro 11-inch (M5), iPadOS 26.5 simulator                       |
| Device ID                 | `9B40EF49-8D4C-4FEC-B09A-EA0AA68E2373`                             |
| App                       | `kr.donminzzi.ttush-push`, production flavor, debug, `1.1.1+6`     |
| Portrait image            | 1668 × 2420 pixels                                                 |
| Landscape image           | 2420 × 1668 pixels                                                 |
| Gameplay test SHA-256     | `8988fa7492aa38abfff1c7cb2bfa61d5052b70553461273c04b1b1f37b41ae7d` |
| Screenshot driver SHA-256 | `70363ec2e58cb1bfee9599578bccbd0435c669ff5df2d48adf056272e04eae9a` |
| Production scheme SHA-256 | `cde4a5ae26da453eb488d0ad883f1e8e8842960052809ea056f8f7a4f93e6f9c` |

This is a local simulator build, not the App Store-delivered `1.1.1 (6)` binary.
The version label alone does not establish release provenance.
Universal device support and all four declared iPad orientations remain unchanged.
No physical iPhone or store record was written.

## Checks and observations

The integration test initializes the native Rust bridge and mounts the production app.
It chooses legal moves through Rust, taps rendered board cells, and compares the published board hash and score with independently applied engine moves.
It does not substitute a fake engine, inject a result, or call a game controller to advance play.

The local English scenario exercises coach progression, help replay, a complete best-of-three match, the next-round control, score retention, a new match, and leave cancellation and confirmation.
The Korean scenario completes an Expert match with a Flutter text scale of `2.0`.
This language and scale override is explicit test input rather than an operating-system preference check.

Both final runs exited successfully with two gameplay scenarios each and 15 PNG captures per orientation.
The test framework's additional setup and teardown entries are not extra gameplay scenarios.
Result images show the earned `0 - 2` match outcome and the new-match control in both languages and orientations.

| Run            | Scenarios | Expert replies observed | Wall-clock wait range |
| -------------- | --------- | ----------------------- | --------------------- |
| Portrait       | 2 passed  | 8                       | 1065–1530 ms          |
| Landscape Left | 2 passed  | 8                       | 1060–1399 ms          |

The ordinary production app was also launched with `lib/main_production.dart` and inspected through Device Hub.
Its orientation menu selected Landscape Left, Portrait Upside Down, Landscape Right, and Portrait in sequence; the rendered device and screenshots changed accordingly.
With the system content size set to `accessibility-extra-extra-extra-large`, the coach remained visible, selecting an explorer exposed legal moves, an actual move advanced the turn, and the position survived rotation.
The leave dialog fitted in landscape and its Cancel control returned to the same match.
The original system content size, `large`, was restored before the integration runs.
These observations establish rotation and basic interaction in the other two orientations; complete matches are exercised in portrait and Landscape Left.

### Repository verification

The source and host components of `merry run check` passed: Dart formatting and analysis, 200 Flutter tests, Rust formatting/lint/tests, the host bridge, the Android Alpha guard fixtures, and Trunk.
Trunk initially rejected the new table formatting; formatting only this note and rerunning the check passed.
The native parity component then passed three bridge scenarios on each of the already running iPhone 17 Pro and reference iPad simulators and reported `parity: covered 2 runtime(s)`.
That aggregate run did not cover Android because no Android runtime was returned by its discovery step.
The separate production-flavor iPad parity run also passed three scenarios.
All 88 Markdown files passed CSpell, and the four local document links resolved after the link check first rejected a deliberately missing path.
An independent read-only review found no blocking test, provenance, or inspected-rendering issue.

The host gate checks source behavior and host linkage; native parity checks packaged bridge behavior.
Neither replaces the complete gameplay runs and image inspection reported above.

### Negative control and evidence repair

Temporarily omitting the destination tap caused both scenarios to fail with `UI tap or Expert response did not commit a move` while the board hash remained unchanged.
The test source was restored before positive verification.
This checks that an unchanged game cannot satisfy the match progression assertions.

A warmed route exposed a tap before the entry transition completed; the test now waits for that transition and treats missed finder taps as fatal.
A later screenshot contained the previous frame even though the result widget assertion passed.
The capture helper now waits for settled frames, and result images are inspected separately from the test verdict.

### Observed defect and limits

P3, non-blocking: the disabled opponent selector has low text contrast against the dark panel after the first move.
This is visible in both the ordinary app and integration captures; the board, current-player treatment, and result controls remain usable.
No contrast ratio or assistive-technology certification is claimed.
This validation change records the finding without changing the existing UI.

Automated legal-move play is not a human usability or enjoyment study.
Simulator response waits include deliberate pacing, replay, and scheduling; they are not raw Expert search benchmarks or physical-device performance results.
VoiceOver, TalkBack, multitasking window sizes, other iPad models, and store-release binaries are outside this run.
External play tests remain tracked by [#42](https://github.com/AndrewDongminYoo/ttush_push/issues/42).

## Reproduce and inspect

Run one native job at a time on the named simulator.
Select the actual orientation in Device Hub before each gameplay run.

```sh
flutter test integration_test/rules_engine_parity_test.dart -d 9B40EF49-8D4C-4FEC-B09A-EA0AA68E2373 --flavor production
CARGO_BUILD_JOBS=2 flutter drive --driver=test_driver/ios_gameplay_flow_driver.dart --target=integration_test/ios_gameplay_flow_test.dart -d 9B40EF49-8D4C-4FEC-B09A-EA0AA68E2373 --flavor production
```

The driver writes PNG files under `build/screenshots/ios-gameplay/`.
Preserve each completed run before starting another because filenames are reused.
The local evidence bundle retains final runs in `portrait-final/` and `landscape-left-final/`, and ordinary-app captures in `manual/` under that directory.
These generated images and logs are local artifacts, not committed listing assets.
The PR provides reproduction commands, source fingerprints, and the observations above; operator review uses the retained rendered images.

## Release evidence reconciliation

This dated run supplies iPad gameplay evidence for the current source and the stated simulator scope.
It does not establish whether iPad gameplay was tested before the September 2026 submission or certify the earlier approved binary.
The historical [App Review information](app-review-information.md) retains that distinction.
