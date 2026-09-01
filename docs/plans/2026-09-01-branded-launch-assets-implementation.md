# Branded Launch Assets Implementation Plan

## Goal

Replace the VGV launcher and startup artwork with one deterministic composition of the existing air-ruins scene, Azure and Ember explorers, and intact foothold.

## Scope

- Add the approved Spec and Interview Ledger.
- Add one ImageMagick generator and its canonical branded sources.
- Replace Android, iOS, macOS, and web icon outputs and the existing Android, iOS, and web launch outputs.
- Delete the unused macOS launch-image set.
- Preserve the current DEV and STG environment indicators.
- Add one focused asset-contract test without a new dependency.

## Tasks

### 1. Establish the failing asset contract

Decode the current production Android icon and Apple launch mark through a Flutter test.
Require readable Azure-blue and Ember-red regions at the actual small icon scale.
Run only this test and confirm that the grayscale VGV assets fail.

### 2. Add the deterministic composition

Create one script that validates ImageMagick, OxiPNG, and the four existing source images.
Compose the opaque 1,024-pixel app icon and transparent 600-pixel launch mark.
Generate each existing platform density and flavor output from those two results.

### 3. Connect native and web consumers

Point Icon Composer bundles at the branded PNG layer while keeping their environment overlays.
Use the branded background and launch mark in Android day and night startup resources and in the iOS launch screen.
Delete the unconsumed macOS launch-image set instead of adding a custom startup window.
Replace the web icons and show the launch mark in the existing bootstrap surface.

### 4. Verify the artifacts

Run `dart format` on the focused test.
Run the asset test, generator idempotence check, `flutter analyze`, and representative production builds.
Inspect the 48-pixel icon, launch mark, adaptive safe-zone bounds, and flavor variants directly.

### 5. Run delivery gates

Run `merry run check` and inspect the complete diff.
Request one local adversarial review against `origin/main`.
Resolve every supported finding before the semantic commit and pull request.
