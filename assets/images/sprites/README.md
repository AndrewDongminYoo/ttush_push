# Production Sprite Set

<!-- cspell:words chibi desaturated imagegen Lanczos landable unlandable -->

## Provenance

The five sprites were generated on 2026-08-26 with OpenAI's built-in `imagegen` tool for this repository.
`assets/images/air_ruins_twilight.png` was used only as the project's atmosphere, lighting, palette, material, and camera-reference image.
No third-party asset pack was used.

The selected source outputs were `exec-d84bd363-42ee-4c6d-bd6a-b6f9f844fad4.png` for Azure, `exec-fcc2d88d-cc49-4d00-942e-66f82d947d7c.png` for Ember, `exec-bec9f913-79d5-44fd-94eb-51279764fc43.png` for the intact foothold, `exec-f2fa6edb-e853-456c-82a8-016e7eca23d1.png` for the damaged foothold, and `exec-95edb866-8ecc-4923-ba68-84bc69ccc0f9.png` for the collapsed foothold.
Azure and Ember were selected as structural opposites: Azure has a broad rounded cloak while Ember has a narrow angular robe.
The three footholds share the intact structure's viewpoint, stone language, palette, and lighting, then progress from continuous to cracked to discontinuous.

## Selection and editing notes

Each asset was generated independently or edited from the approved intact foothold instead of being cut from a sprite sheet.
The approved Azure, Ember, and intact foothold outputs received an `imagegen` background-extraction edit that preserved the selected artwork while replacing the generated checker field with alpha transparency.
The damaged and collapsed outputs retained a flattened near-white checker field after four distinct `imagegen` alpha-extraction attempts, so their generated artwork was preserved and the 247–255 background range was removed deterministically with ImageMagick's `-fuzz 5% -transparent white` operation.
After device-scale inspection exposed isolated remnants in the collapsed file, its alpha mask was filtered with 8-connected components to remove components smaller than 1,024 pixels while preserving the intended stone fragments.
All five selected outputs were trimmed, centered on a square transparent canvas, and resized with Lanczos filtering to 512 by 512 pixels.
Explorer bounds occupy at most 78% of the canvas dimension, while foothold bounds occupy at most 88%, leaving a stable cell gutter.
The final PNG metadata was checked for RGBA channels, 512 by 512 dimensions, transparent corner pixels, and a transparent center in `foothold_hole.png`.

## Final prompts

### Azure explorer

```plaintext
Use case: stylized-concept
Asset type: production 2D board-game explorer sprite for a Flutter game
Input image: Image 1 is a style, atmosphere, palette, material, and lighting reference only; do not edit or reproduce its scene.
Primary request: Create the Azure explorer as one original static full-body sprite, a small fantasy air-ruins traveler with a broad rounded silhouette, a round hood, and a wide rounded travel cloak. The silhouette must remain unmistakably broad and rounded at tiny board-cell scale without relying on color.
Scene/backdrop: genuinely transparent background and empty transparent canvas only; no floor, scenery, cloud, island, cell marker, or cast-shadow patch.
Style/medium: polished hand-painted fantasy game art with subtle painterly brush texture, matching the referenced post-storm twilight environment rather than vector art, pixel art, chibi toy rendering, or photorealism.
Composition/framing: square canvas; neutral three-quarter top-down board-game view; centered visual anchor; full body fully contained within the central 78% of the canvas; generous even transparent padding; upright neutral pose with no directional facing cue.
Lighting/mood: cool blue-violet twilight ambient light with a restrained warm peach rim light from the low horizon direction, matching Image 1.
Color palette: deep azure and indigo cloak, cool slate-blue shadows, restrained pale silver-blue trim; structural silhouette must work without the hue.
Materials/textures: weathered woven travel cloak with simplified large readable folds; no tiny accessories.
Constraints: output a single isolated sprite with actual alpha transparency; crisp clean outer edge with no halo; no text, letters, logos, watermark, background, border, UI, weapons, props, extra characters, face detail, animation frames, directional variants, or sprite sheet.
```

### Ember explorer

Image 1 in this prompt was the air-ruins reference, and Image 2 was the approved Azure sprite.

```plaintext
Use case: stylized-concept
Asset type: production 2D board-game explorer sprite for a Flutter game
Input images: Image 1 is the air-ruins atmosphere, palette, material, and lighting reference only. Image 2 is the approved Azure sprite and defines the shared painterly brushwork, neutral board-game viewpoint, edge quality, lighting direction, visual scale, and set cohesion; do not copy Azure's broad silhouette or blue identity.
Primary request: Create the Ember explorer as one original static full-body sprite, a small fantasy air-ruins traveler with a narrow angular silhouette, a pointed angular hood, sharp layered shoulders, and a slim straight robe. The silhouette must remain unmistakably narrow and angular at tiny board-cell scale without relying on color, clearly contrasting Image 2.
Scene/backdrop: genuinely transparent background and empty transparent canvas only; no floor, scenery, cloud, island, cell marker, or cast-shadow patch.
Style/medium: the same polished hand-painted fantasy game art and subtle painterly brush texture as Image 2, visually belonging to Image 1; not vector art, pixel art, chibi toy rendering, or photorealism.
Composition/framing: square canvas; neutral three-quarter top-down board-game view matching Image 2; centered visual anchor; full body fully contained within the central 78% of the canvas; generous even transparent padding; upright neutral pose with no directional facing cue.
Lighting/mood: the same cool blue-violet twilight ambient light and restrained warm peach rim light from the low horizon direction as Images 1 and 2.
Color palette: deep ember crimson, burnt vermilion, and dark wine-red cloth with restrained warm copper trim; structural silhouette must work without the hue.
Materials/textures: weathered woven narrow robe with simplified large angular folds; no tiny accessories.
Constraints: output a single isolated sprite with actual alpha transparency; crisp clean outer edge with no halo; no text, letters, logos, watermark, background, checkerboard, border, UI, weapons, props, extra characters, face detail, animation frames, directional variants, or sprite sheet.
```

### Intact foothold

Image 1 in this prompt was the air-ruins reference, and Images 2 and 3 were the approved explorer sprites.

```plaintext
Use case: stylized-concept
Asset type: production 2D board-game terrain sprite for a Flutter game
Input images: Image 1 defines the air-ruins atmosphere, ancient architecture, twilight palette, stone material, and lighting. Images 2 and 3 define the approved painterly brushwork, edge quality, lighting direction, visual scale, and production-set cohesion; do not include the explorers.
Primary request: Create the intact foothold as one original isolated ancient air-ruin floor slab, a sturdy square-ish floating stone platform with a clear unbroken landing surface, beveled thickness, a few large readable masonry seams, and restrained carved geometric ruin motifs.
Scene/backdrop: genuinely transparent background and empty transparent canvas only; no sky, cloud, island, floor plane, cell marker, or cast-shadow patch.
Style/medium: polished hand-painted fantasy game art with subtle painterly brush texture matching the approved explorer sprites and Image 1; not vector art, pixel art, miniature toy rendering, or photorealism.
Composition/framing: square canvas; neutral three-quarter top-down board-game view; centered visual anchor; platform fully contained within the central 88% of the canvas with an even transparent gutter on every side; no directional rotation that implies movement.
Lighting/mood: cool blue-violet twilight ambient light with restrained warm peach rim light from the same low horizon direction as the explorer set.
Color palette: weathered cool gray-blue limestone, desaturated lavender shadows, subtle pale stone edges, restrained warm rim highlights.
Materials/textures: ancient chipped stone edges and large readable worn facets; the top landing surface remains continuous and structurally intact.
Constraints: output a single isolated sprite with actual alpha transparency; crisp clean outer edge with no halo; no explorer, character, text, letters, logos, watermark, background, checkerboard, border, UI, grass, flowers, props, destination marker, cracks across the surface, missing chunks, animation frames, variants, or sprite sheet.
```

### Damaged foothold

Image 1 in this prompt was the approved intact foothold.

```plaintext
Use case: precise-object-edit
Asset type: damaged production 2D board-game terrain sprite for a Flutter game
Input image: Image 1 is the approved intact foothold. Preserve its exact camera angle, centered placement, overall footprint, transparent canvas, painterly brushwork, stone palette, lighting direction, carved motifs, beveled thickness, and visual scale.
Primary request: Transform only the structural condition from intact to visibly damaged. Add two or three deep, broad, readable cracks across the landing surface, chip away two or three substantial edge chunks, expose a few broken stone faces, and add restrained rubble not separated far from the slab. Keep most of the top surface continuous and clearly landable.
Scene/backdrop: preserve genuine alpha transparency and the empty transparent canvas; no replacement background, checkerboard, sky, cloud, island, floor plane, cell marker, or cast-shadow patch.
Style/medium: preserve the same polished hand-painted fantasy game art and subtle painterly brush texture.
Composition/framing: preserve the same neutral three-quarter top-down board-game view, centered anchor, even transparent gutter, and non-directional orientation.
Lighting/mood: preserve the same cool blue-violet twilight ambient light and restrained warm peach rim light.
Constraints: one isolated damaged foothold sprite with actual alpha transparency; crisp clean outer edge with no halo; no explorer, character, text, letters, logos, watermark, background, checkerboard, border, UI, grass, flowers, props, destination marker, central hole, total collapse, animation frames, variants, or sprite sheet. The result must be obviously damaged by silhouette and large cracks, not by color alone, while remaining a valid continuous landing surface.
```

### Collapsed foothold

Image 1 in this prompt was the approved intact foothold.

```plaintext
Use case: precise-object-edit
Asset type: collapsed hole production 2D board-game terrain sprite for a Flutter game
Input image: Image 1 is the approved intact foothold. Preserve its exact camera angle, centered placement, overall outer footprint, painterly brushwork, stone palette, lighting direction, carved motif language, beveled thickness, and visual scale.
Primary request: Transform the intact foothold into a clearly unlandable collapsed hole state. Remove roughly the central 70% of the landing surface completely. Leave only four or five separated perimeter corner and edge stone fragments whose broken inner faces point toward a large empty center. The fragments must be discontinuous: no complete ring, no bridge, no continuous landing surface, and no central stone.
Scene/backdrop: transparent empty canvas only. The large center between fragments and everything outside them must be transparent, with no dark pit fill, floor, sky, cloud, island, cell marker, or cast-shadow patch.
Style/medium: preserve the same polished hand-painted fantasy game art and subtle painterly brush texture as the intact foothold.
Composition/framing: preserve the same neutral three-quarter top-down board-game view, centered anchor, even gutter, and non-directional orientation.
Lighting/mood: preserve the same cool blue-violet twilight ambient light and restrained warm peach rim light.
Constraints: one isolated group of collapsed perimeter fragments; the empty center must dominate and remain readable at tiny board-cell scale; crisp clean fragment edges; no explorer, character, text, letters, logos, watermark, checkerboard, visible background, border, UI, grass, flowers, props, destination marker, intact center, continuous platform, animation frames, variants, or sprite sheet.
```
