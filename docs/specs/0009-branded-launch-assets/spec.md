---
type: Spec
title: Branded Launch Assets
---

## Problem

The supported Android, iOS, macOS, and web targets still expose VGV or unbranded default artwork in their launcher icons, while Android, iOS, and web expose it during startup. [L1]
Those assets do not identify the air-ruins board or its Azure and Ember opponents. [L2]

## Proposed Outcome

Use the existing production scene and sprites to present one recognizable Ttush Push identity in every launcher and in each existing startup consumer. [L1] [L2]
Generate every density and flavor output from the same repository-owned composition. [L3] [L4]

## User Stories

1. As a player, I can recognize Ttush Push from its app icon before opening it.
2. As a player, I see the same visual identity while the app starts.
3. As a developer, I can regenerate and verify every platform asset from the current production artwork.

## Requirements

1. Compose the app icon from `air_ruins_twilight.png`, the active Azure and Ember top-down explorers, and `foothold_intact.png`. [L2]
2. Keep the app-icon source opaque, square, 1,024 by 1,024 pixels, and free of text, platform masks, or baked rounded corners. [L3]
3. Preserve readable Azure-blue and Ember-red regions after the production icon is reduced to 48 by 48 pixels. [L3]
4. Compose the launch mark from the same two explorers and foothold on a transparent 600 by 600-pixel canvas. [L3]
5. Present the launch mark on the existing dark scene family rather than the current white default background.
6. Replace the production icon consumers for Android, iOS, macOS, and web, and replace the startup consumers for Android, iOS, and web. [L1]
7. Remove the unused macOS launch-image set instead of adding a startup surface that the application does not consume. [L1]
8. Preserve the existing DEV and STG flavor indicators while replacing their VGV logo layer, and keep every Android adaptive foreground inside its central 264 by 264-pixel safe zone. [L4]
9. Generate density and flavor outputs through one repository script that fails clearly when ImageMagick or OxiPNG is unavailable. [L4]
10. Add no Flutter package, native dependency, generated runtime code, or image-model output. [L2] [L4]
11. Keep game rendering, rules, navigation, localization, and application state unchanged.

## Technical Decisions

Use the previewed composition with the intact foothold centered in the lower field and Azure and Ember above opposite sides.
The icon uses the existing air-ruins crop as its opaque background.
The launch mark omits that crop so Apple and Android can place it on a solid deep-navy background without a visible square edge.

Use ImageMagick because it is already installed locally and the repository already records ImageMagick processing for production sprites.
Use OxiPNG because the existing Trunk gate requires the generated PNG outputs to be losslessly optimized.
Commit the generated platform outputs because Xcode, Android resources, and web startup files consume them directly.
Do not add `flutter_launcher_icons`, `flutter_native_splash`, or another dependency for a deterministic composition that the existing tool can produce.

## Testing Strategy

1. Add one asset-contract test that decodes the current production icon and launch assets.
2. Confirm that the test fails because the VGV assets contain no readable Azure-blue or Ember-red regions.
3. Decode the new canonical icon at 48 pixels and require visible cool-blue and warm-red regions.
4. Verify the canonical dimensions, icon opacity, launch-mark transparency, platform output dimensions, Android day and night startup references, and the absence of the unused macOS launch-image set.
5. Verify that all Android adaptive foregrounds remain inside the safe zone and that both Apple flavor bundles retain their cyan environment badges.
6. Run the generator twice and confirm that the tracked asset hashes do not change on the second run.
7. Run `dart format`, the focused asset test, `flutter analyze`, representative Android and Apple builds, and `merry run check`.

## Acceptance Criteria

1. The focused asset regression fails against the current VGV icon or launch mark before implementation.
2. The canonical icon remains recognizable through both team-color checks at 48 pixels.
3. The launch mark contains transparent padding and both team colors.
4. Android, iOS, macOS, and web reference the branded icon outputs, while Android, iOS, and web reference the branded startup outputs.
5. Android applies the branded system splash in both day and night mode on API 31 or later.
6. DEV and STG launchers remain visibly distinct from production without leaving the Android adaptive-icon safe zone.
7. A second generator run produces identical tracked bytes.
8. `flutter analyze`, representative platform builds, and `merry run check` complete without a product failure.
9. One local adversarial review reports no unresolved findings.

## Out of Scope

- New character art, a standalone text logo, animated splash content, or store marketing screenshots.
- Changes to app names, bundle identifiers, package identifiers, versioning, or release metadata.
- A new asset-generation dependency or CI image-generation job.
- A custom macOS startup window when the current application has no launch-image consumer.
- Changes to gameplay, game screens, bridge code, or Rust rules.

## Verification

```shell
flutter test test/app/brand_assets_test.dart
tool/generate_brand_assets.sh
flutter analyze
flutter build apk --flavor production --debug --target lib/main_production.dart
flutter build ios --flavor production --debug --simulator --no-codesign --target lib/main_production.dart
merry run check
```
