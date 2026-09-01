# Branded Launch Assets

`app_icon.png` and `launch_mark.png` are deterministic composites of the active air-ruins background, Azure and Ember top-down explorers, and intact foothold.

Run the generator from the repository root after any source changes.

```shell
tool/generate_brand_assets.sh
```

The app icon uses an opaque 1,024 by 1,024-pixel canvas.
The launch mark uses a transparent 600 by 600-pixel canvas.
The generator derives Android density and flavor icons, Android launch artwork, Apple Icon Composer artwork, iOS launch images, and web icons from these two canonical files.
It requires ImageMagick for composition and OxiPNG for the same lossless optimization enforced by the project gate.

No image-model output was created for this identity.
The source art and its generation provenance remain documented in `assets/images/sprites/README.md` and the source commit history for `assets/images/air_ruins_twilight.png`.
