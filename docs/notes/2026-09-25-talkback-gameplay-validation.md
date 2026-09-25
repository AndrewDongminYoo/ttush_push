# TalkBack gameplay validation — 2026-09-25

## Source and runtime

This run addresses [#68](https://github.com/AndrewDongminYoo/ttush_push/issues/68) using the ordinary development app and its native Rust engine.
Application source is `6704c629506212cdbcb46568d228f7848b470bf6`.
The validation documents were uncommitted during the run; no application or engine files changed.
An unrelated working-tree edit to `.github/workflows/main.yaml` appeared during validation and was excluded from this change.

| Input         | Value                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------ |
| Runtime       | Existing `Pixel_10` AVD, Android 17, ARM64, portrait                                       |
| Serial        | `emulator-5554`                                                                            |
| Android build | `google/sdk_gphone16k_arm64/emu64a16k:17/CE2A.260420.019/15611780:user/dev-keys`           |
| App           | `kr.donminzzi.ttush_push.dev`, development debug, `1.1.1+6`                                |
| APK SHA-256   | `88f0c74509453ce36d1c1d9d328e6217d1830dfd0259cf7e80171d339a9f0bdf`                         |
| TalkBack      | `17.0.0.889642762`, version code `60201234`                                                |
| Settings      | English, system font scale `1.0`, touch exploration enabled, Display speech output enabled |
| Captures      | 1080 × 2424 pixels                                                                         |

The Android accessibility service dump reports TalkBack bound with spoken, haptic, and audible feedback, touch exploration, and service-handled double taps.
The speech display is TalkBack's own output overlay.
It records generated utterance text; no human listening assessment of pronunciation or audio quality is claimed.
This is not the Play-delivered release binary or a physical-device pass.

## Actual interaction and observations

The agent operated TalkBack through emulator touchscreen events, inspected its focus ring and speech overlay, and activated the focused control with a double tap.
Core game actions used left/right sequential navigation rather than taps on board-cell coordinates.
No Flutter semantics callback, game-controller mutation, fake engine, or injected result advanced the game.

| Scenario    | Observed result                                                                                            | Local capture                                                                                                 |
| ----------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Start       | TalkBack focused and activated Start Match in the two-player setup                                         | `01-start-focus.png`                                                                                          |
| Coach       | Three steps advanced and completed; help later reopened step one and Dismiss closed it                     | `06-coach-step2.png`, `60-help-reopened.png`, `61-dismiss-focus.png`, `62-dismissed.png`                      |
| Explorer    | Focus and speech identified Azure, row 5, column 2, and three available moves                              | `11-explorer.png`                                                                                             |
| Normal move | Up destination read row 4, column 2; double tap moved the explorer and advanced to Ember                   | `16-up.png`, `18-next-turn.png`                                                                               |
| Push        | Down Push identified row 3, column 2 and affected Azure; activation displaced that explorer                | `28-push.png`, `30-azure-turn.png`, `push.mp4`                                                                |
| Playback    | TalkBack displayed “Move resolution in progress. Board controls are disabled.”                             | `35-push-result.png`                                                                                          |
| Round       | Knockout produced 0–1; result, score, and Start Next Round were reachable; continuation retained the score | `42-round-label.png`, `44-continue.png`, `45-continue-focus.png`, `46-round2.png`                             |
| Match       | The second knockout produced 0–2 and MATCH COMPLETE; Start New Match reset the board and score             | `56-match-complete.png`, `57-new-match-focus.png`, `58-restart.png`                                           |
| Leave       | The confirmation dialog was reachable; Cancel returned to the board and Leave returned to setup            | `63-leave-dialog.png`, `64-cancel-focus.png`, `65-cancelled.png`, `71-leave-focus.png`, `73-left-settled.png` |

Each round followed the same eight legal actions from the baseline board.
Coordinates below are one-based and describe the spoken destinations, not injected touch targets.

1. Azure at row 5, column 2 moves up to row 4.
2. Ember at row 1, column 2 moves down to row 2.
3. Azure at row 4, column 2 moves up to row 3.
4. Ember at row 2, column 2 pushes down, displacing Azure to row 4.
5. The other Azure explorer moves from row 5, column 4 up to row 4.
6. Ember at row 3, column 2 pushes down, displacing Azure to row 5.
7. Azure at row 4, column 4 moves up to row 3.
8. Ember at row 4, column 2 pushes down and knocks Azure off the board.

No blocker prevented this complete match.
After each move, accessibility focus returned to Leave instead of the next explorer.
Sequential navigation still reached the next legal explorer, but repeated navigation is a non-blocking usability cost.
Selecting an explorer retained its focus; spatial ordering placed the up destination before it, so both previous and next navigation were needed.
The previously recorded disabled-opponent contrast observation remains visible and is not repaired by this validation-only change.

## Evidence limits

Playback speech was observed on the actual service; exhaustive rejection of repeated inputs during animation remains automated coverage, not a claim from a still image.
The existing accessibility widget test removes semantic move controls during playback and covers recoverable move errors, initial bridge errors, and Retry.
The ordinary app did not produce those failures, and the existing integration fixtures do not expose an interactive error-injection scenario.
Error/Retry operation with actual TalkBack therefore remains unobserved; no production failure switch was added for this pass.
Korean speech, physical hardware, other Android versions, audio intelligibility, and external usability testing are outside this run.
External player evidence remains [#42](https://github.com/AndrewDongminYoo/ttush_push/issues/42).

## Reproduction and retained artifacts

Build the ordinary app from the recorded revision, with one native job at a time:

```sh
CARGO_BUILD_JOBS=2 flutter run --no-resident --flavor development --target lib/main_development.dart -d emulator-5554
```

Enable TalkBack and its Display speech output option, then use sequential navigation and double tap for the sequence above.
In this runtime, `adb shell input` gestures did not move TalkBack focus reliably and were excluded from gameplay evidence.
The emulator console's `event mouse` touchscreen path did move actual TalkBack focus and invoke its double-tap handler.
For reproduction, generate a continuous horizontal touchscreen swipe followed by release; use two press/release pairs to activate the focused control.
Keyboard shortcuts were investigated using [Google's TalkBack documentation](https://support.google.com/accessibility/android/answer/6110948?hl=en), but were not used for gameplay.

Local artifacts are retained under `build/screenshots/talkback-gameplay/`: numbered PNG captures, `push.mp4`, the native service dump, the build log, and the small console-input helper.
They are generated validation artifacts, not committed store assets.
The first build attempt was cancelled after system load rose above the core count; the recorded APK came from the later successful build, started at load 8.68 on 10 cores.

The Display speech output toggle was restored to off, and Android settings returned to no enabled accessibility service and `accessibility_enabled=0`.
The restored settings screenshot and service dump are retained with the captures.

## Automated validation

`merry run check` passed after the runtime session: Dart formatting and analysis, 200 Flutter tests with the configured 100% coverage threshold, Rust formatting, Clippy and tests, the host bridge tests, the Alpha version-guard fixture tests, and Trunk.
The native parity step passed its three bridge scenarios on `emulator-5554` and reported one covered runtime; no iOS runtime was included in this gate.
These checks inspect code, fixtures, and bridge packaging; the actual TalkBack gameplay evidence remains the separate interaction record above.
CSpell checked 91 Markdown files with no issues after the two exact runtime terms were added to the project dictionary.
An independent read-only review compared the documents with selected captures, service dumps, and issue #68 and found no actionable mismatch.

The parity gate subsequently installed its test fixture over the development app.
Accessibility settings remained restored, and the task-booted emulator was shut down after the gate.

## Historical reconciliation

The checked manual criterion in closed [#11](https://github.com/AndrewDongminYoo/ttush_push/issues/11) did not establish a historical TalkBack run.
This dated observation supplies current Android core-move, Push, and match-flow evidence without backdating it to that issue's completion.
The [historical specification](../specs/2026-08-24-accessible-first-play-match-flow.md) retains its earlier workflow checkboxes and distinguishes this actual-service result from automated error-path coverage and the previously recorded operator VoiceOver review.
