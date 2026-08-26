---
type: Spec
title: Production Sprite Set
---

## Problem

The air-ruins match currently uses procedural painter shapes for explorers and footholds.
Those shapes preserve gameplay clarity but were explicitly a temporary presentation layer, and the current hole treatment draws no remaining ruin fragments.
The match needs a cohesive production sprite set without allowing art assets to redefine Rust-authored tile state, board geometry, move legality, interaction, accessibility, or resolution playback.

## Proposed Outcome

Replace the procedural foreground appearance with five original static raster sprites: Azure explorer, Ember explorer, intact foothold, damaged foothold, and collapsed hole foothold. [L1] [L2]
The sprites visually belong to the existing painterly post-storm air-ruins scene, preserve non-color faction and terrain distinctions, and retain every existing board behavior. [L3]
The board loads the five bundled assets as one atomic set and remains immediately playable through an equivalent procedural fallback during loading or after a decode failure. [L4]

## User Stories

1. As a player, I can distinguish Azure and Ember explorers at board-cell scale without relying on color alone.
2. As a player, I can read a foothold's intact, damaged, or collapsed state from its structure, including a collapsed hole whose central void is surrounded by broken ruin fragments.
3. As a player, I continue to see selection, move, Push, impact, fall, and tile-transition feedback above the production art.
4. As a player, I can continue the match with a coherent procedural fallback if the bundled sprite set is still loading or cannot be decoded.
5. As a reviewer, I can inspect one deterministic exercised scene that visibly contains all five sprites and the primary board overlays on the actual iOS and Android Flutter renderers.

## Requirements

1. The milestone must add exactly five static transparent PNG assets named `azure_explorer.png`, `ember_explorer.png`, `foothold_intact.png`, `foothold_damaged.png`, and `foothold_hole.png` under `assets/images/sprites/`. [L1] [L2]
2. Each final asset must be a 512 by 512 pixel PNG with a consistent square canvas, centered visual anchor, and transparent background. [L2]
3. The sprites must form one original AI-generated set that matches the painterly fantasy, post-storm twilight, stone material, lighting direction, and three-quarter top-down presentation of `assets/images/air_ruins_twilight.png`. [L3]
4. The sprites must contain no text, logos, watermarks, separate scenic background, board-cell markers, or third-party asset-pack content. [L3]
5. `assets/images/sprites/README.md` must record the generation tool, generation date, final prompt, selection or editing notes, and the relationship between the five final files. [L3]
6. Azure must retain a broad, rounded silhouette and Ember must retain a narrow, angular silhouette. Their shapes, not only blue and red color treatment, must distinguish them at the smallest supported board-cell size. [L3]
7. The three foothold assets must depict one coherent stone structure progressing from intact, to visibly cracked and damaged, to collapsed. [L1] [L3]
8. `foothold_hole.png` must leave most of the cell center transparent so the void remains visible, while discontinuous broken floor fragments remain around the perimeter. The fragments must not form a continuous surface or resemble a legal destination. [L1]
9. The procedural fallback must be updated to express the same three terrain states, including broken perimeter fragments for a hole, so loading or decode failure does not violate the collapsed-foothold visual contract. [L1] [L4]
10. Sprite selection must map directly from the Rust-authored `GameTileKind` and `GamePlayer` values already present in the snapshot. Flutter must not infer terrain transitions, move legality, Push outcomes, fall direction, ownership, or winner state. [L1]
11. `BoardGeometry` must remain the sole mapping from snapshot tile coordinates to visual cells and hit regions. Sprite bounds, transparent pixels, and visible fragments must not change input geometry. [L1]
12. Explorer sprites must remain visually contained within their owning cell and must not obscure adjacent foothold state or legal-destination overlays.
13. Foothold sprites must retain the existing cell gutter so adjacent tiles remain separable on compact and tall phone layouts.
14. Selection outlines, normal-move markers, Push rings, Push impact, and resolution playback must paint above the production sprites. Occupied Push destinations must remain visible above the affected explorer. [L1] [L2]
15. Existing resolution playback must translate the static explorer sprite as a whole. Reduced-motion timing and step behavior must remain unchanged, and no frame animation or directional facing state may be introduced. [L2]
16. A transition to `GameTileKind.hole` must clear the prior foothold appearance and then show the collapsed-hole sprite or its equivalent fallback fragments at the existing playback transition point. [L1] [L2]
17. The board must use the procedural fallback until all five production sprites have decoded successfully, then replace the complete fallback set in one frame. Painter terrain or explorer visuals must not mix with production terrain or explorer visuals on the same board. [L4]
18. If any sprite is missing or fails to decode, the board must keep the complete procedural fallback for the remainder of that board session, remain interactive, preserve semantics, and call `FlutterError.reportError` exactly once with the exception, stack trace, and sprite-loading context without presenting a new loading, error, or Retry surface. [L4]
19. Sprite loading must use bundled application assets only. The milestone must not introduce runtime downloads, network access, remote configuration, a disk cache, secrets, or API keys. [L4]
20. The production sprites and fallback must remain decorative under the existing semantic projection. Explorer and legal-destination semantics, activation behavior, announcements, coach behavior, and disabled playback state must remain unchanged.
21. The milestone must preserve the existing air-ruins background, HUD hierarchy, localization, match controller behavior, Rust bridge contract, board configuration, rules, audio, and tactile feedback.

## Technical Decisions

1. Keep `RoundBoard` as the owner of board geometry, hit testing, semantics, overlay ordering, and playback composition. Preserve its public constructor and behavioral contract, while keeping the sprite-loading state under a stable element identity across snapshot, selection, and playback updates. The current conditional playback key must not recreate the loader state; playback tests must observe `RoundBoard.playback` rather than use widget identity as the playback signal. [L1]
2. Introduce one small asynchronous sprite-loading Test Seam that completes with either a complete decoded five-image set or a controlled failure. An unresolved completion represents every internal partial-loading state, and no partial image collection crosses the seam. Production uses the Flutter asset bundle, while widget and device tests may inject deterministic loading outcomes without network or API access. [L4] [L5]
3. Represent readiness as one complete sprite-set value rather than five independently visible futures. Partial success is not available for rendering. [L4]
4. Keep the current procedural explorer and foothold paths as the fallback, with the minimum hole-fragment addition required by this Spec. Do not create a second generalized rendering framework. [L1] [L4]
5. Load and retain the sprite set for the board lifecycle, ignore stale asynchronous completion after disposal, and release any explicitly owned decoded image resources exactly once. If loading fails after one or more images have decoded, release those partial resources before completing with failure.
6. Declare the sprite directory through `pubspec.yaml` and do not hand-edit generated asset code.
7. Add no package dependency. Flutter's bundled asset and image APIs are sufficient for five static images.
8. Preserve existing overlay and playback math. Static sprites replace the body and tile paint operations but do not introduce a new animation timeline. [L2]

## Testing Strategy

1. Use test-driven development for sprite loading, state mapping, atomic readiness, fallback behavior, overlay order, playback transitions, and lifecycle cleanup.
2. Add an asset-integrity test that reads the exact five production paths through Flutter's asset bundle, decodes each PNG, verifies the expected dimensions, and proves that each file contains transparent pixels. [L5]
3. Before trusting the new asset-integrity check, temporarily point one test entry at a missing fixture and confirm that the check fails with the expected asset path, then restore the production path and confirm the pass.
4. Use an unresolved sprite-loader completion to prove that the complete procedural fallback remains visible throughout loading, then prove that a complete five-image result switches the set atomically, a controlled failure keeps the fallback and calls `FlutterError.reportError` exactly once, and a stale completion cannot update a disposed board. Test the production loader separately to prove that a failure after partial decoding disposes every image it owns without publishing a partial set. [L4] [L5]
5. Extend focused board rendering tests to cover Azure and Ember non-color silhouettes, intact and damaged footholds, collapsed-hole fragments around visible void, cell gutters, selection, normal-move markers, occupied Push rings, normal movement, Push displacement, fall playback, tile transitions, and reduced motion. [L1] [L2] [L3] [L5]
6. Preserve and run the existing geometry, tap-up cancellation, semantics activation, announcement, accessibility, responsive-layout, and playback regression tests. A green property test is evidence only for the mapping or semantics it inspects, not for the final rendered art.
7. Add a deterministic device integration fixture that mounts the real match surface with the production sprite loader. Its fake rules engine must return a snapshot containing both explorer factions and all three foothold states plus legal moves that lead from one Azure explorer to one empty normal destination and one Ember-occupied Push destination. The fixture must tap the Azure explorer through the real match interaction path so selection and both destinations become visible; it must not fabricate those Flutter-owned states inside `GameSnapshot`. [L5]
8. Run the deterministic fixture on one compact iOS Simulator and one tall Android Emulator through a screenshot-aware `flutter drive` driver. The integration test must use `IntegrationTestWidgetsFlutterBinding.takeScreenshot`, including `convertFlutterSurfaceToImage` on Android, and `test_driver/production_sprite_scene_driver.dart` must write the returned PNGs under `build/screenshots/production-sprite-set/` with platform-specific names. Inspect faction distinction, terrain progression, visible central void, fragment readability, board gutters, overlay ordering, background cohesion, and absence of cell-scale clipping in both saved PNGs. [L5]
9. Do not write to Andrew's daily iPhone as part of the default milestone. Any later install or launch on that phone requires a separate action-specific announcement and approval. [L5]
10. Run the focused Flutter view tests and the full repository gate. `merry run check` inspects formatting, analysis, unit and widget coverage, Rust formatting, Rust linting, Rust tests, and Trunk checks; it does not establish the actual iOS or Android sprite rendering, which comes from the device fixture and screenshot inspection. [L5]

Minimum verification commands:

```sh
flutter pub get
flutter test test/game/view
merry run check
npx cspell lint --config cspell.json --no-progress --quiet 'docs/specs/0001-production-sprite-set/**/*.md' assets/images/sprites/README.md
flutter drive --driver=test_driver/production_sprite_scene_driver.dart --target=integration_test/production_sprite_scene_test.dart -d <ios-simulator-id> --flavor development
flutter drive --driver=test_driver/production_sprite_scene_driver.dart --target=integration_test/production_sprite_scene_test.dart -d <android-emulator-id> --flavor development
```

## Out of Scope

- Frame animation, sprite atlases, directional explorer variants, persistent facing state, skins, alternate faction art, and a generalized sprite configuration system are out of scope. [L2]
- New backgrounds, board themes, HUD changes, visible copy, navigation, settings, account state, online play, analytics, sound, and tactile-feedback changes are out of scope.
- Rust rules, bridge APIs, board topology, starting pieces, tile-state semantics, legal-move calculation, Push resolution, fall direction, match state, and canonical hashes are out of scope. [L1]
- Runtime asset downloads, remote storage, remote configuration, new packages, API keys, and Web-specific visual certification are out of scope. [L4]
- Physical daily-iPhone validation is out of scope unless separately approved. [L5]

## Follow-Ups

- A later animation milestone may add explicitly specified frame animation only after static production sprites have been validated in play.
- A later board-configuration milestone may connect alternative board metadata to art selection without changing the contracts in this Spec.
