# Blueprint drift audit — 2026-09-26

## Scope and source

This narrow audit corrects current-state claims in [the plan-checkbox reconciliation](2026-08-31-plan-checkbox-drift.md) against `d88d4d0`.
It does not re-audit the repository or alter historical plans, checkboxes, or dated execution records.

## Verified claims

- **True — built-in board selection is implemented.** [BoardDefinition](../../lib/game/board/board_definition.dart) defines `baseline`, `clipped-corners`, `large`, and `large-holes`.
  The large-hole definition supplies initial hole tiles, and the engine bridge accepts initial tile overrides, including damaged and hole states.
  The [large-board validation](2026-09-26-large-board-validation.md) and [match setup review](2026-09-26-match-setup-review.md) record the scoped native setup and gameplay evidence.
  [#72](https://github.com/AndrewDongminYoo/ttush_push/issues/72) is closed.
- **True — the baseline TalkBack core-gameplay pass was recorded.** The [TalkBack validation](2026-09-25-talkback-gameplay-validation.md) records actual service interaction for start, normal move, Push, playback, round, match, and leave flows.
  [#68](https://github.com/AndrewDongminYoo/ttush_push/issues/68) is closed.
- **Unverified — screen-reader spoken output for the refreshed match setup.** The [match setup review](2026-09-26-match-setup-review.md) explicitly records no VoiceOver/TalkBack session.
  Its widget semantics checks do not establish spoken output.
- **True — Strategic, trace, and seed-swap controls exist in `simulate`.** [simulate.rs](../../engine/src/bin/simulate.rs) accepts `strategic`, `--trace-game`, and `--swap-seeds`.
  It prints `board=baseline` and constructs `GameState::baseline()`, so the CLI does not currently select a board variant.
  [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67) remains open for board-variant experiments, representative forced lines, and initial-position conclusions.

## Issue-state check

At this audit, [#68](https://github.com/AndrewDongminYoo/ttush_push/issues/68), [#69](https://github.com/AndrewDongminYoo/ttush_push/issues/69), [#72](https://github.com/AndrewDongminYoo/ttush_push/issues/72), and [#80](https://github.com/AndrewDongminYoo/ttush_push/issues/80) are closed.
[#42](https://github.com/AndrewDongminYoo/ttush_push/issues/42), [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67), [#70](https://github.com/AndrewDongminYoo/ttush_push/issues/70), [#71](https://github.com/AndrewDongminYoo/ttush_push/issues/71), [#73](https://github.com/AndrewDongminYoo/ttush_push/issues/73), [#74](https://github.com/AndrewDongminYoo/ttush_push/issues/74), [#75](https://github.com/AndrewDongminYoo/ttush_push/issues/75), [#76](https://github.com/AndrewDongminYoo/ttush_push/issues/76), [#77](https://github.com/AndrewDongminYoo/ttush_push/issues/77), [#78](https://github.com/AndrewDongminYoo/ttush_push/issues/78), [#79](https://github.com/AndrewDongminYoo/ttush_push/issues/79), and [#81](https://github.com/AndrewDongminYoo/ttush_push/issues/81) are open.

## Current verification limits

The historical TalkBack pass covers baseline core gameplay on the recorded Android emulator and leaves actual TalkBack Error/Retry interaction unobserved.
It does not verify the newer match-setup controls.
The native board checks establish their recorded configurations and interactions, not comparative balance, physical-device performance, human decision quality, or a solved initial position.
