---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the production sprite milestone replace both explorer and foothold painter visuals while leaving rules, board geometry, interaction, semantics, playback, and the air-ruins background unchanged?

Recommended Answer:

- Replace Azure explorer, Ember explorer, intact foothold, and damaged foothold visuals with production raster sprites.
- Keep a hole as exposed void with no sprite.
- Keep selection, move, Push, and resolution overlays in the painter.

Answer: "hole도 공중 유적의 부서져 비어있는 공간이니 부서진 바닥의 남은 부분은 보여야 할 것 같습니다. 진행해주세요."

Decision: Replace both explorers and all three foothold states with production sprites while preserving the existing rules and interaction contracts. A hole is a collapsed foothold whose central void remains visible while broken perimeter fragments show what remains of the air ruin.

Answer History:

- Initial recommendation: render a hole as exposed void with no sprite.
- Final answer: add a collapsed foothold sprite that retains broken floor fragments around the void.

Constraints:

- Hole fragments are decorative and must not look like a legal landing surface.
- The hole visual must not change tile legality, hit geometry, board geometry, or Rust ownership of state.
- Selection, move, Push, and resolution overlays remain independent from the production sprites.

### L2

Status: current

Question: Should the milestone use five static raster assets and leave movement, collision, and fall motion to the existing resolution playback?

Recommended Answer:

- Add `azure_explorer`, `ember_explorer`, `foothold_intact`, `foothold_damaged`, and `foothold_hole`.
- Keep the existing playback transformations and painter overlays.
- Do not add frame animation, a sprite atlas, or directional facing state.

Answer: "네 좋습니다."

Decision: Use exactly five static raster assets. Existing playback moves the explorer images as whole sprites, and existing painter overlays continue to communicate selection, moves, Pushes, impact, and tile transitions.

Negative Requirements:

- Do not add frame animation or a sprite atlas.
- Do not add directional variants, facing state, skins, or a generalized asset configuration system.

### L3

Status: current

Question: Should the five sprites be an original AI-generated set that matches the existing air-ruins background?

Recommended Answer:

- Match the painterly fantasy and post-storm twilight atmosphere of `air_ruins_twilight.png`.
- Use a neutral three-quarter top-down presentation without directional facing state.
- Keep Azure broad and rounded and Ember narrow and angular so they remain distinct without color.
- Show the same stone structure progressing from intact to cracked to collapsed.
- Use transparent PNGs without text, logos, watermarks, separate backgrounds, or third-party asset-pack content.
- Record the generation source and final prompt in the repository.

Answer: "네 좋습니다."

Decision: Produce one cohesive original AI-generated transparent PNG set that visually belongs to the current air-ruins scene, preserves non-color faction distinction, and records asset provenance in the repository.

### L4

Status: current

Question: What should the match show while the sprite set is decoding or when any bundled sprite cannot be decoded?

Recommended Answer:

- Show the procedural painter fallback until all five images are ready.
- Switch the complete set atomically so painter and production visuals never mix on the same board.
- Keep the procedural fallback for the session if any image fails.
- Report the error through Flutter's error path and make missing or corrupt assets fail an automated asset-loading test.
- Do not add runtime downloads, remote assets, a disk cache, or a new Retry surface.

Answer: "네 좋습니다."

Decision: Sprite loading is non-blocking and all-or-nothing. The board remains playable through an equivalent painter fallback during loading and after a decode failure, while automated checks treat missing or corrupt bundled assets as defects.

### L5

Status: current

Question: Should completion require automated asset and rendering coverage plus deterministic visual evidence from both native renderers?

Recommended Answer:

- Verify all five PNGs exist, decode, and contain transparency.
- Cover asset mapping, atomic switching, decode fallback, overlay order, semantics, hit geometry, reduced motion, and playback with focused tests.
- Add a deterministic device integration fixture that uses the production asset loader and visibly produces every sprite plus selection, move, and Push states.
- Review the fixture on a compact iOS Simulator and a tall Android Emulator.
- Run `merry run check`.
- Exclude Andrew's daily iPhone unless a separate device-write approval is obtained.

Answer: "네 좋습니다."

Decision: The milestone is complete only when focused automated checks pass and a deterministic exercised scene is visually reviewed through the actual iOS and Android Flutter renderers. The daily iPhone is not part of the default verification scope.
