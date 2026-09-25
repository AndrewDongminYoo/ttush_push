# iPad gameplay validation

## Purpose

[Issue #69](https://github.com/AndrewDongminYoo/ttush_push/issues/69) needs gameplay evidence on a supported iPad runtime.
The existing native parity test exercises the Rust bridge, while listing screenshots use synthetic match states.
Neither establishes that the rendered app can complete a real match on iPad.

## Scope

Use the installed iPad Pro 11-inch (M5) simulator on iOS 26.5 as the reference runtime.
Keep universal support, production rules, board configuration, native orientation declarations, and dependencies unchanged.
Retain the Flutter tool's generated LLDB initialization references in the production scheme, matching the existing development scheme, so the native debug validation can be repeated.
Use the real Rust bridge, the production baseline board, and real pointer taps on rendered controls and cells.
An automated player may obtain legal moves from Rust, but it must apply them through the UI rather than fabricate snapshots or invoke presentation callbacks directly.
Record that automated play verifies mechanics and rendering, not human enjoyment or accessibility with assistive technology.

## Acceptance

1. Complete a local two-player match and an Expert match using the real engine.
   Verify that rendered selection and committed positions change, round transitions keep scores, and the match reaches an earned result.
2. Exercise coach progression and help, match restart, and leave cancellation and confirmation through visible controls.
3. Measure observed Expert response completion without treating simulator timing as physical-device performance certification.
4. Capture setup, gameplay, coach/help, round result, match result, restart, and leave evidence.
   Inspect actual images for readable controls and clipping.
5. Exercise English and Korean and large text at the reference iPad dimensions.
   Distinguish a Flutter text-scale override from the system accessibility setting.
6. Check the four declared iPad orientations using actual simulator controls when available.
   Record unresolved orientations explicitly if runtime control is unavailable.
   A requested orientation or synthetic test surface size alone is insufficient evidence of native rotation.
7. Prove the new gameplay check detects a missing UI move using a temporary negative control, then restore the test.
   Run formatting, analysis, the applicable repository gate, Markdown spelling, and independent review.

## Evidence boundaries

Record source revision and any uncommitted test inputs, app flavor/version, simulator model/OS/UDID, commands, observations, screenshots, and remaining gaps.
App Store approval, screenshots from an older release, host widget checks, and a native bridge-only pass do not close missing gameplay evidence.
No physical phone writes or store operations belong to this task.
Do not close #69 unless its runtime and rendered acceptance criteria are supported by recorded evidence.
