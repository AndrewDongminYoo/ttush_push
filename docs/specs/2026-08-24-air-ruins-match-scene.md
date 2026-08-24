# Air-Ruins Match Scene

## Goal

Turn the prototype match screen into a coherent air-ruins scene that explains crumbling footholds, Pushes, and falls at a glance while retaining a dominant, playable board.

## Context

The current screen uses a dark background, generic Player 1 and Player 2 panels, and hard-coded English text.
The visual treatment does not establish why a foothold damages when left or why an explorer can be pushed into a sinkhole or over an edge.

This milestone follows the authoritative move-resolution milestone.
It consumes its snapshot-derived `BoardGeometry` and resolution playback without reinterpreting rules in Flutter.

## Scope

- Add one original AI-generated landscape raster asset behind the match board.
- Compose the match as a fragmented floating island at post-storm twilight, with a visible sky, distant debris, and a dark void beneath the playable area.
- Keep the practical board central and low contrast against the environment so tile, explorer, destination, and resolution effects remain readable.
- Replace generic player presentation with `Azure Expedition` for First and `Ember Expedition` for Second.
- Place Ember's compact HUD at the top and Azure's compact HUD at the bottom for the hot-seat orientation.
- Evolve the painter's disc and rounded-square pieces into distinct explorer silhouettes while leaving raster tile and explorer sprite production to a later asset milestone.
- Move all visible match-screen copy into English ARB resources.
- Replace the whole-panel opponent cycle with an explicit `Opponent` control and a bottom sheet for Human, Random, Greedy, and Minimax.
- Permit opponent changes only before the first move of a fresh match.

## Non-Goals

- Do not change the board configuration, Rust rules, bridge contract, or resolution playback contract.
- Do not add raster explorer or tile sprites, a main menu, settings screen, account state, online play, or sound settings.
- Do not add the first-play coach, persistence, or the complete VoiceOver/TalkBack board interaction surface.
- Do not introduce a package dependency.

## Product Contract

### Environment

The environment is one original, AI-generated landscape asset without text, logos, characters, or interactive affordances.
It depicts a fragmented floating island at post-storm twilight, with distant ruin debris, a controlled warm horizon, and enough negative space around the board for foreground state to remain legible.

The image is a background layer only.
It never defines an input boundary, legal cell, board size, tile state, Push outcome, or fall direction.
The snapshot-derived board remains the interactive and rule-readable foreground.

### Match hierarchy

The screen is full-bleed within the safe area.
The board remains visually dominant and is centered over the environment using the geometry produced by the previous milestone.

The Ember HUD is compact and anchored at the top.
The Azure HUD is compact and anchored at the bottom.
Both show the expedition name, current round wins, and a non-color-only current-turn state without obscuring practical board cells.

First is always Azure and is physically represented by the lower HUD.
Second is always Ember and is physically represented by the upper HUD.
These side names do not change when Second is a human or a bot.

### Explorer and foothold treatment

Azure and Ember explorers have distinct large silhouettes as well as distinct color treatment.
The silhouette must remain recognizable at board-cell scale without a face, small text, or a raster sprite.

Normal footholds read as intact air-ruin slabs.
Damaged footholds retain an unmistakable crack.
Hole tiles show the void rather than a colored cell.
Existing legal move and Push affordances remain distinguishable, and resolution playback from the prior milestone remains above the board.

### Opponent selection

The top HUD shows an explicit `Opponent` control with the current Human, Random, Greedy, or Minimax value.
It opens a bottom sheet with all four choices and an accessible selected value.

The control remains available until the first move of a fresh match is applied.
It locks for the remainder of that match, including between rounds.
After `New Match` resets the match, it is available again before the first move.

### Copy and visible states

All visible match strings move from Dart source into the English ARB file.
This includes expedition labels, turn state, opponent choices, result text, win reasons, retry errors, controls, and any text introduced by the new scene.

Loading, recoverable initialization failure, recoverable action failure, round result, and match result retain their existing behavior.
They adopt the new visual hierarchy without losing a visible Retry or a clear continuation action.

## Architecture

| Component                        | Responsibility                                                                                      |
| -------------------------------- | --------------------------------------------------------------------------------------------------- |
| `assets/images/`                 | Owns the air-ruins background raster used by the app.                                               |
| `pubspec.yaml`                   | Declares the new image asset for direct loading without hand-editing generated asset code.          |
| `lib/app/view/app.dart`          | Provides the theme tokens shared by HUD and scene copy.                                             |
| `lib/game/view/game_page.dart`   | Composes background, HUDs, result and error surfaces, opponent sheet, and the existing board layer. |
| `lib/game/view/round_board.dart` | Paints readable explorer and foothold silhouettes over the geometry from milestone 1.               |
| `lib/l10n/arb/app_en.arb`        | Owns every visible English match-screen string.                                                     |
| `test/game/view/`                | Covers layout, text, controls, and painter behavior with fake rule engines.                         |

## Testing Strategy

| Layer                    | Evidence                                                                                                                                                            |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Widget tests             | Assert HUD orientation, explicit opponent control, pre-first-move unlock, post-move lock, result and Retry reachability, and localized visible copy.                |
| Painter tests            | Assert each expedition remains distinct without color-only recognition and current move and Push affordances remain visible over the revised footholds.             |
| Asset declaration checks | Declare the background in `pubspec.yaml` and load its checked-in path without editing generated output.                                                             |
| Visual verification      | Capture the running app on a simulator at a compact phone and a tall phone size, then inspect board legibility, HUD occlusion, void depth, and result presentation. |

## Acceptance Criteria

- [ ] The AI-generated background makes the board read as fragments of a floating air ruin without creating any false interactive surface.
- [ ] Azure is always the lower First HUD and Ember is always the upper Second HUD.
- [ ] HUDs show expedition identity, wins, and turn state while keeping the board dominant at compact and tall phone sizes.
- [ ] Explorers and footholds remain distinguishable without color alone.
- [ ] Every visible match-screen string is read through English ARB resources rather than a Dart literal.
- [ ] `Opponent` is a visible bottom-sheet control that works only before the first move of a fresh match and remains locked through subsequent rounds.
- [ ] Existing errors, results, Retry, and continuation actions remain visible and usable in the new scene.
- [ ] Focused widget and painter tests pass, `merry run check` passes, and visual screenshots are reviewed from a running simulator.

## Verification Commands

```sh
flutter pub get
merry run check
flutter test test/game/view
```

Run the app on a simulator for screenshot review.
Before writing to Andrew's daily iPhone, announce the exact install or launch action and obtain the separate required approval.

## Follow-Up Milestones

- Milestone 3 adds the persisted first-play coach and full VoiceOver/TalkBack board interaction surface.
- A later asset milestone may replace painter-based explorers and footholds with production sprites without changing the rules or board geometry.
- A later configuration milestone adds `BoardDefinition` so future board topology, starting pieces, and background metadata are data-only edits.
