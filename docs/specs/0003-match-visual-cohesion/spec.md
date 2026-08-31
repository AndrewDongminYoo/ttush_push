---
type: Spec
title: Match Visual Cohesion
---

## Problem

The current match scene combines an opaque full-color turn panel with two explorer sprites that have different visual mass and character proportions.
The current Push replay adds only a symmetric ring, so a Push can read as an ordinary move.
Perspective footholds and front-facing explorers also make the characters read as images layered over the board instead of occupants of each tile.

## Proposed Outcome

Create one coherent air-ruins match presentation.
Use matched static high-angle super-deformed explorer sprites, orthographic square footholds, a restrained HUD, and a directional Push contact marker.
Keep the existing background, input flow, Rust-owned results, accessibility behavior, and replay ownership.

## User Stories

1. As a player, I can recognize Azure and Ember as parts of the same expedition set while I can still distinguish them without color.
2. As a player, I can identify a Push as a collision before the displaced explorer moves or falls.
3. As a player who reduces motion, I receive the same Push meaning without interpolated movement or scale effects.
4. As a reviewer, I can inspect selection, Push contact, and settled Push output on real iOS and Android renderers.

## Requirements

1. Preserve the first five generated sprites under `assets/images/reference/match-visual-cohesion-v1/` for external-content use. Keep `azure_explorer.png` and `ember_explorer.png` unchanged, replace the three foothold paths in place, and load the new `azure_explorer_top_down.png` and `ember_explorer_top_down.png` board sprites. [L2] [L6] [L7]
2. Keep each active production asset as a transparent 512 by 512 PNG that the existing atomic `ProductionSpriteSet` loader can decode. [L2] [L7]
3. Render Azure and Ember as matched static super-deformed human-like expedition characters from the same elevated game-board camera with the same head-to-body proportion, neutral pose, lighting direction, material language, and comparable visual mass. The top of each hood and shoulders must dominate over a front-facing portrait view. [L3] [L7]
4. Preserve a small structural team marker that does not rely on hue alone. Azure uses rounded hood and cape details. Ember uses angular hood and short-coat details. The distinction must not make either explorer look like a different art set. [L3]
5. Make the three footholds read as orthographic top-down squares with one outer scale, no visible side wall, and one stone language from intact, to damaged, to collapsed. The collapsed asset keeps a large transparent center and one connected perimeter. [L2] [L6]
6. Keep the existing `assets/images/air_ruins_twilight.png` background. Do not add a second scenic background, a board-cell marker, a floor plane, or a cast-shadow patch to a sprite. [L2]
7. The HUD must use one muted opaque surface and one shared border rule. Team color may appear only as a small team marker and an active-turn accent. The active team must not fill the complete panel with saturated team color. [L1]
8. Do not add glass effects, decorative frames, ornamental runes, status badges, logos, watermarks, or extra visible copy. [L1] [L4]
9. A Push replay must present three stages from the existing `MoveResolution`: approach, a short contact hold with a directional non-color collision marker, and displacement or fall. [L1] [L5]
10. The contact marker must derive its direction only from the Rust-authored mover travel in `MoveResolution`. Flutter must not calculate move legality, Push outcomes, fall direction, tile transitions, or winners. [L5]
11. Reduced motion must retain a static directional contact cue during the existing replay interval. It must not interpolate positions, shake the board, or scale sprites. [L3] [L5]
12. Keep `BoardGeometry`, hit regions, selection, destination markers, semantics, large-text behavior, disabled replay controls, live announcements, current audio, and current haptic feedback unchanged. [L2] [L5]
13. Keep the existing complete procedural fallback and atomic five-image loader during sprite loading or decode failure. Do not add an asset framework, dependency, download, cache, or runtime asset configuration. [L2] [L7]
14. Record both retained and active image-generation prompts, selected source paths, tool, processing steps, and reference hashes in the asset README files. [L2] [L7]

## Technical Decisions

`GamePage` keeps its replay controller and its normal and reduced-motion durations.
`RoundBoard` keeps its ownership of sprite composition, painter overlay order, hit testing, semantics, and playback painting.

The HUD changes only its visual treatment.
It keeps the Ember panel at the top, the Azure panel at the bottom, the score pips, the opponent control, and the existing stable widget keys.

The Push marker is a short directional contact brace that paints above both static sprites.
It has no new timeline, particles, camera movement, or persistent state.
The existing replay progress defines when it appears.

## Testing Strategy

1. Add a `RoundBoard` pixel regression that fails without the directional contact brace and proves that the brace changes with Rust-authored mover direction. [L4] [L5]
2. Preserve the existing normal and reduced-motion replay, disabled-control, semantics, and haptic tests. [L5]
3. Keep the bundled-asset integrity test for all five active production paths, dimensions, alpha transparency, matched square foothold footprints, and collapsed-hole fragment readability. [L2] [L6] [L7]
4. Extend `integration_test/production_sprite_scene_test.dart` to create a legal Push through the real `GamePage` interaction path. Capture `selection`, `push-contact`, and `push-settled` screenshots on each native renderer. [L4] [L5]
5. Inspect the three screenshots on one iOS Simulator and one Android Emulator. Verify the shared explorer set, terrain progression, HUD hierarchy, contact direction, board gutters, and the absence of clipping or generated text. [L4]
6. Run the focused Flutter view tests, documentation spell check, and `merry run check`. The local gate checks source behavior and formatting. It does not prove the iOS or Android rendered images. [L5]

## Out of Scope

- Rust rules, bridge APIs, board topology, match state, move legality, Push resolution, sound, haptics, and localization changes.
- Frame animation, sprite atlases, directional variants, persistent facing state, particles, camera shake, a new animation framework, or a game engine.
- New backgrounds, themes, navigation, settings, packages, asset downloads, remote configuration, persistence, or Flutter Web support.
- Daily-iPhone installation, launch, or screenshot capture.

## Follow-Ups

Evaluate a future full animation pass only after this static set and the Push presentation are visually validated on both native renderers.
