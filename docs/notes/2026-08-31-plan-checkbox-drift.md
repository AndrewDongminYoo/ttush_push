# Plan Checkbox Drift in docs/plans

## Current reconciliation: 2026-09-26

Reviewed against `6da4099f4c0371854ca821066fa82c2aa074cbd1` for [#80](https://github.com/AndrewDongminYoo/ttush_push/issues/80).
The [2026-09-26 scoped audit](2026-09-26-blueprint-drift-audit.md) updates board selection, simulation support, and native verification against `d88d4d0`.
The dated sections linked below supersede the need for a future artifact audit described in the original note; they do not certify that historical command sequences were executed.
**Implemented** describes current source, **superseded** describes an older design replaced by later work, **verification pending** identifies missing execution or acceptance evidence, and **deliberately deferred** describes work outside the accepted implementation scope.
An unchecked historical step remains an execution record, not a current feature backlog.

| Area                          | Current classification and evidence                                                                                                                                                                                                                  |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Playable-round plan           | Implemented through the later match flow; the planned round controller is superseded. See the [task reconciliation](../plans/2026-08-22-playable-round-vertical-slice.md).                                                                           |
| Authoritative move resolution | Implemented artifacts with historical execution steps unconfirmed. See the [resolution reconciliation](../plans/2026-08-24-authoritative-move-resolution-implementation.md).                                                                         |
| Accessibility                 | Baseline TalkBack core gameplay is verified; the refreshed setup still lacks an actual screen-reader spoken-output pass. See [TalkBack validation](2026-09-25-talkback-gameplay-validation.md) and [setup review](2026-09-26-match-setup-review.md). |
| Ad boundary                   | Implemented no-op gateway and lifecycle boundary; a real provider is deliberately deferred. See the [ad-plan reconciliation](../plans/2026-09-06-ad-provider-boundary-implementation.md).                                                            |
| Store release                 | Later dated evidence supersedes the old no-iOS-archive statement. Current public readiness remains verification pending; see the [release checklist](android-release-checklist.md) and [review history](app-review-information.md).                  |

### Current product and analysis scope

The functional MVP means the local best-of-three match described in [repository scope](../../CLAUDE.md#scope-boundaries).
It does not include completion of the original blueprint's strategic analysis or the external-play milestone.

- **Implemented: Expert.** [StartPage](../../lib/game/start/start_page.dart) offers the Strategic opponent, [MatchController](../../lib/game/match/match_controller.dart) maps it to the engine policy, and [StrategicBot](../../engine/src/bot/strategic.rs) performs budgeted iterative search.
  The older depth-2-only and deferred-search descriptions in [#42](https://github.com/AndrewDongminYoo/ttush_push/issues/42) and the [bot-policy specification](../specs/2026-08-22-bot-policies.md) describe an earlier implementation.
- **Implemented: Korean UI.** [Korean source strings](../../lib/l10n/arb/app_ko.arb), the [localization generator configuration](../../l10n.yaml), and [AppView](../../lib/app/view/app.dart) provide the localized interface.
  Source wiring alone does not establish text fit or screen-reader quality on every device.
- **Implemented and verified: built-in board selection.** [BoardDefinition](../../lib/game/board/board_definition.dart) defines baseline, clipped-corners, large, and large-holes configurations, and [StartPage](../../lib/game/start/start_page.dart) exposes them through match setup.
  The [match setup review](2026-09-26-match-setup-review.md) records native interaction and capture evidence for all four choices; [#72](https://github.com/AndrewDongminYoo/ttush_push/issues/72) is closed.
- **Implemented build support; release decision and runtime verification pending: Web.** The [Web workflow](../../.github/workflows/main.yaml) invokes [the production build script](../../tool/build_web.sh).
  [#71](https://github.com/AndrewDongminYoo/ttush_push/issues/71) retains the ship-or-defer decision and browser acceptance; a build does not establish a deployed, playable release.
- **Implemented reporting; analysis verification pending: original blueprint Phase 4.** [PR #82](https://github.com/AndrewDongminYoo/ttush_push/pull/82) added Strategic simulation and first-move outcome reporting on the baseline board.
  The simulator also supports selected-game traces, swapped seed assignments, and exported app board definitions through `--board-file`.
  The [board-comparison contract](../specs/2026-09-26-board-comparison-control.md) preserves the baseline default and defines the bounded variant experiment.
  Its [bounded protocol](2026-09-25-strategic-simulation-protocol.md) separates smoke runs from balance evidence.
  [#67](https://github.com/AndrewDongminYoo/ttush_push/issues/67) remains open for board-variant experiments, representative forced lines, and initial-position conclusions.
  The historical 100,000-round Random baseline in the bot-policy specification is neither Expert evidence nor exhaustive proof.
- **Verification pending: human play and delivery.** #42 retains external tester, match-record, and Play-delivered device acceptance.
  Its earlier pre-upload and no-iOS-attempt narrative must be read with the dated release checklist and review history above, not as the current release state.

### Remaining work

Use [tracker #81](https://github.com/AndrewDongminYoo/ttush_push/issues/81) as the single backlog entry point.
It records the closed TalkBack, iPad, and built-in-board evidence alongside the open external-play, strategic-analysis, public-store, Web, and deferred-product decisions.
Those decision issues are not blanket approval to implement the original conversation's optional suggestions.
No completion percentage is implied by this reconciliation.

## Historical audit: 2026-08-31

Verified against `main` on 2026-08-31, after the board-definition work merged.

### What is stale

Two plans in `docs/plans/` carry unchecked steps although the work they describe is present in the code:

- `2026-08-22-playable-round-vertical-slice.md` — 31 unchecked steps.
  Its seven checked boxes are the Plan Self-Review section, which is filled in while the plan is written, not while it is executed.
- `2026-08-24-authoritative-move-resolution-implementation.md` — 33 unchecked steps.

`2026-08-21-rust-engine-checkpoint.md`, `2026-08-22-playtest-ready-game-screen.md`, `2026-08-25-air-ruins-match-scene-implementation.md`, and `2026-08-30-board-definition-implementation.md` are fully checked and need nothing.

### Why they were not simply checked off

`2026-08-22-playable-round-vertical-slice.md` was **not executed as written**.
Its file table and several steps build `lib/game/round/round_controller.dart`, which does not exist; the controller that survives is `lib/game/match/match_controller.dart`, introduced by a later plan.
Marking those steps complete would record a step that never ran on the artifact it names.

The same caution applies more weakly to the 08-24 plan: its end state is present, but no session confirmed its steps one by one.

### What reconciling it would take

Walk both plans step by step against the current tree, check only the steps whose artifact still exists under the name the step gives, and add a short note where a later plan superseded one.
Treat a plan whose deliverable was renamed as superseded rather than complete.

Until that is done, read an unchecked box in these two files as "unconfirmed", not as "not implemented".
