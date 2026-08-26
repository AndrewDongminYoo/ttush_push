---
type: Work Item
title: Produce and certify the production sprite set
parent: ../spec.md
---

## What to build

Produce and curate the five original production sprites as one cohesive set, declare them as bundled Flutter assets, document their provenance, and add an asset-integrity test that rejects missing or malformed files.
Keep this slice limited to the checked-in art contract and its direct automated verification; do not change board rendering yet.

## Required context

- `../spec.md` defines the exact filenames, dimensions, art direction, negative requirements, and fail-before-pass check.
- `../interview-ledger.md` records the approved collapsed-hole treatment and original AI-generated asset decision.
- `assets/images/air_ruins_twilight.png` is the lighting, atmosphere, and presentation reference for the complete set.
- `pubspec.yaml` currently declares assets explicitly and must remain dependency-neutral.
- `lib/gen/assets.gen.dart` is generated output and must not be edited by hand.

## Acceptance criteria

- [x] Exactly `azure_explorer.png`, `ember_explorer.png`, `foothold_intact.png`, `foothold_damaged.png`, and `foothold_hole.png` exist under `assets/images/sprites/` as 512 by 512 transparent PNGs with centered anchors.
- [x] Azure has a broad rounded silhouette, Ember has a narrow angular silhouette, and the distinction remains structural rather than color-only.
- [x] The three footholds depict one coherent stone structure progressing from intact to damaged to collapsed.
- [x] The collapsed foothold leaves most of the center transparent and retains discontinuous perimeter fragments that do not resemble a legal landing surface.
- [x] The five assets match the existing air-ruins background without text, logos, watermarks, scenic backgrounds, board markers, or third-party asset-pack content.
- [x] `assets/images/sprites/README.md` records the generation tool, generation date, final prompt, selection or editing notes, and the relationship between the final files.
- [x] `pubspec.yaml` declares `assets/images/sprites/`, `flutter pub get` succeeds, and any resulting lockfile change remains in the same implementation concern.
- [x] An asset-integrity test loads the exact five paths through Flutter's asset bundle, decodes each image, verifies 512 by 512 dimensions, and proves that every image contains transparent pixels.
- [x] The asset-integrity check is deliberately pointed at one missing fixture first and fails with that path before the production paths are restored and pass.
- [x] Focused asset tests and CSpell for the Spec folder and sprite README pass.

## Covers

- User Stories: 1-2
- Requirements: 1-8
- Technical Decisions: 6-7
- Testing Strategy: 2-3
- Interview Ledger: L1-L3, L5

## Blocked by

None - ready to start
