# Branded Launch Assets

`app_icon_artwork.png` is the approved palm-pushing illustration for the launcher icon.
`app_icon.png` is its deterministic 1,024-pixel canonical output.
`launch_mark.png` remains a deterministic composite of the active Azure and Ember top-down explorers and intact foothold.

Run the generator from the repository root after any source changes.

```shell
tool/generate_brand_assets.sh
```

The app icon uses an opaque 1,024 by 1,024-pixel canvas.
The launch mark uses a transparent 600 by 600-pixel canvas.
The generator derives Android density and flavor icons, Android adaptive background artwork, Android launch artwork, Apple Icon Composer artwork, iOS launch images, and web icons from these files.
It requires ImageMagick for composition and OxiPNG for the same lossless optimization enforced by the project gate.

OpenAI's built-in image generation tool created `app_icon_artwork.png` from the active Azure and Ember directional sprites on 2026-09-02.
The selected output is `exec-8936b702-9d11-4641-9032-6c69ed5688b5.png`.
The illustration shows both explorers as equal competitors who press both pairs of open palms together.
It excludes weapons, injury, falling, supernatural effects, text, and baked platform masks.
Android adaptive icons use the full illustration as their background layer so the wide action remains legible under platform masks.
Android development and staging icons add the existing DEV or STG badge inside the centered adaptive safe area.
