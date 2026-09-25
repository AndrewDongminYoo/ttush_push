# Accessible First-Play Match Flow

## Goal

Make the air-ruins match understandable on a first play and playable through VoiceOver or TalkBack without turning the match screen into a separate tutorial or settings product.

## Context

> **Verification status:** VoiceOver was manually reviewed by the operator.
> An agent-operated actual TalkBack run on 2026-09-25 now supplies separate [Android gameplay evidence](../notes/2026-09-25-talkback-gameplay-validation.md).
> This does not backdate the Android result or establish audio quality and error/Retry behavior on TalkBack.

## Status reconciliation — 2026-09-25

This is a historical implementation specification.
Its unchecked execution boxes remain a record of the proposed workflow, not a current backlog.
The classifications below distinguish implementation artifacts from verification that those artifacts cannot establish.

| Acceptance outcome                                                                    | Status           | Evidence and remaining work                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `shared_preferences` and its resolved lockfile                                        | Implemented      | [`pubspec.yaml`](../../pubspec.yaml) declares `shared_preferences`, [`pubspec.lock`](../../pubspec.lock) resolves it, and [`first_play_coach_store.dart`](../../lib/game/coach/first_play_coach_store.dart) uses the versioned key.                                                                                                                                                                                                                                |
| The first-play coach is versioned, dismissible, and can be reopened from HUD help     | Implemented      | [`game_page.dart`](../../lib/game/view/game_page.dart) loads, completes, and reopens the coach, and [`game_page_accessibility_test.dart`](../../test/game/view/game_page_accessibility_test.dart) covers completion, dismissal, and help reopening.                                                                                                                                                                                                                |
| The coach leaves visual board and HUD actions available                               | Implemented      | [`game_page_accessibility_test.dart`](../../test/game/view/game_page_accessibility_test.dart) has the `keeps visual board actions available while the coach is open` scenario.                                                                                                                                                                                                                                                                                     |
| A screen-reader user can select an explorer and activate a normal or Push destination | Runtime verified | [`round_board.dart`](../../lib/game/view/round_board.dart) projects actionable explorer and destination semantics, and [`game_page_accessibility_test.dart`](../../test/game/view/game_page_accessibility_test.dart) activates normal and Push moves through those semantics. The [2026-09-25 TalkBack run](../notes/2026-09-25-talkback-gameplay-validation.md) selected explorers and activated normal and Push destinations through the actual Android service. |
| Semantic labels distinguish controls, playback, results, and recoverable errors       | Implemented      | [`round_board.dart`](../../lib/game/view/round_board.dart) labels explorers, destinations, and disabled playback, while [`game_page_accessibility_test.dart`](../../test/game/view/game_page_accessibility_test.dart) covers those labels and live announcements.                                                                                                                                                                                                  |
| Large text preserves the primary match, coach, and result actions                     | Implemented      | [`game_page_accessibility_test.dart`](../../test/game/view/game_page_accessibility_test.dart) has 200% text scenarios for the match, coach, and result actions. The [2026-09-25 iPad run](../notes/2026-09-25-ipad-gameplay-validation.md) records separate runtime evidence and its limits.                                                                                                                                                                       |
| Automated checks and manual VoiceOver and TalkBack moves have all passed              | Dated evidence   | The earlier operator VoiceOver record and [2026-09-25 actual TalkBack run](../notes/2026-09-25-talkback-gameplay-validation.md) cover core normal and Push moves separately. Historical command boxes remain unchanged; actual TalkBack error/Retry and audio quality remain unobserved. [#81](https://github.com/AndrewDongminYoo/ttush_push/issues/81) tracks remaining verification and decisions.                                                              |

Screenshots establish neither a playable match nor screen-reader operation.
Repository notes also do not establish current store-console state.
Public store readiness remains verification pending under [#70](https://github.com/AndrewDongminYoo/ttush_push/issues/70) and is coordinated by [#81](https://github.com/AndrewDongminYoo/ttush_push/issues/81).

## Historical problem statement — 2026-08-24

The following context records the gap this specification proposed to address.

The production match scene explains the world visually, but a first-time player still needs to learn explorer selection, the move-versus-Push affordance, and the meaning of a cracked foothold.
The board is a `CustomPainter`, so it currently does not expose enough semantic controls for a screen-reader user to choose an explorer and a legal destination.

This milestone follows authoritative move resolution and the air-ruins match scene.
It retains their public behavior and adds persistent first-play guidance plus an accessible interaction projection.

## Scope

- Add `shared_preferences` as the local storage layer and regenerate the lockfile through `flutter pub get`.
- Persist one versioned first-play completion flag named by the coach version.
- Show a non-blocking three-step coach only until it is completed or dismissed for that version.
- Provide a visible HUD help action that reopens the coach without resetting its completion state.
- Expose active explorers and their legal destinations as semantic controls that let VoiceOver and TalkBack users make a core legal move.
- Announce selection, normal move, Push destination, round result, match result, and recoverable error states accessibly.
- Validate that the primary board, HUD, result action, Retry, coach action, and opponent control remain usable at large text scale.

## Non-Goals

- Do not change game rules, board configuration, Rust bridge ownership, resolution playback data, or opponent-selection timing.
- Do not add a settings screen, account state, analytics, remote persistence, localization beyond the English ARB contract, or a new tutorial route.
- Do not add raster tile or explorer sprites.

## Product Contract

### First-play coach

The coach appears only for a fresh installation or after its explicit version changes.
It is a non-blocking overlay anchored away from the active board target and never intercepts board, HUD, result, or system-navigation input.

The ordered coach steps are:

1. Select an Azure explorer.
2. A filled glowing marker is a move and a ring is a Push.
3. A cracked foothold collapses when an explorer leaves it again.

Each step has a visible next action and a dismiss action.
Completing or dismissing the coach stores the current version as complete.
The HUD help action opens the same three steps on demand without clearing the persisted completion value.

### Semantic board controls

The painter supplies a semantic projection rather than exposing every inert cell as a control.
Before selection, each movable explorer is an accessible button with its expedition, row, column, and available-move count.

After selection, each legal destination is an accessible button with its direction and destination coordinates.
A normal destination names itself as a move.
A legal occupied destination names itself as a Push and names the affected opposing expedition.

Activating a movable explorer selects it.
Activating a legal destination applies the same move path used by a visual tap.
The semantic projection never calculates legality, Push result, fall direction, tile damage, or outcomes.

Round and match results, selection changes, applied moves, recoverable errors, and disabled playback state expose clear semantic labels or live announcements.
The board must not announce decorative background content as actionable game state.

### Responsive and motion behavior

At the supported large text scale, visible HUD text may wrap or reflow but must not hide the board, the selected state, the result continuation action, Retry, opponent control, help action, or coach controls.
Non-color expedition silhouettes and the reduced-motion behavior from the resolution milestone remain intact.

## Architecture

| Component                         | Responsibility                                                                                      |
| --------------------------------- | --------------------------------------------------------------------------------------------------- |
| `pubspec.yaml` and `pubspec.lock` | Declare and resolve `shared_preferences`.                                                           |
| Coach preference store            | Reads and writes only the versioned coach-completion value behind a boundary that tests can fake.   |
| `lib/game/view/game_page.dart`    | Owns coach presentation, help entry, announcements, and visible state coordination.                 |
| `lib/game/view/round_board.dart`  | Produces semantic explorer and legal-destination controls from Rust snapshot and legal-move inputs. |
| Existing fake rule engines        | Provide deterministic snapshots and legal moves for coach, semantic, and large-text tests.          |
| `test/game/view/`                 | Covers persistence, coach behavior, semantic activation, announcements, and responsive layout.      |

## Error Handling

- If the coach preference cannot be read, the coach fails open and is shown without blocking the match.
- If the preference cannot be written, the current completion action still dismisses the coach for the active page and the failure does not prevent a move.
- A semantic action offered during resolution playback is unavailable rather than queued.
- A stale coach or announcement callback cannot change a disposed page.

## Testing Strategy

| Layer                             | Evidence                                                                                                                                                     |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Preference tests                  | A fake store proves first display, completion persistence, dismissal persistence, version reset, and read or write failure behavior.                         |
| Widget tests                      | Assert each coach step, HUD help reopening, visible actions at large text scale, and non-blocking interaction.                                               |
| Semantics tests                   | Use Flutter semantics testing to activate an explorer and legal normal and Push destinations through labels and verify the same rule-engine move is applied. |
| Device accessibility verification | Manually exercise one core move and a Push with VoiceOver on iOS and TalkBack on Android after automated coverage passes.                                    |

## Acceptance Criteria

- [ ] `shared_preferences` and its lockfile resolution are committed together.
- [ ] The first-play coach appears only until dismissed or completed for its current version and can be reopened through HUD help.
- [ ] The coach never prevents a visual board or HUD action.
- [ ] A VoiceOver or TalkBack user can select an active explorer and activate a legal normal or Push destination without relying on color or canvas coordinates.
- [ ] Semantic labels distinguish selectable explorers, normal destinations, Push destinations, disabled playback, results, and recoverable errors.
- [ ] Large text scale preserves every primary match action without clipping or hiding the board.
- [ ] Preference, widget, and semantics tests pass, `merry run check` passes, and one core move plus one Push are manually verified with VoiceOver and TalkBack.

## Verification Commands

```sh
flutter pub get
merry run check
flutter test test/game/view
```

Run the manual accessibility checks on one Android runtime and one iOS runtime.
Before writing to Andrew's daily iPhone, announce the exact install or launch action and obtain the separate required approval.
