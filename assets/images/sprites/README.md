# Production Sprite Set

<!-- cspell:words desaturated imagegen landable Lanczos orthographic recenter srgba -->

## Active top-down set

The active `ProductionSpriteSet` uses `azure_explorer_top_down.png`, `ember_explorer_top_down.png`, `foothold_intact.png`, `foothold_damaged.png`, and `foothold_hole.png`.
OpenAI's built-in `imagegen` tool generated the original selected sources on 2026-08-31 and the replacement damaged source on 2026-09-01.
No third-party asset pack was used.

The selected intact, damaged, and collapsed foothold sources are `exec-14150cc0-00a8-45db-8714-b31a538b5bad.png`, `exec-af903cfa-fe60-42ca-8043-682ca3da8b65.png`, and `exec-6d71f6db-7669-4426-8e63-6cf4dad791f1.png`.
The selected Azure source is `exec-1d826f3e-fde1-4459-8271-37efde206fd9.png`, which extracted genuine alpha from the high-angle base `exec-b77439d4-550b-4910-86ee-e591a3cb2c21.png`.
The selected Ember source is `exec-476cce73-e2c3-4217-8a89-14e07b8439e4.png`, which extracted genuine alpha from the high-angle base `exec-d0b49152-757c-4238-80ce-51eb6f60d59d.png`.

The footholds use one orthographic square camera and no visible outer side wall.
The explorers use one elevated game-board camera so the hood and shoulders read before the foreshortened body.
The first generated five-sprite set remains under `assets/images/reference/match-visual-cohesion-v1/` for future screenshots and other external content.

## Active processing and checks

ImageMagick derived each foothold crop from alpha values at or above 50 percent, resized the crop to a 420 by 420-pixel square, centered it on a transparent 512 by 512 canvas, and stripped nonessential metadata.
For the replacement damaged source, ImageMagick cropped the 1,044-pixel source square at offset 106,103, resized it to 420 by 420 pixels, centered it on the 512-pixel canvas, copied the preceding damaged sprite's alpha mask, and stripped nonessential metadata.
ImageMagick resized each explorer to fit a 320 by 340-pixel content box and centered it on the same transparent canvas.
Each active asset is a 512 by 512 PNG with sRGBA channels.
The collapsed foothold's alpha mask was filtered with 8-connected components to remove detached components smaller than 1,024 pixels.
The collapsed foothold has a transparent canvas-center pixel.
The asset tests verify the active paths, dimensions, transparency, matched square foothold footprints, connected collapsed rim, damaged fracture contrast, and the solid damaged center region after a 64-pixel decode.
An ImageMagick pixel check verifies the transparent center.

## Active generation prompts

### Azure top-down explorer

```plaintext
Use case: stylized-concept
Asset type: production 2D board-game character sprite for a Flutter game
Input images: Image 1 is the Azure character identity, costume, palette, and silhouette reference. Image 2 is the companion-set proportion and rendering reference only.
Primary request: Redraw Azure as the same original compact super-deformed explorer, but for an orthographic top-down board. Replace the frontal full-body portrait view with a clearly elevated high-angle game-board view, roughly 65 to 70 degrees downward: the top of the rounded hood and shoulders are prominent, the face is only partly visible, the torso and legs are foreshortened, and the boots are small beneath the body. It must read as a character occupying a square tile, not a portrait pasted over it.
Scene/backdrop: genuinely transparent background and otherwise empty transparent canvas.
Style/medium: preserve the polished hand-painted fantasy game art, simplified readable forms, deep azure and indigo cloth, pale silver trim, cool twilight ambient light, and restrained warm peach rim light.
Composition/framing: square canvas; one compact projected silhouette centered in the central 58 percent; generous equal transparent padding; neutral static pose; no directional facing cue; same visual mass expected for a companion Ember sprite.
Constraints: preserve Azure's rounded hood and short rounded cape; one isolated character only; no tile; no platform; no floor; no cast-shadow patch; no scenery; no weapon; no prop; no text; no letters; no logo; no watermark; no border; no UI; no extra character; no sprite sheet; no animation frame; actual alpha transparency.
```

### Ember top-down explorer

```plaintext
Use case: stylized-concept
Asset type: production transparent 2D board-game character sprite
Input images: Image 1 is the Ember identity, angular costume, palette, and silhouette reference. Image 2 is the exact companion camera, projected scale, pose, lighting, rendering, and SD proportion reference.
Primary request: Redraw Ember as the companion to Image 2 in the same clearly elevated high-angle game-board view, roughly 65 to 70 degrees downward. The top of Ember's angular hood and squared shoulders are prominent, the face is only partly visible, the torso and legs are foreshortened, and the boots are small beneath the body. It must read as a character occupying a square tile, not a frontal portrait pasted over it.
Scene/backdrop: genuine alpha transparency and otherwise empty canvas.
Style/medium: match Image 2's polished hand-painted fantasy rendering and visual mass while preserving deep ember crimson, muted burgundy, warm charcoal, restrained pale brass trim, and the angular hood and short coat from Image 1.
Composition/framing: one compact projected silhouette centered at the same scale and location as Image 2; generous equal transparent padding; neutral static pose; no directional facing cue.
Constraints: RGBA PNG with alpha-zero corners; one isolated character only; no checkerboard; no opaque background; no tile; no platform; no floor; no cast-shadow patch; no scenery; no weapon; no prop; no text; no logo; no watermark; no border; no UI; no extra character; no sprite sheet; no animation frame.
```

The final Azure and Ember sources apply a `background-extraction` edit that removes only the generated checkerboard, preserves the selected character artwork, and encodes the exterior as genuine alpha transparency.

### Intact top-down foothold

```plaintext
Use case: stylized-concept
Asset type: production transparent 2D board-game terrain sprite for a Flutter game
Primary request: Create one intact orthographic top-down square foothold made from ancient pale slate paving stones. The four outer edges are parallel to the square canvas. The tile is seen directly from above with a flat landable surface, no visible front wall, no visible side wall, and no slab thickness.
Scene/backdrop: actual alpha transparency outside the stone object. Leave the transparent area empty. Do not draw, paint, or visualize a checkerboard.
Style/medium: polished hand-painted 2D fantasy game art; broad readable stone planes; sparse low-contrast seams; simplified forms; no glossy toy treatment.
Composition/framing: square canvas; centered square footprint filling about 76 percent of the canvas; generous equal transparent padding on all four sides.
Lighting/mood: cool blue-violet twilight ambient light with restrained warm peach edge light.
Color palette: pale weathered slate, desaturated blue-gray crevices, restrained warm stone edges.
Constraints: output an RGBA PNG with alpha-zero corner pixels; one isolated intact tile only; no perspective; no diamond; no trapezoid; no character; no floor; no shadow patch; no scenery; no debris; no text; no letters; no logo; no watermark; no border; no UI; no extra tile; no runes; no glow; no checkerboard.
```

### Damaged top-down foothold

```plaintext
Make a surgical in-place edit of this exact game sprite. DO NOT REDRAW, ROTATE, FLATTEN, RESTYLE, RESCALE, RECENTER, OR CHANGE THE SILHOUETTE. The existing visible front and side walls, foreshortened square top, outer contour, masonry blocks, palette, highlights, shadows, transparency, and every other visual element must remain visually identical. Change only the existing cracks on the top walkable surface: add two dark branching crack arms so there are three clearly readable fracture paths at 64-pixel scale. Add no hole and remove no major stone. The exact center remains filled by opaque stone. Do not add moss, dirt, debris, separated pieces, scenery, checkerboard, ground, text, characters, symbols, glow, frame, or background. Return the same isolated transparent RGBA sprite with only the crack edit.
```

### Collapsed top-down foothold

```plaintext
Use case: stylized-concept
Asset type: production transparent 2D board-game terrain sprite for a Flutter game
Primary request: Create one collapsed-hole orthographic top-down square foothold made from ancient pale slate paving stones. A large irregular opening is completely absent through the center, leaving one connected square outer rim of broad readable broken stone sections. Both the exterior and the entire center opening must contain no pixels and reveal actual alpha transparency. The four outer edges are parallel to the square canvas. The tile is seen directly from above with no visible outer front wall, side wall, or slab thickness.
Scene/backdrop: actual alpha transparency outside the stone object and inside the center hole. Leave both transparent regions empty. Do not draw, paint, or visualize a checkerboard or black void.
Style/medium: polished hand-painted 2D fantasy game art; broad readable stone planes; sparse low-contrast seams; simplified forms; no glossy toy treatment.
Composition/framing: square canvas; centered square outer footprint filling about 76 percent of the canvas; generous equal transparent padding on all four sides.
Lighting/mood: cool blue-violet twilight ambient light with restrained warm peach edge light.
Color palette: pale weathered slate, desaturated blue-gray crevices, restrained warm stone edges.
Constraints: output an RGBA PNG with alpha-zero corner pixels and an alpha-zero center pixel; one isolated collapsed tile only; no perspective; no diamond; no trapezoid; no painted center; no detached debris; no character; no floor; no shadow patch; no text; no logo; no watermark; no border; no extra tile; no checkerboard.
```

## Reference v1 provenance

The five production sprites were generated on 2026-08-31 with OpenAI's built-in `imagegen` tool for this repository.
No third-party asset pack was used.

The selected source outputs are `exec-c989573b-f018-4161-b8f8-0db5304f8a84.png` for Azure, `exec-2c98197b-d05e-4bb6-b8a7-4dde48fefcd9.png` for Ember, `exec-1a6dc18a-a9dd-41ad-9ff3-aa098b1503a3.png` for the intact foothold, `exec-42dce2a5-f04b-44f0-90f9-546f602cd56b.png` for the damaged foothold, and `exec-524a61d5-fecf-43da-998d-7203214abc4a.png` for the collapsed foothold.
The damaged foothold was edited from the selected intact source.
Azure and Ember share a compact super-deformed explorer proportion while their rounded and angular outer silhouettes remain distinct.
The footholds use one pale slate, twilight-lit stone language that progresses from intact, to cracked, to a transparent central collapse.

## Reference v1 processing and checks

ImageMagick trimmed each selected RGBA source, centered it on a transparent square canvas, and stripped nonessential metadata.
The explorers were resized to a 390-pixel content height.
The footholds were resized to fit a 440 by 410-pixel content box.
Each final asset is a 512 by 512 PNG with sRGBA channels.
The collapsed foothold's alpha mask was filtered with 8-connected components to remove detached components smaller than 1,024 pixels.
The collapsed foothold has a transparent pixel at its canvas center.

## Reference v1 generation prompts

### Azure explorer

```plaintext
Use case: stylized-concept
Asset type: production 2D board-game explorer sprite for a Flutter game
Primary request: Create one original Azure expedition character as a static super-deformed human-like explorer. The character has a large rounded hood, a compact body, a short rounded travel cape, practical boots, and a calm neutral full-body pose. This is a board-game piece, not a portrait.
Scene/backdrop: genuinely transparent background and otherwise empty transparent canvas only.
Style/medium: polished hand-painted 2D fantasy game art with simplified readable forms, subtle painterly texture, and no glossy toy or pixel-art treatment.
Composition/framing: square canvas, neutral three-quarter top-down game-board viewpoint, centered visual anchor, full body contained in the central 72 percent of the canvas, generous even transparent padding, no directional facing cue.
Lighting/mood: cool blue-violet twilight ambient light with a restrained warm peach rim light, matching an ancient air-ruins sky at dusk.
Color palette: deep azure and indigo fabric, cool slate shadows, restrained pale silver trim.
Materials/textures: woven cloth, soft leather boots, simple large folds, no tiny accessories.
Constraints: actual alpha transparency; one isolated character only; no floor, scenery, clouds, island, cell marker, cast-shadow patch, weapon, prop, text, letters, logos, watermark, background, border, UI, extra character, animation frame, directional variant, sprite sheet, excessive runes, glow effects, or fake chrome.
```

### Ember explorer

```plaintext
Use case: stylized-concept
Asset type: production 2D board-game explorer sprite for a Flutter game
Primary request: Create one original Ember expedition character as a static super-deformed human-like explorer. The character has a large angular hood, a compact body, a short angular travel coat with squared shoulders, practical boots, and a calm neutral full-body pose. This is a board-game piece, not a portrait. Match the same visual mass and large-head compact-body ratio as a companion Azure explorer in the same set, while keeping this silhouette clearly more angular.
Scene/backdrop: the PNG must contain an actual alpha channel. The area outside the isolated character must be fully transparent pixels. Do not render a checkerboard or any visual representation of transparency.
Style/medium: polished hand-painted 2D fantasy game art with simplified readable forms, subtle painterly texture, and no glossy toy or pixel-art treatment.
Composition/framing: square canvas, neutral three-quarter top-down game-board viewpoint, centered visual anchor, full body contained in the central 72 percent of the canvas, generous even transparent padding, no directional facing cue.
Lighting/mood: cool blue-violet twilight ambient light with a restrained warm peach rim light, matching an ancient air-ruins sky at dusk.
Color palette: deep ember crimson and muted burgundy fabric, warm charcoal shadows, restrained pale brass trim.
Materials/textures: woven cloth, soft leather boots, simple large folds, no tiny accessories.
Constraints: one isolated character only; no floor, scenery, clouds, island, cell marker, cast-shadow patch, weapon, prop, text, letters, logos, watermark, background, border, UI, extra character, animation frame, directional variant, sprite sheet, excessive runes, glow effects, fake chrome, or checkerboard.
```

### Intact foothold

```plaintext
Use case: stylized-concept
Asset type: production 2D board-game terrain sprite for a Flutter game
Primary request: Create one original intact foothold tile: a compact square floating slab of ancient pale slate stone, seen from a neutral three-quarter top-down game-board viewpoint. The tile must have a stable, simple silhouette with a broad landable top surface and a visible but compact stone thickness. It belongs under the Azure and Ember super-deformed explorer sprites in the same painterly fantasy set.
Scene/backdrop: genuinely transparent background and otherwise empty transparent canvas only.
Style/medium: polished hand-painted 2D fantasy game art with simplified readable forms, subtle painterly texture, and no glossy toy or pixel-art treatment.
Composition/framing: square canvas, centered tile, top surface filling about 72 percent of the canvas, generous even transparent padding, no directional facing cue.
Lighting/mood: cool blue-violet twilight ambient light with a restrained warm peach rim light, matching an ancient air-ruins sky at dusk.
Color palette: pale weathered slate, desaturated blue-gray shadows, restrained warm stone edges.
Materials/textures: broad readable stone planes, small edge chips, sparse low-contrast seams, no tiny debris.
Constraints: actual alpha transparency; one isolated intact tile only; no character, no floor, scenery, clouds, island, cell marker, cast-shadow patch, text, letters, logos, watermark, background, border, UI, extra tile, animation frame, directional variant, sprite sheet, excessive runes, glow effects, or fake chrome.
```

### Damaged foothold

```plaintext
Use the attached intact foothold tile as the exact composition, camera, material, lighting, and transparent-canvas reference. Transform it into the damaged state from the same production board-game terrain set. Preserve its square footprint, broad landable top surface, floating stone thickness, centered scale, generous transparent padding, pale slate and blue-gray palette, and restrained warm rim light. Add only a single clear shallow diagonal fracture and a few modest chipped corners; it must remain visibly intact and landable, with no missing center and no debris. Keep the same simple readable hand-painted fantasy finish. Deliver one isolated damaged tile on a genuinely transparent background. Do not add characters, floor, scenery, clouds, island, cell marker, cast-shadow patch, text, letters, logos, watermark, UI, extra tile, animation frame, directional variant, sprite sheet, runes, glow effects, border, or fake chrome.
```

### Collapsed foothold

```plaintext
Use case: stylized-concept
Asset type: production 2D board-game terrain sprite for a Flutter game
Primary request: Create one original collapsed-hole foothold tile from a matched set of ancient floating stone board tiles. The object is a compact square pale slate slab in a neutral three-quarter top-down game-board view. Its broad outer footprint has a large irregular opening through the center, leaving a stable broken stone rim of large readable fragments. The center opening must be completely absent, so it reveals only transparency. This is a board-game tile, not an environment illustration.
Scene/backdrop: the PNG must contain an actual alpha channel. The area outside the tile and inside its center hole must be fully transparent pixels. Do not render a checkerboard, black void, painted background, or any visual representation of transparency.
Style/medium: polished hand-painted 2D fantasy game art with simplified readable forms, subtle painterly texture, and no glossy toy or pixel-art treatment.
Composition/framing: square canvas, centered tile, outer footprint filling about 72 percent of the canvas, generous even transparent padding, no directional facing cue.
Lighting/mood: cool blue-violet twilight ambient light with a restrained warm peach rim light, matching an ancient air-ruins sky at dusk.
Color palette: pale weathered slate, desaturated blue-gray shadows, restrained warm stone edges.
Materials/textures: broad readable stone planes, few large fractured edges, no tiny debris.
Constraints: one isolated collapsed tile only; no character, floor, scenery, clouds, island, cell marker, cast-shadow patch, text, letters, logos, watermark, background, border, UI, extra tile, animation frame, directional variant, sprite sheet, runes, glow effects, fake chrome, or checkerboard.
```
