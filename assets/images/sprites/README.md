# Production Sprite Set

<!-- cspell:words desaturated imagegen landable Lanczos orthographic recenter srgba -->

## Active directional set

The active `ProductionSpriteSet` uses `azure_explorer_{up,down,left,right}.png`, `ember_explorer_{up,down,left,right}.png`, `foothold_intact.png`, `foothold_damaged.png`, and `foothold_hole.png`.
OpenAI's built-in `imagegen` tool generated the original selected sources on 2026-08-31, the replacement damaged source on 2026-09-01, and the directional explorer sources on 2026-09-01.
No third-party asset pack was used.

The selected intact, damaged, and collapsed foothold sources are `exec-14150cc0-00a8-45db-8714-b31a538b5bad.png`, `exec-af903cfa-fe60-42ca-8043-682ca3da8b65.png`, and `exec-6d71f6db-7669-4426-8e63-6cf4dad791f1.png`.
The selected Azure source is `exec-1d826f3e-fde1-4459-8271-37efde206fd9.png`, which extracted genuine alpha from the high-angle base `exec-b77439d4-550b-4910-86ee-e591a3cb2c21.png`.
The selected Ember source is `exec-476cce73-e2c3-4217-8a89-14e07b8439e4.png`, which extracted genuine alpha from the high-angle base `exec-d0b49152-757c-4238-80ce-51eb6f60d59d.png`.
The directional Azure sources are `exec-b758191b-01db-4dc9-9773-c66e605a3485.png`, `exec-91e2f909-3fd2-4547-813c-2b149834f581.png`, `exec-ee71f87b-9ae1-4b5d-8edc-114880b85ea8.png`, and `exec-02fd056e-9f56-4bc4-986e-329f9612eba3.png` in up, down, left, and right order.
The directional Ember sources are `exec-4fc21ba1-535e-4c4e-8e1d-86571b34d5d9.png`, `exec-d02bebdf-1bbd-441a-9479-70b313635146.png`, `exec-525097ee-6463-4a4f-b300-b1b83ae82991.png`, and `exec-ac9838ea-126c-450a-a5e4-49b9092358fc.png` in up, down, left, and right order.
The approved turnaround reference is `assets/images/reference/directional-explorer-sprites-v1/azure_turnaround_reference.png`.

The footholds use one orthographic square camera and no visible outer side wall.
The explorers use one elevated game-board camera so the hood and shoulders read before the foreshortened body.
The first generated five-sprite set remains under `assets/images/reference/match-visual-cohesion-v1/` for future screenshots and other external content.

## Active processing and checks

ImageMagick derived each foothold crop from alpha values at or above 50 percent, resized the crop to a 420 by 420-pixel square, centered it on a transparent 512 by 512 canvas, and stripped nonessential metadata.
For the replacement damaged source, ImageMagick cropped the 1,044-pixel source square at offset 106,103, resized it to 420 by 420 pixels, centered it on the 512-pixel canvas, copied the preceding damaged sprite's alpha mask, and stripped nonessential metadata.
ImageMagick removes explorer-source alpha below 5 percent, trims the remaining bounds, resizes every directional explorer to a 340-pixel content height, centers it horizontally, and places its lowest visible pixel at y-coordinate 425 on the transparent 512-pixel canvas.
Each active asset is a 512 by 512 PNG with sRGBA channels.
The collapsed foothold's alpha mask was filtered with 8-connected components to remove detached components smaller than 1,024 pixels.
The collapsed foothold has a transparent canvas-center pixel.
The asset tests verify the active paths, dimensions, transparency, explorer height and foot anchors, matched square foothold footprints, connected collapsed rim, damaged fracture contrast, and the solid damaged center region after a 64-pixel decode.
An ImageMagick pixel check verifies the transparent center.

### Directional explorer integrity

| Team  | Direction | Source SHA-256                                                     | Active SHA-256                                                     |
| ----- | --------- | ------------------------------------------------------------------ | ------------------------------------------------------------------ |
| Azure | up        | `1c3b8a0f3fd9d2409cee11d874a0557e70f216da7de819fc4a64a54966a909bf` | `8af170300153881f75e1f3cc3624ae1c73f22a1ee76e2b86ab60b65d0250cbf4` |
| Azure | down      | `9d988937e7195bb2f5c5fa6e02bfd305ee9896460fdbf05a251bf0f5a57f7924` | `942ff51d8d6fd3aaba2a4271dacc2b10c8d9312f8d847c9ab9cadac7a83bc87f` |
| Azure | left      | `0d67b167b3b6507f010de5cd27241b26edbe8a0782b5c3b9d8c3a9fb9e5a3fa8` | `75a7a82fa6272ac5da3819d05b2bfecf6b2fffd27a94feb24681b6afd19ed97b` |
| Azure | right     | `ddacb50ad7d32fef22d1b89ff2d7442b71b420ff6b7ce7a66f8b8c6c224c8fe2` | `944c1ba8ff631c3c491ac5fee2c2ab1de8a0d89dca9398bc9655100c9eb4cbff` |
| Ember | up        | `802a07c316a43ce28f1cb9dfed10108452d5e2c6b0381161e26df301872027f7` | `a638796973ca27d96302f72e1daac92c1af6eb3db6d227d993b15db4cb1a4615` |
| Ember | down      | `de5ef2004069bec24520210d72749b9efc795c73a9f2c088f02dedc5bed59073` | `64e65febe1a1fde715743fbd659129940bb2c88ec7bb1eae1037d4417bc8c92a` |
| Ember | left      | `5d6da5adfbc6768d1f96209b164430056dcdaeb2633cc46c8f8db30ca9ae823c` | `a8ac8444048b8e28bf42c061bf49e7407ffee5898be95efa4bb86130775679c3` |
| Ember | right     | `191b157b452bf7ce127788f4254e70b42d63311a97eaa2958a1b84b93403c76f` | `07bd9d432dd73175c9b070147b33c4de592565d9b10545b816f68447b6a647cc` |

## Directional explorer generation prompt

The following template was run once for each team and each visual direction.
The direction clause named up, down, left, or right and described the matching canvas edge.
The Azure run used the approved turnaround and the active Azure top-down sprite as references.
The Ember run used the approved turnaround for camera and directional anatomy and the active Ember top-down sprite for team identity.

```plaintext
Create one production 2D board-game character sprite for the [TEAM] explorer facing VISUAL [DIRECTION], meaning the character looks toward the matching edge of the square canvas. Use the supplied 3-by-3 Azure turnaround only as the directional anatomy and fixed high-angle camera reference. Use the supplied active [TEAM] sprite as the exact team identity, palette, material, painterly finish, silhouette family, apparent height, and scale reference. Preserve the team's compact super-deformed body, hood and cloak or robe silhouette, trim, leather boots, cool blue-violet ambient light, and restrained warm peach rim light. Keep Ember's silhouette clearly angular and distinct from Azure. Output one isolated full-body character only on a genuine transparent background. Use a square canvas with the character centered horizontally, the lowest boot pixels aligned near 82 percent of canvas height, and generous even transparent padding. The camera, apparent character height, and ground anchor must match the active sprite so this can join one fixed four-direction set. No floor, cast shadow, scenery, cell marker, background color, border, grid, text, logo, watermark, weapon, prop, extra character, extra pose, sprite sheet, glow, or checkerboard.
```

## Foothold and previous neutral explorer prompts

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
