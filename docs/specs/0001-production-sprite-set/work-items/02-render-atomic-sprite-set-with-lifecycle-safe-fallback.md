---
type: Work Item
title: Render the atomic sprite set with a lifecycle-safe fallback
parent: ../spec.md
---

## What to build

Render the approved production sprites through the existing board while preserving Rust-authored state, board geometry, interaction, semantics, overlays, and resolution playback.
Add the smallest asynchronous loader boundary and lifecycle state needed for atomic readiness, failure fallback, and exact resource cleanup without introducing a generalized rendering framework.

## Required context

- `../spec.md` is the source of truth for loader behavior, stable element identity, sprite mapping, fallback behavior, overlay ordering, playback, and cleanup.
- `lib/game/view/round_board.dart` owns `BoardGeometry`, hit testing, semantics, procedural painting, overlay order, and playback composition.
- `lib/game/view/game_page.dart` currently applies a conditional playback key to `RoundBoard`; loader state must remain stable when playback starts and ends.
- `test/game/view/round_board_test.dart` provides the current pixel-sampling seam and fills omitted fixture coordinates with hole tiles, whose visual expectations intentionally change under this milestone.
- `test/game/view/game_page_test.dart` and `test/game/view/game_page_accessibility_test.dart` cover replay identity, interaction, semantics, announcements, and responsive behavior.
- `lib/src/rust/api.dart` is generated and read-only; `GameTileKind` and `GamePlayer` values must be consumed directly rather than reinterpreted.

## Acceptance criteria

- [x] One asynchronous loader seam completes with either a complete five-image sprite-set value or a controlled failure, and no partial collection becomes available for rendering.
- [x] The board shows only the complete procedural fallback while the loader remains unresolved and switches the complete sprite set in one frame after success.
- [x] Sprite-loader state remains stable across snapshot, selection, and playback updates, and playback tests observe `RoundBoard.playback` without using a changing widget key as state identity.
- [x] Any missing or undecodable sprite keeps the fallback for the remaining board session and calls `FlutterError.reportError` exactly once with the exception, stack trace, and sprite-loading context.
- [x] A failure after partial decoding disposes every image owned by that failed load exactly once and never publishes the partial set.
- [x] A completion that arrives after board disposal cannot update widget state, and every retained decoded image is disposed exactly once when its owner ends.
- [x] `GameTileKind.normal`, `GameTileKind.damaged`, and `GameTileKind.hole` select the three foothold sprites directly, while `GamePlayer.first` and `GamePlayer.second` select Azure and Ember directly.
- [x] The procedural fallback depicts intact, damaged, and collapsed terrain, including broken hole fragments around a visible central void.
- [x] Production footholds retain the existing cell gutter, explorers remain contained in their cells, and transparent pixels do not alter `BoardGeometry` or hit regions.
- [x] Selection, normal-move, occupied Push, impact, fall, and tile-transition effects remain above the sprites, including unchanged normal, Push, fall, and reduced-motion playback timing.
- [x] Existing semantic projection, activation, announcements, coach behavior, disabled playback input, responsive layout, and tap-up cancellation remain unchanged.
- [x] Focused loader, painter, game-page, accessibility, and lifecycle tests pass after formatting the explicitly changed Dart paths, and `flutter analyze` passes.

## Covers

- User Stories: 1-4
- Requirements: 6-21
- Technical Decisions: 1-8
- Testing Strategy: 1, 4-6
- Interview Ledger: L1-L5

## Blocked by

- `01-produce-and-certify-production-sprite-set.md`
