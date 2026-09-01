---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which default assets must be replaced?

Answer: The production Android launcher and launch drawable, iOS and macOS Icon Composer artwork, iOS launch images, and web icon and bootstrap assets still show the VGV unicorn or another unbranded default.

Decision: Replace app icons on Android, iOS, macOS, and web, replace the existing startup presentation on Android, iOS, and web, and delete the unused macOS launch-image set.

Source: Operator request and platform asset inspection on 2026-09-01.

### L2

Status: current

Question: What should define the product identity?

Answer: The repository already contains the approved air-ruins background, Azure and Ember explorers, and orthographic intact foothold.

Decision: Reuse those production assets in one icon composition instead of generating a separate logo style.

Source: `assets/images/air_ruins_twilight.png`, `assets/images/sprites/README.md`, and the active production sprite files on 2026-09-01.

### L3

Status: current

Question: How should the icon and launch screen differ?

Answer: A launcher needs an opaque square scene, while a launch screen needs a centered mark that does not expose square edges against its background.

Decision: Compose one opaque 1,024-pixel app icon and one transparent 600-pixel launch mark from the same three gameplay subjects.

Source: Current Android, Apple, and web consumers plus the 48-pixel composition preview on 2026-09-01.

### L4

Status: current

Question: How should generated platform files stay consistent?

Answer: More than forty density and flavor outputs consume the same artwork.

Decision: Keep one small ImageMagick and OxiPNG generator in `tool/`, commit its outputs, preserve the current DEV and STG indicators within each platform's icon constraints, and add no package dependency.

Source: Current platform directory structure and installed `/opt/homebrew/bin/magick` on 2026-09-01.

### L5

Status: current

Question: Does the project have an applicable precedent for branded launch assets?

Answer: `[no precedent found]`

Decision: The reuse-first source and deterministic generation record become the first project precedent for branded launch assets.

Source: Personal-account Oracle lookup for `ttush_push` on 2026-09-01.
